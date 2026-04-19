provider "aws" {
  region = "ap-south-1"  # Replace with your desired AWS region.
}

variable "cidr" {
  default = "10.0.0.0/16"
}

resource "aws_key_pair" "example" {
  key_name   = "terraform-key"  # Replace with your desired key name
  public_key = file("C:/terraform/day5/terraform-key.pub")  # Replace with the path to your public key file
}

resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-sg"
  }
}

resource "aws_instance" "server" {
  ami                    = "ami-05d2d839d4f73aafb"
  instance_type          = "t3.micro"
  key_name      = aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub1.id


  connection {
    type        = "ssh"
    user        = "ubuntu"  # Replace with the appropriate username for your EC2 instance
    private_key = file("C:/terraform/day5/terraform-key")  # Replace with the path to your private key
    host        = self.public_ip
  }

  # File provisioner to copy a file from local to the remote EC2 instance
  provisioner "file" {
    source      = "app.py"  # Replace with the path to your local file
    destination = "/home/ubuntu/app.py"  # Replace with the path on the remote instance
  }

 provisioner "remote-exec" {
  inline = [
    "set -ex",  # 👈 VERY IMPORTANT (debug + fail fast)

    "sleep 30",  # 👈 wait for instance readiness

    "sudo apt-get update -y",
    "sudo apt-get install -y python3-pip",

    "sudo pip3 install flask",

    # ensure file exists (safe fallback)
    "echo \"from flask import Flask; app = Flask(__name__); @app.route('/')\\ndef hello(): return 'Hello Terraform'; app.run(host='0.0.0.0', port=5000)\" > /home/ubuntu/app.py",

    # run in background
    "nohup python3 /home/ubuntu/app.py > /home/ubuntu/app.log 2>&1 &"
  ]
}
}
