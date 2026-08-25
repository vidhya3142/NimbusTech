#!/usr/bin/env python3
"""Patch Ubuntu EC2 instances through SSM and verify kernel/OpenSSL state.

Default mode is dry-run. Use --execute to send commands and --reboot to reboot
instances after patching. The script deliberately uses tag/ID targeting instead
of blindly patching every managed instance in an account.
"""

import argparse
import sys
import time
from datetime import datetime, timezone

import boto3
from botocore.exceptions import BotoCoreError, ClientError


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--region", default="us-east-1")
    p.add_argument("--tag-key")
    p.add_argument("--tag-value")
    p.add_argument("--instance-id", action="append", dest="instance_ids")
    p.add_argument("--min-age-days", type=int, default=0)
    p.add_argument("--reboot", action="store_true")
    p.add_argument("--execute", action="store_true", help="Actually patch; otherwise dry-run")
    return p.parse_args()


def get_targets(ec2, ssm, args):
    filters = [{"Name": "instance-state-name", "Values": ["running"]}]
    if args.tag_key and args.tag_value:
        filters.append({"Name": f"tag:{args.tag_key}", "Values": [args.tag_value]})

    paginator = ec2.get_paginator("describe_instances")
    instances = []
    for page in paginator.paginate(Filters=filters):
        for reservation in page["Reservations"]:
            instances.extend(reservation["Instances"])

    wanted = set(args.instance_ids or [])
    managed = []
    for instance in instances:
        iid = instance["InstanceId"]
        if wanted and iid not in wanted:
            continue
        tags = {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
        if tags.get("Name"):
            continue
        launch = instance.get("LaunchTime")
        age_days = (datetime.now(timezone.utc) - launch).total_seconds() / 86400
        if age_days <= args.min_age_days:
            continue
        managed.append(iid)

    # Verify SSM is aware of the selected instances before attempting Run Command.
    if not managed:
        return []
    resp = ssm.describe_instance_information(
        Filters=[{"Key": "InstanceIds", "Values": managed}]
    )
    online = {x["InstanceId"] for x in resp["InstanceInformationList"] if x.get("PingStatus") == "Online"}
    return sorted(set(managed) & online)


def send_and_wait(ssm, instance_ids, commands, comment, timeout=900):
    resp = ssm.send_command(
        InstanceIds=instance_ids,
        DocumentName="AWS-RunShellScript",
        Parameters={"commands": commands},
        Comment=comment,
        TimeoutSeconds=timeout,
    )
    command_id = resp["Command"]["CommandId"]
    print(f"SSM command: {command_id}")

    deadline = time.time() + timeout + 60
    while time.time() < deadline:
        inv = ssm.list_command_invocations(CommandId=command_id, Details=True)
        statuses = {x["InstanceId"]: x["Status"] for x in inv["CommandInvocations"]}
        print(statuses)
        if statuses and all(s in {"Success", "Failed", "TimedOut", "Cancelled", "Undeliverable"} for s in statuses.values()):
            return command_id, statuses
        time.sleep(10)
    raise TimeoutError(f"SSM command {command_id} did not finish before timeout")


def main():
    args = parse_args()
    session = boto3.Session(region_name=args.region)
    ec2 = session.client("ec2")
    ssm = session.client("ssm")

    try:
        targets = get_targets(ec2, ssm, args)
    except (BotoCoreError, ClientError) as exc:
        print(f"Discovery failed: {exc}", file=sys.stderr)
        return 2

    print(f"Eligible SSM-online targets: {targets}")
    if not targets:
        return 0
    if not args.execute:
        print("DRY RUN: no commands sent. Re-run with --execute to patch.")
        return 0

    patch_commands = [
        "set -euo pipefail",
        "export DEBIAN_FRONTEND=noninteractive",
        "apt-get update",
        "apt-get -y dist-upgrade",
        "apt-get -y install --only-upgrade openssl",
        "dpkg-query -W -f='openssl=${Version}\\n' openssl || true",
        "uname -r",
        "test -f /var/run/reboot-required && echo REBOOT_REQUIRED || echo REBOOT_NOT_REQUIRED",
    ]
    _, patch_status = send_and_wait(ssm, targets, patch_commands, "NimbusTech critical CVE patch")
    if not all(v == "Success" for v in patch_status.values()):
        print("Patch command failed for one or more instances.", file=sys.stderr)
        return 3

    if args.reboot:
        reboot_commands = ["shutdown -r now"]
        try:
            send_and_wait(ssm, targets, reboot_commands, "NimbusTech kernel reboot")
        except Exception as exc:
            # A reboot can interrupt the Run Command transport; verify with a fresh command below.
            print(f"Reboot command ended with transport exception (expected during reboot): {exc}")
        time.sleep(45)

    verify_commands = [
        "set -euo pipefail",
        "echo KERNEL=$(uname -r)",
        "echo OPENSSL=$(dpkg-query -W -f='${Version}' openssl)",
        "test -f /var/run/reboot-required && echo REBOOT_REQUIRED || echo REBOOT_NOT_REQUIRED",
    ]
    _, verify_status = send_and_wait(ssm, targets, verify_commands, "NimbusTech CVE patch verification")
    if not all(v == "Success" for v in verify_status.values()):
        print("Verification failed for one or more instances.", file=sys.stderr)
        return 4

    print("Patch workflow completed. Re-run Inspector/SSM Inventory and verify the CVEs are closed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
