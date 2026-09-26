output "splunk_web_url" {
  description = "Splunk Web defaults to plain HTTP on port 8000 unless you enable SSL in web.conf"
  value       = "http://${aws_instance.splunk.public_ip}:8000"
}

output "splunk_public_ip" {
  value = aws_instance.splunk.public_ip
}

output "splunk_private_ip" {
  value = aws_instance.splunk.private_ip
}

output "thehive_web_url" {
  value = "http://${aws_instance.thehive.public_ip}:9000"
}

output "kali_ssh" {
  value = "ssh -i <path-to-key>.pem kali@${aws_instance.kali.public_ip}"
}

output "ubuntu_victim_ssh" {
  value = "ssh -i <path-to-key>.pem ubuntu@${aws_instance.ubuntu_victim.public_ip}"
}

output "windows_victim_public_ip" {
  value = aws_instance.windows_victim.public_ip
}

output "windows_victim_password_data" {
  description = "Encrypted Administrator password blob. Decrypt with: aws ec2 get-password-data --instance-id <id> --priv-launch-key <path-to-key>.pem"
  value       = aws_instance.windows_victim.password_data
  sensitive   = true
}

output "windows_victim_instance_id" {
  value = aws_instance.windows_victim.id
}

output "suricata_public_ip" {
  value = var.enable_suricata_ids ? aws_instance.suricata[0].public_ip : null
}
