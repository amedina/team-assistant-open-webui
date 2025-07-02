# Configure Terraform to store state in Google Cloud Storage
# This ensures team collaboration and state locking

terraform {
  backend "gcs" {
    bucket = "ps-agent-sandbox-terraform-state"
    prefix = "open-webui/staging"
  }
}

# Note: Before running terraform init, create the state bucket:
# gsutil mb gs://your-project-id-terraform-state
# gsutil versioning set on gs://your-project-id-terraform-state 