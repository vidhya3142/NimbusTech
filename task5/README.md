# Task 5 — AI Prompt Log

## Chosen Mini-Task

**Option A:** Find unnamed EC2 instances across all enabled AWS regions that have been running for more than seven days, send an SNS alert, and stop them.

The exercise specifically asks to show the AI prompt, the raw AI output, and what was changed after reviewing the AI-generated code.

---

## Prompt Used

> Act as an AWS Cloud Engineer. For the NimbusTech hiring exercise, write a simple Python 3 script using boto3 that finds all running EC2 instances across all enabled AWS regions. The script should find instances that have been running for more than 7 days and do not have a Name tag. Before stopping an instance, send an SNS notification containing the region and instance ID. Keep the code simple and easy to understand because I need to explain it in an interview. Add a simple dry-run option so instances are not accidentally stopped while testing. Use basic exception handling where appropriate.

---

## Raw AI Output

The initial AI-generated code was similar to the following:

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

                print(
                    "Found instance:",
                    instance["InstanceId"]
                )

                ec2.stop_instances(
                    InstanceIds=[instance["InstanceId"]]
                )
```

---

## What the AI Got Right

The initial code correctly:

* Used `boto3` to work with AWS.
* Used UTC-aware datetime values.
* Checked all enabled AWS regions.
* Looked for running EC2 instances.
* Checked whether the instance had a `Name` tag.
* Checked whether the instance was older than seven days.
* Used `stop_instances()` to stop the EC2 instance.

---

## What Was Wrong or Incomplete

After reviewing the generated code, I identified several areas that needed improvement:

1. It stopped instances without sending an SNS notification first.
2. It did not check whether the SNS notification was successfully sent.
3. It did not have a dry-run option.
4. It did not handle AWS API errors.
5. It did not clearly print what was happening.
6. It was not safe to test directly because it could stop an instance immediately.

---

## Changes Made in the Final Version

I simplified and modified the code so that it is easier to understand and explain.

The final version:

* Checks all enabled AWS regions.
* Finds running EC2 instances.
* Checks for a missing `Name` tag.
* Checks whether the instance is older than seven days.
* Sends an SNS notification before stopping the instance.
* Includes a simple `DRY_RUN` setting.
* Does not stop an instance when dry-run mode is enabled.
* Prints the instances that are identified as candidates.

I intentionally kept the final code simple instead of adding unnecessary classes, multiple helper functions, complex command-line arguments, or advanced error-handling logic.

---

## What I Learned From the AI Output

The AI was useful for creating the initial structure, but I reviewed the code before using it.

The main lesson was that AI-generated AWS automation code should not be used without checking the actual AWS operations and adding safety controls. In this case, I specifically added the SNS notification and dry-run behavior so that the script does not accidentally stop an EC2 instance during testing.
