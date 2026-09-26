resource "aws_instance" "kali" {
  ami                    = var.kali_ami_id
  instance_type          = var.kali_instance_type
  subnet_id              = aws_subnet.lab.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.mgmt.id, aws_security_group.lab_internal.id]

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-kali"
    Role = "Attacker"
  }
}
