# Aptos-ETL Infrastructure-as-code

## Prerequisites

Before running the Terraform code, ensure the following:

1. **GCP Bucket**: A Google Cloud Storage bucket is required to store the Terraform state files.
2. **Admin Permissions**: You must have `gcloud` admin permissions.
3. **Enable Required APIs**: Enable the following APIs in the GCP console:

   - Dataflow API
   - Kubernetes Engine API
   - Cloud Pub/Sub API
   - Cloud Composer API
   - BigQuery API

   You can follow the [official documentation](https://cloud.google.com/endpoints/docs/openapi/enable-api) to enable these APIs.
4. Terraform >= 1.5.7
5. Helm >= 3.16.1

## Code Structure

- **`tfvars/prod.tfvars`**: Contains values for the Terraform variables for the production environment.
- **`vars.tf`**: Defines Terraform variables and local variables.
- **`provider.tf`**: Specifies the Terraform providers, backend bucket, and versions.
- **`bq.tf`**: Manages BigQuery resources.
- **`composer.tf`**: Manages Cloud Composer resources.
- **`dataflow.tf`**: Manages Dataflow resources.
- **`gcs.tf`**: Manages Google Cloud Storage bucket resources.
- **`networks.tf`**: Manages GCP network resources.
- **`pubsub.tf`**: Manages Cloud Pub/Sub resources.
- **`sa.tf`**: Manages Google Cloud IAM (Service Account) resources.
- **`helm/aptos-fullnodes`**: Helm chart to deploy aptos fullnodes

## Provisioning Infrastructure Resources
To provision resources, run the following commands:
```sh
terraform init
# Provision resources for the production environment
terraform plan -var-file=tfvars/prod.tfvars
terraform apply -var-file=tfvars/prod.tfvars
```

## Deploy Aptos Fullnodes
To deploy Aptos mainnet and testnet fulllnodes, get into `helm/aptos-fullnodes` folder, and run the following commands:
```
# Deploy mainnet fullnode
helm install <release name> -f values.aptos.prod.mainnet.yaml -n <namespace name>
# Deploy testnet fullnode
helm install <release name> -f values.aptos.prod.testnet.yaml -n <namespace name>
```
Note: The namespace is required to be created before you can deploy the fullnodes.

## Destroying Resources

To destroy the infrastructure resources, run the following command:

```sh
terraform destroy -var-file=tfvars/prod.tfvars
```



