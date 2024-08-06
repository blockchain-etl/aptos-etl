# Aptos Infrastructure Terraform Code

## Prerequisites

* A GCP bucket to store the Terraform states
* `gcloud` admin permissions

## Code structure
- tfvars/prod.tfvars - Values to assign to the Terraform variables
- vars.tf - Definitions of the variables and local variables
- provider.tf - Definitions of the Terraform providers, backend bucket and versions
- bq.tf - Bigquery resources
- composer.tf - Composer resources
- dataflow.tf - Dataflow resources
- gcs.tf - GCP storage bucket resources
- networks.tf - GCP network resources
- pubsub.tf - Pubsub resources
- sa.tf - GCP IAM resources

## Provision the resources

```sh
terraform init
# This assumes that the provision is for the prod environment
terraform plan -var-file=tfvars/prod.tfvars
terraform apply -var-file=tfvars/prod.tfvars
```


## Destroy the resources
```sh
terraform destroy -var-file=tfvars/prod.tfvars
```