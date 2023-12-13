# WARNING: Please DO NOT edit this file! It is maintained in the Repository Template (https://github.com/nhs-england-tools/repository-template). Raise a PR instead.

include scripts/docker/docker.mk
include scripts/tests/test.mk

# ==============================================================================

runner-act: # Run GitHub Actions locally - mandatory: workflow=[workflow file name], job=[job name] @Development
	source ./scripts/docker/docker.lib.sh
	act $(shell [[ "${VERBOSE}" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]] && echo --verbose) \
		--container-architecture linux/amd64 \
		--platform ubuntu-latest=$$(name="ghcr.io/nhs-england-tools/github-runner-image" docker-get-image-version-and-pull) \
		--container-options "--privileged" \
		--bind \
		--pull=false \
		--reuse \
		--rm \
		--defaultbranch main \
		--workflows .github/workflows/${workflow}.yaml \
		--job ${job}

version-create-effective-file: # Create effective version file - optional: dir=[path to the VERSION file to use, default is '.'], BUILD_DATETIME=[build date and time in the '%Y-%m-%dT%H:%M:%S%z' format generated by the CI/CD pipeline, default is current date and time] @Development
	source scripts/docker/docker.lib.sh
	version-create-effective-file

shellscript-lint-all: # Lint all shell scripts in this project, do not fail on error, just print the error messages @Quality
	for file in $$(find . -type f -name "*.sh"); do
		file=$${file} scripts/shellscript-linter.sh ||:
	done

githooks-config: # Trigger Git hooks on commit that are defined in this repository @Configuration
	make _install-dependency name="pre-commit"
	pre-commit install \
		--config scripts/config/pre-commit.yaml \
		--install-hooks

githooks-run: # Run git hooks configured in this repository @Operations
	pre-commit run \
		--config scripts/config/pre-commit.yaml \
		--all-files

_install-dependency: # Install asdf dependency - mandatory: name=[listed in the '.tool-versions' file]; optional: version=[if not listed]
	asdf plugin add ${name} ||:
	asdf install ${name} $(or ${version},)

clean:: # Remove all generated and temporary files (common) @Operations
	rm -rf \
		.scannerwork \
		*report*.json \
		*report*json.zip \
		docs/diagrams/.*.bkp \
		docs/diagrams/.*.dtmp \
		.version

config:: # Configure development environment (common) @Configuration
	make \
		githooks-config

help: # Print help @Others
	printf "\nUsage: \033[3m\033[93m[arg1=val1] [arg2=val2] \033[0m\033[0m\033[32mmake\033[0m\033[34m <command>\033[0m\n\n"
	perl -e '$(HELP_SCRIPT)' $(MAKEFILE_LIST)

list-variables: # List all the variables available to make @Others
	$(foreach v, $(sort $(.VARIABLES)),
		$(if $(filter-out default automatic, $(origin $v)),
			$(if $(and $(patsubst %_PASSWORD,,$v), $(patsubst %_PASS,,$v), $(patsubst %_KEY,,$v), $(patsubst %_SECRET,,$v)),
				$(info $v=$($v) ($(value $v)) [$(flavor $v),$(origin $v)]),
				$(info $v=****** (******) [$(flavor $v),$(origin $v)])
			)
		)
	)

# ==============================================================================

.DEFAULT_GOAL := help
.EXPORT_ALL_VARIABLES:
.NOTPARALLEL:
.ONESHELL:
.PHONY: * # Please do not change this line! The alternative usage of it introduces unnecessary complexity and is considered an anti-pattern.
MAKEFLAGS := --no-print-director
SHELL := /bin/bash
ifeq (true, $(shell [[ "${VERBOSE}" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]] && echo true))
	.SHELLFLAGS := -cex
else
	.SHELLFLAGS := -ce
endif

# This script parses all the make target descriptions and renders the help output.
HELP_SCRIPT = \
	\
	use Text::Wrap; \
	%help_info; \
	my $$max_command_length = 0; \
	my $$terminal_width = `tput cols` || 120; chomp($$terminal_width); \
	\
	while(<>){ \
		next if /^_/; \
		\
		if (/^([\w-_]+)\s*:.*\#(.*?)(@(\w+))?\s*$$/) { \
			my $$command = $$1; \
			my $$description = $$2; \
			$$description =~ s/@\w+//; \
			my $$category_key = $$4 // 'Others'; \
			(my $$category_name = $$category_key) =~ s/(?<=[a-z])([A-Z])/\ $$1/g; \
			$$category_name = lc($$category_name); \
			$$category_name =~ s/^(.)/\U$$1/; \
			\
			push @{$$help_info{$$category_name}}, [$$command, $$description]; \
			$$max_command_length = (length($$command) > 37) ? 40 : $$max_command_length; \
		} \
	} \
	\
	my $$description_width = $$terminal_width - $$max_command_length - 4; \
	$$Text::Wrap::columns = $$description_width; \
	\
	for my $$category (sort { $$a eq 'Others' ? 1 : $$b eq 'Others' ? -1 : $$a cmp $$b } keys %help_info) { \
		print "\033[1m$$category\033[0m:\n\n"; \
		for my $$item (sort { $$a->[0] cmp $$b->[0] } @{$$help_info{$$category}}) { \
			my $$description = $$item->[1]; \
			my @desc_lines = split("\n", wrap("", "", $$description)); \
			my $$first_line_description = shift @desc_lines; \
			\
			$$first_line_description =~ s/(\w+)(\|\w+)?=/\033[3m\033[93m$$1$$2\033[0m=/g; \
			\
			my $$formatted_command = $$item->[0]; \
			$$formatted_command = substr($$formatted_command, 0, 37) . "..." if length($$formatted_command) > 37; \
			\
			print sprintf("  \033[0m\033[34m%-$${max_command_length}s\033[0m%s %s\n", $$formatted_command, $$first_line_description); \
			for my $$line (@desc_lines) { \
				$$line =~ s/(\w+)(\|\w+)?=/\033[3m\033[93m$$1$$2\033[0m=/g; \
				print sprintf(" %-$${max_command_length}s  %s\n", " ", $$line); \
			} \
			print "\n"; \
		} \
	}

# ==============================================================================

${VERBOSE}.SILENT: \
	_install-dependency \
	clean \
	config \
	githooks-config \
	githooks-run \
	help \
	list-variables \
	runner-act \
	shellscript-lint-all \
	version-create-effective-file \
