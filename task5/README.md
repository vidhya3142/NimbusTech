# Task 5 — AI-Assisted Automation

## Chosen mini-task

Option A: find unnamed EC2 instances across all regions that have been running for more than seven days, alert via SNS, then stop them.

## Usage

Install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Dry run (recommended first):

```bash
python3 ec2_cleanup.py --topic-arn arn:aws:sns:us-east-1:123456789012:nimbus-ec2-alerts
```

Execute:

```bash
python3 ec2_cleanup.py \
  --topic-arn arn:aws:sns:us-east-1:123456789012:nimbus-ec2-alerts \
  --execute
```

## Required IAM permissions

The identity running the script needs, at minimum:

- `ec2:DescribeRegions`
- `ec2:DescribeInstances`
- `ec2:StopInstances`
- `sns:Publish`

If the script is run through an automation role, scope `sns:Publish` to the exact SNS topic ARN and scope EC2 actions to the intended accounts/regions where supported.

## Safety decisions

- Dry-run is the default.
- Only `running` instances are considered.
- The `Name` tag must be absent or empty.
- The launch time must be older than the configured age threshold.
- The script publishes the SNS alert before stopping and skips the stop if publish fails.
- The SNS topic can live in a different region from the EC2 instance.
- The script reports API failures instead of terminating the entire regional scan.

## AI transparency

See `ai_prompt_log.md` for the prompt, raw baseline output, review notes, and final changes. This is intentionally included because the exercise asks the candidate to demonstrate judgment over AI-generated output.
