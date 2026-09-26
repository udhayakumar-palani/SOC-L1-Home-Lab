resource "aws_instance" "splunk" {
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = var.splunk_instance_type
  subnet_id              = aws_subnet.lab.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.mgmt.id, aws_security_group.lab_internal.id, aws_security_group.splunk_ui.id]

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/../scripts/user_data/splunk_install.sh.tftpl", {
    admin_password     = var.splunk_admin_password
    pass4symmkey       = var.splunk_uf_pass4symmkey
    app_conf           = file("${path.module}/../scripts/splunk/app.conf")
    default_meta       = file("${path.module}/../scripts/splunk/default.meta")
    savedsearches_conf = file("${path.module}/../scripts/splunk/detections/savedsearches.conf")
    props_conf         = file("${path.module}/../scripts/splunk/props.conf")
    dashboard_xml      = file("${path.module}/../scripts/splunk/dashboards/soc_overview.xml")
    lookup_csv         = file("${path.module}/../scripts/splunk/lookups/threat_intel.csv")
  })

  tags = {
    Name = "${var.project_name}-splunk"
    Role = "SIEM"
  }
}
