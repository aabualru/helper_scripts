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

# Run Terraform command to get subnets string and assign it to SUBNET_IDS
SUBNET_IDS=$(terraform output -raw cluster-subnets-string)

# Extract the first subnet (public subnet) and assign it to PUBLIC_SUBNET
PUBLIC_SUBNET=$(echo $SUBNET_IDS | cut -d ',' -f1)

# Extract the second subnet (private subnet) and assign it to PRIVATE_SUBNET
PRIVATE_SUBNET=$(echo $SUBNET_IDS | cut -d ',' -f2)

# Now, you can use the $PUBLIC_SUBNET and $PRIVATE_SUBNET variables as needed
echo "Public Subnet: $PUBLIC_SUBNET"
echo "Private Subnet: $PRIVATE_SUBNET"
