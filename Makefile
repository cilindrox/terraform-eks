SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

ALL = \
	check

# Run all linters and static checks
all: $(ALL)

bootstrap:
	@terraform -chdir=./bootstrap init -upgrade && \
  terraform -chdir=./bootstrap plan -out tfplan

check: check_terraform

check_github_actions:
	@zizmor .github/workflows

check_terraform:
	@terraform fmt -recursive -diff .

clean:
	@find ** -name "tfplan" -exec rm "{}" +

.PHONY: all bootstrap check check_terraform check_github_actions clean
