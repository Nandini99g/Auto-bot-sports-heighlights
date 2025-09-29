###############################################################################
# main.tf - Single-file Terraform for Sports Highlights Pipeline (EC2 + S3)
# - Creates S3 buckets (metadata, videos, logs)
# - Creates IAM roles (EC2 instance role + MediaConvert role)
# - Creates optional SNS topic
# - Creates EC2 instance (Ubuntu) with user_data to install Docker + run container
#
# NOTE: Customize variable values below BEFORE apply. Don't commit secrets.
###############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

# --------------------
# VARIABLES
# --------------------
variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "ap-south-1"
}

variable "project_prefix" {
  description = "Prefix for naming buckets and resources"
  type        = string
  default     = "sports-highlights"
}

variable "ssh_my_ip_cidr" {
  description = "Your IP in CIDR format for SSH access (e.g. 203.0.113.5/32)"
  type        = string
  default     = "49.207.222.248/32"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "public_key" {
  description = "Optional: your SSH public key contents (leave empty to skip creating key pair)"
  type        = string
  default     = "cat ~/.ssh/id_rsa.pub | pbcopy"
}

variable "create_sns" {
  description = "Create an SNS topic for optional notifications"
  type        = bool
  default     = false
}

variable "git_repo_url" {
  description = "Git repo URL where your app code resides (public or private if you handle auth)"
  type        = string
  default     = "https://github.com/Nandini99g/sports-highlights-pipeline.git"  # set to your repo (e.g. https://github.com/Nandini99g/sports-highlights-pipeline.git)
}

variable "env_s3_key" {
  description = "S3 key (object path) inside metadata bucket where pipeline.env will be stored for EC2 user_data to download"
  type        = string
  default     = "config/pipeline.env"
}

# --------------------
# DATA: Account, AMI
# --------------------
data "aws_caller_identity" "me" {}

# Grab latest Ubuntu 22.04 AMI in region
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# --------------------
# S3 BUCKETS
# --------------------
locals {
  metadata_bucket = "${var.project_prefix}-metadata-${data.aws_caller_identity.me.account_id}"
  videos_bucket   = "${var.project_prefix}-videos-${data.aws_caller_identity.me.account_id}"
  logs_bucket     = "${var.project_prefix}-logs-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket" "metadata" {
  bucket = local.metadata_bucket
  #acl    = "private"
  tags = {
    Name = local.metadata_bucket
    Env  = "dev"
  }
}

resource "aws_s3_bucket" "videos" {
  bucket = local.videos_bucket
  #acl    = "private"
  tags = {
    Name = local.videos_bucket
    Env  = "dev"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket
  #acl    = "private"
  tags = {
    Name = local.logs_bucket
    Env  = "dev"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "metadata_block" {
  bucket                  = aws_s3_bucket.metadata.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "videos_block" {
  bucket                  = aws_s3_bucket.videos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "logs_block" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------
# IAM: EC2 instance role (for S3, MediaConvert, SSM, SNS)
# --------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Inline policy for EC2 to access S3 buckets, MediaConvert (create job/describe), SSM, SNS publish
data "aws_iam_policy_document" "ec2_policy" {
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.metadata.arn,
      "${aws_s3_bucket.metadata.arn}/*",
      aws_s3_bucket.videos.arn,
      "${aws_s3_bucket.videos.arn}/*",
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*"
    ]
  }

  statement {
    sid    = "MediaConvertAccess"
    effect = "Allow"
    actions = [
      "mediaconvert:DescribeEndpoints",
      "mediaconvert:CreateJob",
      "mediaconvert:GetJob",
      "mediaconvert:CancelJob"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SSMAccess"
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommands"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SNSAccess"
    effect = "Allow"
    actions = ["sns:Publish"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_inline_policy" {
  name   = "${var.project_prefix}-ec2-policy"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_policy.json
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_prefix}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# --------------------
# IAM: MediaConvert role (service role for MediaConvert to write outputs to S3)
# --------------------
data "aws_iam_policy_document" "mc_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["mediaconvert.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "mediaconvert_role" {
  name               = "${var.project_prefix}-mediaconvert-role"
  assume_role_policy = data.aws_iam_policy_document.mc_assume.json
}

data "aws_iam_policy_document" "mediaconvert_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.videos.arn,
      "${aws_s3_bucket.videos.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "mediaconvert_inline" {
  name   = "${var.project_prefix}-mediaconvert-policy"
  role   = aws_iam_role.mediaconvert_role.id
  policy = data.aws_iam_policy_document.mediaconvert_policy.json
}

# --------------------
# (Optional) Create Key pair if public_key provided
# --------------------
resource "aws_key_pair" "deployer" {
  count = var.public_key == "" ? 0 : 1
  key_name   = "sports-highlights-key"
  public_key = file("/home/nandini/new-ec2-key.pub") 
}

# --------------------
# SECURITY GROUP
# --------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_prefix}-sg"
  description = "Allow SSH from user"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.ssh_my_ip_cidr]
    ipv6_cidr_blocks = []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_prefix}-sg"
  }
}

# Get default VPC (for ease)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --------------------
# EC2 INSTANCE
# --------------------
# user_data will:
# - install docker, awscli, git, ssm agent
# - clone repo (if provided) into /home/ubuntu/app
# - attempt to download pipeline.env from metadata bucket/key to app/.env
# - build docker and run container
locals {
  user_data = <<-EOF
              #!/bin/bash
              set -e
              apt-get update -y
              apt-get install -y docker.io git python3-pip unzip
              # Install AWS CLI v2 if not present (simple install)
              if ! command -v aws >/dev/null 2>&1; then
                apt-get install -y curl
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
                unzip /tmp/awscliv2.zip -d /tmp
                /tmp/aws/install
              fi
              # Install and start SSM agent (for Ubuntu)
              snap install amazon-ssm-agent --classic || true
              systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
              mkdir -p /home/ubuntu/app
              chown -R ubuntu:ubuntu /home/ubuntu/app
              cd /home/ubuntu/app
              # clone repo if provided
              if [ "${var.git_repo_url}" != "" ]; then
                su - ubuntu -c "if [ ! -d /home/ubuntu/app/repo ]; then git clone '${var.git_repo_url}' repo || true; fi"
                cd /home/ubuntu/app/repo || true
              fi
              # Try to fetch pipeline.env from metadata bucket
              if aws s3 ls "s3://${aws_s3_bucket.metadata.bucket}/${var.env_s3_key}" 2>/dev/null; then
                aws s3 cp "s3://${aws_s3_bucket.metadata.bucket}/${var.env_s3_key}" /home/ubuntu/app/.env || true
                chown ubuntu:ubuntu /home/ubuntu/app/.env || true
              fi
              # Build docker image if Dockerfile present
              if [ -f /home/ubuntu/app/repo/app/Dockerfile ]; then
                cd /home/ubuntu/app/repo/app
                docker build -t sports-pipeline:latest .
                # Run once as detached container (it can handle scheduling internally or exit)
                docker run -d --env-file /home/ubuntu/app/.env --name sports-pipeline sports-pipeline:latest || true
              fi
              # Add a cron job (simple) that runs daily at 03:00 UTC
              ( crontab -l 2>/dev/null; echo "0 3 * * * cd /home/ubuntu/app/repo/app && docker run --rm --env-file /home/ubuntu/app/.env sports-pipeline:latest >> /home/ubuntu/pipeline_cron.log 2>&1" ) | crontab -
              EOF
}

resource "aws_instance" "pipeline_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = "new_key"
  subnet_id              = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  #key_name = var.public_key == "" ? null : aws_key_pair.deployer[0].key_name

  user_data = local.user_data

  tags = {
    Name = "${var.project_prefix}-ec2"
  }
}

# --------------------
# (Optional) SNS Topic
# --------------------
resource "aws_sns_topic" "pipeline_topic" {
  count = var.create_sns ? 1 : 0
  name  = "${var.project_prefix}-topic"
}

# --------------------
# OUTPUTS
# --------------------
output "metadata_bucket" {
  value = aws_s3_bucket.metadata.bucket
}

output "videos_bucket" {
  value = aws_s3_bucket.videos.bucket
}

output "logs_bucket" {
  value = aws_s3_bucket.logs.bucket
}

output "ec2_public_ip" {
  value = aws_instance.pipeline_instance.public_ip
}

output "ec2_instance_id" {
  value = aws_instance.pipeline_instance.id
}

output "ec2_iam_role" {
  value = aws_iam_role.ec2_role.arn
}

output "mediaconvert_role_arn" {
  value = aws_iam_role.mediaconvert_role.arn
}

output "sns_topic_arn" {
  value       = var.create_sns ? aws_sns_topic.pipeline_topic[0].arn : ""
  description = "SNS topic ARN (empty if not created)"
}

# --------------------
# (Optional) EventBridge + SSM RunCommand integration
# --------------------
# NOTE: EventBridge can't directly "start a container on EC2". Common pattern:
# - Create an EventBridge schedule rule
# - Use EventBridge target of type SSM SendCommand to run a shell on the EC2 instance
# - For this to work the EC2 role must allow ssm:SendCommand (we add that above) AND the event target requires an IAM role that EventBridge will assume.
#
# The below is left commented because it requires additional role detail and may be confusing for first-time users.
#
# resource "aws_cloudwatch_event_rule" "daily" {
#   name                = "${var.project_prefix}-daily"
#   schedule_expression = "cron(0 3 * * ? *)"  # daily at 03:00 UTC
# }
#
# # create role for eventbridge to call ssm:SendCommand (requires careful least-privilege)
# resource "aws_iam_role" "eb_svc_role" {
#   name = "${var.project_prefix}-eb-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action = "sts:AssumeRole",
#       Effect = "Allow",
#       Principal = {
#         Service = "events.amazonaws.com"
#       }
#     }]
#   })
# }
#
# resource "aws_iam_role_policy" "eb_svc_policy" {
#   role = aws_iam_role.eb_svc_role.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = ["ssm:SendCommand"],
#         Resource = "*"
#       }
#     ]
#   })
# }
#
# resource "aws_cloudwatch_event_target" "run_cmd" {
#   rule = aws_cloudwatch_event_rule.daily.name
#   arn  = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.me.account_id}:document/AWS-RunShellScript"
#   role_arn = aws_iam_role.eb_svc_role.arn
#   input = jsonencode({
#     DocumentName = "AWS-RunShellScript",
#     Parameters = {
#       commands = [
#         "docker run --rm --env-file /home/ubuntu/app/.env sports-pipeline:latest"
#       ]
#     },
#     InstanceIds = [ aws_instance.pipeline_instance.id ]
#   })
# }
#
# # If you want EventBridge schedule -> SSM, uncomment above blocks and then run terraform apply.
#
