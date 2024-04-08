#!/bin/bash

# Prompt the user for the path to their local git folder
read -p "Enter the path of your local git folder: " git_folder

# Check if the specified path ends with a '/', if it does, remove it
[[ "$git_folder" == */ ]] && git_folder="${git_folder:0:-1}"

# Define the full path to the terraform-vpc-example directory
dir="$git_folder/terraform-vpc-example"

# Check if the terraform-vpc-example folder exists
if [ ! -d "$dir" ]; then
    echo "The folder terraform-vpc-example does not exist. Cloning..."
    # Change to the git_folder directory
    cd "$git_folder" || exit
    # Clone the terraform-vpc-example repository
    git clone https://github.com/openshift-cs/terraform-vpc-example
else
    echo "The folder terraform-vpc-example already exists."
fi

# Change directory to terraform-vpc-example
cd "$dir" || exit

# Prompt for the AWS region
read -p "Enter the AWS region: " region

# Initialize Terraform
terraform init

# Plan Terraform with the specified region
terraform plan -out rosa.tfplan -var "region=$region"

echo "Terraform plan has been executed and output to rosa.tfplan"

# Apply the Terraform plan
terraform apply "rosa.tfplan"

# Extract Subnets and Tagging
SUBNET_IDS=$(terraform output -raw cluster-subnets-string)
PUBLIC_SUBNET=$(echo $SUBNET_IDS | cut -d ',' -f1)
PRIVATE_SUBNET=$(echo $SUBNET_IDS | cut -d ',' -f2)
aws ec2 create-tags --resources $PUBLIC_SUBNET --tags Key=kubernetes.io/role/elb,Value=1
aws ec2 create-tags --resources $PRIVATE_SUBNET --tags Key=kubernetes.io/role/internal-elb,Value=1

# Create ROSA account roles
rosa create account-roles --hosted-cp --mode auto --yes

# Prompt for ACCOUNT_ROLES_PREFIX and set it
read -p "Enter the ACCOUNT_ROLES_PREFIX: " ACCOUNT_ROLES_PREFIX
export ACCOUNT_ROLES_PREFIX=$ACCOUNT_ROLES_PREFIX
echo "ACCOUNT_ROLES_PREFIX: $ACCOUNT_ROLES_PREFIX"

# Create OIDC provider
rosa create oidc-config --mode=auto  --yes

# Prompt for OIDC_ID and set it
read -p "Enter the OIDC_ID: " OIDC_ID
export OIDC_ID=$OIDC_ID

# Prompt for OPERATOR_ROLE_PREFIX and set it
read -p "Enter the OPERATOR_ROLE_PREFIX: " OPERATOR_ROLE_PREFIX
export OPERATOR_ROLES_PREFIX=$OPERATOR_ROLE_PREFIX

export AWS_ACCOUNT_ID=`aws sts get-caller-identity --query Account --output text`

# Create operator roles
rosa create operator-roles --hosted-cp --prefix=$OPERATOR_ROLES_PREFIX --oidc-config-id=$OIDC_ID --installer-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ACCOUNT_ROLES_PREFIX}-HCP-ROSA-Installer-Role

# Prompt for CLUSTER_NAME
read -p "Enter the CLUSTER_NAME: " CLUSTER_NAME

# Create ROSA cluster
rosa create cluster --cluster-name=$CLUSTER_NAME --sts --mode=auto --hosted-cp --operator-roles-prefix $OPERATOR_ROLES_PREFIX --oidc-config-id $OIDC_ID --subnet-ids=$SUBNET_IDS

echo "Script execution completed."
