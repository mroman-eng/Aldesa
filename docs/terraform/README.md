<p align="center">
  <img src="../img/terraform.svg" alt="Terraform logo" width="88">
</p>

# Terraform and infrastructure

This document is the main entry point for the Terraform side of the repository. It explains how the code is organized, how the components depend on each other, and where to look when you need to change platform behavior.

## Structure

Terraform is split into three layers:

- `terraform/components/`: reusable platform components such as bootstrap, storage, orchestration, governance, BI, and CI/CD.
- `terraform/envs/`: environment-specific wiring and values.
- `terraform/modules/`: smaller reusable modules consumed by the components.

## Component catalog

### `00-bootstrap`

Prepares the target project for Terraform operations.

- enables required APIs
- reads the pre-existing Terraform service account
- grants IAM roles to that service account
- creates KMS resources that the platform may use in the future

### `10-foundation`

Creates the shared network base.

- VPC
- subnetwork
- Cloud Router
- Cloud NAT
- internal firewall rule

### `20-storage-bq`

Creates the storage and BigQuery base for workload environments.

- landing bucket
- bronze parquet bucket
- BigQuery datasets
- SAP/Datasphere ingestion service account
- Secret Manager containers for the SAP JSON key backup and the Dataform Git PAT

### `30-orchestration`

Creates the orchestration and transformation platform.

- Cloud Composer 3
- custom DAG bucket
- Composer IAM bindings
- Dataform repository and related identities
- landing-to-Composer event flow with Pub/Sub, Eventarc, and Cloud Function

### `40-governance`

Creates Dataplex data profile and data quality scans.

### `50-bi`

Grants BigQuery access for Looker Studio Pro and stores the reference values used for manual Context-Aware Access setup.

### `60-cicd`

Creates the Cloud Build identities and trigger definitions used by the delivery pipelines.

### `dev`

Creates the optional developer sandbox stack in `data-buildtrack-dev`.

- landing bucket
- bronze parquet bucket
- DAG bucket
- a lightweight Composer environment

This environment exists to support manual DAG testing and can be created or destroyed with a boolean in its `terraform.tfvars`.

## Environment wiring

The repository currently uses these Terraform environments:

- `shared`
- `pre`
- `dev`
- `pro`

The current mapping is:

- `shared`, `pre`, and `dev` live in `data-buildtrack-dev`
- `pro` lives in `data-buildtrack-pro`

See [Environment model](environments.md) for the full explanation.

## Dependency order

### Shared and production foundation

For `shared` and `pro`, the base order is:

1. `bootstrap`
2. `foundation`

### Workload environments

For `pre` and `pro`, the workload order is:

1. `storage_bq`
2. `orchestration`
3. `governance`
4. `bi`
5. `cicd`

### Dev sandbox

The `dev` sandbox is managed through the single `dev_*` target family.

## Remote state model

The components depend on each other through GCS-backed remote state.

Typical examples:

- `orchestration` reads outputs from `foundation` and `storage_bq`
- `governance` reads outputs from `storage_bq`
- `bi` reads outputs from `storage_bq`
- `cicd` reads outputs from `bootstrap` and `orchestration`

This design keeps each component focused while still allowing later layers to reuse resolved names and service account emails from earlier layers.

## What Terraform manages

Terraform is responsible for the platform foundation and for the configuration needed to operate it safely.

That includes:

- project bootstrap and IAM wiring
- networking
- buckets and datasets
- Composer infrastructure
- Dataform infrastructure
- Dataplex scans
- Looker Studio BigQuery IAM
- Cloud Build identities and triggers

## What Terraform does not manage

Terraform is intentionally not the place for every change.

In this repository, Terraform does not manage:

- the actual secret values stored inside Secret Manager
- business tables through Terraform
- Dataform project content itself
- DAG experimentation performed directly in the `dev` sandbox

The most important practical rule is:

- Terraform prepares datasets and platform infrastructure.
- Dataform is the layer expected to create and maintain business tables.

## Common change scenarios

Use Terraform when you need to:

- change bucket names, settings, or retention behavior
- change Composer sizing, environment variables, or Python dependencies
- adjust Dataform infrastructure settings such as repository wiring or release config values
- add or modify Dataplex scans
- change Looker Studio access
- add or modify Cloud Build trigger definitions

Do not start with Terraform when you need to:

- add a business model or table in BigQuery
- change SQLX logic
- create or refine DAG logic only

For those tasks, start from the Data Engineering docs instead.

## Where to go next

- [Bootstrap a new project](bootstrap.md)
- [Environment model](environments.md)
- [Make targets and local operation](../operations/make-targets.md)
- [Cloud Build and CI/CD](../cicd/cloud-build.md)
