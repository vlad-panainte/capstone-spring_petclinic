variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Region of the infrastructure"
}

variable "zone" {
  type        = string
  description = "Zone of the infrastructure"
}

variable "gke_name" {
  type        = string
  description = "Google Kubernetes Engine cluster name"
}

variable "gke_deployment_name" {
  type        = string
  description = "Kubernetes deployment name"
}

variable "gke_deployment_secret_service_account" {
  type        = string
  description = "Service account file path"
}

variable "artifact_repository_id" {
  type        = string
  description = "ID of the Google Artifact Registry repository"
}

variable "image_name" {
  type        = string
  description = "Docker image name:tag"
}

variable "sql_database_name" {
  type        = string
  description = "Name of the Google Cloud SQL Database"
}

variable "sql_user_name" {
  type        = string
  description = "Username of the Cloud SQL database user"
}

variable "sql_user_password" {
  type        = string
  description = "Password of the Cloud SQL database user"
}
