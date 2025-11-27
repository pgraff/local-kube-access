#!/bin/bash
# Script to stop all cluster service port-forwards
# This is a convenience wrapper for: ./access-all.sh stop
#
# NOTE: If you're using URL-based access (Ingress), you don't need this script.
# This is only needed if you're using port-forwarding for TCP services or fallback access.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/access-all.sh" stop

