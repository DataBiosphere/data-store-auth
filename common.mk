SHELL=/bin/bash

ifndef DSS_AUTH_HOME
$(error Please run "source environment" in the data-store repo root directory before running make commands)
endif

ifeq ($(findstring terraform, $(shell which terraform 2>&1)),)
else ifeq ($(findstring Terraform v0.12.16, $(shell terraform --version 2>&1)),)
$(error You must use Terraform v0.12.16, please check your terraform version.)
endif

ifeq ("$(wildcard ~/.terraform.d/plugins/terraform-provider-auth0_v0.5.1)", "")
$(error You must have auth0 plug-in installed to ~/.terraform.d/plugins/terraform-provider-auth0_v0.5.1)
endif