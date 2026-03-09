.PHONY: cicd cicd_init cicd_plan cicd_apply cicd_destroy cicd_clean
cicd: cicd_apply ## Run 60-cicd workflow (init + plan + apply)

cicd_init: _check_gcp_project _check_gcp_auth _check_bootstrap_dir _check_cicd_dir _check_bootstrap_state_bucket ## Initialize Terraform in envs/<env>/60-cicd
	@state_bucket="$(TFSTATE_BACKEND_BUCKET)"; \
	echo "Using cicd backend bucket: $$state_bucket (prefix=$(CICD_BACKEND_PREFIX))"; \
	terraform -chdir=$(CICD_DIR) init -migrate-state -force-copy \
		-backend-config="bucket=$$state_bucket" \
		-backend-config="prefix=$(CICD_BACKEND_PREFIX)"

cicd_plan: _check_gcp_project _check_cicd_dir cicd_init ## Plan env CI/CD (Cloud Build identities and optional triggers)
	terraform -chdir=$(CICD_DIR) plan \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(CICD_PLAN_FILE)

cicd_apply: _check_gcp_project _check_cicd_dir cicd_plan ## Apply env CI/CD (Cloud Build identities and optional triggers)
	terraform -chdir=$(CICD_DIR) apply $(CICD_PLAN_FILE)

cicd_destroy: _check_gcp_project _check_cicd_dir cicd_init _confirm_destroy_cicd ## Destroy env CI/CD resources (confirmation skipped when CI=true/FORCE_DESTROY=true)
	terraform -chdir=$(CICD_DIR) destroy \
		$(TF_DESTROY_AUTO_APPROVE) \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)"

cicd_clean: _check_cicd_dir ## Clean up CI/CD plan and local .terraform
	rm -f $(CICD_DIR)/$(CICD_PLAN_FILE)
	rm -rf $(CICD_DIR)/.terraform
