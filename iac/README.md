# Aptos-ETL Infrastructure-as-code

## Overview
This repository contains the necessary infrastructure as code to set up Aptos Fullnodes for an ETL (Extract, Transform, Load) project. It provisions and configures a secure environment on Google Cloud Platform (GCP) for efficient data handling and processing.

## Structure
- **`terraform`**: Contains the Terraform configuration for provisioning the GCP environment, setup Aptos Fullnodes, and ETL applications (aptos-indexing-coordinator and aptos-extracting-transformer). 
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
    - **`helm.tf`**: Manages Helm charts resources.
    - **`kubernetes.tf`**: Manages Kubernetes resrouces
- **`helm`**: Contains Helm charts for Aptos Fullnodes, and ETL applications
    - **`aptos-fullnodes`**: Helm chart to deploy aptos fullnodes
    - **`aptos-indexing-coordinator`**: Helm chart to deploy Aptos indexing coordinator
    - **`aptos-extractor-transformer`**: Helm chart to deply Aptos extracting transformer
    - **`keda`**: Heml chart to deploy KEDA to autoscale the ETL applications

## Resources and Scripts

### Terraform-Provisioned Resources
The Terraform code in the `terraform/` directory provisions the following resources:

1. Virtual Private Cloud (VPC) network and subnets
2. Firewall rules to ensure secure access
3. Google Kubernetes Engine (GKE) cluster with:
    - Aptos Fullnodes
    - Aptos Indexing Coordinator
    - Aptos Extractor Transformer
- KEDA Autoscaler
4. Cloud NAT for secure outbound internet access
5. IAM service accounts and roles for secure operations
6. BigQuery datasets and tables with predefined schemas
7. Dataflow jobs for data processing
8. Cloud Composer pipelines for workflow orchestration
9. Pub/Sub messaging services
10. GCS buckets for object storage

## Deployment Environment
This project can be deployed from:

- A personal laptop
- A virtual machine (VM)
- Google Cloud Shell

As long as the prerequisites are met and the Google Cloud SDK is properly configured, Terraform commands can be executed from any of these environments.

## Prerequisites
- Terraform >= 1.5.7
- A GCP bucket for storing Terraform states
- A Google Cloud Platform account
- Authenticate Terraform to Google Cloud Platform:
    ```bash
    gcloud auth application-default login
    ```
- Helm >= 3.16.1
- GCP Bucket: A Google Cloud Storage bucket is required to store the Terraform state files

## Setup Guide

### 1. Setting up Google Cloud SDK
1. Install the Google Cloud SDK by following the [official documentation](https://cloud.google.com/sdk/docs/install).
2. Authenticate with Google Cloud:
   ```bash
   gcloud auth login
   ```

### 2. Creating a New Google Cloud Project
1. Create a new project:
   ```bash
   gcloud projects create [PROJECT_ID] --name="[PROJECT_NAME]"
   ```
   Replace `[PROJECT_ID]` with a unique ID for your project, and `[PROJECT_NAME]` with a descriptive name.

2. Set the newly created project as the active project:
   ```bash
   gcloud config set project [PROJECT_ID]
   ```

3. List your existing billing accounts:
   ```bash
   gcloud billing accounts list
   ```
   This command will display a list of billing accounts you have access to, along with their IDs.

4. If you don't have a billing account or want to create a new one, follow the instructions in the [official Google Cloud documentation to create a billing account](https://cloud.google.com/billing/docs/how-to/create-billing-account). 

   Note: Creating a new billing account typically requires going through the Google Cloud Console, as it involves setting up payment methods and cannot be done entirely through the CLI.

5. Once you have a billing account ID, link it to your project:
   ```bash
   gcloud billing projects link [PROJECT_ID] --billing-account=[BILLING_ACCOUNT_ID]
   ```
   Replace `[BILLING_ACCOUNT_ID]` with the ID of the billing account you want to use.

### 3. Enabling Required APIs
Enable the necessary APIs in the GCP console:
```bash
gcloud services enable \
  dataflow.googleapis.com \
  container.googleapis.com \
  pubsub.googleapis.com \
  composer.googleapis.com \
  bigquery.googleapis.com \
  compute.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com
```

### 4. Creating a GCS Bucket for Terraform State

To create a new GCS bucket, you can use the following command:

```bash
gcloud storage buckets create gs://BUCKET_NAME --project=PROJECT_ID --location=BUCKET_LOCATION
```

Replace the following:
- `BUCKET_NAME`: A globally unique name for your bucket
- `PROJECT_ID`: Your Google Cloud project ID
- `BUCKET_LOCATION`: The location for your bucket (e.g., `us-central1`)

You can also specify additional flags:
- `--uniform-bucket-level-access`: Enables uniform bucket-level access
- `--public-access-prevention`: Sets public access prevention
- `--default-storage-class`: Sets the default storage class (e.g., `STANDARD`, `NEARLINE`, `COLDLINE`, `ARCHIVE`)

For example:

```bash
gcloud storage buckets create gs://my-terraform-state --project=my-project-id --location=us-central1 --uniform-bucket-level-access --public-access-prevention=enforced --default-storage-class=STANDARD
```
For more detailed information on creating buckets, including available regions and storage classes, refer to the [official Google Cloud documentation on creating storage buckets](https://cloud.google.com/storage/docs/creating-buckets#command-line).

### 5. Configuring Terraform

Now that you have set up your Google Cloud project and created a bucket for the Terraform state, you need to configure the Terraform files.

1. Navigate to the `terraform` directory in the Terraform codebase.

2. Open the `provider.tf` file and update the following:

   ```hcl
   terraform {
     backend "gcs" {
       bucket = "[BUCKET_NAME]"  # Replace with your bucket name
       prefix = "terraform/state"
     }
   }
   ```
   Open the `tfvars/prod.tfvars` file and update the following:
   ```hcl 
    project_id = <GCP project name>
   ```

   Replace `<BUCKET NAME>` with the name of the GCS bucket you created, and `<PROJECT ID>` with your Google Cloud project ID.

3. Review and adjust other variables in the `provider.tf` file as needed.

### 6. Specify Inserter and Extractor app versions 

Define the image repository and tag for the Coordinator app using the coordinator_image_tag and coordinator_repo variables located in [helm.tf](./terraform/helm.tf#L60-L77).
Similarly, define the image repository and tag for the Transformer app using the transformer_image_tag and transformer_repo variables in [helm.tf](./terraform/helm.tf#L101-L117).

You can find the latest application releases at the following repository: https://github.com/bcwt/aptos-etl # This is to be changed

### 7. Supple values for all the variables

Populate the necessary variables in the [tfvars/prod.tfvars](./terraform/tfvars/prod.tfvars#L1-L16) file with appropriate values for your environment.

The [`enabled_network` variable](./terraform/tfvars/prod.tfvars#L44) controls which network to be created.

### 8. Initializing and Applying Terraform

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the planned changes:
   ```bash
   terraform plan -var-file=tfvars/prod.tfvars
   ```
3. Run heml repo update
   ```bash
   helm repo update
   ```
   Note: This step is required as sometimes the helm provider would fail to retrieve the helm repository from the Internet.

3. Apply the Terraform configuration:
   ```bash
   terraform apply -var-file=tfvars/prod.tfvars
   ```
   Note: Due to the Dataflow API timed out issuw with Terraform, the Apply might fail with error message similar as:

   ```bash
   │ Error: Error waiting for job with job ID "2024-10-20_02_04_40-5400230924078250603" to be running: the job with ID "2024-10-20_02_04_40-5400230924078250603" has terminated with state "JOB_STATE_FAILED" instead of expected state "JOB_STATE_RUNNING"
   ```
   then rerun the `terraform apply -var-file=tfvars/prod.tfvars` command again.
### Project Teardown

1. Remove the kubernetes_namespace resource from the Terraform state file:
   ```bash
   terraform state list | grep kubernetes_namespace | xargs -n 1 terraform state rm
   ```
   Note: This command assumes that you have the bash compatible shell.
2. Remove all resources:
   ```sh
   terraform destroy -var-file=tfvars/prod.tfvars
   ```

## Additional Resources
- [Aptos Documentation](https://aptos.dev/en/build/get-started)
- [Google Cloud Documentation](https://cloud.google.com/docs)

