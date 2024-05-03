#!/bin/bash
set -e

# Prompt the user for the path to their local git folder and validate it
read -p "Enter the path of your local git folder: " git_folder
if [[ ! -d "$git_folder" ]]; then
    echo "The specified directory does not exist."
    exit 1
fi

# Normalize the path to remove a trailing '/'
git_folder="${git_folder%/}"

# Define the full path to the terraform-vpc-example directory
dir="$git_folder/terraform-vpc-example"

# Clone or check the terraform-vpc-example directory
if [ ! -d "$dir" ]; then
    echo "The folder terraform-vpc-example does not exist. Cloning..."
    git clone https://github.com/openshift-cs/terraform-vpc-example "$dir"
else
    echo "The folder terraform-vpc-example already exists."
fi

# Change directory to terraform-vpc-example
cd "$dir"

# Prompt for the AWS region and validate input
read -p "Enter the AWS region: " region
if [[ -z "$region" ]]; then
    echo "AWS region cannot be empty."
    exit 1
fi
export region=$region

# Initialize and plan Terraform deployment
terraform init
terraform plan -out rosa.tfplan -var "region=$region"
echo "Terraform plan has been executed and output to rosa.tfplan"

# Apply the Terraform plan
terraform apply "rosa.tfplan"

# Extract Subnets and Tagging
SUBNET_IDS=$(terraform output -raw cluster-subnets-string)

# Create ROSA account roles
rosa create account-roles --hosted-cp --mode auto --yes

# Prompt for ACCOUNT_ROLES_PREFIX, set, and export it
read -p "Enter the ACCOUNT_ROLES_PREFIX: " account_roles_prefix
export ACCOUNT_ROLES_PREFIX=$account_roles_prefix
echo "ACCOUNT_ROLES_PREFIX: $ACCOUNT_ROLES_PREFIX"

# Create OIDC provider and obtain OIDC_ID
OIDC_ID=$(rosa create oidc-config --mode auto --yes -o json | jq -r '.id')
if [[ -z "$OIDC_ID" ]]; then
    echo "Failed to create OIDC provider or parse the ID."
    exit 1
fi

# Prompt for OPERATOR_ROLE_PREFIX, set, and export it
read -p "Enter the OPERATOR_ROLE_PREFIX: " operator_role_prefix
export OPERATOR_ROLE_PREFIX=$operator_role_prefix

# Retrieve AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Prompt for Billing ID, set, and export it
read -p "Enter the Billing ID: " billing_id
export BILLING_ID=$billing_id
echo "BILLING_ID: $BILLING_ID"

# Create operator roles
rosa create operator-roles --hosted-cp --prefix=$OPERATOR_ROLE_PREFIX --oidc-config-id=$OIDC_ID --installer-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ACCOUNT_ROLES_PREFIX}-HCP-ROSA-Installer-Role

# Prompt for CLUSTER_NAME
read -p "Enter the CLUSTER_NAME: " cluster_name

# Create ROSA cluster
rosa create cluster --cluster-name=$cluster_name --sts --mode=auto --hosted-cp --operator-roles-prefix $OPERATOR_ROLE_PREFIX --oidc-config-id $OIDC_ID --subnet-ids=$SUBNET_IDS --billing-account=$BILLING_ID

echo "Script execution completed."
