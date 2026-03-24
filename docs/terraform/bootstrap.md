# Bootstrap a new project

This guide is for DevOps and platform engineers who need to bootstrap a new GCP project for Build Track.

It focuses on the shared responsibilities between project owners and the DevOps team, because the bootstrap flow is intentionally split between both sides.

## Scope

This document covers:

- local prerequisites
- the Terraform service account and required IAM
- the Terraform state bucket
- the first Terraform bootstrap apply
- the manual steps that must happen after bootstrap

It does not cover day-to-day feature development. For that, go back to [Terraform and infrastructure](README.md) or [Make targets and local operation](../operations/make-targets.md).

## Tested local tooling

The repository is currently known to work with the following local tool versions:

- `Terraform v1.14.4`
- `Google Cloud SDK 547.0.0`
- `GNU Make 4.3`
- `jq 1.7`
- `Python 3.12.3`

If you use newer versions, keep them reasonably close to current releases and verify behavior before changing shared runbooks.

## Local authentication model

The local DevOps flow is based on:

- a normal user login in `gcloud`
- user Application Default Credentials
- service account impersonation through environment variables

That model matches the safeguards already built into this repository.

### Recommended local flow

Replace the project and service account values as needed for the target environment.

```bash
gcloud config set account YOUR_USER@YOUR_DOMAIN
gcloud config set project TARGET_PROJECT_ID

gcloud config unset auth/impersonate_service_account || true
unset CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT
unset GOOGLE_APPLICATION_CREDENTIALS
unset GOOGLE_IMPERSONATE_SERVICE_ACCOUNT
unset GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT

gcloud auth login
gcloud auth application-default revoke || true
gcloud auth application-default login
gcloud auth application-default set-quota-project TARGET_PROJECT_ID

export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="sa-terraform-buildtrack@TARGET_PROJECT_ID.iam.gserviceaccount.com"
export GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT="$GOOGLE_IMPERSONATE_SERVICE_ACCOUNT"
```

This repository expects user ADC plus impersonation variables. It is better not to keep `gcloud` permanently configured to impersonate the Terraform service account by default, because that can create confusing double-impersonation behavior in local runs.

## Terraform service account

The Terraform service account is created by the project owner, not by Terraform itself.

### Naming convention

- `sa-terraform-buildtrack@data-buildtrack-dev.iam.gserviceaccount.com`
- `sa-terraform-buildtrack@data-buildtrack-pro.iam.gserviceaccount.com`

### Required roles

The effective role set currently used by the platform is:

- `roles/artifactregistry.admin`
- `roles/bigquery.admin`
- `roles/cloudbuild.builds.editor`
- `roles/cloudfunctions.admin`
- `roles/cloudkms.admin`
- `roles/composer.admin`
- `roles/compute.networkAdmin`
- `roles/compute.securityAdmin`
- `roles/dataform.admin`
- `roles/dataplex.admin`
- `roles/eventarc.admin`
- `roles/iam.serviceAccountAdmin`
- `roles/iam.serviceAccountUser`
- `roles/pubsub.admin`
- `roles/run.admin`
- `roles/secretmanager.admin`
- `roles/serviceusage.serviceUsageAdmin`
- `roles/storage.admin`

The service account also receives a custom project role used to manage project IAM policy without granting Owner:

- `Terraform Project IAM Admin`

That custom role includes:

- `resourcemanager.projects.get`
- `resourcemanager.projects.getIamPolicy`
- `resourcemanager.projects.setIamPolicy`

### Local impersonation permission

If a DevOps engineer will run Terraform locally, the owner must grant that user `roles/iam.serviceAccountTokenCreator` on the Terraform service account.

## Terraform state bucket

The Terraform state bucket is also created by the project owner.

### Naming convention

- `data-buildtrack-dev-tfstate-europe-west1`
- `data-buildtrack-pro-tfstate-europe-west1`

### Notes

- the bucket is not created by the bootstrap component
- the bucket should exist before any `make bootstrap_*` target is executed
- the current convention uses `europe-west1`

## Bootstrap procedure

### Step 1: owner prepares the project

The owner must:

- create the Terraform service account
- grant the required project roles
- grant the custom IAM role
- create the Terraform state bucket

### Step 2: DevOps reviews the Terraform values

Before the first apply:

- verify the correct `terraform.tfvars` for the target environment
- verify project id, region, naming overrides, and labels
- verify the environment-specific bucket name and service account naming

### Step 3: DevOps runs bootstrap

For the target environment:

```bash
make bootstrap_apply ENV=shared
```

or:

```bash
make bootstrap_apply ENV=pro
```

The bootstrap target:

- initializes remote state in the owner-managed bucket
- enables required APIs
- reads the pre-existing Terraform service account
- grants the expected IAM roles to that service account
- creates the KMS resources used by the platform foundation

### Step 4: owner connects GitHub to Cloud Build

After bootstrap and API enablement are complete, the owner must connect the GitHub repository in Cloud Build.

The owner then shares the repository resource name with DevOps, for example:

```text
projects/data-buildtrack-dev/locations/europe-southwest1/connections/github-data-build-track/repositories/GrupoAldesa-build-track-gcp-dataops
```

That value is later used in the CI/CD Terraform inputs.

### Step 5: DevOps applies the remaining components

After the repository connection is available:

- complete the remaining component `terraform.tfvars`
- apply components in dependency order
- commit the final environment values to Git

### Step 6: hand over normal deployment to Cloud Build

Once the platform is fully in place, the expected operating model is:

- pull requests perform validation
- merges trigger deployment
- production promotion happens through `develop -> main`

## Manual secret steps

Terraform creates secret containers, not the secret values.

### SAP / Datasphere service account JSON key

Terraform creates the service account and the Secret Manager container used as a backup location for the JSON key.

The JSON key itself:

- must be generated by the project owner
- should then be uploaded to the Secret Manager container created by Terraform

This is already done in the current environments, but it should be documented because future credential rotation will follow the same pattern.

### GitHub PAT used by Dataform and Cloud Build

Terraform creates the Secret Manager container.

The PAT value:

- is generated outside Terraform
- is uploaded manually as a secret version
- is shared between the non-production and production setup by process, even though each project keeps its own secret container

If the PAT changes in the future, the new value should be uploaded as a new secret version.

## Troubleshooting

### I cannot impersonate the Terraform service account

Check that your user has `roles/iam.serviceAccountTokenCreator` on the service account and that you are logged in with the expected `gcloud` account.

### Terraform says ADC is missing

Re-run:

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project TARGET_PROJECT_ID
```

### Terraform cannot access the backend bucket

Check that:

- the bucket already exists
- you are pointing at the correct project
- your user can access the bucket directly or through service account impersonation

## Further reading

- Google Cloud authentication and ADC:
  https://cloud.google.com/docs/authentication/application-default-credentials
- Google Cloud service account impersonation:
  https://cloud.google.com/docs/authentication/use-service-account-impersonation
- Terraform authentication for Google Cloud:
  https://docs.cloud.google.com/docs/terraform/authentication
