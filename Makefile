# Setting SHELL to bash allows bash commands to be executed by recipes.
# This is a requirement for 'setup-envtest.sh' in the test target.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

YAML_FILE_PATHS = $(shell find demos -type f -name "README.md" -exec grep -hoE 'YAML-START: [^ ]+' {} + | sed 's/YAML-START: //')

.PHONY: update-readme
update-readme:
	YAML_FILE_PATHS="$(YAML_FILE_PATHS)" ./hack/update_readme/update-readme.sh
