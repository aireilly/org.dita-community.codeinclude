#!/usr/bin/env bash
# Deploy the config
set -euo pipefail
NS="${1:-kserve}"
for f in config/*.yaml; do
  kubectl apply -n "$NS" -f "$f" --server-side   # apply
done
echo 'done' $HOME
