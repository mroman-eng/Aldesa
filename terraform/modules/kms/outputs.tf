output "key_ring_id" {
  description = "KMS key ring resource ID."
  value       = google_kms_key_ring.this.id
}

output "crypto_key_id" {
  description = "KMS crypto key resource ID."
  value       = google_kms_crypto_key.this.id
}
