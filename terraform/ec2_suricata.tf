# Suricata IDS sensor fed by AWS VPC Traffic Mirroring - the cloud-native
# replacement for pfSense+Suricata sitting inline on the host-only network in
# the original diagram. See scripts/user_data/suricata_install.sh.tftpl.

resource "aws_security_group" "suricata_mirror" {
  count       = var.enable_suricata_ids ? 1 : 0
  name        = "${var.project_name}-suricata-mirror"
  description = "Accept VXLAN-encapsulated traffic mirror sessions (UDP 4789) from inside the VPC"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "AWS Traffic Mirroring (VXLAN)"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.project_name}-suricata-mirror" }
}

resource "aws_instance" "suricata" {
  count                  = var.enable_suricata_ids ? 1 : 0
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = var.suricata_instance_type
  subnet_id              = aws_subnet.lab.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.mgmt.id, aws_security_group.lab_internal.id, aws_security_group.suricata_mirror[0].id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/../scripts/user_data/suricata_install.sh.tftpl", {
    splunk_ip    = aws_instance.splunk.private_ip
    pass4symmkey = var.splunk_uf_pass4symmkey
    subnet_cidr  = var.subnet_cidr
  })

  tags = {
    Name = "${var.project_name}-suricata"
    Role = "IDS sensor"
  }
}

resource "aws_ec2_traffic_mirror_target" "suricata" {
  count                = var.enable_suricata_ids ? 1 : 0
  network_interface_id = aws_instance.suricata[0].primary_network_interface_id
  description          = "${var.project_name} Suricata sensor"
}

resource "aws_ec2_traffic_mirror_filter" "all_traffic" {
  count       = var.enable_suricata_ids ? 1 : 0
  description = "Mirror all ingress+egress traffic for IDS inspection"
}

resource "aws_ec2_traffic_mirror_filter_rule" "ingress_all" {
  count                    = var.enable_suricata_ids ? 1 : 0
  description              = "all ingress"
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.all_traffic[0].id
  destination_cidr_block   = "0.0.0.0/0"
  source_cidr_block        = "0.0.0.0/0"
  rule_number              = 1
  rule_action              = "accept"
  traffic_direction        = "ingress"
}

resource "aws_ec2_traffic_mirror_filter_rule" "egress_all" {
  count                    = var.enable_suricata_ids ? 1 : 0
  description              = "all egress"
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.all_traffic[0].id
  destination_cidr_block   = "0.0.0.0/0"
  source_cidr_block        = "0.0.0.0/0"
  rule_number              = 1
  rule_action              = "accept"
  traffic_direction        = "egress"
}

# One mirror session per box we want visibility into: both victims and the
# attacker (so Suricata also sees the Nmap/Hydra traffic leaving Kali).
locals {
  mirror_sources = var.enable_suricata_ids ? {
    windows = aws_instance.windows_victim.primary_network_interface_id
    ubuntu  = aws_instance.ubuntu_victim.primary_network_interface_id
    kali    = aws_instance.kali.primary_network_interface_id
  } : {}
}

resource "aws_ec2_traffic_mirror_session" "sessions" {
  for_each = local.mirror_sources

  description              = "mirror-${each.key}"
  network_interface_id     = each.value
  traffic_mirror_target_id = aws_ec2_traffic_mirror_target.suricata[0].id
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.all_traffic[0].id
  session_number           = index(keys(local.mirror_sources), each.key) + 1
  virtual_network_id       = 1
}
