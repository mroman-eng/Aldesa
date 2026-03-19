.PHONY: bootstrap bootstrap_init bootstrap_plan bootstrap_apply bootstrap_destroy bootstrap_clean _bootstrap_reconcile_kms_state _bootstrap_detach_legacy_state_bucket_from_state
bootstrap: _check_bootstrap_env bootstrap_apply ## Run 00-bootstrap workflow (init + plan + apply)

bootstrap_init: _check_bootstrap_env _check_gcp_project _check_bootstrap_impersonation_auth _check_gcp_auth _check_bootstrap_dir _check_bootstrap_state_bucket ## Initialize Terraform in envs/<env>/00-bootstrap with GCS backend
	@set -euo pipefail; \
	state_bucket="$(TFSTATE_BACKEND_BUCKET)"; \
	state_prefix="$(BOOTSTRAP_BACKEND_PREFIX)"; \
	local_state_file="$(BOOTSTRAP_DIR)/terraform.tfstate"; \
	remote_state_uri="gs://$$state_bucket/$$state_prefix/default.tfstate"; \
	remote_state_exists="false"; \
	impersonation_flag=""; \
	if [ -n "$${GOOGLE_IMPERSONATE_SERVICE_ACCOUNT:-}" ]; then impersonation_flag="--impersonate-service-account=$$GOOGLE_IMPERSONATE_SERVICE_ACCOUNT"; fi; \
	if command -v gcloud >/dev/null 2>&1; then \
		if gcloud storage objects describe "$$remote_state_uri" --project="$(GOOGLE_PROJECT)" $$impersonation_flag >/dev/null 2>&1; then \
			remote_state_exists="true"; \
		fi; \
	fi; \
	echo "Using bootstrap backend bucket: $$state_bucket (prefix=$$state_prefix)"; \
	if [ -f "$$local_state_file" ] && [ "$$remote_state_exists" != "true" ]; then \
		echo "Bootstrap init mode: one-time local->remote state migration."; \
		terraform -chdir=$(BOOTSTRAP_DIR) init -migrate-state -force-copy \
			-backend-config="bucket=$$state_bucket" \
			-backend-config="prefix=$$state_prefix"; \
	else \
		if [ -f "$$local_state_file" ] && [ "$$remote_state_exists" = "true" ]; then \
			echo "Local bootstrap state exists, but remote state already exists. Skipping migration."; \
		fi; \
		terraform -chdir=$(BOOTSTRAP_DIR) init -reconfigure \
			-backend-config="bucket=$$state_bucket" \
			-backend-config="prefix=$$state_prefix"; \
	fi

bootstrap_plan: _check_bootstrap_env _check_gcp_project _check_bootstrap_dir bootstrap_init _bootstrap_detach_legacy_state_bucket_from_state _bootstrap_reconcile_kms_state ## Plan env bootstrap (APIs, IAM on existing Terraform SA, KMS)
	terraform -chdir=$(BOOTSTRAP_DIR) plan \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(BOOTSTRAP_PLAN_FILE)

bootstrap_apply: _check_bootstrap_env _check_gcp_project _check_bootstrap_dir bootstrap_plan ## Apply env bootstrap (APIs, IAM on existing Terraform SA, KMS)
	terraform -chdir=$(BOOTSTRAP_DIR) apply $(BOOTSTRAP_PLAN_FILE)

bootstrap_destroy: _check_bootstrap_env _check_gcp_project _check_bootstrap_dir bootstrap_init _confirm_destroy_bootstrap ## Destroy env bootstrap resources (confirmation skipped when CI=true/FORCE_DESTROY=true)
	terraform -chdir=$(BOOTSTRAP_DIR) destroy \
		$(TF_DESTROY_AUTO_APPROVE) \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)"

bootstrap_clean: _check_bootstrap_env _check_bootstrap_dir ## Clean up bootstrap plan and local .terraform
	rm -f $(BOOTSTRAP_DIR)/$(BOOTSTRAP_PLAN_FILE)
	rm -rf $(BOOTSTRAP_DIR)/.terraform

_bootstrap_reconcile_kms_state:
	@key_ring_id="projects/$(GOOGLE_PROJECT)/locations/$(GCP_REGION)/keyRings/$(BOOTSTRAP_KMS_KEY_RING_NAME)"; \
	crypto_key_id="$$key_ring_id/cryptoKeys/$(BOOTSTRAP_KMS_CRYPTO_KEY_NAME)"; \
	impersonation_flag=""; \
	if [ -n "$${GOOGLE_IMPERSONATE_SERVICE_ACCOUNT:-}" ]; then impersonation_flag="--impersonate-service-account=$$GOOGLE_IMPERSONATE_SERVICE_ACCOUNT"; fi; \
	if ! command -v gcloud >/dev/null 2>&1; then \
		echo "Warning: gcloud not found; skipping KMS import reconciliation."; \
		exit 0; \
	fi; \
	if ! gcloud kms keyrings describe "$(BOOTSTRAP_KMS_KEY_RING_NAME)" --location="$(GCP_REGION)" --project="$(GOOGLE_PROJECT)" $$impersonation_flag >/dev/null 2>&1; then \
		exit 0; \
	fi; \
	if ! terraform -chdir=$(BOOTSTRAP_DIR) state show module.bootstrap.module.bootstrap_kms.google_kms_key_ring.this >/dev/null 2>&1; then \
		echo "Found existing KMS key ring in GCP. Importing into Terraform state: $$key_ring_id"; \
		if ! import_out=$$(terraform -chdir=$(BOOTSTRAP_DIR) import module.bootstrap.module.bootstrap_kms.google_kms_key_ring.this "$$key_ring_id" 2>&1 >/dev/null); then \
			if echo "$$import_out" | grep -q "Resource already managed by Terraform"; then \
				echo "KMS key ring already managed in Terraform state. Skipping import."; \
			else \
				echo "$$import_out"; \
				exit 1; \
			fi; \
		fi; \
	fi; \
	if gcloud kms keys describe "$(BOOTSTRAP_KMS_CRYPTO_KEY_NAME)" --keyring="$(BOOTSTRAP_KMS_KEY_RING_NAME)" --location="$(GCP_REGION)" --project="$(GOOGLE_PROJECT)" $$impersonation_flag >/dev/null 2>&1; then \
		if ! terraform -chdir=$(BOOTSTRAP_DIR) state show module.bootstrap.module.bootstrap_kms.google_kms_crypto_key.this >/dev/null 2>&1; then \
			echo "Found existing KMS crypto key in GCP. Importing into Terraform state: $$crypto_key_id"; \
			if ! import_out=$$(terraform -chdir=$(BOOTSTRAP_DIR) import module.bootstrap.module.bootstrap_kms.google_kms_crypto_key.this "$$crypto_key_id" 2>&1 >/dev/null); then \
				if echo "$$import_out" | grep -q "Resource already managed by Terraform"; then \
					echo "KMS crypto key already managed in Terraform state. Skipping import."; \
				else \
					echo "$$import_out"; \
					exit 1; \
				fi; \
			fi; \
		fi; \
	fi

_bootstrap_detach_legacy_state_bucket_from_state:
	@legacy_addrs=$$(terraform -chdir=$(BOOTSTRAP_DIR) state list 2>/dev/null | grep '^module\.bootstrap\.module\.state_bucket\.' || true); \
	if [ -n "$$legacy_addrs" ]; then \
		echo "Detaching legacy bootstrap tfstate bucket resources from Terraform state (bucket is owner-managed)."; \
		while IFS= read -r addr; do \
			[ -z "$$addr" ] && continue; \
			echo " - removing $$addr"; \
			terraform -chdir=$(BOOTSTRAP_DIR) state rm "$$addr" >/dev/null; \
		done <<< "$$legacy_addrs"; \
	fi
