resource "google_storage_bucket" "this" {
  project       = var.project_id
  name          = var.name
  location      = var.location
  storage_class = var.storage_class
  force_destroy = var.force_destroy

  uniform_bucket_level_access = true
  public_access_prevention    = var.public_access_prevention

  versioning {
    enabled = var.versioning_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = var.delete_noncurrent_versions_after_days == null ? [] : [var.delete_noncurrent_versions_after_days]

    content {
      action {
        type = "Delete"
      }

      condition {
        days_since_noncurrent_time = lifecycle_rule.value
      }
    }
  }

  labels = var.labels
}
