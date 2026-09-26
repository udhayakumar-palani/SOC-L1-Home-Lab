resource "aws_instance" "windows_victim" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = var.windows_instance_type
  subnet_id              = aws_subnet.lab.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.mgmt.id, aws_security_group.lab_internal.id]
  get_password_data      = true

  root_block_device {
    volume_size = 60
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/../scripts/user_data/windows_uf_install.ps1.tftpl", {
    splunk_ip     = aws_instance.splunk.private_ip
    pass4symmkey  = var.splunk_uf_pass4symmkey
    sysmon_config = file("${path.module}/../scripts/sysmon/sysmonconfig.xml")
  })

  tags = {
    Name = "${var.project_name}-windows-victim"
    Role = "Victim - Windows Server 2022 (Sysmon + UF)"
  }
}
