#!/usr/bin/env python3
"""Find unnamed EC2 instances older than 7 days in every enabled region.

Default is a dry run. With --execute, the script sends an SNS alert first and
stops only instances for which the SNS publish succeeded.
"""

import argparse
import json
from datetime import datetime, timedelta, timezone
from typing import Iterable

import boto3
from botocore.exceptions import BotoCoreError, ClientError


def regions_for(session) -> list[str]:
    ec2 = session.client("ec2", region_name="us-east-1")
    response = ec2.describe_regions(AllRegions=False)
    return sorted(r["RegionName"] for r in response["Regions"])


def instance_name(instance: dict) -> str | None:
    for tag in instance.get("Tags", []):
        if tag["Key"] == "Name":
            return tag["Value"]
    return None


def candidates(ec2, cutoff: datetime) -> list[dict]:
    paginator = ec2.get_paginator("describe_instances")
    found = []
    for page in paginator.paginate(
        Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
    ):
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                if instance_name(instance):
                    continue
                if instance["LaunchTime"] < cutoff:
                    found.append(instance)
    return found


def sns_client_from_topic(session, topic_arn: str):
    topic_region = topic_arn.split(":")[3]
    return session.client("sns", region_name=topic_region)


def alert(sns, topic_arn: str, region: str, instance: dict, age_days: float, execute: bool) -> bool:
    message = {
        "event": "NimbusTech EC2 cleanup candidate",
        "action": "stop" if execute else "dry-run",
        "region": region,
        "instance_id": instance["InstanceId"],
        "instance_type": instance.get("InstanceType"),
        "launch_time": instance["LaunchTime"].isoformat(),
        "age_days": round(age_days, 1),
        "reason": "running for more than 7 days and has no Name tag",
    }
    try:
        sns.publish(
            TopicArn=topic_arn,
            Subject="NimbusTech unnamed EC2 cleanup candidate",
            Message=json.dumps(message, indent=2),
        )
        return True
    except (BotoCoreError, ClientError) as exc:
        print(f"SNS publish failed for {instance['InstanceId']}: {exc}")
        return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--topic-arn", required=True, help="SNS topic ARN used for alerts")
    parser.add_argument("--age-days", type=int, default=7)
    parser.add_argument("--execute", action="store_true", help="Send alerts and stop instances")
    parser.add_argument("--regions", nargs="*", help="Optional region override; default is all enabled regions")
    args = parser.parse_args()

    session = boto3.Session()
    regions = args.regions or regions_for(session)
    cutoff = datetime.now(timezone.utc) - timedelta(days=args.age_days)
    sns = sns_client_from_topic(session, args.topic_arn)
    total = 0

    for region in regions:
        ec2 = session.client("ec2", region_name=region)
        try:
            found = candidates(ec2, cutoff)
        except (BotoCoreError, ClientError) as exc:
            print(f"{region}: discovery failed: {exc}")
            continue

        for instance in found:
            age_days = (datetime.now(timezone.utc) - instance["LaunchTime"]).total_seconds() / 86400
            print(f"Candidate: {region} {instance['InstanceId']} age={age_days:.1f}d")
            total += 1

            if not args.execute:
                continue

            if not alert(sns, args.topic_arn, region, instance, age_days, execute=True):
                print(f"Skipping stop because SNS alert failed: {instance['InstanceId']}")
                continue

            try:
                ec2.stop_instances(InstanceIds=[instance["InstanceId"]])
                print(f"Stopped: {region} {instance['InstanceId']}")
            except (BotoCoreError, ClientError) as exc:
                print(f"Stop failed for {instance['InstanceId']}: {exc}")

    mode = "EXECUTE" if args.execute else "DRY RUN"
    print(f"{mode}: {total} candidate instance(s) found.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
