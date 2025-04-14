#!/bin/bash

set -e

echo "🔧 Uninstalling Fleet CRDs via Helm..."
helm -n cattle-fleet-system uninstall fleet
helm -n cattle-fleet-system uninstall fleet-crd


echo "🔧 Installing Fleet CRDs via Helm..."
helm -n cattle-fleet-system install --create-namespace --wait \
  fleet-crd https://github.com/rancher/fleet/releases/download/v0.12.0/fleet-crd-0.12.0.tgz

echo "🚀 Installing Fleet Controller via Helm..."
helm -n cattle-fleet-system install --create-namespace --wait \
  fleet https://github.com/rancher/fleet/releases/download/v0.12.0/fleet-0.12.0.tgz

# Wait for the fleet controller to be ready
echo "⏳ Waiting for Fleet controller to be ready..."
kubectl rollout status -n cattle-fleet-system deploy/fleet-controller --timeout=120s

echo "📦 Applying Fleet bundle from ./fleet-bundle"
fleet apply dev ./fleet-bundle

echo "✅ Deployment triggered via Fleet. Monitor with: kubectl get bundles -A"