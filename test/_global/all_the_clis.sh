#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "check for helmfile" helmfile --version
check "check for kind" kind --version
check "check for yq" yq --version
check "check for gomplate" gomplate --version
check "check for terraform-docs" terraform-docs --version
check "check for pre-commit" pre-commit --version
check "check for gitleaks" gitleaks version
check "check for bats" bats --version
check "check for terraform-config-inspect" terraform-config-inspect --version

# Report result
reportResults
