output "server_ip" {
  value = aws_elastic_ip.minecraft_eip.public_ip
}
