.PHONY: dev dev_init dev_plan dev_apply dev_destroy dev_clean
dev: _check_dev_stack_env dev_apply ## Run dev stack workflow (init + plan + apply)

dev_init: _check_dev_stack_env _check_gcp_project _check_gcp_auth _check_dev_dir _check_bootstrap_state_bucket ## Initialize Terraform in envs/dev
	@state_bucket="$(TFSTATE_BACKEND_BUCKET)"; \
	echo "Using dev backend bucket: $$state_bucket (prefix=$(DEV_BACKEND_PREFIX))"; \
	terraform -chdir=$(DEV_DIR) init -migrate-state -force-copy \
		-backend-config="bucket=$$state_bucket" \
		-backend-config="prefix=$(DEV_BACKEND_PREFIX)"

dev_plan: _check_dev_stack_env _check_gcp_project _check_dev_dir dev_init ## Plan dev stack (datasets + landing bucket + Composer)
	terraform -chdir=$(DEV_DIR) plan \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(DEV_PLAN_FILE)

dev_apply: _check_dev_stack_env _check_gcp_project _check_dev_dir dev_plan ## Apply dev stack (datasets + landing bucket + Composer)
	terraform -chdir=$(DEV_DIR) apply $(DEV_PLAN_FILE)

dev_destroy: _check_dev_stack_env _check_gcp_project _check_dev_dir dev_init _confirm_destroy_dev ## Destroy dev stack resources (confirmation skipped when CI=true/FORCE_DESTROY=true)
	terraform -chdir=$(DEV_DIR) destroy \
		$(TF_DESTROY_AUTO_APPROVE) \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)"

dev_clean: _check_dev_stack_env _check_dev_dir ## Clean up dev plan and local .terraform
	rm -f $(DEV_DIR)/$(DEV_PLAN_FILE)
	rm -rf $(DEV_DIR)/.terraform
