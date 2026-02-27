#!/bin/bash
# =============================================================================
# Entrypoint wrapper: injects our pre-start hook, then runs the base entrypoint
# =============================================================================
set -e

# Ensure user-scripts dir exists (base entrypoint expects it)
mkdir -p /root/user-scripts

# Install our pre-start hook (overwrites default example)
cp -f /bundled-pre-start.sh /root/user-scripts/pre-start.sh
chmod +x /root/user-scripts/pre-start.sh

# Run the base image entrypoint
exec bash /runner-scripts/entrypoint.sh
