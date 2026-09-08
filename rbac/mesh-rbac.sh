#!/bin/bash

set -e

for i in {1..10}; do
  USER="user${i}"
  NAMESPACE="workshop${i}"

  echo "=========================================="
  echo "Configuring ${USER} -> ${NAMESPACE}"
  echo "=========================================="

  oc create role service-mesh-resources-editor \
    --verb=get,list,watch,create,update,patch,delete \
    \
    --resource=servicemonitors.monitoring.coreos.com \
    --resource=podmonitors.monitoring.coreos.com \
    \
    --resource=peerauthentications.security.istio.io \
    --resource=destinationrules.networking.istio.io \
    --resource=virtualservices.networking.istio.io \
    --resource=envoyfilters.networking.istio.io \
    \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | oc apply -f -

  oc create rolebinding "${USER}-service-mesh-resources-editor" \
    --role=service-mesh-resources-editor \
    --user="${USER}" \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | oc apply -f -

  echo "✓ ${USER} configured for ${NAMESPACE}"
  echo
done

echo "=========================================="
echo "All users configured successfully!"
echo "=========================================="