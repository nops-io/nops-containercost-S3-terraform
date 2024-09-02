terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"  # Replace with the specific version you need
    }
  }

  required_version = ">= 1.0.0"  # Replace with the Terraform version you are using
}

provider "aws" {
  region = var.aws_region  # Replace with your desired region or variable
}