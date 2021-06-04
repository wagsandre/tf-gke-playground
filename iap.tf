
// Enable IAP API
resource "google_project_service" "iap_service" {
  project = var.project_id
  service = "iap.googleapis.com"
}

// Enable Identity Toolkit API
resource "google_project_service" "identitytoolkit_service" {
  project = var.project_id
  service = "identitytoolkit.googleapis.com"
}

// Configure IAP Brand (Consent Screen)
resource "google_iap_brand" "project_brand" {
  support_email     = "support@example.com"
  application_title = "Cloud IAP protected Application"
  project           = google_project_service.iap_service.project
}