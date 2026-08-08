# shellcheck shell=bash

################################################################################
# Logging helpers
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info() { printf '%b\n' "${BLUE}[$(date '+%F %T')] [INFO]${NC} $*"; }
success() { printf '%b\n' "${GREEN}[$(date '+%F %T')] [SUCCESS]${NC} $*"; }
warn() { printf '%b\n' "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*"; }
step() {
    local message="$1"
    printf '%b\n' "${BOLD}[$(date '+%F %T')] [STEP ${STEP}] ${message}${NC}"
}

fatal() {
    printf '%b\n' "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2
    exit 1
}
