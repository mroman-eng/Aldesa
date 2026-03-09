.DEFAULT_GOAL := help
SHELL := /bin/bash

MAKEFILES_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

include $(MAKEFILES_DIR)mk/core/config.mk
include $(MAKEFILES_DIR)mk/core/help.mk
include $(MAKEFILES_DIR)mk/core/checks.mk
include $(MAKEFILES_DIR)mk/targets/foundation.mk
include $(MAKEFILES_DIR)mk/targets/storage_bq.mk
include $(MAKEFILES_DIR)mk/targets/orchestration.mk
include $(MAKEFILES_DIR)mk/targets/governance.mk
include $(MAKEFILES_DIR)mk/targets/bi.mk
include $(MAKEFILES_DIR)mk/targets/cicd.mk
include $(MAKEFILES_DIR)mk/targets/bootstrap.mk
