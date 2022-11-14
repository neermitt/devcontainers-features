#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "check for terraform-docs" terraform-docs --version

# Report result
reportResults