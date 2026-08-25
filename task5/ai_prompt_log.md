# Task 5 — AI Prompt Log

## Prompt used

> Act as a senior AWS Cloud Engineer. For the NimbusTech hiring exercise, write a production-quality Python 3 script using boto3 that finds all EC2 instances across all enabled AWS regions that are currently running, have been running for more than 7 days, and have no `Name` tag. Before stopping any candidate, publish an SNS alert containing the region, instance ID, instance type, launch time, age, and reason. Stop the instance only if the SNS publish succeeds. Make the script dry-run by default and require `--execute` to make changes. Allow an SNS topic ARN as a CLI argument and handle the fact that the SNS topic may be in a different region from the EC2 instance. Use paginators, UTC-aware datetimes, and reasonable AWS exception handling. Keep the code readable and explain any important safety decisions.

## Raw AI output

The initial AI-generated baseline was intentionally simple:

```python
import boto3
from datetime import datetime, timedelta, timezone

session = boto3.Session()
cutoff = datetime.now(timezone.utc) - timedelta(days=7)

regions = [r["RegionName"] for r in session.client("ec2", region_name="us-east-1").describe_regions()["Regions"]]

for region in regions:
    ec2 = session.client("ec2", region_name=region)
    sns = session.client("sns", region_name=region)
    response = ec2.describe_instances(
        Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
    )
    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            tags = {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
            if "Name" not in tags and instance["LaunchTime"] < cutoff:
                message = f"Stopping {instance['InstanceId']} in {region}"
                sns.publish(TopicArn="REPLACE_ME", Message=message)
                ec2.stop_instances(InstanceIds=[instance["InstanceId"]])
```

## What the AI got right

- It used UTC-aware time comparison.
- It filtered for running instances and checked the `Name` tag.
- It iterated across AWS regions.
- It sent an SNS notification before stopping.

## What was wrong/incomplete

- It did not use paginators, so a large fleet could be truncated.
- It assumed the SNS topic is in the same region as the EC2 instance.
- It hard-coded the topic ARN placeholder.
- It had no dry-run safety switch.
- It stopped an instance without checking whether the SNS publish succeeded.
- It did not handle AWS API errors.
- It did not explicitly support an override list of regions.

## Changes made in the final version

The final `ec2_cleanup.py` adds paginators, CLI arguments, all-enabled-region discovery, cross-region SNS client handling, dry-run-by-default behavior, structured alert content, exception handling, and the safety rule that a stop occurs only after a successful SNS publish.
