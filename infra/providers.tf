provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  firebase_apis = [
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
  ]
}

resource "google_project_service" "firebase_apis" {
  for_each           = toset(local.firebase_apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

