#!/bin/bash
# Script to stop all cluster service port-forwards
# This is a convenience wrapper for: ./access-all.sh stop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/access-all.sh" stop

