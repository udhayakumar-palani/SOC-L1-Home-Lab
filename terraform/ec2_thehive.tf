resource "aws_instance" "thehive" {
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = var.thehive_instance_type
  subnet_id              = aws_subnet.lab.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.mgmt.id, aws_security_group.lab_internal.id, aws_security_group.hive_ui.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/../scripts/user_data/thehive_install.sh.tftpl", {
    docker_compose = file("${path.module}/../scripts/thehive/docker-compose.yml")
    thehive_secret = var.thehive_secret
  })

  tags = {
    Name = "${var.project_name}-thehive"
    Role = "Case management (TheHive)"
  }
}
