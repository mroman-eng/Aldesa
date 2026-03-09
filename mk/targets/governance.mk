.PHONY: governance governance_init governance_plan governance_apply governance_destroy governance_clean
governance: governance_apply ## Run 40-governance workflow (init + plan + apply)

governance_init: _check_gcp_project _check_gcp_auth _check_bootstrap_dir _check_governance_dir _check_bootstrap_state_bucket ## Initialize Terraform in envs/<env>/40-governance
	@state_bucket="$(TFSTATE_BACKEND_BUCKET)"; \
	echo "Using governance backend bucket: $$state_bucket (prefix=$(GOVERNANCE_BACKEND_PREFIX))"; \
	terraform -chdir=$(GOVERNANCE_DIR) init -migrate-state -force-copy \
		-backend-config="bucket=$$state_bucket" \
		-backend-config="prefix=$(GOVERNANCE_BACKEND_PREFIX)"

governance_plan: _check_gcp_project _check_governance_dir governance_init ## Plan env governance (Dataplex Data Profile / Data Quality scans)
	terraform -chdir=$(GOVERNANCE_DIR) plan \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(GOVERNANCE_PLAN_FILE)

governance_apply: _check_gcp_project _check_governance_dir governance_plan ## Apply env governance (Dataplex Data Profile / Data Quality scans)
	terraform -chdir=$(GOVERNANCE_DIR) apply $(GOVERNANCE_PLAN_FILE)

governance_destroy: _check_gcp_project _check_governance_dir governance_init _confirm_destroy_governance ## Destroy env governance resources (confirmation skipped when CI=true/FORCE_DESTROY=true)
	terraform -chdir=$(GOVERNANCE_DIR) destroy \
		$(TF_DESTROY_AUTO_APPROVE) \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)"

governance_clean: _check_governance_dir ## Clean up governance plan and local .terraform
	rm -f $(GOVERNANCE_DIR)/$(GOVERNANCE_PLAN_FILE)
	rm -rf $(GOVERNANCE_DIR)/.terraform
