_check_gcp_project:
	@if [ -z "$(GOOGLE_PROJECT)" ] || [ "$(GOOGLE_PROJECT)" = "(unset)" ]; then \
		echo "GOOGLE_PROJECT is not set for ENV=$(ENV)."; \
		echo "Set GCP_PROJECT_<ENV> vars or override with GOOGLE_PROJECT=<PROJECT_ID>."; \
		exit 1; \
	fi
	@if [[ "$(GOOGLE_PROJECT)" == REPLACE_ME_* ]] || [[ "$(GOOGLE_PROJECT)" == replace-me-* ]]; then \
		echo "GOOGLE_PROJECT has a placeholder value: $(GOOGLE_PROJECT)"; \
		echo "Please set a real project id before running Terraform."; \
		exit 1; \
	fi
	@if [ "$(CI)" == "true" ]; then \
		echo "CI is set to '$(CI)', skipping confirmation."; \
	else \
		account="$(GOOGLE_ACCOUNT)"; \
		if [ -z "$$account" ] || [ "$$account" = "(unset)" ]; then account="<unknown>"; fi; \
		echo -n "[CONFIRMATION] ENV=$(ENV), project=$(GOOGLE_PROJECT), account=$$account. Continue? [y/N] > " && read ans && [ $${ans:-N} = y ]; \
	fi

_check_gcp_auth:
	@if [ "$(CI)" = "true" ]; then \
		if [ -n "$$GOOGLE_APPLICATION_CREDENTIALS" ]; then \
			if [ ! -f "$$GOOGLE_APPLICATION_CREDENTIALS" ]; then \
				echo "Credential file not found: $$GOOGLE_APPLICATION_CREDENTIALS"; \
				exit 1; \
			fi; \
			if command -v jq >/dev/null 2>&1; then \
				key_sa=$$(jq -r '.client_email // empty' "$$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null || true); \
			elif command -v python3 >/dev/null 2>&1; then \
				key_sa=$$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(\"client_email\", \"\"))' "$$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null || true); \
			else \
				key_sa=$$(sed -n 's/^[[:space:]]*\"client_email\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p' "$$GOOGLE_APPLICATION_CREDENTIALS" | head -n 1); \
			fi; \
			if [ -z "$$key_sa" ]; then \
				echo "Could not read client_email from $$GOOGLE_APPLICATION_CREDENTIALS"; \
				exit 1; \
			fi; \
			if [ "$$key_sa" != "$(TF_SA_EMAIL)" ]; then \
				echo "Credential file belongs to $$key_sa, expected $(TF_SA_EMAIL) for ENV=$(ENV)."; \
				exit 1; \
			fi; \
			echo "CI auth mode: using Terraform SA $$key_sa via GOOGLE_APPLICATION_CREDENTIALS."; \
		elif command -v gcloud >/dev/null 2>&1 && (gcloud auth print-access-token >/dev/null 2>&1 || gcloud auth application-default print-access-token >/dev/null 2>&1); then \
			ambient_account="$$(gcloud config get-value account 2>/dev/null || true)"; \
			if [ -n "$$ambient_account" ] && [ "$$ambient_account" != "(unset)" ]; then \
				echo "CI auth mode: using ambient credentials (gcloud account=$$ambient_account)."; \
			else \
				echo "CI auth mode: using ambient credentials (Cloud Build/WIF/metadata)."; \
			fi; \
		else \
			echo "CI=true requires either:"; \
			echo "  1) GOOGLE_APPLICATION_CREDENTIALS pointing to the Terraform SA key file, or"; \
			echo "  2) ambient credentials (Cloud Build trigger SA / WIF / metadata)."; \
			echo "Expected Terraform SA for ENV=$(ENV): $(TF_SA_EMAIL)"; \
			exit 1; \
		fi; \
	elif [ -n "$$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "$$GOOGLE_APPLICATION_CREDENTIALS" ]; then \
		echo "Using GOOGLE_APPLICATION_CREDENTIALS=$$GOOGLE_APPLICATION_CREDENTIALS"; \
	elif command -v gcloud >/dev/null 2>&1 && gcloud auth application-default print-access-token >/dev/null 2>&1; then \
		echo "ADC detected via gcloud."; \
	else \
		echo "Terraform requires Application Default Credentials (ADC), but none were detected."; \
		echo "Run these commands and retry:"; \
		echo "  gcloud auth application-default login"; \
		echo "  gcloud auth application-default set-quota-project $(GOOGLE_PROJECT)"; \
		echo "Optional verification:"; \
		echo "  gcloud auth application-default print-access-token >/dev/null"; \
		exit 1; \
	fi
	@if [ "$(CI)" != "true" ]; then \
		adc_file="$${GOOGLE_APPLICATION_CREDENTIALS:-$$HOME/.config/gcloud/application_default_credentials.json}"; \
		if [ -f "$$adc_file" ]; then \
			adc_type=""; \
			adc_impersonation_url=""; \
			if command -v jq >/dev/null 2>&1; then \
				adc_type=$$(jq -r '.type // empty' "$$adc_file" 2>/dev/null || true); \
				adc_impersonation_url=$$(jq -r '.service_account_impersonation_url // empty' "$$adc_file" 2>/dev/null || true); \
			elif command -v python3 >/dev/null 2>&1; then \
				adc_type=$$(python3 -c 'import json,sys; j=json.load(open(sys.argv[1])); print(j.get("type",""))' "$$adc_file" 2>/dev/null || true); \
				adc_impersonation_url=$$(python3 -c 'import json,sys; j=json.load(open(sys.argv[1])); print(j.get("service_account_impersonation_url",""))' "$$adc_file" 2>/dev/null || true); \
			fi; \
			if [ "$$adc_type" = "impersonated_service_account" ] && [ -n "$$GOOGLE_IMPERSONATE_SERVICE_ACCOUNT" ]; then \
				adc_target_sa=$$(echo "$$adc_impersonation_url" | sed -n 's#.*serviceAccounts/\\([^:]*\\):.*#\\1#p'); \
				if [ -z "$$adc_target_sa" ] || [ "$$adc_target_sa" = "$$GOOGLE_IMPERSONATE_SERVICE_ACCOUNT" ]; then \
					echo "Detected ADC type=impersonated_service_account in $$adc_file."; \
					echo "Local make mode already exports GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=$$GOOGLE_IMPERSONATE_SERVICE_ACCOUNT."; \
					echo "This creates double impersonation and can fail in Terraform with:"; \
					echo "  Permission 'iam.serviceAccounts.getAccessToken' denied"; \
					echo "Recreate USER ADC (non-impersonated) and keep impersonation only via env vars:"; \
					echo "  gcloud config unset auth/impersonate_service_account"; \
					echo "  unset GOOGLE_APPLICATION_CREDENTIALS"; \
					echo "  gcloud auth application-default revoke"; \
					echo "  gcloud auth application-default login"; \
					echo "  gcloud auth application-default set-quota-project $(GOOGLE_PROJECT)"; \
					echo "  export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=$(TF_SA_EMAIL)"; \
					echo "  export GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT=$$GOOGLE_IMPERSONATE_SERVICE_ACCOUNT"; \
					exit 1; \
				fi; \
			fi; \
		fi; \
	fi

_check_bootstrap_dir:
	@if [ ! -d "$(BOOTSTRAP_DIR)" ]; then \
		echo "Bootstrap directory does not exist: $(BOOTSTRAP_DIR)"; \
		exit 1; \
	fi

_check_bootstrap_impersonation_auth:
	@if [ "$(CI)" = "true" ]; then \
		echo "Bootstrap auth mode: CI=true, using ambient credentials (Cloud Build SA/WIF/metadata)."; \
	else \
		if ! command -v gcloud >/dev/null 2>&1; then \
			echo "gcloud is required for bootstrap impersonation pre-checks."; \
			exit 1; \
		fi; \
		if ! gcloud auth print-access-token --impersonate-service-account="$(TF_SA_EMAIL)" >/dev/null 2>&1; then \
			echo "Cannot impersonate Terraform SA $(TF_SA_EMAIL)."; \
			echo "Grant roles/iam.serviceAccountTokenCreator on that SA to your user/group and run:"; \
			echo "  gcloud auth login"; \
			echo "  gcloud auth application-default login"; \
			exit 1; \
		fi; \
		echo "Bootstrap auth mode: impersonating $(TF_SA_EMAIL)."; \
	fi

_check_foundation_dir:
	@if [ ! -d "$(FOUNDATION_DIR)" ]; then \
		echo "Foundation directory does not exist: $(FOUNDATION_DIR)"; \
		exit 1; \
	fi

_check_storage_bq_dir:
	@if [ ! -d "$(STORAGE_BQ_DIR)" ]; then \
		echo "Storage-BQ directory does not exist: $(STORAGE_BQ_DIR)"; \
		exit 1; \
	fi

_check_orchestration_dir:
	@if [ ! -d "$(ORCHESTRATION_DIR)" ]; then \
		echo "Orchestration directory does not exist: $(ORCHESTRATION_DIR)"; \
		exit 1; \
	fi

_check_governance_dir:
	@if [ ! -d "$(GOVERNANCE_DIR)" ]; then \
		echo "Governance directory does not exist: $(GOVERNANCE_DIR)"; \
		exit 1; \
	fi

_check_bi_dir:
	@if [ ! -d "$(BI_DIR)" ]; then \
		echo "BI directory does not exist: $(BI_DIR)"; \
		exit 1; \
	fi

_check_cicd_dir:
	@if [ ! -d "$(CICD_DIR)" ]; then \
		echo "CI/CD directory does not exist: $(CICD_DIR)"; \
		exit 1; \
	fi

_check_bootstrap_state_bucket:
	@if [ -z "$(TFSTATE_BACKEND_BUCKET)" ]; then \
		echo "TFSTATE_BACKEND_BUCKET is empty."; \
		echo "Expected default: $(TFSTATE_BACKEND_BUCKET_DEFAULT)"; \
		exit 1; \
	fi
	@if [[ "$(TFSTATE_BACKEND_BUCKET)" == REPLACE_ME_* ]] || [[ "$(TFSTATE_BACKEND_BUCKET)" == replace-me-* ]]; then \
		echo "TFSTATE_BACKEND_BUCKET has a placeholder value: $(TFSTATE_BACKEND_BUCKET)"; \
		exit 1; \
	fi
	@if command -v gcloud >/dev/null 2>&1; then \
		impersonation_flag=""; \
		if [ -n "$$GOOGLE_IMPERSONATE_SERVICE_ACCOUNT" ]; then impersonation_flag="--impersonate-service-account=$$GOOGLE_IMPERSONATE_SERVICE_ACCOUNT"; fi; \
		if ! gcloud storage buckets describe gs://$(TFSTATE_BACKEND_BUCKET) --project=$(GOOGLE_PROJECT) $$impersonation_flag >/dev/null 2>&1; then \
			echo "Terraform state backend bucket not found or not accessible: gs://$(TFSTATE_BACKEND_BUCKET)"; \
			echo "Bootstrap no longer creates the tfstate bucket."; \
			echo "Ensure project owners created it, or pass TFSTATE_BACKEND_BUCKET=<existing_bucket>."; \
			exit 1; \
		fi; \
	fi

_confirm_destroy_bootstrap:
	@if [ "$(CI)" = "true" ]; then \
		echo "CI=true, skipping bootstrap destroy confirmation."; \
	elif [ "$(FORCE_DESTROY)" = "true" ]; then \
		echo "FORCE_DESTROY=true, skipping bootstrap destroy confirmation."; \
	else \
		echo -n "[DESTROY CONFIRMATION] Destroy bootstrap in ENV=$(ENV), project=$(GOOGLE_PROJECT). Type 'destroy-bootstrap' to continue > " && read ans && [ "$$ans" = "destroy-bootstrap" ]; \
	fi

_confirm_destroy_foundation:
	@if [ "$(CI)" = "true" ]; then \
		echo "CI=true, skipping foundation destroy confirmation."; \
	elif [ "$(FORCE_DESTROY)" = "true" ]; then \
		echo "FORCE_DESTROY=true, skipping foundation destroy confirmation."; \
	else \
		echo -n "[DESTROY CONFIRMATION] Destroy foundation in ENV=$(ENV), project=$(GOOGLE_PROJECT). Type 'destroy-foundation' to continue > " && read ans && [ "$$ans" = "destroy-foundation" ]; \
	fi

_confirm_destroy_storage_bq:
	@if [ "$(CI)" = "true" ]; then \
		echo "CI=true, skipping storage-bq destroy confirmation."; \
	elif [ "$(FORCE_DESTROY)" = "true" ]; then \
		echo "FORCE_DESTROY=true, skipping storage-bq destroy confirmation."; \
	else \
		echo -n "[DESTROY CONFIRMATION] Destroy storage-bq in ENV=$(ENV), project=$(GOOGLE_PROJECT). Type 'destroy-storage-bq' to continue > " && read ans && [ "$$ans" = "destroy-storage-bq" ]; \
	fi

_confirm_destroy_orchestration:
	@if [ "$(CI)" = "true" ]; then \
		echo "CI=true, skipping orchestration destroy confirmation."; \
	elif [ "$(FORCE_DESTROY)" = "true" ]; then \
		echo "FORCE_DESTROY=true, skipping orchestration destroy confirmation."; \
	else \
		echo -n "[DESTROY CONFIRMATION] Destroy orchestration in ENV=$(ENV), project=$(GOOGLE_PROJECT). Type 'destroy-orchestration' to continue > " && read ans && [ "$$ans" = "destroy-orchestration" ]; \
	fi

_confirm_destroy_governance:
	@if [ "$(CI)" = "true" ]; then \
		echo "CI=true, skipping governance destroy confirmation."; \
	elif [ "$(FORCE_DESTROY)" = "true" ]; then \
		echo "FORCE_DESTROY=true, skipping governance destroy confirmation."; \
	else \
		echo -n "[DESTROY CONFIRMATION] Destroy governance in ENV=$(ENV), project=$(GOOGLE_PROJECT). Type 'destroy-governance' to continue > " && read ans && [ "$$ans" = "destroy-governance" ]; \
	fi

_confirm_destroy_bi:
	@if [ "$(CI)" = "true" ]; then \
		echo "CI=true, skipping BI destroy confirmation."; \
	elif [ "$(FORCE_DESTROY)" = "true" ]; then \
		echo "FORCE_DESTROY=true, skipping BI destroy confirmation."; \
	else \
		echo -n "[DESTROY CONFIRMATION] Destroy BI in ENV=$(ENV), project=$(GOOGLE_PROJECT). Type 'destroy-bi' to continue > " && read ans && [ "$$ans" = "destroy-bi" ]; \
	fi

_confirm_destroy_cicd:
	@if [ "$(CI)" = "true" ]; then \
		echo "CI=true, skipping CI/CD destroy confirmation."; \
	elif [ "$(FORCE_DESTROY)" = "true" ]; then \
		echo "FORCE_DESTROY=true, skipping CI/CD destroy confirmation."; \
	else \
		echo -n "[DESTROY CONFIRMATION] Destroy CI/CD in ENV=$(ENV), project=$(GOOGLE_PROJECT). Type 'destroy-cicd' to continue > " && read ans && [ "$$ans" = "destroy-cicd" ]; \
	fi
