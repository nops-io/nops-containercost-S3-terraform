# Terraform Project
This repository contains Terraform configurations to manage infrastructure on AWS. Follow the steps below to authenticate with AWS, run Terraform commands, and manage your infrastructure.
## Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) installed on your local machine.
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured.
## Step 1: Authenticate to AWS
You need to authenticate to AWS before running Terraform commands. You can authenticate using the AWS CLI or by setting environment variables.
### Option 1: AWS CLI
1. **Configure the AWS CLI:**
    ```bash
    aws configure
    ```
    You'll be prompted to enter your AWS Access Key ID, Secret Access Key, region, and output format.
2. **Verify your authentication:**
    ```bash
    aws sts get-caller-identity
    ```
    This command should return your AWS account details if the authentication was successful.
### Option 2: Environment Variables
Alternatively, you can set the following environment variables:
```bash
export AWS_ACCESS_KEY_ID=<Your_Access_Key_ID>
export AWS_SECRET_ACCESS_KEY=<Your_Secret_Access_Key>
export AWS_DEFAULT_REGION=<Your_Region>
```
### Option 3: Assume an IAM Role
If you need to assume a role, use the following command:
```bash
aws sts assume-role --role-arn arn:aws:iam::<account-id>:role/<role-name> --role-session-name <session-name>
```
Alternatively, you can set the following environment variables:
```bash
export AWS_ACCESS_KEY_ID=<Your_Access_Key_ID>
export AWS_SECRET_ACCESS_KEY=<Your_Secret_Access_Key>
export AWS_DEFAULT_REGION=<Your_Region>
```
## Step 2: Update variables.tf
Update the variables with your values:
```bash
include_regions # Comma-separated list of regions where EKS cluster are created (e.g., us-east-1,us-east-2,us-west-1,us-west-2) or left blank to use the region where the Lambda will be created
```
```bash
role_name # The name of the IAM role created during the AWS acccount onboarding to the nOps platform (e.g., StackSet-example>-1234ab1-nopsAccessIamRole-123A12AB1AB1A, Nops-Integration-example)
```
```bash
aws_region # Replace with your preferred default region
```
## Step 3: Initialize Terraform
Before using Terraform, initialize your working directory:
```bash
terraform init
```
## Step 4: Plan the Infrastructure Changes
Generate an execution plan to review the changes Terraform will make:
```bash
terraform plan
```
## Step 5: Apply the Infrastructure Changes
To apply the changes and create/update the infrastructure, run:
```bash
terraform apply
```
## Step 6: Manually trigger IAM role creation Lambda (Optional)
Once the terraform apply is successfully run you can manually trigger the recently created Lambda (*nops-container-cost-agent-role-creation*) in the specified AWS region set in the variable:
```bash
aws_region
```
or wait 2 hours until the scheduled time is reached, Lambda will create IAM roles for each of your EKS clusters. 
## Step 7: Destroy the Infrastructure (Optional)
If you need to tear down the infrastructure, use:
```bash
terraform destroy
```
## Step 8: Destroy nops-ccost IAM roles (Optional)
After the infrastucture is destroyed via terraform you can destroy the IAM roles that were created via the Lambda (*nops-container-cost-agent-role-creation*), you can identify those IAM roles with the prefix:
```bash
nops-ccost-<your_cluster_name>
```