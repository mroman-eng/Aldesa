.PHONY: bi bi_init bi_plan bi_apply bi_destroy bi_clean
bi: _check_workload_env bi_apply ## Run 50-bi workflow (init + plan + apply)

bi_init: _check_workload_env _check_gcp_project _check_gcp_auth _check_bootstrap_dir _check_bi_dir _check_bootstrap_state_bucket ## Initialize Terraform in envs/<env>/50-bi
	@state_bucket="$(TFSTATE_BACKEND_BUCKET)"; \
	echo "Using bi backend bucket: $$state_bucket (prefix=$(BI_BACKEND_PREFIX))"; \
	terraform -chdir=$(BI_DIR) init -migrate-state -force-copy \
		-backend-config="bucket=$$state_bucket" \
		-backend-config="prefix=$(BI_BACKEND_PREFIX)"

bi_plan: _check_workload_env _check_gcp_project _check_bi_dir bi_init ## Plan env BI (Looker Studio Pro access + manual CAA reference)
	terraform -chdir=$(BI_DIR) plan \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(BI_PLAN_FILE)

bi_apply: _check_workload_env _check_gcp_project _check_bi_dir bi_plan ## Apply env BI (Looker Studio Pro access + manual CAA reference)
	terraform -chdir=$(BI_DIR) apply $(BI_PLAN_FILE)

bi_destroy: _check_workload_env _check_gcp_project _check_bi_dir bi_init _confirm_destroy_bi ## Destroy env BI resources (confirmation skipped when CI=true/FORCE_DESTROY=true)
	terraform -chdir=$(BI_DIR) destroy \
		$(TF_DESTROY_AUTO_APPROVE) \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)"

bi_clean: _check_workload_env _check_bi_dir ## Clean up BI plan and local .terraform
	rm -f $(BI_DIR)/$(BI_PLAN_FILE)
	rm -rf $(BI_DIR)/.terraform
