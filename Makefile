# Native Makefile (cloudposse-style targets, no build-harness dependency).

TF ?= terraform

.PHONY: init validate lint test readme docs clean

## init: terraform init without a backend
init:
	$(TF) init -backend=false

## validate: fmt check + terraform validate
validate: init
	$(TF) fmt -check -recursive
	$(TF) validate

## lint: run tflint
lint:
	tflint --init && tflint

## test: plan-only unit + contract tests (run with Terraform 1.9.5 to match CI)
test: init
	$(TF) test -filter=tests/unit.tftest.hcl -filter=tests/contract.tftest.hcl

## readme: regenerate the terraform-docs section of README.md
readme:
	terraform-docs -c .terraform-docs.yml .

## docs: alias for readme
docs: readme

## clean: remove local terraform state/cache
clean:
	rm -rf .terraform .terraform.lock.hcl
