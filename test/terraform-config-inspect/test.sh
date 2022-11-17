#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "check for terraform-config-inspect" terraform-config-inspect --version

# Report result
reportResults
