# 2. Deploy the infrastructure

## Configure variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: set `my_ip`, `key_name`, `kali_ami_id`, `aws_region`
if not us-east-1. Leave the three secret variables out of this file - export
them instead:

```bash
export TF_VAR_splunk_admin_password='ChangeMe_Strong_Pw_123!'
export TF_VAR_thehive_secret=$(openssl rand -hex 32)
export TF_VAR_splunk_uf_pass4symmkey=$(openssl rand -hex 24)
```

## Init, plan, apply

```bash
terraform init
terraform plan -out=tfplan
```

Read the plan. It should show ~15-20 resources to add: 1 VPC, 1 subnet, 1 IGW,
1 route table, 4 security groups, 5-6 EC2 instances, and (if
`enable_suricata_ids = true`) a traffic mirror target/filter/2 rules/3 sessions.

Nothing here modifies or deletes anything outside this VPC - it's a clean,
isolated build.

```bash
terraform apply tfplan
```

This takes ~3-5 minutes for AWS to provision the instances, then each one
spends another 3-10 minutes running its first-boot script (downloading and
installing Splunk/TheHive/Suricata/Sysmon). Give it 15 minutes total before
troubleshooting.

## Get the outputs

```bash
terraform output
```

You'll see the Splunk Web URL, TheHive URL, SSH commands for Kali/Ubuntu, and
the Windows instance ID. For the Windows Administrator password:

```bash
aws ec2 get-password-data \
  --instance-id "$(terraform output -raw windows_victim_instance_id)" \
  --priv-launch-key ~/.ssh/soc-lab-key.pem
```
(Can take a few minutes after launch before AWS has the password ready - it
returns empty until then.)

## If something didn't come up

SSH into the box and check cloud-init/user_data logs:

```bash
# Linux boxes (splunk, ubuntu_victim, thehive, suricata):
ssh -i ~/.ssh/soc-lab-key.pem ubuntu@<public-ip>
sudo cat /var/log/cloud-init-output.log
```

For Windows, RDP in and check `C:\ProgramData\Amazon\EC2Launch\log\agent.log`
or `C:\ProgramData\Amazon\EC2-Windows\Launch\Log\UserdataExecution.log`
depending on the AMI's launch agent version.

Common failure: the pinned Splunk/UF download URL 404s because Splunk shipped
a new build since these scripts were written. Fix in
`scripts/user_data/*.tftpl` (update `*_VERSION`/`*_BUILD`). Changing
`user_data` alone does **not** re-run it on an already-running instance (EC2
only executes user_data at first boot) - force that one instance to be
recreated with the fixed script:

```bash
terraform apply -replace=aws_instance.splunk   # or whichever box needs it
```
