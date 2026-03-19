.PHONY: storage_bq storage_bq_init storage_bq_plan storage_bq_apply storage_bq_destroy storage_bq_clean
storage_bq: _check_workload_env storage_bq_apply ## Run 20-storage-bq workflow (init + plan + apply)

storage_bq_init: _check_workload_env _check_gcp_project _check_gcp_auth _check_bootstrap_dir _check_storage_bq_dir _check_bootstrap_state_bucket ## Initialize Terraform in envs/<env>/20-storage-bq
	@state_bucket="$(TFSTATE_BACKEND_BUCKET)"; \
	echo "Using storage-bq backend bucket: $$state_bucket (prefix=$(STORAGE_BQ_BACKEND_PREFIX))"; \
	terraform -chdir=$(STORAGE_BQ_DIR) init -migrate-state -force-copy \
		-backend-config="bucket=$$state_bucket" \
		-backend-config="prefix=$(STORAGE_BQ_BACKEND_PREFIX)"

storage_bq_plan: _check_workload_env _check_gcp_project _check_storage_bq_dir storage_bq_init ## Plan env storage-bq (landing bucket, medallion datasets, bronze transfers)
	terraform -chdir=$(STORAGE_BQ_DIR) plan \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(STORAGE_BQ_PLAN_FILE)

storage_bq_apply: _check_workload_env _check_gcp_project _check_storage_bq_dir storage_bq_plan ## Apply env storage-bq (landing bucket, medallion datasets, bronze transfers)
	terraform -chdir=$(STORAGE_BQ_DIR) apply \
		-parallelism=$(STORAGE_BQ_APPLY_PARALLELISM) \
		$(STORAGE_BQ_PLAN_FILE)

storage_bq_destroy: _check_workload_env _check_gcp_project _check_storage_bq_dir storage_bq_init _confirm_destroy_storage_bq ## Destroy env storage-bq resources (confirmation skipped when CI=true/FORCE_DESTROY=true)
	terraform -chdir=$(STORAGE_BQ_DIR) destroy \
		$(TF_DESTROY_AUTO_APPROVE) \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)"

storage_bq_clean: _check_workload_env _check_storage_bq_dir ## Clean up storage-bq plan and local .terraform
	rm -f $(STORAGE_BQ_DIR)/$(STORAGE_BQ_PLAN_FILE)
	rm -rf $(STORAGE_BQ_DIR)/.terraform
