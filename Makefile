# Copyright 2025 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

YAML_FILE_PATHS = $(shell find demos -type f -name "README.md" -exec grep -hoE 'YAML-START: [^ ]+' {} + | sed 's/YAML-START: //')

.PHONY: update-readme
update-readme:
	YAML_FILE_PATHS="$(YAML_FILE_PATHS)" ./hack/update_readme/update-readme.sh
