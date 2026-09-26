# 1. Prerequisites

## Tools (on this Mac)

Already installed and confirmed in this session:
- `aws` CLI v2 (`/opt/homebrew/bin/aws`)

Still needed:
```bash
brew install terraform
```

## AWS account + credentials

You need an AWS account and credentials configured locally. Pick one:

```bash
aws configure          # access key + secret key
# or, if your org uses SSO:
aws sso login --profile <your-profile>
```

Verify:
```bash
aws sts get-caller-identity
```

**IAM permissions needed**: EC2 (instances, security groups, key pairs, traffic
mirroring), VPC (VPC/subnet/route table/IGW). Easiest is an account/role with
`AmazonEC2FullVPCFullAccess`-equivalent access; a locked-down org account may
need those permissions added explicitly.

## EC2 key pair

Create one (or reuse an existing one) - Terraform references it by name only,
your `.pem` file stays local:

```bash
aws ec2 create-key-pair --key-name soc-lab-key --query 'KeyMaterial' --output text > ~/.ssh/soc-lab-key.pem
chmod 400 ~/.ssh/soc-lab-key.pem
```

## Your public IP

Every management port (SSH/RDP/Splunk UI/TheHive UI) is locked to your IP only:

```bash
curl -s https://checkip.amazonaws.com
```
Use this as `<ip>/32` for the `my_ip` Terraform variable.

## Kali Linux AMI (manual Marketplace subscription)

AWS Marketplace AMIs need a one-time click-through subscription before
Terraform (or any automation) can launch them - there's no way to script past
this, it's an AWS Marketplace requirement:

1. Go to AWS Marketplace and search "Kali Linux" (publisher: Kali Linux / OffSec).
2. Click **Continue to Subscribe** > **Accept Terms**.
3. Once subscribed, click **Continue to Configuration** > **Continue to Launch**.
4. On the launch page, note the **AMI ID** for your chosen region - this is
   what goes into the `kali_ami_id` Terraform variable.

You do not need to actually launch it from that page; Terraform will do that.

## ServiceNow (for the case-management step)

The diagram's "TheHive + ServiceNow" box needs a ServiceNow instance to open
incidents in. ServiceNow is SaaS, not something Terraform provisions - sign up
for a free Personal Developer Instance:

1. https://developer.servicenow.com/ -> Sign up (free) -> Request Instance.
2. Wait for provisioning (a few minutes), note the instance URL
   (`https://devXXXXXX.service-now.com`) and the auto-generated admin credentials.
3. Keep the instance **awake** - free PDIs auto-hibernate after a few days of
   inactivity; wake it from the developer portal before you use the lab again.

Full setup of the TheHive <-> ServiceNow bridge is in
[04-thehive-servicenow.md](04-thehive-servicenow.md).

## Cost awareness

This stands up 5-6 EC2 instances (a couple of them `t3.large`) running 24/7
until you tear it down. See [06-cost-and-teardown.md](06-cost-and-teardown.md)
before you `terraform apply` so there are no surprises on your AWS bill.
