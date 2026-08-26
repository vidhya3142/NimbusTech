#!/usr/bin/env python3

import boto3
from datetime import datetime, timedelta, timezone

# SNS topic
SNS_TOPIC_ARN = "arn:aws:sns:us-east-1:123456789012:nimbustech-alerts"

# Instances older than 7 days
CUTOFF_DATE = datetime.now(timezone.utc) - timedelta(days=7)

# Create AWS session
session = boto3.Session()

# Get all enabled AWS regions
ec2 = session.client("ec2", region_name="us-east-1")

regions = ec2.describe_regions()["Regions"]

sns = session.client("sns", region_name="us-east-1")


for region_data in regions:

    region = region_data["RegionName"]

    print("\nChecking region:", region)

    ec2 = session.client("ec2", region_name=region)

    response = ec2.describe_instances(
        Filters=[
            {
                "Name": "instance-state-name",
                "Values": ["running"]
            }
        ]
    )

    for reservation in response["Reservations"]:

        for instance in reservation["Instances"]:

            instance_id = instance["InstanceId"]
            launch_time = instance["LaunchTime"]

            # Check if instance has a Name tag
            has_name = False

            for tag in instance.get("Tags", []):
                if tag["Key"] == "Name":
                    has_name = True

            # Skip instances that have a Name tag
            if has_name:
                continue

            # Check if instance is older than 7 days
            if launch_time < CUTOFF_DATE:

                print(
                    "Found instance:",
                    instance_id,
                    "in",
                    region
                )

                # Send SNS alert
                message = (
                    f"EC2 instance {instance_id} in {region} "
                    "has been running for more than 7 days "
                    "and does not have a Name tag. "
                    "The instance will be stopped."
                )

                sns.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject="NimbusTech EC2 Cleanup Alert",
                    Message=message
                )

                print("SNS alert sent.")

                # Stop the instance
                ec2.stop_instances(
                    InstanceIds=[instance_id]
                )

                print("Instance stopped:", instance_id)