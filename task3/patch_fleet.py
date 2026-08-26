#!/usr/bin/env python3

import boto3
import time

region = "us-east-1"

ec2 = boto3.client("ec2", region_name=region)
ssm = boto3.client("ssm", region_name=region)


# Get running EC2 instances
response = ec2.describe_instances(
    Filters=[
        {
            "Name": "instance-state-name",
            "Values": ["running"]
        }
    ]
)

instance_ids = []

for reservation in response["Reservations"]:
    for instance in reservation["Instances"]:

        # Check if instance has a Name tag
        name_tag = False

        for tag in instance.get("Tags", []):
            if tag["Key"] == "Name":
                name_tag = True

        # We patch instances without a Name tag
        if not name_tag:
            instance_ids.append(instance["InstanceId"])


print("Instances to patch:", instance_ids)


if not instance_ids:
    print("No instances found.")
    exit()


# Send patch command using SSM
command = ssm.send_command(
    InstanceIds=instance_ids,
    DocumentName="AWS-RunShellScript",
    Parameters={
        "commands": [
            "sudo apt-get update",
            "sudo apt-get -y upgrade",
            "sudo apt-get -y install --only-upgrade openssl",
            "uname -r",
            "openssl version"
        ]
    }
)

command_id = command["Command"]["CommandId"]

print("SSM Command ID:", command_id)

# Wait for the command to finish
time.sleep(30)


# Check command result
result = ssm.list_command_invocations(
    CommandId=command_id,
    Details=True
)

for item in result["CommandInvocations"]:

    instance_id = item["InstanceId"]
    status = item["Status"]

    print(instance_id, ":", status)

    if status == "Success":
        print("Patch completed successfully for", instance_id)
    else:
        print("Patch failed for", instance_id)


# Verify kernel and OpenSSL
print("\nVerifying patch status...")

verify = ssm.send_command(
    InstanceIds=instance_ids,
    DocumentName="AWS-RunShellScript",
    Parameters={
        "commands": [
            "echo Kernel:",
            "uname -r",
            "echo OpenSSL:",
            "openssl version"
        ]
    }
)

verify_command_id = verify["Command"]["CommandId"]

time.sleep(20)

verification = ssm.list_command_invocations(
    CommandId=verify_command_id,
    Details=True
)

for item in verification["CommandInvocations"]:

    print(
        item["InstanceId"],
        ":",
        item["Status"]
    )

    if "CommandPlugins" in item:
        for plugin in item["CommandPlugins"]:
            print(plugin.get("Output", ""))