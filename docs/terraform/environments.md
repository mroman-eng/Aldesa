# Environment model

This document explains how the repository maps logical environments to GCP projects and why the current structure looks the way it does.

## Current layout

### `data-buildtrack-dev`

This project currently hosts three logical environments:

- `shared`: bootstrap and network foundation
- `pre`: the main non-production workload environment
- `dev`: an optional sandbox for manual DAG testing

### `data-buildtrack-pro`

This project hosts:

- `pro`: the production workload environment

## Why `data-buildtrack-dev` contains more than one environment

The current platform is being developed and stabilized in `data-buildtrack-dev`.

That project therefore carries:

- the shared bootstrap and networking base used by non-production
- the `pre` environment, which is the real target for normal non-production deployments
- the `dev` environment, which exists as a flexible sandbox for Data Engineers to test DAG behavior manually

It is fair to say that the project name can feel a little misleading, because the main non-production workload environment is actually `pre`. The documentation should make that explicit instead of pretending the naming is cleaner than it is.

## Purpose of each environment

### `shared`

Used for the shared infrastructure base of the non-production project.

It includes:

- project bootstrap
- core APIs
- Terraform IAM wiring
- KMS resources
- VPC and network foundation

### `pre`

Used for normal non-production platform work.

It is the place where:

- infrastructure changes are validated in a realistic environment
- Dataform changes are expected to run before production promotion
- Composer and CI/CD behavior are exercised as part of the normal delivery flow

### `dev`

Used as an optional and disposable sandbox.

It is controlled by a boolean in `terraform/envs/dev/terraform.tfvars` and creates:

- a landing bucket
- a bronze parquet bucket
- a DAG bucket
- a Composer environment

The `dev` environment exists so that Data Engineers can run manual DAG-oriented experiments without disturbing the `pre` workload flow.

### `pro`

Used for production only.

The target operating model is to replicate the stable `pre` platform in production, without the `dev` sandbox.

## Promotion rule

The rule is simple:

- what reaches `pro` should already be deployed and working in `pre`

In practice that means:

- day-to-day work is integrated through `develop`
- non-production deployment happens from `develop`
- production promotion happens only by opening a pull request from `develop` to `main`

## Backend state layout

Remote state uses environment-specific prefixes. Typical examples are:

- `shared/00-bootstrap`
- `shared/10-foundation`
- `pre/20-storage-bq`
- `pre/30-orchestration`
- `pro/20-storage-bq`
- `pro/30-orchestration`

That layout is important because later components read remote state from earlier ones.

## Naming conventions

The repository follows a predictable naming style for the main resources.

Examples:

- Terraform state bucket:
  `<project_id>-tfstate-<region>` when the project name already carries the environment suffix
- landing bucket:
  `<environment>-<project_id>-ingesta-sap-<region>`
- Composer DAG bucket:
  `<environment>-<project_id>-dags-composer-<region>`
- Composer environment:
  `<environment>-<project_id>-orchestrator-sap-<region>`
- Dataform repository:
  `<environment>-<project_id>-dataform-sap-<region>`

The Terraform code also avoids duplicating the environment token when the project id already ends with that suffix.

## Operating guidance

If you are deciding where a change belongs:

- use `shared` for the non-production base project and network
- use `pre` for normal non-production platform behavior
- use `dev` only for the optional manual sandbox
- use `pro` only after the change is proven in `pre`

For the operational commands behind that flow, continue with [Make targets and local operation](../operations/make-targets.md).
