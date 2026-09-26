variable "aws_region" {
  description = "AWS region to deploy the lab into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used to tag/name every resource"
  type        = string
  default     = "soc-lab"
}

variable "my_ip" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.4/32). Management access (SSH/RDP/Splunk UI/TheHive UI) is restricted to this. Find yours with: curl -s https://checkip.amazonaws.com"
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair (create in AWS Console > EC2 > Key Pairs, or `aws ec2 create-key-pair`)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the lab VPC"
  type        = string
  default     = "10.60.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for the single lab subnet (all boxes live here, mirroring the 192.168.56.0/24 host-only network in the original diagram)"
  type        = string
  default     = "10.60.56.0/24"
}

variable "kali_ami_id" {
  description = "AMI ID for Kali Linux in your region. Subscribe first at https://aws.amazon.com/marketplace (search 'Kali Linux', publisher Kali Linux / OffSec), then copy the AMI ID shown on the 'Launch' tab for your region. Not auto-looked-up because Marketplace AMIs require a one-time manual subscription click before Terraform can use them."
  type        = string
}

variable "kali_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "windows_instance_type" {
  description = "Windows victim box. t3.large recommended (Sysmon + UF + normal Windows overhead wants >4GB RAM)"
  type        = string
  default     = "t3.large"
}

variable "ubuntu_instance_type" {
  type    = string
  default = "t3.small"
}

variable "splunk_instance_type" {
  description = "Splunk single-instance. t3.large (8GB RAM) is a practical minimum for a responsive lab search head+indexer combo"
  type        = string
  default     = "t3.large"
}

variable "thehive_instance_type" {
  description = "TheHive + Cassandra + Elasticsearch via docker-compose. Needs real RAM."
  type        = string
  default     = "t3.large"
}

variable "suricata_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "enable_suricata_ids" {
  description = "Deploy the Suricata IDS sensor + VPC Traffic Mirroring. Set false to skip this module and save cost/complexity."
  type        = bool
  default     = true
}

variable "splunk_admin_password" {
  description = "Initial admin password for Splunk Enterprise (min 8 chars). Set via TF_VAR_splunk_admin_password env var, not in a committed .tfvars file."
  type        = string
  sensitive   = true
}

variable "thehive_secret" {
  description = "Application secret for TheHive (play.http.secret.key). Set via TF_VAR_thehive_secret env var."
  type        = string
  sensitive   = true
}

variable "splunk_uf_pass4symmkey" {
  description = "Shared secret Splunk Enterprise and every Universal Forwarder use to authenticate to each other. Set via TF_VAR_splunk_uf_pass4symmkey env var."
  type        = string
  sensitive   = true
}
