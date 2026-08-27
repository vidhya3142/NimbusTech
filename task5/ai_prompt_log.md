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
