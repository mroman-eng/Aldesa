.PHONY: orchestration orchestration_init orchestration_plan orchestration_apply orchestration_sync_dags orchestration_sops_decrypt orchestration_sops_encrypt orchestration_destroy orchestration_clean _orchestration_cleanup_dataform_workspaces _orchestration_auto_import_eventarc_subscription_tuning _orchestration_detach_eventarc_subscription_tuning
orchestration: orchestration_apply ## Run 30-orchestration workflow (init + plan + apply)

orchestration_init: _check_gcp_project _check_gcp_auth _check_bootstrap_dir _check_orchestration_dir _check_bootstrap_state_bucket ## Initialize Terraform in envs/<env>/30-orchestration
	@state_bucket="$(TFSTATE_BACKEND_BUCKET)"; \
	echo "Using orchestration backend bucket: $$state_bucket (prefix=$(ORCHESTRATION_BACKEND_PREFIX))"; \
	terraform -chdir=$(ORCHESTRATION_DIR) init -migrate-state -force-copy \
		-backend-config="bucket=$$state_bucket" \
		-backend-config="prefix=$(ORCHESTRATION_BACKEND_PREFIX)"

orchestration_plan: _check_gcp_project _check_orchestration_dir orchestration_init _orchestration_auto_import_eventarc_subscription_tuning ## Plan env orchestration (Composer 3 + DAG bucket + IAM)
	terraform -chdir=$(ORCHESTRATION_DIR) plan \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(ORCHESTRATION_PLAN_FILE)

orchestration_apply: _check_gcp_project _check_orchestration_dir orchestration_plan ## Apply env orchestration (Composer 3 + DAG bucket + IAM)
	terraform -chdir=$(ORCHESTRATION_DIR) apply $(ORCHESTRATION_PLAN_FILE)
	@echo "Running post-apply reconciliation for Eventarc subscription tuning (auto-discover/import + second apply if needed)..."
	@$(MAKE) --no-print-directory _orchestration_auto_import_eventarc_subscription_tuning ENV=$(ENV)
	@set -e; \
	rc=0; \
	terraform -chdir=$(ORCHESTRATION_DIR) plan -detailed-exitcode \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		-out=$(ORCHESTRATION_PLAN_FILE) || rc=$$?; \
	if [ $$rc -eq 0 ]; then \
		echo "No post-apply reconciliation changes."; \
	elif [ $$rc -eq 2 ]; then \
		echo "Applying post-apply reconciliation changes..."; \
		terraform -chdir=$(ORCHESTRATION_DIR) apply $(ORCHESTRATION_PLAN_FILE); \
	else \
		echo "Post-apply reconciliation plan failed."; \
		exit 1; \
	fi

orchestration_sync_dags: _check_gcp_project _check_gcp_auth _check_orchestration_dir orchestration_init ## Sync local DAGs to the orchestration DAG bucket (on-demand, no delete)
	@set -euo pipefail; \
	if ! command -v gcloud >/dev/null 2>&1; then \
		echo "gcloud CLI is required for orchestration_sync_dags."; \
		exit 1; \
	fi; \
	source_dir="$(DAGS_SYNC_SOURCE_DIR)"; \
	if [ ! -d "$$source_dir" ]; then \
		echo "DAG source directory not found: $$source_dir"; \
		exit 1; \
	fi; \
	bucket="$(DAGS_SYNC_BUCKET)"; \
	if [ -z "$$bucket" ]; then \
		bucket=$$(terraform -chdir=$(ORCHESTRATION_DIR) output -raw dags_bucket_name 2>/dev/null || true); \
	fi; \
	case "$$bucket" in \
		""|"null") \
			echo "Could not resolve dags_bucket_name from orchestration outputs."; \
			echo "Apply orchestration first or pass DAGS_SYNC_BUCKET=<bucket>."; \
			exit 1;; \
	esac; \
	dest_prefix="$(DAGS_SYNC_DEST_PREFIX)"; \
	dest_uri="gs://$$bucket"; \
	if [ -n "$$dest_prefix" ]; then \
		dest_prefix="$${dest_prefix#/}"; \
		dest_uri="$$dest_uri/$$dest_prefix"; \
	fi; \
		echo "Syncing DAGs: $$source_dir -> $$dest_uri"; \
		if [ "$(DAGS_SYNC_DRY_RUN)" = "true" ]; then \
			echo "DAGS_SYNC_DRY_RUN=true, preview mode only."; \
			gcloud storage rsync --recursive --dry-run "$$source_dir" "$$dest_uri"; \
		else \
			gcloud storage rsync --recursive "$$source_dir" "$$dest_uri"; \
		fi

orchestration_sops_decrypt: _check_gcp_project _check_gcp_auth _check_orchestration_dir ## Decrypt orchestration SOPS secret in place (local only)
	@set -euo pipefail; \
	if ! command -v sops >/dev/null 2>&1; then \
		echo "sops binary not found in PATH."; \
		exit 1; \
	fi; \
	encrypted_file="$(ORCHESTRATION_SOPS_SECRET_FILE)"; \
	if [ ! -f "$$encrypted_file" ]; then \
		echo "Encrypted SOPS file not found: $$encrypted_file"; \
		exit 1; \
	fi; \
	use_impersonated_adc="false"; \
	if command -v gcloud >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 && gcloud auth print-access-token --impersonate-service-account="$(TF_SA_EMAIL)" >/dev/null 2>&1; then \
		use_impersonated_adc="true"; \
	fi; \
	if [ "$$use_impersonated_adc" = "true" ]; then \
		src_adc_file="$${GOOGLE_APPLICATION_CREDENTIALS:-$$HOME/.config/gcloud/application_default_credentials.json}"; \
		if [ ! -f "$$src_adc_file" ]; then \
			echo "ADC file not found: $$src_adc_file"; \
			echo "Run: gcloud auth application-default login"; \
			exit 1; \
		fi; \
		tmp_adc_file="$$(mktemp)"; \
		tmp_py_file="$$(mktemp)"; \
		cleanup() { rm -f "$$tmp_adc_file" "$$tmp_py_file"; }; \
		trap cleanup EXIT; \
		printf '%s\n' \
			'import json, sys' \
			'src = json.load(open(sys.argv[1]))' \
			'sa = sys.argv[2]' \
			'out = sys.argv[3]' \
			't = src.get("type")' \
			'sc = src if t == "authorized_user" else src.get("source_credentials", {}) if t == "impersonated_service_account" else None' \
			'req = ("client_id", "client_secret", "refresh_token")' \
			'if (not sc) or sc.get("type") != "authorized_user" or any(not sc.get(k) for k in req):' \
			'    raise SystemExit("ADC must be authorized_user or impersonated_service_account with source_credentials authorized_user.")' \
			'doc = {' \
			'    "type": "impersonated_service_account",' \
			'    "service_account_impersonation_url": f"https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{sa}:generateAccessToken",' \
			'    "source_credentials": {' \
			'        "type": "authorized_user",' \
			'        "client_id": sc["client_id"],' \
			'        "client_secret": sc["client_secret"],' \
			'        "refresh_token": sc["refresh_token"],' \
			'    },' \
			'}' \
			'qp = sc.get("quota_project_id") or src.get("quota_project_id")' \
			'if qp:' \
			'    doc["quota_project_id"] = qp' \
			'json.dump(doc, open(out, "w"))' \
			> "$$tmp_py_file"; \
		python3 "$$tmp_py_file" "$$src_adc_file" "$(TF_SA_EMAIL)" "$$tmp_adc_file"; \
		chmod 600 "$$tmp_adc_file"; \
		echo "SOPS auth mode: temporary ADC impersonating $(TF_SA_EMAIL)."; \
		GOOGLE_APPLICATION_CREDENTIALS="$$tmp_adc_file" \
		GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="" \
		GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT="" \
		sops -d -i "$$encrypted_file"; \
	else \
		echo "SOPS auth mode: caller ADC (no Terraform SA impersonation)."; \
		sops -d -i "$$encrypted_file"; \
	fi; \
	echo "File decrypted in place: $$encrypted_file"; \
	echo "After editing, run: make orchestration_sops_encrypt ENV=$(ENV)"

orchestration_sops_encrypt: _check_gcp_project _check_gcp_auth _check_orchestration_dir ## Encrypt orchestration SOPS secret in place with env-specific KMS (local only)
	@set -euo pipefail; \
	if ! command -v sops >/dev/null 2>&1; then \
		echo "sops binary not found in PATH."; \
		exit 1; \
	fi; \
	encrypted_file="$(ORCHESTRATION_SOPS_SECRET_FILE)"; \
	kms_resource="$(ORCHESTRATION_SOPS_KMS_RESOURCE)"; \
	if [ ! -f "$$encrypted_file" ]; then \
		echo "SOPS file not found: $$encrypted_file"; \
		exit 1; \
	fi; \
	use_impersonated_adc="false"; \
	if command -v gcloud >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 && gcloud auth print-access-token --impersonate-service-account="$(TF_SA_EMAIL)" >/dev/null 2>&1; then \
		use_impersonated_adc="true"; \
	fi; \
	if [ "$$use_impersonated_adc" = "true" ]; then \
		src_adc_file="$${GOOGLE_APPLICATION_CREDENTIALS:-$$HOME/.config/gcloud/application_default_credentials.json}"; \
		if [ ! -f "$$src_adc_file" ]; then \
			echo "ADC file not found: $$src_adc_file"; \
			echo "Run: gcloud auth application-default login"; \
			exit 1; \
		fi; \
		tmp_adc_file="$$(mktemp)"; \
		tmp_py_file="$$(mktemp)"; \
		cleanup() { rm -f "$$tmp_adc_file" "$$tmp_py_file"; }; \
		trap cleanup EXIT; \
		printf '%s\n' \
			'import json, sys' \
			'src = json.load(open(sys.argv[1]))' \
			'sa = sys.argv[2]' \
			'out = sys.argv[3]' \
			't = src.get("type")' \
			'sc = src if t == "authorized_user" else src.get("source_credentials", {}) if t == "impersonated_service_account" else None' \
			'req = ("client_id", "client_secret", "refresh_token")' \
			'if (not sc) or sc.get("type") != "authorized_user" or any(not sc.get(k) for k in req):' \
			'    raise SystemExit("ADC must be authorized_user or impersonated_service_account with source_credentials authorized_user.")' \
			'doc = {' \
			'    "type": "impersonated_service_account",' \
			'    "service_account_impersonation_url": f"https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{sa}:generateAccessToken",' \
			'    "source_credentials": {' \
			'        "type": "authorized_user",' \
			'        "client_id": sc["client_id"],' \
			'        "client_secret": sc["client_secret"],' \
			'        "refresh_token": sc["refresh_token"],' \
			'    },' \
			'}' \
			'qp = sc.get("quota_project_id") or src.get("quota_project_id")' \
			'if qp:' \
			'    doc["quota_project_id"] = qp' \
			'json.dump(doc, open(out, "w"))' \
			> "$$tmp_py_file"; \
		python3 "$$tmp_py_file" "$$src_adc_file" "$(TF_SA_EMAIL)" "$$tmp_adc_file"; \
		chmod 600 "$$tmp_adc_file"; \
		echo "SOPS auth mode: temporary ADC impersonating $(TF_SA_EMAIL)."; \
		GOOGLE_APPLICATION_CREDENTIALS="$$tmp_adc_file" \
		GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="" \
		GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT="" \
		sops --encrypt --gcp-kms "$$kms_resource" --input-type yaml --output-type yaml -i "$$encrypted_file"; \
	else \
		echo "SOPS auth mode: caller ADC (no Terraform SA impersonation)."; \
		sops --encrypt --gcp-kms "$$kms_resource" --input-type yaml --output-type yaml -i "$$encrypted_file"; \
	fi; \
	echo "Encrypted file updated: $$encrypted_file"; \
	echo "KMS used: $$kms_resource"

orchestration_destroy: _check_gcp_project _check_orchestration_dir orchestration_init _confirm_destroy_orchestration _orchestration_cleanup_dataform_workspaces _orchestration_auto_import_eventarc_subscription_tuning _orchestration_detach_eventarc_subscription_tuning ## Destroy env orchestration resources (confirmation skipped when CI=true/FORCE_DESTROY=true)
	terraform -chdir=$(ORCHESTRATION_DIR) destroy \
		$(TF_DESTROY_AUTO_APPROVE) \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)"

orchestration_clean: _check_orchestration_dir ## Clean up orchestration plan and local .terraform
	rm -f $(ORCHESTRATION_DIR)/$(ORCHESTRATION_PLAN_FILE)
	rm -f $(ORCHESTRATION_DIR)/.eventarc_subscription_tuning.auto.tfvars.json
	rm -rf $(ORCHESTRATION_DIR)/.terraform

_orchestration_cleanup_dataform_workspaces:
	@repo_id=$$(terraform -chdir=$(ORCHESTRATION_DIR) output -raw dataform_repository_id 2>/dev/null || true); \
	case "$$repo_id" in projects/*/locations/*/repositories/*) ;; *) repo_id="";; esac; \
	repo_name=""; \
	if [ -n "$$repo_id" ] && [ "$$repo_id" != "null" ]; then repo_name="$${repo_id##*/}"; fi; \
	if [ -z "$$repo_name" ]; then \
		repo_name=$$(terraform -chdir=$(ORCHESTRATION_DIR) output -raw dataform_repository_name 2>/dev/null || true); \
	fi; \
	case "$$repo_name" in \
		""|"null") repo_name="";; \
		*[!a-zA-Z0-9_-]*) repo_name="";; \
	esac; \
	if [ -z "$$repo_name" ] || [ "$$repo_name" = "null" ]; then \
		echo "No Dataform repository found in orchestration state. Skipping Dataform workspace cleanup."; \
		exit 0; \
	fi; \
	if ! command -v gcloud >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then \
		echo "Warning: gcloud/curl/jq is required to auto-clean Dataform workspaces. Skipping cleanup."; \
		exit 0; \
	fi; \
	token=$$(gcloud auth print-access-token 2>/dev/null || gcloud auth application-default print-access-token 2>/dev/null || true); \
	if [ -z "$$token" ]; then \
		echo "Warning: could not obtain an access token from gcloud. Skipping Dataform workspace cleanup."; \
		exit 0; \
	fi; \
	workspaces_url="https://dataform.googleapis.com/v1/projects/$(GOOGLE_PROJECT)/locations/$(GCP_REGION)/repositories/$$repo_name/workspaces"; \
	workspace_names=$$(curl -sS -f -H "Authorization: Bearer $$token" "$$workspaces_url" | jq -r '.workspaces[]?.name' || true); \
	if [ -z "$$workspace_names" ]; then \
		echo "No Dataform workspaces found for $$repo_name."; \
		exit 0; \
	fi; \
	echo "Cleaning Dataform workspaces in $$repo_name before destroy..."; \
	while IFS= read -r workspace_name; do \
		if [ -n "$$workspace_name" ]; then \
			echo " - deleting $$workspace_name"; \
			curl -sS -f -X DELETE -H "Authorization: Bearer $$token" "https://dataform.googleapis.com/v1/$$workspace_name" >/dev/null || true; \
		fi; \
	done <<< "$$workspace_names"

_orchestration_auto_import_eventarc_subscription_tuning:
	@addr='module.orchestration.google_pubsub_subscription.landing_to_composer_eventarc_delivery[0]'; \
	auto_tfvars_file='$(ORCHESTRATION_DIR)/.eventarc_subscription_tuning.auto.tfvars.json'; \
	tf_console() { \
		terraform -chdir=$(ORCHESTRATION_DIR) console \
			-var="project_id=$(GOOGLE_PROJECT)" \
			-var="environment=$(ENV)" \
			-var="region=$(GCP_REGION)" 2>/dev/null; \
	}; \
	trigger_enabled=$$(printf '%s\n' 'try(local.landing_to_composer_trigger_config.enabled, false)' | tf_console | tr -d '[:space:]'); \
	tuning_enabled=$$(printf '%s\n' 'try(local.landing_to_composer_trigger_config.eventarc_subscription_tuning.enabled, false)' | tf_console | tr -d '[:space:]'); \
	explicit_sub_name=$$(printf '%s\n' 'try(trimspace(var.landing_to_composer_trigger.eventarc_subscription_tuning.subscription_name), "")' | tf_console | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$$//' -e 's/^"//' -e 's/"$$//'); \
	sub_name=$$(printf '%s\n' 'try(trimspace(local.landing_to_composer_trigger_config.eventarc_subscription_tuning.subscription_name), "")' | tf_console | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$$//' -e 's/^"//' -e 's/"$$//'); \
	if [ "$$trigger_enabled" != "true" ] || [ "$$tuning_enabled" != "true" ]; then \
		rm -f "$$auto_tfvars_file"; \
		echo "Eventarc subscription tuning import not enabled in tfvars. Skipping."; \
		exit 0; \
	fi; \
	if [ -z "$$sub_name" ] && terraform -chdir=$(ORCHESTRATION_DIR) state show "$$addr" >/dev/null 2>&1; then \
		sub_name=$$(terraform -chdir=$(ORCHESTRATION_DIR) state show "$$addr" | sed -n 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\"[[:space:]]*$$/\\1/p' | head -n 1); \
		if [ -z "$$sub_name" ]; then \
			sub_name=$$(terraform -chdir=$(ORCHESTRATION_DIR) state show "$$addr" | sed -n 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*\\([^[:space:]].*\\)$$/\\1/p' | head -n 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$$//'); \
		fi; \
		if [ -n "$$sub_name" ]; then \
			printf '{\n  "landing_to_composer_trigger_eventarc_subscription_name_override": "%s"\n}\n' "$$sub_name" > "$$auto_tfvars_file"; \
			echo "Recovered Eventarc subscription name '$$sub_name' from Terraform state and wrote $$auto_tfvars_file"; \
		fi; \
	fi; \
	if [ -z "$$sub_name" ]; then \
		trigger_id=$$(terraform -chdir=$(ORCHESTRATION_DIR) output -raw landing_to_composer_eventarc_trigger_id 2>/dev/null || true); \
		case "$$trigger_id" in projects/*/locations/*/triggers/*) ;; *) trigger_id="";; esac; \
		if [ -z "$$trigger_id" ] || [ "$$trigger_id" = "null" ]; then \
			echo "Eventarc subscription tuning is enabled but Eventarc trigger is not created yet. Deferring subscription import until a later run."; \
			exit 0; \
		fi; \
		trigger_name="$${trigger_id##*/}"; \
		subscription_ref=$$(gcloud eventarc triggers describe "$$trigger_name" --project=$(GOOGLE_PROJECT) --location=$(GCP_REGION) --format='value(transport.pubsub.subscription)' 2>/dev/null || true); \
		if [ -z "$$subscription_ref" ]; then \
			echo "Could not discover Eventarc Pub/Sub subscription from trigger '$$trigger_name'."; \
			echo "Check that the trigger exists and your gcloud account can read Eventarc."; \
			exit 1; \
		fi; \
		if [[ "$$subscription_ref" == projects/*/subscriptions/* ]]; then \
			sub_name="$${subscription_ref##*/}"; \
		else \
			sub_name="$$subscription_ref"; \
		fi; \
		printf '{\n  "landing_to_composer_trigger_eventarc_subscription_name_override": "%s"\n}\n' "$$sub_name" > "$$auto_tfvars_file"; \
		echo "Discovered Eventarc subscription '$$sub_name' from trigger '$$trigger_name' and wrote $$auto_tfvars_file"; \
	fi; \
	if terraform -chdir=$(ORCHESTRATION_DIR) state show "$$addr" >/dev/null 2>&1; then \
		echo "Eventarc subscription tuning resource already imported in Terraform state."; \
		exit 0; \
	fi; \
	if [[ "$$sub_name" == projects/*/subscriptions/* ]]; then \
		sub_import_id="$$sub_name"; \
		sub_lookup_name="$${sub_name##*/}"; \
	else \
		sub_lookup_name="$$sub_name"; \
		sub_import_id="projects/$(GOOGLE_PROJECT)/subscriptions/$$sub_lookup_name"; \
	fi; \
	if ! gcloud pubsub subscriptions describe "$$sub_lookup_name" --project=$(GOOGLE_PROJECT) >/dev/null 2>&1; then \
		if [ -z "$$explicit_sub_name" ]; then \
			trigger_id=$$(terraform -chdir=$(ORCHESTRATION_DIR) output -raw landing_to_composer_eventarc_trigger_id 2>/dev/null || true); \
			case "$$trigger_id" in projects/*/locations/*/triggers/*) ;; *) trigger_id="";; esac; \
			trigger_name=""; \
			if [ -n "$$trigger_id" ] && [ "$$trigger_id" != "null" ]; then trigger_name="$${trigger_id##*/}"; fi; \
			if [ -n "$$trigger_name" ]; then \
				subscription_ref=$$(gcloud eventarc triggers describe "$$trigger_name" --project=$(GOOGLE_PROJECT) --location=$(GCP_REGION) --format='value(transport.pubsub.subscription)' 2>/dev/null || true); \
				if [ -n "$$subscription_ref" ]; then \
					if [[ "$$subscription_ref" == projects/*/subscriptions/* ]]; then \
						fresh_sub_name="$${subscription_ref##*/}"; \
					else \
						fresh_sub_name="$$subscription_ref"; \
					fi; \
					if [ -n "$$fresh_sub_name" ] && [ "$$fresh_sub_name" != "$$sub_lookup_name" ]; then \
						sub_name="$$fresh_sub_name"; \
						sub_lookup_name="$$fresh_sub_name"; \
						sub_import_id="projects/$(GOOGLE_PROJECT)/subscriptions/$$sub_lookup_name"; \
						printf '{\n  "landing_to_composer_trigger_eventarc_subscription_name_override": "%s"\n}\n' "$$sub_name" > "$$auto_tfvars_file"; \
						echo "Updated stale Eventarc subscription override to '$$sub_name' from trigger '$$trigger_name'."; \
					fi; \
				fi; \
			fi; \
			if ! gcloud pubsub subscriptions describe "$$sub_lookup_name" --project=$(GOOGLE_PROJECT) >/dev/null 2>&1; then \
				rm -f "$$auto_tfvars_file"; \
				echo "Eventarc subscription '$$sub_lookup_name' is not available yet (or the auto-discovered value is stale). Deferring import until a later run."; \
				exit 0; \
			fi; \
		else \
			echo "Configured Eventarc subscription '$$sub_lookup_name' does not exist."; \
			echo "The value comes from terraform.tfvars (explicit configuration), so it is treated as an error."; \
			exit 1; \
		fi; \
	fi; \
	echo "Importing Eventarc-created Pub/Sub subscription into Terraform state for tuning: $$sub_import_id"; \
	terraform -chdir=$(ORCHESTRATION_DIR) import \
		-var="project_id=$(GOOGLE_PROJECT)" \
		-var="environment=$(ENV)" \
		-var="region=$(GCP_REGION)" \
		"$$addr" "$$sub_import_id"

_orchestration_detach_eventarc_subscription_tuning:
	@addr='module.orchestration.google_pubsub_subscription.landing_to_composer_eventarc_delivery[0]'; \
	if terraform -chdir=$(ORCHESTRATION_DIR) state show "$$addr" >/dev/null 2>&1; then \
		echo "Removing imported Eventarc-managed Pub/Sub subscription tuning resource from Terraform state before destroy (Eventarc owns lifecycle)."; \
		terraform -chdir=$(ORCHESTRATION_DIR) state rm "$$addr" >/dev/null; \
	else \
		echo "No imported Eventarc subscription tuning resource found in orchestration state. Skipping state detach."; \
	fi
