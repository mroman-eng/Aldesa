<p align="center">
  <img src="../img/cloud-composer.svg" alt="Cloud Composer logo" width="88">
</p>

# DAGs and Composer

This document explains how DAG changes are expected to move from development to deployment.

## Source of truth

For deployed DAGs, the source of truth is this repository.

The relevant path is:

- `dags/`

That means the supported deployment path is Git-based:

- create or update DAG code
- open a pull request
- let CI validate the change
- merge
- let Cloud Build sync the approved DAGs into the Composer DAG bucket

## Standard DAG workflow

1. Create or update the DAG in `dags/`.
2. Push the change on a feature branch.
3. Open a pull request to `develop`.
4. Let the DAG validation checks run.
5. Merge after the checks pass.
6. Let Cloud Build sync the repository DAGs to the Composer environment.

## What the DAG validation checks

The repository includes lightweight DAG validation that focuses on:

- loading the DAGs with Airflow
- failing on import errors
- confirming that the DAG folder is not empty

The goal is not to enforce every possible orchestration convention yet. The goal is to catch broken imports and obviously invalid DAG changes early.

## Composer dependencies

If a DAG needs additional Python packages in Composer, those dependencies should be added to:

- `composer/requirements.txt`

That file is consumed by Terraform when the Composer environments are configured to read it.

In practice, this means a Composer dependency change is not just a DAG change. It also affects infrastructure configuration and should go through the same branch and PR flow.

## Manual testing in `dev`

The `dev` environment exists to give the Data Engineering team room for manual DAG testing.

The intended use is flexible on purpose.

Typical examples include:

- uploading or removing DAGs directly in the dev DAG bucket
- copying parquet files from the `pre` landing bucket into the `dev` landing bucket for experiments

Those manual actions are acceptable for sandbox work, but they are not the source of truth for deployment. The Git repository remains the authoritative source for DAGs that should be deployed through CI/CD.

## Landing event flow

The platform includes an event bridge between landing files and Composer.

At a high level:

1. a parquet file lands in Cloud Storage
2. Pub/Sub and Eventarc deliver the event
3. a Cloud Function posts a dataset event to Composer
4. the relevant DAG can react to that dataset event

This repository contains both sides of that flow:

- the infrastructure wiring in Terraform
- the Cloud Function code under `functions/`
- the DAG code under `dags/`

## Current state

The DAG area of the repository is still being built out, so it currently contains only a small number of examples and utility DAGs.

That should be read as an early platform state, not as a limitation of the design.

## Team-owned notes

As the team settles on its daily workflow, the Data Engineering team can extend [Operating model placeholder](operating-model.md) with practical notes such as:

- how to structure DAG folders
- how to test event-driven DAGs
- how to use the `dev` sandbox consistently
- what review standards to apply to DAG changes

## Related docs

- [Data Engineering guide](README.md)
- [Dataform workflow](dataform.md)
- [Cloud Build and CI/CD](../cicd/cloud-build.md)
