#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

readonly runfiles_dir="${PWD}"

PATH="$(dirname "${runfiles_dir}/${GO}"):${PATH}"
export PATH

cd "${BUILD_WORKSPACE_DIRECTORY}"

"${runfiles_dir}/${GO}" mod tidy

cd "${runfiles_dir}"

"${runfiles_dir}/${GAZELLE}" update-repos \
    -build_file_proto_mode=disable_global \
    -from_file=go.mod \
    -to_macro=deps.bzl%go_dependencies \
    -prune=true

cd "${BUILD_WORKSPACE_DIRECTORY}"

git diff --exit-code go.{mod,sum} deps.bzl

cd "${runfiles_dir}"

"${runfiles_dir}/${GAZELLE}" -mode=fix

cd "${BUILD_WORKSPACE_DIRECTORY}"

git diff --exit-code
