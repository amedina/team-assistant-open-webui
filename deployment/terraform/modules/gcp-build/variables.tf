variable "project_id" {
  description = "The ID of the Google Cloud project."
  type        = string
}

variable "region" {
  description = "The Google Cloud region where the build will be executed."
  type        = string
}

variable "build_config_path" {
  description = "The path to the Cloud Build configuration file."
  type        = string
}

variable "artifact_repository_url" {
  description = "The URL of the Artifact Registry repository."
  type        = string
}

variable "source_path" {
  description = "The path to the source code to be built."
  type        = string
}

variable "machine_type" {
  description = "The machine type to use for the build."
  type        = string
  default     = "E2_HIGHCPU_8"
}

variable "image_name" {
  description = "The name of the Docker image to be built."
  type        = string
  default     = "open-webui"
}

variable "branch_name" {
  description = "The branch to build from."
  type        = string
  default     = "main"
}

variable "github_repo_name" {
  description = "The name of the GitHub repository."
  type        = string
}
