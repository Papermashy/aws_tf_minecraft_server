provider "aws" {
  region = "eu-west-2"# Change to your preferred AWS region
}

resource "aws_key_pair" "minecraft_key" {
  key_name   = "minecraft_key"
  public_key = file("~/.ssh/id_rsa.pub") # Make sure to replace this with the path to your public SSH key
}

resource "aws_security_group" "minecraft_sg" {
  name        = "minecraft_sg"
  description = "Allow Minecraft Bedrock Edition traffic"

  ingress {
    from_port   = 19132
    to_port     = 19132
    protocol    = "tcp"
    cidr_blocks = ["82.14.67.254/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["82.14.67.254/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Find latest Ubuntu AMI, use as default if no AMI specified
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "minecraft_server" {
  ami           = data.aws_ami.ubuntu.id # Ubuntu 22.04 LTS - amd64 - eu-west-2 - changes as needed
  instance_type = "m4.large"
  key_name      = aws_key_pair.minecraft_key.key_name
  security_groups = [aws_security_group.minecraft_sg.name]

  root_block_device {
    volume_size = 8
  }

  tags = {
    Name = "MinecraftServer"
  }

  # Provisioning block to install Minecraft Bedrock server
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y wget unzip",
      "wget https://minecraft.azureedge.net/bin-linux/bedrock-server-1.21.23.01.zip -O bedrock-server.zip",
      "sudo unzip bedrock-server.zip -d /minecraft",
      "sudo rm bedrock-server.zip"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa") # Replace with your private SSH key
      host        = self.public_ip
    }
  }
}

resource "aws_ebs_volume" "minecraft_volume" {
  availability_zone = aws_instance.minecraft_server.availability_zone
  size              = 10 # Adjust the size as needed

  tags = {
    Name = "MinecraftDataVolume"
  }
}

resource "aws_volume_attachment" "minecraft_volume_attachment" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.minecraft_volume.id
  instance_id = aws_instance.minecraft_server.id
}

resource "aws_eip" "minecraft_eip" {
  instance = aws_instance.minecraft_server.id
}

