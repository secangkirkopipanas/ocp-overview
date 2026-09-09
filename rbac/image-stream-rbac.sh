#!/bin/bash

set -e

echo "=============================================="
echo " Grant ImageStream Push/Pull Permissions"
echo "=============================================="

for i in {1..10}; do
    USER="user${i}"
    NAMESPACE="workshop${i}"

    echo ""
    echo "Processing ${USER} -> ${NAMESPACE}"

    # Push permission
    oc adm policy add-role-to-user \
        system:image-builder "${USER}" \
        -n "${NAMESPACE}"

    # Pull permission
    oc adm policy add-role-to-user \
        system:image-puller "${USER}" \
        -n "${NAMESPACE}"

    echo "  ✓ Push access granted"
    echo "  ✓ Pull access granted"
done

echo ""
echo "=============================================="
echo " Completed"
echo "=============================================="
