terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

data "aws_caller_identity" "current" {}


provider "aws" {
  region = var.AWS_REGION

  default_tags {
    tags = {
      Application = "terraform-backend"
    }
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-production-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name                        = "terraform-locks"
  hash_key                    = "LockID"
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true

  lifecycle {
    prevent_destroy = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_iam_role" "terraform_backend" {
  name = "TerraformBackendRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          AWS = data.aws_caller_identity.current.account_id
        }
      }
    ]
  })
}

resource "aws_iam_policy" "terraform_backend" {
  name = "TerraformBackendPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
        ],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/*",
        ],
      },
      {
        Action = [
          "s3:ListBucket",
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.terraform_state.arn,
        ],
      },
      {
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        Effect = "Allow",
        Resource = [
          aws_dynamodb_table.terraform_locks.arn,
        ],
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_backend" {
  policy_arn = aws_iam_policy.terraform_backend.arn
  role       = aws_iam_role.terraform_backend.name
}
