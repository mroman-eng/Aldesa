# Data engineering guide

This section is for Data Engineers working with Build Track on Google Cloud.

The platform is split cleanly:

- Terraform prepares and maintains the platform infrastructure.
- Data Engineers use that platform to build Dataform assets and Composer DAGs.

If you only need the shortest possible guidance, start here:

- use [Dataform workflow](dataform.md) for SQLX and transformation work
- use [DAGs and Composer](dags-and-composer.md) for orchestration work
- use [GitFlow and promotion model](../release/gitflow.md) for branch and promotion rules

## What the platform already provides

The Terraform side of this repository already prepares:

- buckets for ingestion and intermediate file handling
- BigQuery datasets
- a Composer environment
- a Dataform repository connected to Git
- CI/CD validation and deployment pipelines

That means Data Engineers do not need to provision the platform before starting to build on top of it.

## What data engineers usually change

In normal work, Data Engineers mainly interact with:

- Dataform content
- DAG code under `dags/`
- occasionally `composer/requirements.txt` when Composer needs new Python packages

## What data engineers usually do not change

Most DE changes should not start in Terraform.

Terraform is usually not the right place for:

- business SQL logic
- model definitions
- DAG business behavior on its own

If the change is about infrastructure shape, IAM, buckets, Composer sizing, Dataform repository wiring, or CI/CD triggers, that usually belongs to the DevOps side instead.

## The `dev` sandbox

The `dev` environment exists to support manual DAG testing.

It gives the team an isolated sandbox with:

- a landing bucket
- a bronze parquet bucket
- a DAG bucket
- a Composer environment

How the DE team uses that sandbox day to day is intentionally left flexible. A starter placeholder for team-owned notes is provided in [Operating model placeholder](operating-model.md).

## Current state

The platform wiring is already in place, but the project content is still being built out. That is why you may not see a mature set of SQLX files or many production-like DAGs in the repository yet.

That is expected at this stage.
