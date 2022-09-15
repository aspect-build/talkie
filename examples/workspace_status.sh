#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

git_commit=$(git rev-parse HEAD)
readonly git_commit

cat <<EOF
STABLE_GIT_COMMIT ${git_commit}
STABLE_GIT_SHORT_COMMIT ${git_commit:0:8}
STABLE_TALKIE_SERVICE_TAG ${git_commit}
EOF
