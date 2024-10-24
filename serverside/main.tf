terraform {
  required_providers {
    google = {
      version = "~> 6.0.0"
    }
  }
  backend "gcs" {
    bucket = "landing-page-378522-tf-state"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "landing-page-378522"
  region  = "europe-west1"
  zone    = "europe-west1-c"
}

locals {
  project = "landing-page-378522" # Google Cloud Platform Project ID
}

variable "notion_db_id" {
  type      = string
  sensitive = true
}
variable "notion_api_key" {
  type      = string
  sensitive = true
}

data "archive_file" "collect_email_zip" {
  type        = "zip"
  source_dir  = "${path.module}/collect_email"
  output_path = "${path.module}/collect-email.zip"
}

resource "google_storage_bucket" "bucket" {
  name                        = "${local.project}-collect-email-source" # Every bucket name must be globally unique
  location                    = "europe-west1"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket_object" "object" {
  name   = "collect-email-${data.archive_file.collect_email_zip.output_sha}.zip"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.collect_email_zip.output_path
}

resource "google_cloudfunctions_function" "function" {
  name                  = "collect-email"
  description           = "Collecting emails and saving them in Notion"
  runtime               = "python311"
  available_memory_mb   = 512
  trigger_http          = true
  entry_point           = "handle_email_collection"
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.object.name
  docker_registry       = "ARTIFACT_REGISTRY"
  environment_variables = {
    "NOTION_DB_ID"   = var.notion_db_id
    "NOTION_API_KEY" = var.notion_api_key
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_binding" "binding" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name
  role           = "roles/cloudfunctions.invoker"
  members = [
    "allUsers",
  ]
}

output "function_uri" {
  value = google_cloudfunctions_function.function.https_trigger_url
}
