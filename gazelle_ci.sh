#!/bin/env bash

# Copyright 2023 Aspect Build Systems, Inc. All rights reserved.
#
# Original authors: Thulio Ferraz Assis (thulio@aspect.dev)
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

readonly runfiles_dir="${PWD}"

PATH="$(dirname "${runfiles_dir}/${GO}"):${PATH}"
export PATH

cd "${BUILD_WORKSPACE_DIRECTORY}"

"${runfiles_dir}/${GO}" mod tidy

cd "${runfiles_dir}"

"${runfiles_dir}/${GAZELLE_UPDATE_REPOS}"

cd "${BUILD_WORKSPACE_DIRECTORY}"

if ! git diff --exit-code go.{mod,sum} deps.bzl; then
    echo "ERROR: gazelle update-repos produced changes to the repository. Please run 'bazel run //:gazelle.ci' and commit the changes."
    exit 1
fi

cd "${runfiles_dir}"

"${runfiles_dir}/${GAZELLE}" -mode=fix

cd "${BUILD_WORKSPACE_DIRECTORY}"

if ! find . -name 'BUILD.bazel' -exec git diff --exit-code {} \;; then
    echo "ERROR: gazelle -mode=fix produced changes to the repository. Please run 'bazel run //:gazelle.ci' and commit the changes."
    exit 1
fi
