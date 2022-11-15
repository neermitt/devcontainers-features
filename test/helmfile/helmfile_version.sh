#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "check for helmfile" helmfile --version

# Report result
reportResults
