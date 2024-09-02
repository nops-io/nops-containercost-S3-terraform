import boto3
import json
import os
import re

def lambda_handler(event, context):
    # Use the IncludeRegions environment variable
    default_region = os.environ['AWS_REGION']
    default_regions = [default_region]
    included_regions = os.environ.get('IncludeRegions', '').split(',') if os.environ.get('IncludeRegions') else default_regions
    print(f"These are the included regions: {included_regions}")

    # Initialize the STS client to get the account ID
    sts_client = boto3.client('sts')
    account_id = os.environ.get('AccountId')

    # Initialize the boto3 clients
    iam_client = boto3.client('iam')

    # A set to keep track of the required roles
    required_roles = set()
    cluster_region_map = {}

    # Iterate through each included region to find EKS clusters
    for region in included_regions:
        regional_eks = boto3.client('eks', region_name=region)
        try:
            clusters = regional_eks.list_clusters()['clusters']
        except Exception as e:
            print(f"Error retrieving clusters for region {region}: {e}")
            continue

        # Prepare the required role names based on the cluster names
        for cluster_name in clusters:
            required_roles.add(f"nops-ccost-{cluster_name}_{region}")

    # List existing IAM roles
    existing_roles = set()
    paginator = iam_client.get_paginator('list_roles')
    for page in paginator.paginate():
        for role in page['Roles']:
            role_name = role['RoleName']
            if role_name.startswith("nops-ccost-"):
                existing_roles.add(role_name)

    # Determine which roles need to be created and which are orphaned
    missing_roles = required_roles - existing_roles
    orphaned_roles = existing_roles - required_roles

    # Define the regex pattern to extract cluster name and region
    pattern = re.compile(r"^nops-ccost-(.+)_(.+)$")

    # Create missing IAM roles
    for role_name in missing_roles:
        try:
            # Use regex to match and capture cluster name and region
            match = pattern.match(role_name)
            if not match:
                print(f"Skipping malformed role name: {role_name}")
                continue

            cluster_name, region_to_use = match.groups()
            print(f"Creating role for cluster: {cluster_name} in region: {region_to_use}")

            # Validate the region against AWS known region names
            all_regions = [region_info['RegionName'] for region_info in boto3.client('ec2').describe_regions()['Regions']]
            if region_to_use not in all_regions:
                print(f"Skipping unknown region: {region_to_use}")
                continue

            # Initialize the regional EKS client
            regional_eks = boto3.client('eks', region_name=region_to_use)
            cluster_info = regional_eks.describe_cluster(name=cluster_name)['cluster']

            oidc_issuer = cluster_info.get('identity', {}).get('oidc', {}).get('issuer')
            if oidc_issuer:
                # Extract the last segment of the OIDC URL to form the correct ARN
                oidc_id = oidc_issuer.split('/')[-1]
                oidc_arn = f"arn:aws:iam::{account_id}:oidc-provider/oidc.eks.{region_to_use}.amazonaws.com/id/{oidc_id}"

                # Construct the trust relationship document
                assume_role_policy = json.dumps({
                    "Version": "2012-10-17",
                    "Statement": [{
                        "Effect": "Allow",
                        "Principal": {"Federated": oidc_arn},
                        "Action": "sts:AssumeRoleWithWebIdentity",
                        "Condition": {
                            "StringEquals": {
                                f"oidc.eks.{region_to_use}.amazonaws.com/id/{oidc_id}:sub": "system:serviceaccount:nops:nops-container-insights"
                            }
                        }
                    }]
                })

                # Define the inline policy
                inline_policy = {
                    "Version": "2012-10-17",
                    "Statement": [{
                        "Effect": "Allow",
                        "Action": [
                            "s3:PutObject",
                            "s3:GetObject",
                            "s3:ListBucket"
                        ],
                        "Resource": [
                            f"arn:aws:s3:::nops-container-cost-{account_id}",
                            f"arn:aws:s3:::nops-container-cost-{account_id}/*"
                        ]
                    }]
                }

                # Create the IAM role
                iam_client.create_role(
                    RoleName=role_name,
                    AssumeRolePolicyDocument=assume_role_policy
                )
                print(f"Created role {role_name} with trust relationship")

                # Attach the inline policy
                iam_client.put_role_policy(
                    RoleName=role_name,
                    PolicyName='S3Policy',
                    PolicyDocument=json.dumps(inline_policy)
                )
                print(f"Attached inline policy to role {role_name}")
            else:
                print(f"No OIDC identity provider associated with cluster {cluster_name} in region {region_to_use}")

        except Exception as e:
            print(f"Error creating role {role_name}: {e}")

    # Delete orphaned IAM roles
    for role_name in orphaned_roles:
        try:
            # List and delete inline policies for the role
            policies = iam_client.list_role_policies(RoleName=role_name)['PolicyNames']
            for policy in policies:
                iam_client.delete_role_policy(RoleName=role_name, PolicyName=policy)
                print(f"Deleted policy {policy} from role {role_name}")

            # Delete the role itself
            iam_client.delete_role(RoleName=role_name)
            print(f"Deleted orphaned IAM role {role_name}")
        except Exception as e:
            print(f"Error deleting IAM role {role_name}: {e}")
