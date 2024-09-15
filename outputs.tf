output "server_ip" {
  value = aws_eip.minecraft_eip.public_ip
}
