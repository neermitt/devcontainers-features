#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "check for helmfile" helmfile --version
check "check for kind" kind --version
check "check for yq" yq --version

# Report result
reportResults