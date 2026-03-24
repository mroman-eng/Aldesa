# Make targets and local operation

This repository uses `make` as the main local entrypoint for Terraform workflows. The Makefile does not hide Terraform from you, but it does standardize authentication checks, backend setup, environment selection, and component order.

## Purpose

Use this document when you need to know:

- which `ENV` values are valid
- which target to run
- how local mode differs from `CI=true`
- what checks run before Terraform starts

## How the Makefile is organized

The root [`Makefile`](../../Makefile) includes:

- shared configuration from `mk/core/`
- target families from `mk/targets/`

The component target families are:

- `bootstrap`
- `foundation`
- `storage_bq`
- `orchestration`
- `governance`
- `bi`
- `cicd`
- `dev`

## Valid environment values

The repository recognizes:

- `ENV=shared`
- `ENV=pre`
- `ENV=dev`
- `ENV=pro`

Not every target supports every environment.

### Target scope by environment

- `bootstrap_*`: `shared`, `pro`
- `foundation_*`: `shared`, `pro`
- `storage_bq_*`: `pre`, `pro`
- `orchestration_*`: `pre`, `pro`
- `governance_*`: `pre`, `pro`
- `bi_*`: `pre`, `pro`
- `cicd_*`: `pre`, `pro`
- `dev_*`: `dev`

## Common target pattern

Most component families expose the same lifecycle:

- `<component>_init`
- `<component>_plan`
- `<component>_apply`
- `<component>_destroy`
- `<component>_clean`

There is also a shorthand `<component>` target that resolves to `<component>_apply`.

## Useful commands

Show the current runtime context:

```bash
make show_context ENV=pre
```

Plan a workload component:

```bash
make storage_bq_plan ENV=pre
```

Apply a workload component:

```bash
make orchestration_apply ENV=pre
```

Run the optional dev sandbox:

```bash
make dev_apply ENV=dev
```

## Local mode vs `CI=true`

### Local mode

Local mode is the default.

In local mode, the Makefile expects:

- user ADC to be present
- service account impersonation to be provided through environment variables

The Makefile exports:

- `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT`
- `GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT`

when they are not already set.

### CI mode

When `CI=true`, the Makefile stops assuming an interactive user session.

That mode is designed for Cloud Build and supports:

- ambient credentials
- service account credentials when explicitly provided

It also skips interactive confirmations and uses Terraform auto-approve behavior where appropriate for destroy flows.

## Authentication checks

Before a target runs, the Makefile performs preflight checks such as:

- valid `ENV`
- valid project selection
- backend bucket accessibility
- ADC presence in local mode
- impersonation sanity checks for bootstrap

These checks are meant to fail early and with readable messages.

## Component notes

### Bootstrap

- uses the owner-managed state bucket
- checks impersonation explicitly in local mode
- can reconcile existing KMS resources into state

### Orchestration

- can auto-import the Eventarc-created Pub/Sub subscription when subscription tuning is enabled
- exposes `orchestration_sync_dags` for on-demand DAG sync

### Storage-BQ

- applies with configurable parallelism

### Dev

- manages the sandbox as a single stack

## On-demand DAG sync

There is one notable non-Terraform operation:

```bash
make orchestration_sync_dags ENV=pre
```

That command syncs the local `dags/` folder to the Composer DAG bucket without deleting objects that already exist in the bucket.

It is useful for controlled operational sync, but the standard team workflow should still be Git plus Cloud Build.

## Destroy safety

Destroy targets are deliberately noisy.

- local mode asks for explicit typed confirmation
- `FORCE_DESTROY=true` skips that confirmation locally
- `CI=true` also skips the interactive confirmation

Even with those safeguards, destroy commands should be treated as exceptional operations.

## Troubleshooting

### Wrong environment for target

If a target complains about `ENV`, check whether you are using a shared, workload, or dev-only target family.

### Backend bucket access failure

Verify:

- the project id
- the bucket name
- your local impersonation setup

### ADC or impersonation issues

Rebuild your local auth session using the flow described in [Bootstrap a new project](../terraform/bootstrap.md).

## Related docs

- [Terraform and infrastructure](../terraform/README.md)
- [Bootstrap a new project](../terraform/bootstrap.md)
- [Cloud Build and CI/CD](../cicd/cloud-build.md)
