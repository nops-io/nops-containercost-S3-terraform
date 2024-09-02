variable "include_regions" {
  description = "Comma-separated list of regions where EKS cluster are created (e.g., us-east-1,us-east-2,us-west-1,us-west-2) or left blank to use the region where the Lambda will be created"
  type        = string
  default     = ""
}

variable "role_name" {
  description = "The name of the IAM role created during the AWS acccount onboarding to the nOps platform (e.g., StackSet-example>-1234ab1-nopsAccessIamRole-123A12AB1AB1A, Nops-Integration-example)"
  type        = string
  default     = ""
}

variable "create_iam_user" {
  description = "Whether to create an IAM user (true or false), to support EKS clusters that do not have an IAM OIDC provider configured."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "The AWS region where resources will be created."
  type        = string
  default     = ""  # Replace with your preferred default region
}