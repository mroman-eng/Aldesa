<p align="center">
  <img src="../img/dataform.png" alt="Dataform logo" width="88">
</p>

# Dataform workflow

This document explains how Data Engineers are expected to work with Dataform in this platform.

## What Terraform provides

Terraform provisions the platform side of Dataform, including:

- the Dataform repository in Google Cloud
- the Git remote connection
- the secret reference used for Git authentication
- the release config
- the workflow config
- the execution identity used by Dataform when configured

In other words, Terraform makes Dataform ready to use, but it does not create or maintain the transformation logic itself.

## What Terraform does not manage

Terraform does not manage:

- SQLX files
- JavaScript helpers used by Dataform logic
- model definitions
- assertions and business transformations

Those assets belong to the Data Engineering workflow.

## Recommended working model

Data Engineers can work with Dataform in two normal ways:

- from the Google Cloud Dataform UI
- locally in Git, using branches and pull requests

Both paths are valid as long as they follow the repository branch model.

## Normal development flow

### Option 1: work from the Google Cloud Dataform UI

1. Start from `develop`.
2. Create a branch from the Dataform UI.
3. Build and test the Dataform change.
4. Use the UI to open a pull request to `develop`.
5. Let Cloud Build validate the change.
6. Merge only after the checks pass.

### Option 2: work locally with Git

1. Create a feature branch from `develop`.
2. Edit the Dataform project content locally.
3. Push the branch and open a pull request to `develop`.
4. Let Cloud Build validate the change.
5. Merge only after the checks pass.

## Protected branch rules

- `develop` is protected
- `main` is protected
- direct commits are not part of the intended workflow

For normal Dataform work, `develop` is the target branch.

## Promotion to production

Production promotion does not happen by opening direct feature pull requests to `main`.

The rule is:

- Dataform changes are integrated and validated through `develop`
- once they are already deployed and working in `pre`, they are promoted by opening a pull request from `develop` to `main`

That keeps production aligned with the already proven non-production state.

## Validation in CI/CD

When a Dataform-related pull request is opened, Cloud Build can validate the change by creating a Dataform compilation result for the current commit.

That validation is triggered by repository changes such as:

- `definitions/`
- `includes/`
- `workflow_settings.yaml`
- `package.json`
- `package-lock.json`

## Repository notes

At the time of writing, the infrastructure for Dataform is already present, but the repository content is still at an early stage.

That is why:

- `definitions/` may still be mostly empty
- the repository may not yet look like a mature Dataform project

This is normal while the team is still standing up the non-production workflow.

## Team-owned notes

This section is intentionally short for now. The expectation is that the Data Engineering team can extend [Operating model placeholder](operating-model.md) later with practical conventions such as:

- naming conventions
- testing habits
- branch naming
- review expectations
- release notes for transformations

## Related docs

- [Data Engineering guide](README.md)
- [DAGs and Composer](dags-and-composer.md)
- [GitFlow and promotion model](../release/gitflow.md)
- [Cloud Build and CI/CD](../cicd/cloud-build.md)

## Further reading

- Dataform in Google Cloud:
  https://cloud.google.com/dataform/docs
