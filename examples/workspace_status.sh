#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

git_commit=$(git rev-parse HEAD)
readonly git_commit

# Semver compatible git describe: https://github.com/choffmeister/git-describe-semver
version=$(cd ../.. && ./tools/git-describe-semver --fallback v0.0.0)
readonly version

cat << EOF
STABLE_GIT_COMMIT ${git_commit}
STABLE_GIT_SHORT_COMMIT ${git_commit:0:8}
STABLE_TALKIE_RELEASE_VERSION ${version}
EOF
