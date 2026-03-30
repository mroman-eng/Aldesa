project_id   = "data-buildtrack-dev"
environment  = "pre"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

storage_bq_remote_state = {
  bucket            = "data-buildtrack-dev-tfstate-europe-west1"
  storage_bq_prefix = "pre/20-storage-bq"
}

# Optional override; keep null to resolve from storage-bq remote state.
bi_dependencies = {
  gold_dataset_id = null
}

# Principals that will access Looker Studio Pro and query BigQuery GOLD data.
looker_studio = {
  enabled = true
  user_emails = [
    "sergio.ibanez.ext@aldesa.es",
    "vanessa.moyano.ext@aldesa.es",
    "maypher.roman.ext@aldesa.es",
    "jorge.gonzalezd.ext@aldesa.es",
  ]
  grant_bigquery_job_user        = true
  grant_gold_dataset_data_viewer = true
}

# Reference-only metadata for the manual Context-Aware Access setup done by an org-admin.
# Terraform does not create or assign the access level; this block records the agreed values
# (policy, access level name, CIDRs, scope and mode) used in Google Admin Console.
# Keep disabled while there is no stable scope (OU/group) managed by Workspace admins.
# CAA assignment for Google-owned apps (including Looker Studio) is managed in Admin Console:
# https://support.google.com/a/answer/16502999
context_aware_access = {
  enabled                 = false                       # default is disabled
  access_policy_id        = "accessPolicies/1234567890" # change-it
  access_level_short_name = "ls_pre_corp_access"        # change-it
  title                   = "Looker Studio PRE allowed networks"
  scope                   = "group:REPLACE_ME_WORKSPACE_SCOPE_GROUP@aldesa.com"
  mode                    = "WARN" # change to ACTIVE to enable enforcement
  allowed_ip_cidrs = []
}
