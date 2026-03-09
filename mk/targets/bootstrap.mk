.PHONY: bootstrap bootstrap_init bootstrap_plan bootstrap_apply bootstrap_destroy bootstrap_clean _bootstrap_reconcile_kms_state
bootstrap: bootstrap_apply ## Run 00-bootstrap workflow (init + plan + apply)

bootstrap_init: _check_gcp_project _check_bootstrap_impersonation_auth _check_gcp_auth _check_bootstrap_dir ## Initialize Terraform in envs/<env>/00-bootstrap
	terraform -chdir=$(BOOTSTRAP_DIR) init -reconfigure

bootstrap_plan: _check_gcp_project _check_bootstrap_dir bootstrap_init _bootstrap_reconcile_kms_state ## Plan env bootstrap (bucket, IAM on existing Terraform SA, KMS)
	terraform -chdir=$(BOOTSTRAP_DIR) plan \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(BOOTSTRAP_PLAN_FILE)

bootstrap_apply: _check_gcp_project _check_bootstrap_dir bootstrap_plan ## Apply env bootstrap (bucket, IAM on existing Terraform SA, KMS)
	terraform -chdir=$(BOOTSTRAP_DIR) apply $(BOOTSTRAP_PLAN_FILE)

bootstrap_destroy: _check_gcp_project _check_bootstrap_dir bootstrap_init _confirm_destroy_bootstrap ## Destroy env bootstrap resources (confirmation skipped when CI=true/FORCE_DESTROY=true)
	terraform -chdir=$(BOOTSTRAP_DIR) destroy \
		$(TF_DESTROY_AUTO_APPROVE) \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)"

bootstrap_clean: _check_bootstrap_dir ## Clean up bootstrap plan and local .terraform
	rm -f $(BOOTSTRAP_DIR)/$(BOOTSTRAP_PLAN_FILE)
	rm -rf $(BOOTSTRAP_DIR)/.terraform

_bootstrap_reconcile_kms_state:
	@key_ring_id="projects/$(GOOGLE_PROJECT)/locations/$(GCP_REGION)/keyRings/$(BOOTSTRAP_KMS_KEY_RING_NAME)"; \
	crypto_key_id="$$key_ring_id/cryptoKeys/$(BOOTSTRAP_KMS_CRYPTO_KEY_NAME)"; \
	impersonation_flag="--impersonate-service-account=$(TF_SA_EMAIL)"; \
	if ! command -v gcloud >/dev/null 2>&1; then \
		echo "Warning: gcloud not found; skipping KMS import reconciliation."; \
		exit 0; \
	fi; \
	if ! gcloud kms keyrings describe "$(BOOTSTRAP_KMS_KEY_RING_NAME)" --location="$(GCP_REGION)" --project="$(GOOGLE_PROJECT)" $$impersonation_flag >/dev/null 2>&1; then \
		exit 0; \
	fi; \
	if ! terraform -chdir=$(BOOTSTRAP_DIR) state show module.bootstrap.module.sops_kms.google_kms_key_ring.this >/dev/null 2>&1; then \
		echo "Found existing KMS key ring in GCP. Importing into Terraform state: $$key_ring_id"; \
		terraform -chdir=$(BOOTSTRAP_DIR) import module.bootstrap.module.sops_kms.google_kms_key_ring.this "$$key_ring_id" >/dev/null; \
	fi; \
	if gcloud kms keys describe "$(BOOTSTRAP_KMS_CRYPTO_KEY_NAME)" --keyring="$(BOOTSTRAP_KMS_KEY_RING_NAME)" --location="$(GCP_REGION)" --project="$(GOOGLE_PROJECT)" $$impersonation_flag >/dev/null 2>&1; then \
		if ! terraform -chdir=$(BOOTSTRAP_DIR) state show module.bootstrap.module.sops_kms.google_kms_crypto_key.this >/dev/null 2>&1; then \
			echo "Found existing KMS crypto key in GCP. Importing into Terraform state: $$crypto_key_id"; \
			terraform -chdir=$(BOOTSTRAP_DIR) import module.bootstrap.module.sops_kms.google_kms_crypto_key.this "$$crypto_key_id" >/dev/null; \
		fi; \
	fi
