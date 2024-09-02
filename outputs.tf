output "s3_bucket_name" {
  value = aws_s3_bucket.nops_container_cost.bucket
}

output "iam_user_name" {
  value = var.create_iam_user ? aws_iam_user.nops_container_cost_user[0].name : ""
}

output "lambda_function_name" {
  value = var.create_iam_user ? null : aws_lambda_function.role_creation_function[0].function_name
}