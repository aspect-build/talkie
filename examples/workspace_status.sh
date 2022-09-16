#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

git_commit=$(git rev-parse HEAD)
readonly git_commit
version=$(
    git describe --tags --long --match="[0-9][0-9][0-9][0-9].[0-9][0-9]" \
        | sed -e 's/-/./;s/-g/-/'
)
readonly version

cat << EOF
STABLE_GIT_COMMIT ${git_commit}
STABLE_GIT_SHORT_COMMIT ${git_commit:0:8}
STABLE_TALKIE_RELEASE_VERSION ${version}
EOF
