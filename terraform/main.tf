data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
data "aws_ssm_parameter" "ami" { name = var.ami_ssm_parameter }
data "aws_caller_identity" "current" {}
locals {
  chosen_subnet = var.subnet_id != "" ? var.subnet_id : sort(data.aws_subnets.default.ids)[0]
  prefix = "spring-ai-training"
}
resource "aws_security_group" "llm" {
  name_prefix = "${local.prefix}-"
  description = "HTTPS public, other ports closed"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    description = "ACME HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Project = local.prefix }
}
resource "aws_secretsmanager_secret" "credentials" {
  name_prefix = "${local.prefix}-credentials-"
  recovery_window_in_days = 0
  tags = { Project = local.prefix }
}
resource "aws_iam_role" "ec2" {
  name_prefix = "${local.prefix}-"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }] })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "secret_write" {
  name = "write-training-credentials"
  role = aws_iam_role.ec2.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["secretsmanager:PutSecretValue"], Resource = aws_secretsmanager_secret.credentials.arn }] })
}
resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${local.prefix}-"
  role = aws_iam_role.ec2.name
}
resource "aws_instance" "gpu" {
  ami = data.aws_ssm_parameter.ami.value
  instance_type = var.instance_type
  subnet_id = local.chosen_subnet
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.llm.id]
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  user_data = templatefile("${path.module}/../server/bootstrap.sh.tftpl", {
    model = var.model
    domain = var.domain
    region = var.aws_region
    secret_arn = aws_secretsmanager_secret.credentials.arn
    litellm_image = var.litellm_image
  })
  user_data_replace_on_change = true
  root_block_device {
    volume_type = "gp3"
    volume_size = 100
    encrypted = true
    delete_on_termination = true
  }
  metadata_options { http_tokens = "required" }
  tags = { Name = local.prefix, Project = local.prefix }
  depends_on = [aws_iam_role_policy.secret_write]
}
resource "aws_eip" "llm" {
  domain = "vpc"
  instance = aws_instance.gpu.id
  tags = { Project = local.prefix }
}
resource "aws_route53_record" "llm" {
  count = var.route53_zone_id == "" ? 0 : 1
  zone_id = var.route53_zone_id
  name = var.domain
  type = "A"
  ttl = 60
  records = [aws_eip.llm.public_ip]
}
