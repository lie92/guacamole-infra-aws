//configuration de la région utilisée pour le déploiement de l'infra
// et des crédentials AWS
// key_name doit correspondre à la clé privée créée dans les prérequis
provider "aws" {
  region = "eu-west-1"
  shared_credentials_file = "%USERPROFILE%/.aws/credentials"
}

//creation d'un VPC avec un subnet public, privé, une NAT gateway avec les routes correspondantes 
module "vpc" {
  #source = "../"
  source = "terraform-aws-modules/vpc/aws"
  name = "guacamole-vpc"

  cidr = "172.31.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = ["172.31.16.0/20"]
  public_subnets  = ["172.31.0.0/24"]

  enable_ipv6 = true

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    Name = "public-subnet"
  }

  tags = {
    Owner       = "guacamole"
  } 

  vpc_tags = {
    Name = "guacamole-vpc"
  }
}


//création du security groupe pour le bastion Guacamole
resource "aws_security_group" "guacamole-sg" {
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id      = module.vpc.vpc_id
}

//règle du security groupe pour le port 80
resource "aws_security_group_rule" "port-80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.guacamole-sg.id
}

//règle du security groupe pour le port 8080
resource "aws_security_group_rule" "port-8080" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.guacamole-sg.id
}

//règle du security groupe pour le port 22
resource "aws_security_group_rule" "port-22" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.guacamole-sg.id
}

//règle du security groupe pour le port 443 si ajout TLS
resource "aws_security_group_rule" "port-443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.guacamole-sg.id
}

//création du bastion Guacamole avec le security group précédemment créé dans le subnet public
//changer key_name par le nom de la clé privée
module "ec2_guacamole" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 2.0"

  name                   = "guacamole"
  instance_count         = 1

  ami                    = "ami-0be809ca8847f5649"
  instance_type          = "t2.micro"
  key_name               =  var.key_name
  vpc_security_group_ids	= [aws_security_group.guacamole-sg.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Terraform   = "true"
  }
}

//création du security groupe pour les VMs du subnet privé
resource "aws_security_group" "vm-linux-guacamole-sg" {
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id      = module.vpc.vpc_id
}

//règle du security groupe pour le port 80
resource "aws_security_group_rule" "vm-linux-guacamole-port-80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vm-linux-guacamole-sg.id
}

//règle du security groupe pour le port 443
resource "aws_security_group_rule" "vm-linux-guacamole-port-443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vm-linux-guacamole-sg.id
}

//règle du security groupe pour le port 22
resource "aws_security_group_rule" "vm-linux-guacamole-port-22" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  source_security_group_id = aws_security_group.guacamole-sg.id
  security_group_id = aws_security_group.vm-linux-guacamole-sg.id
}

//règle du security groupe pour le port 3389
resource "aws_security_group_rule" "vm-linux-guacamole-port-3389" {
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  source_security_group_id = aws_security_group.guacamole-sg.id
  security_group_id = aws_security_group.vm-linux-guacamole-sg.id
}

//Création de la VM ubuntu dans le subnet privé modifier count pour créer un nombre précis de VMs
//changer key_name par le nom de la clé privée
resource "aws_instance" "vm-linux" {
  ami           = "ami-0dc8d444ee2a42d8a"
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.nic1[count.index].id
    device_index         = 0
  }

  key_name = var.key_name
  count = 1
}

//Création de la carte réseau de la vm Ubuntu dans le subnet privé modifier count pour créer un nombre précis de VMs
resource "aws_network_interface" "nic1" {
  subnet_id   = module.vpc.private_subnets[0]
  security_groups = [aws_security_group.vm-linux-guacamole-sg.id]
  count = 1
}