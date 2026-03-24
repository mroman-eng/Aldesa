<p align="center">
  <img src="../img/git.svg" alt="Git logo" width="88">
</p>

# GitFlow and promotion model

This repository follows a simple branch model designed to keep production aligned with what has already been proven in non-production.

## Protected branches

- `develop`
- `main`

Neither branch should receive direct commits.

All changes should arrive through pull requests.

## Day-to-day development flow

1. Create a feature branch from `develop`.
2. Implement and test the change.
3. Open a pull request into `develop`.
4. Let the configured checks run.
5. Merge only after the checks pass.

After merge to `develop`, the non-production deployment flow updates the platform in `data-buildtrack-dev`.

## Production promotion flow

Production promotion always starts from `develop`.

1. Open a pull request from `develop` to `main`.
2. Let the required checks run.
3. Require human approval.
4. Merge into `main`.

After merge to `main`, the production deployment flow updates `data-buildtrack-pro`.

## Practical rules

- Do not build production-only changes directly on `main`.
- Do not promote a change to `pro` unless it is already deployed and behaving correctly in `pre`.
- Treat `develop` as the integration branch for non-production.
- Treat `main` as the production promotion branch only.

## Dataform and DAG implications

This model also applies to Data Engineering work.

### Dataform

Data Engineers can work:

- locally with Git branches and pull requests
- directly from the GCP Dataform UI, using its branch and PR features

In both cases, the target branch for normal work is still `develop`.

### DAGs

DAG changes should be committed on a feature branch and merged through a pull request.

The repository remains the source of truth for DAG deployment, even if manual experiments happen in the `dev` sandbox.

## Deployment mapping

- `develop` drives deployment in `data-buildtrack-dev`
- `main` drives deployment in `data-buildtrack-pro`

That mapping keeps the delivery story easy to explain and easy to audit.

## Related docs

- [Cloud Build and CI/CD](../cicd/cloud-build.md)
- [Dataform workflow](../data-engineering/dataform.md)
- [DAGs and Composer](../data-engineering/dags-and-composer.md)
