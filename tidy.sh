#!/usr/bin/env bash

# Copyright 2022 Aspect Build Systems Inc.
# Original authors: Dylan Martin (dylan@aspect.dev)
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

set -o errexit -o nounset -o pipefail

# To add a new go dependency, make the required changes to the go files (import and use) and then
# run this file.

cd "${BUILD_WORKSPACE_DIRECTORY}"

bazel run @go_sdk//:bin/go -- mod tidy
bazel run //:gazelle_update_repos
bazel run //:gazelle

if [ "$(git status --porcelain | wc -l)" -gt 0 ]; then
    echo >&2 "ERROR: files changed, commit them"
    git >&2 diff
    exit 1
fi
