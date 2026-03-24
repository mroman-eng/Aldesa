<p align="center">
  <img src="../img/cloud-build.svg" alt="Cloud Build logo" width="88">
</p>

# Cloud Build and CI/CD

This document explains how Cloud Build is used in this repository, which triggers exist, and how they are expected to evolve into the final operating model.

## Scope

This guide covers:

- the Cloud Build resources created by Terraform
- the GitHub connection requirement
- PR validation pipelines
- deployment pipelines
- DAG sync pipelines
- how to modify or extend the setup

## Design summary

Terraform creates the Cloud Build plumbing, including:

- IAM for the Terraform deployment service account
- IAM for the DAG sync service account
- Cloud Build trigger definitions

The GitHub connection itself is still created manually in GCP and then referenced from Terraform through `cloudbuild.repository_resource_name`.

## Build configuration files in this repository

- `cloudbuild/pr-validate-python.yaml`: validates Python function changes.
- `cloudbuild/pr-validate-dags.yaml`: validates DAG changes.
- `cloudbuild/pr-validate-dataform.yaml`: validates Dataform changes.
- `cloudbuild/pr-validate-terraform.yaml`: validates Terraform changes.
- `cloudbuild/push-shared-terraform-apply.yaml`: applies `shared` bootstrap and foundation.
- `cloudbuild/push-terraform-apply-ordered.yaml`: applies workload components in dependency order.
- `cloudbuild/push-dev-terraform-apply.yaml`: reconciles the `dev` sandbox stack.
- `cloudbuild/push-dags-sync.yaml`: syncs `dags/` to the Composer DAG bucket.

Helper scripts live under `cloudbuild/scripts/`.

## Validation pipelines

### Python validation

Purpose:

- compile Python code under `functions/`
- run `ruff` on the selected files

Main files:

- `cloudbuild/pr-validate-python.yaml`
- `cloudbuild/scripts/pr_validate_python.sh`

### DAG validation

Purpose:

- resolve the Airflow version from the Terraform configuration
- install the matching Airflow test dependencies
- load the repository DAGs through `pytest`

Main files:

- `cloudbuild/pr-validate-dags.yaml`
- `cloudbuild/scripts/pr_validate_dags.sh`
- `tests/dags/test_dag_integrity.py`

### Dataform validation

Purpose:

- detect Dataform-related changes
- call the Dataform API to create a compilation result for the current commit

Main files:

- `cloudbuild/pr-validate-dataform.yaml`
- `cloudbuild/scripts/pr_validate_dataform.sh`

This validation is aimed at the Data Engineering workflow where SQLX changes may come from the GCP Dataform UI or from local Git work, but still land in this repository through a branch and pull request.

### Terraform validation

Purpose:

- run `terraform fmt`
- run `terraform init -backend=false`
- run `terraform validate`
- run selective `make *_plan` targets based on the files changed in the pull request

Main files:

- `cloudbuild/pr-validate-terraform.yaml`
- `cloudbuild/scripts/pr_validate_terraform.sh`

## Trigger catalog

The final intended operating model is for all relevant triggers to be enabled. During the project build-out, some may remain temporarily disabled, but the documentation should describe the target setup clearly.

### Triggers in `data-buildtrack-dev`

#### Pull request validation to `develop`

- `cb-pr-pre-python`
- `cb-pr-pre-dags`
- `cb-pr-pre-dataform`
- `cb-pr-pre-terraform`
- `cb-pr-dev-terraform`

#### Push to `develop`

- `cb-shared-tf-apply`
- `cb-pre-tf-apply-ordered`
- `cb-pre-dags-sync`
- `cb-dev-tf-apply`

### Triggers in `data-buildtrack-pro`

#### Pull request validation to `main`

- `cb-pr-pro-python`
- `cb-pr-pro-dags`
- `cb-pr-pro-dataform`
- `cb-pr-pro-terraform`

#### Push to `main`

- `cb-pro-tf-apply-ordered`
- `cb-pro-dags-sync`

## What each trigger family does

### Shared foundation apply

`cb-shared-tf-apply` applies:

- `bootstrap` in `shared`
- `foundation` in `shared`

### Ordered workload apply

The ordered apply pipelines run components in dependency order:

1. optional `bootstrap`
2. optional `foundation`
3. `storage_bq`
4. `orchestration`
5. `governance`
6. `bi`
7. `cicd`

### Dev sandbox apply

`cb-dev-tf-apply` reconciles the `dev` sandbox stack.

### DAG sync

The DAG sync pipelines push the contents of `dags/` to the Composer DAG bucket.

That keeps deployed DAGs aligned with the repository after merge.

## File filters and selective execution

The trigger definitions use `included_files` to limit when they fire.

Examples:

- DAG validation only reacts to `dags/`
- Dataform validation reacts to `definitions/`, `includes/`, and workflow files
- Terraform validation reacts to Terraform code, Make targets, and selected supporting files

This matters because it keeps PR feedback fast and focused.

## How to modify the CI/CD setup

### Change an existing build

Update the relevant file under `cloudbuild/` or `cloudbuild/scripts/`, then open a pull request.

Examples:

- change the DAG test logic in `cloudbuild/scripts/pr_validate_dags.sh`
- change the Dataform validation logic in `cloudbuild/scripts/pr_validate_dataform.sh`
- change Terraform validation selection logic in `cloudbuild/scripts/pr_validate_terraform.sh`

### Change trigger behavior

Edit the trigger definition in:

- `terraform/envs/pre/60-cicd/terraform.tfvars`
- `terraform/envs/pro/60-cicd/terraform.tfvars`

Depending on the project and environment.

Typical changes include:

- enabling or disabling a trigger
- changing `included_files`
- changing the target branch regex
- changing the build file
- changing substitutions

### Add a new trigger

The usual path is:

1. create or update the build file under `cloudbuild/`
2. add or update any helper scripts under `cloudbuild/scripts/`
3. define the new trigger in the correct `60-cicd` `terraform.tfvars`
4. apply the `cicd` component

## GitHub connection requirement

Triggers cannot be created until the GitHub repository is connected in Cloud Build and the repository resource name is known.

That step is manual and owner-led.

After the connection is created, DevOps stores the resulting repository resource name in the CI/CD Terraform values.

## DE-facing notes

For Data Engineers, the practical takeaway is straightforward:

- SQLX and Dataform project changes should land through a branch and pull request
- DAG changes should also land through a branch and pull request
- pull requests are the point where validation happens
- merges are the point where deployment happens

The `dev` sandbox is still available for manual experimentation, but it does not replace the Git-based deployment path.

## Related docs

- [Make targets and local operation](../operations/make-targets.md)
- [GitFlow and promotion model](../release/gitflow.md)
- [Dataform workflow](../data-engineering/dataform.md)
- [DAGs and Composer](../data-engineering/dags-and-composer.md)

## Further reading

- Cloud Build repositories and connections:
  https://cloud.google.com/build/docs/repositories
- Cloud Build triggers:
  https://cloud.google.com/build/docs/triggers
- Dataform in Google Cloud:
  https://cloud.google.com/dataform/docs
