#!/bin/bash

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== UVM Shell Hook Repair ===${NC}"

if [ ! -f "${HOME}/.local/lib/uvm/uvm-config.sh" ]; then
    echo -e "${YELLOW}uvm is not installed in ${HOME}/.local/lib/uvm${NC}"
    exit 1
fi

# shellcheck source=/dev/null
source "${HOME}/.local/lib/uvm/uvm-config.sh"

shell_rc=$(get_shell_rc_file)
uvm_ensure_shell_hook_configured "$shell_rc"

echo -e "${GREEN}Shell integration repaired in ${shell_rc}${NC}"
echo "Next steps:"
echo "  1. source ${shell_rc}"
echo "  2. uvm doctor"
