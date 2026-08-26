# Task 5 — AI Prompt Log

## Prompt used

> Act as a senior AWS Cloud Engineer. For the NimbusTech hiring exercise, write a production-quality Python 3 script using boto3 that finds all EC2 instances across all enabled AWS regions that are currently running, have been running for more than 7 days, and have no `Name` tag. Before stopping any candidate, publish an SNS alert containing the region, instance ID, instance type, launch time, age, and reason. Stop the instance only if the SNS publish succeeds. Make the script dry-run by default and require `--execute` to make changes. Allow an SNS topic ARN as a CLI argument and handle the fact that the SNS topic may be in a different region from the EC2 instance. Use paginators, UTC-aware datetimes, and reasonable AWS exception handling. Keep the code readable and explain any important safety decisions.

## Raw AI output

The initial AI-generated baseline was:

```python
import boto3

from datetime import datetime, timedelta, timezone

session = boto3.Session()

cutoff = datetime.now(timezone.utc) - timedelta(days=7)

regions = [
    r["RegionName"]
    for r in session.client(
        "ec2",
        region_name="us-east-1"
    ).describe_regions()["Regions"]
]

for region in regions:

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

            tags = {
                t["Key"]: t["Value"]
                for t in instance.get("Tags", [])
            }

            if "Name" not in tags and instance["LaunchTime"] < cutoff:

                message = f"Stopping {instance['InstanceId']} in {region}"

                print(message)

                ec2.stop_instances(
                    InstanceIds=[instance["InstanceId"]]
                )
## What the AI got right

It used boto3 to work with AWS.
It used UTC-aware datetime values.
It discovered enabled AWS regions.
It filtered for running EC2 instances.
It checked whether the instance had a Name tag.
It checked whether the instance had been running for more than 7 days.
It used stop_instances() to stop the matching EC2 instances.

## What was wrong/incomplete
It did not send an SNS notification before stopping the instance.
It did not check whether the SNS notification was successfully sent.
It did not have a dry-run option.
It did not include useful information such as the region and reason in the SNS notification.
It did not have basic AWS error handling.
It could stop an instance immediately if the script was run accidentally.
It used a simple describe_instances() call instead of a paginator, which may not be suitable for a large number of instances.

## Changes made in the final version

Checks all enabled AWS regions.
Finds running EC2 instances.
Checks whether an instance has a Name tag.
Checks whether the instance is older than 7 days.
Sends an SNS notification before stopping the instance.
Uses a simple DRY_RUN setting.
Does not stop instances when dry-run mode is enabled.
Prints the instances found during the scan.
Keeps the code simple so that each step is easy to explain.
