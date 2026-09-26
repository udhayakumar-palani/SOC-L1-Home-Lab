# 6. Cost and teardown

## Rough cost (us-east-1 on-demand, default sizes)

| Box | Type | ~$/hr | ~$/day (24h) |
|---|---|---|---|
| Splunk | t3.large | $0.083 | $2.00 |
| TheHive | t3.large | $0.083 | $2.00 |
| Windows victim | t3.large | $0.083 + Windows license | ~$2.90 |
| Suricata | t3.medium | $0.042 | $1.00 |
| Kali | t3.medium | $0.042 | $1.00 |
| Ubuntu victim | t3.small | $0.021 | $0.50 |

That's roughly **$0.35-0.40/hour, ~$9-10/day** if left running continuously,
plus EBS storage (~300GB total across all volumes, a few dollars/month) and
negligible data transfer for a lab this size. Traffic Mirroring sessions
themselves are billed per GB processed, trivial at lab traffic volumes.

**This is a "leave it running only while you're using it" lab, not a
"deploy once and forget" one.**

## Stop vs. destroy

- `aws ec2 stop-instances` (or just stop instances in the console) halts
  compute billing but **you still pay for the attached EBS volumes** (~$25-30/
  month total if left stopped indefinitely). Fine for an overnight pause.
- For anything longer than a day or two, destroy and redeploy when you come
  back - `terraform apply` takes ~15 minutes to rebuild everything from
  scratch since it's all code.

## Full teardown

```bash
cd terraform
terraform destroy
```

Review the plan it shows (it should list every resource this project
created and nothing else) before confirming. This removes all EC2 instances,
the VPC, security groups, and traffic mirroring sessions/targets/filters.

**Not destroyed by Terraform** (these live outside this project's state):
- The EC2 key pair you created manually in
  [01-prerequisites.md](01-prerequisites.md) - remove with
  `aws ec2 delete-key-pair --key-name soc-lab-key` if you're done with it.
- The ServiceNow PDI - it auto-hibernates on its own after inactivity; no
  action needed unless you want to fully delete it from the developer portal.

## Sanity check after destroy

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=soc-lab-*" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]'
```
Should return nothing (or only `terminated` entries, which stop billing
immediately and disappear from the console after a while).
