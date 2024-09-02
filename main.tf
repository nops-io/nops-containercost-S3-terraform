data "aws_caller_identity" "current" {}

# S3 Bucket resource
resource "aws_s3_bucket" "nops_container_cost" {
  bucket = "nops-container-cost-${data.aws_caller_identity.current.account_id}"
}

# Optional: Ensure that all objects are encrypted using bucket default encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.nops_container_cost.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_policy" "read_policy" {
  name        = "nops-container-cost-s3-read-only"
  description = "Read-only access to nops-container-cost bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::nops-container-cost-${data.aws_caller_identity.current.account_id}",
        "arn:aws:s3:::nops-container-cost-${data.aws_caller_identity.current.account_id}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_read_policy" {
  policy_arn = aws_iam_policy.read_policy.arn
  role      = var.role_name
}

resource "aws_iam_user" "nops_container_cost_user" {
  count    = var.create_iam_user ? 1 : 0
  name     = "nops-container-cost-s3"
}

resource "aws_iam_policy" "s3_policy" {
  count    = var.create_iam_user ? 1 : 0
  name     = "nops-container-cost-s3-read-only-iam-user"
  policy   = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::nops-container-cost-${data.aws_caller_identity.current.account_id}",
        "arn:aws:s3:::nops-container-cost-${data.aws_caller_identity.current.account_id}/*"
      ]
    }]
  })
}

resource "aws_iam_user_policy_attachment" "s3_policy_attachment" {
  count      = var.create_iam_user ? 1 : 0
  user       = aws_iam_user.nops_container_cost_user[count.index].name
  policy_arn = aws_iam_policy.s3_policy[count.index].arn
}

resource "aws_iam_role" "lambda_role" {
  count    = var.create_iam_user ? 0 : 1
  name = "nops-container-cost-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  count    = var.create_iam_user ? 0 : 1
  name       = "attach-basic-execution-role"
  roles      = [aws_iam_role.lambda_role[count.index].name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_inline_policy" {
  count    = var.create_iam_user ? 0 : 1
  name   = "nops-container-cost-lambda-policy"
  role   = aws_iam_role.lambda_role[count.index].name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Action = [
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:CreateRole",
        "iam:PutRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DeleteRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:ListRoles",
        "iam:DeleteRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListRolePolicies",
        "eks:DescribeCluster",
        "eks:ListClusters",
        "sts:GetCallerIdentity",
        "events:PutEvents",
        "ec2:DescribeRegions"
      ]
      Resource = "*"
    }]
  })
}

data "archive_file" "python_lambda_package" {
  type        = "zip"
  source_file = "${path.module}/files/index.py"
  output_path = "${path.module}/files/index.zip"
}

resource "aws_lambda_function" "role_creation_function" {
  count    = var.create_iam_user ? 0 : 1
  function_name = "nops-container-cost-agent-role-creation"
  role          = aws_iam_role.lambda_role[count.index].arn
  handler       = "index.lambda_handler"
  runtime       = "python3.10"
  timeout       = 60
  environment {
    variables = {
      IncludeRegions = var.include_regions
      AccountId      = data.aws_caller_identity.current.account_id
    }
  }
  architectures = ["arm64"]

  filename      = data.archive_file.python_lambda_package.output_path
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
}

# Create a CloudWatch Events rule to trigger the Lambda function every 2 hours
resource "aws_cloudwatch_event_rule" "role_creation_lambda_schedule" {
  count    = var.create_iam_user ? 0 : 1
  name        = "nops-container-cost-agent-role-creation-schedule"
  description = "Trigger Lambda every 2 hours"
  schedule_expression = "rate(2 hours)"
}

# Create a CloudWatch Events target to invoke the Lambda function
resource "aws_cloudwatch_event_target" "role_creation_lambda_target" {
  count    = var.create_iam_user ? 0 : 1
  rule      = aws_cloudwatch_event_rule.role_creation_lambda_schedule[count.index].name
  arn       = aws_lambda_function.role_creation_function[count.index].arn
  target_id = "nops-container-cost-agent-role-creation-lambda"
}

# Grant CloudWatch Events permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  count    = var.create_iam_user ? 0 : 1
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.role_creation_function[count.index].function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.role_creation_lambda_schedule[count.index].arn
}
