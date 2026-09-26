# Firewalling in this cloud build is done with Security Groups + NACLs instead of the
# pfSense box in the original diagram (AWS VPC networking already provides that stateful
# edge-firewall/router role natively). Suricata still exists as its own IDS sensor -
# see ec2_suricata.tf - just decoupled from firewalling duty.

resource "aws_security_group" "mgmt" {
  name        = "${var.project_name}-mgmt"
  description = "Admin access (SSH/RDP) restricted to the operator IP"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-mgmt" }
}

# All-to-all inside the lab subnet: this is what makes it behave like the flat
# 192.168.56.0/24 host-only network in the diagram (attacker -> victims, victims -> Splunk,
# Suricata mirror traffic, etc). Everything stays inside this VPC; nothing here opens
# ingress to the internet at large.
resource "aws_security_group" "lab_internal" {
  name        = "${var.project_name}-lab-internal"
  description = "Free traffic between lab boxes (attacker to victims to SIEM)"
  vpc_id      = aws_vpc.lab.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-lab-internal" }
}

resource "aws_security_group_rule" "lab_internal_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.lab_internal.id
  source_security_group_id = aws_security_group.lab_internal.id
}

resource "aws_security_group" "splunk_ui" {
  name        = "${var.project_name}-splunk-ui"
  description = "Splunk web UI (8000) and management port (8089), operator IP only"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "Splunk Web"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Splunk mgmt / REST API"
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  tags = { Name = "${var.project_name}-splunk-ui" }
}

resource "aws_security_group" "hive_ui" {
  name        = "${var.project_name}-hive-ui"
  description = "TheHive web UI (9000), operator IP only"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "TheHive Web"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  tags = { Name = "${var.project_name}-hive-ui" }
}
