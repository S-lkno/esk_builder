#!/usr/bin/env bash
set -euo pipefail

# Check for shfmt command
command -v shfmt > /dev/null || {
    echo "shfmt not found"
    exit 127
}

# Get script directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd -P)"

# Format build.sh with shfmt
exec shfmt -w -i 4 -ci -bn -sr "$SCRIPT_DIR"/*.sh
