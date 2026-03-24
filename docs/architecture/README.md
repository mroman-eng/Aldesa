# Architecture overview

This document explains how the platform fits together at a high level. It is the best place to start if you are new to the repository and want to understand what each part is doing before looking at Terraform details.

## Purpose

Build Track uses Google Cloud to receive parquet files from SAP Datasphere, orchestrate ingestion and processing, transform data into BigQuery with Dataform, and expose curated data to Looker Studio Pro.

This repository contains the platform code that makes that workflow possible.

## End-to-end flow

1. SAP Datasphere uploads parquet files to the landing bucket of the target environment.
2. Cloud Storage object-finalize events are sent to Pub/Sub.
3. Eventarc delivers those events to a Cloud Function.
4. The Cloud Function posts a dataset event to Cloud Composer 3.
5. Composer DAGs react to the event and move or prepare data, including writes to the bronze parquet bucket.
6. Dataform transforms data into BigQuery datasets and tables.
7. Looker Studio Pro reads curated data from BigQuery.

## Platform building blocks

### Infrastructure foundation

- Terraform bootstraps the target project, enables APIs, grants IAM to the Terraform service account, and creates KMS resources that can be used later if needed.
- Terraform also provisions the shared network foundation: VPC, subnetwork, router, NAT, and internal firewall rules.

### Storage and datasets

- Each workload environment has a landing bucket for inbound files.
- Each workload environment also has a bronze parquet bucket for file-based intermediate storage and history.
- Terraform creates the BigQuery datasets used by the platform.
- Dataform is expected to create and maintain the business-facing tables inside those datasets.

### Orchestration

- Cloud Composer 3 is the orchestration runtime.
- DAG source code is stored in this repository under `dags/`.
- A Cloud Function bridges landing-bucket events into Composer dataset events.
- The Composer environment can install Python dependencies from `composer/requirements.txt`.

### Transformation

- Terraform provisions the Dataform repository, release config, workflow config, service identities, and Secret Manager integration.
- Data Engineers own the Dataform project content itself.
- Dataform can be used directly from the Google Cloud console while staying connected to this Git repository.

### Governance and BI

- Dataplex scans can be configured for data profiling and data quality.
- Looker Studio Pro access is granted through Terraform at the BigQuery IAM layer.
- Context-Aware Access remains a manual, admin-owned configuration, but the agreed values are kept in Terraform inputs for traceability.

### CI/CD

- Cloud Build validates pull requests and deploys infrastructure and DAG changes after merge.
- Terraform provisions the service accounts and trigger definitions needed for that automation.
- GitHub repository connections are created outside Terraform and then referenced from Terraform.

## Environment map

- `shared`: bootstrap and network foundation in `data-buildtrack-dev`
- `pre`: main non-production workload environment in `data-buildtrack-dev`
- `dev`: optional sandbox in `data-buildtrack-dev` for manual DAG testing
- `pro`: production environment in `data-buildtrack-pro`

The `data-buildtrack-dev` project therefore carries more than one logical environment. That is intentional in the current design and should be explained openly in the documentation rather than hidden behind naming shortcuts.

## Ownership boundaries

### DevOps / platform engineers

- Terraform structure and values
- bootstrap and environment setup
- Cloud Build trigger design
- Composer, Dataform, IAM, secrets, and infrastructure wiring

### Data engineers

- Dataform project content
- DAG code
- day-to-day development workflow through branches and pull requests

### Project owners / administrators

- creation of the Terraform service account
- creation of the Terraform state bucket
- GitHub to Cloud Build connection in GCP
- generation of sensitive secret values that are not managed by Terraform

## What Terraform manages and what it does not

Terraform manages the platform scaffolding: buckets, datasets, service accounts, IAM bindings, Composer, Dataform infrastructure, Dataplex, BI access, and Cloud Build resources.

Terraform does not manage the secret values themselves, nor the business logic of Dataform models, nor the manual testing activity that the team may perform in the `dev` sandbox.

## Where to go next

- For infrastructure details, continue with [Terraform and infrastructure](../terraform/README.md).
- For local operation, see [Make targets and local operation](../operations/make-targets.md).
- For CI/CD behavior, see [Cloud Build and CI/CD](../cicd/cloud-build.md).
- For branch and promotion rules, see [GitFlow and promotion model](../release/gitflow.md).
- For Data Engineering workflows, start at [Data Engineering guide](../data-engineering/README.md).
