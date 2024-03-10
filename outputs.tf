output "terraform_backend_role_arn" {
  value = aws_iam_role.terraform_backend.arn
}

output "terraform_state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}
