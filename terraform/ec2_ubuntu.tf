resource "aws_instance" "ubuntu_victim" {
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = var.ubuntu_instance_type
  subnet_id              = aws_subnet.lab.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.mgmt.id, aws_security_group.lab_internal.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/../scripts/user_data/ubuntu_uf_install.sh.tftpl", {
    splunk_ip    = aws_instance.splunk.private_ip
    pass4symmkey = var.splunk_uf_pass4symmkey
  })

  tags = {
    Name = "${var.project_name}-ubuntu-victim"
    Role = "Victim - SSH target"
  }
}
