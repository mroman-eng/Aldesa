.PHONY: foundation foundation_init foundation_plan foundation_apply foundation_destroy foundation_clean
foundation: foundation_apply ## Run 10-foundation workflow (init + plan + apply)

foundation_init: _check_gcp_project _check_gcp_auth _check_bootstrap_dir _check_foundation_dir _check_bootstrap_state_bucket ## Initialize Terraform in envs/<env>/10-foundation
	@state_bucket="$(TFSTATE_BACKEND_BUCKET)"; \
	echo "Using foundation backend bucket: $$state_bucket (prefix=$(FOUNDATION_BACKEND_PREFIX))"; \
	terraform -chdir=$(FOUNDATION_DIR) init -migrate-state -force-copy \
		-backend-config="bucket=$$state_bucket" \
		-backend-config="prefix=$(FOUNDATION_BACKEND_PREFIX)"

foundation_plan: _check_gcp_project _check_foundation_dir foundation_init ## Plan env foundation (network, subnetwork, router, nat)
	terraform -chdir=$(FOUNDATION_DIR) plan \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(FOUNDATION_PLAN_FILE)

foundation_apply: _check_gcp_project _check_foundation_dir foundation_plan ## Apply env foundation (network, subnetwork, router, nat)
	terraform -chdir=$(FOUNDATION_DIR) apply $(FOUNDATION_PLAN_FILE)

foundation_destroy: _check_gcp_project _check_foundation_dir foundation_init _confirm_destroy_foundation ## Destroy env foundation resources (confirmation skipped when CI=true/FORCE_DESTROY=true)
	terraform -chdir=$(FOUNDATION_DIR) destroy \
		$(TF_DESTROY_AUTO_APPROVE) \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)"

foundation_clean: _check_foundation_dir ## Clean up foundation plan and local .terraform
	rm -f $(FOUNDATION_DIR)/$(FOUNDATION_PLAN_FILE)
	rm -rf $(FOUNDATION_DIR)/.terraform
