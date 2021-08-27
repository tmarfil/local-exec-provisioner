# Look for Ubuntu ami

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create web server, but wait until wait-for-endpoint.sh script confirms http is alive on web server before Terraform thinks we're done."

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.f5_management.id]
  tags = {
    Name = "marfil-test"
  }

  user_data = <<-EOF
    #!/bin/bash 
    mkdir -p /var/www && cd /var/www
    echo "App v${var.release}" >> index.html
    python3 -m http.server 80
  EOF

  lifecycle {
    create_before_destroy = true
  }
  provisioner "local-exec" {
    command = "./wait-for-endpoint.sh http://${self.public_ip} -t 300"
# Simulate a failed health check by commenting out the line above and uncommenting the line below:
#   command = "./wait-for-endpoint.sh http://too.much.fail.biz -t 15"
  }
}

# f5_management security group allows:
# - inbound: http, https, ssh
# - outbound: any


resource "aws_security_group" "f5_management" {
  name = "f5_management"
  #  vpc_id = aws_vpc.terraform-vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

