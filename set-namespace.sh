```bash
#!/bin/bash

# ============================================================
# OpenShift Workshop Namespace Selector
#
# Usage:
#   ./set-namespace.sh user1
#   ./set-namespace.sh user10
#
# Mapping:
#   user1  -> workshop1
#   user2  -> workshop2
#   ...
#   user10 -> workshop10
# ============================================================

set -e

# ------------------------------------------------------------
# Check input
# ------------------------------------------------------------

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <username>"
    echo
    echo "Valid usernames:"
    echo "  user1"
    echo "  user2"
    echo "  ..."
    echo "  user10"
    exit 1
fi

USERNAME="$1"

# ------------------------------------------------------------
# Validate username
# ------------------------------------------------------------

if [[ ! "$USERNAME" =~ ^user([1-9]|10)$ ]]; then
    echo "ERROR: Invalid username '$USERNAME'"
    echo
    echo "Valid usernames are user1 through user10."
    exit 1
fi

USER_NUMBER="${USERNAME#user}"
TARGET_NAMESPACE="workshop${USER_NUMBER}"

echo
echo "======================================"
echo " OpenShift Workshop"
echo "======================================"
echo " Username  : $USERNAME"
echo " Namespace : $TARGET_NAMESPACE"
echo "======================================"
echo

# ------------------------------------------------------------
# Manifest directory
# ------------------------------------------------------------

MANIFEST_DIR="./basic"

if [ ! -d "$MANIFEST_DIR" ]; then
    echo "ERROR: Directory '$MANIFEST_DIR' does not exist."
    exit 1
fi

# ------------------------------------------------------------
# Confirmation
# ------------------------------------------------------------

read -r -p "Change namespace to '$TARGET_NAMESPACE'? [y/N] " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo
echo "Updating manifests..."
echo

# ------------------------------------------------------------
# Find and update YAML files
#
# macOS uses BSD sed, so:
#
#   sed -i '' ...
#
# is used instead of GNU/Linux:
#
#   sed -i ...
# ------------------------------------------------------------

find "$MANIFEST_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0 |
while IFS= read -r -d '' FILE; do

    # Check whether the file contains a workshop namespace
    if grep -Eq '^[[:space:]]*namespace:[[:space:]]*workshop([0-9]+)?[[:space:]]*$' "$FILE"; then

        echo "Updating: $FILE"

        sed -i '' -E \
            "s/^([[:space:]]*namespace:[[:space:]]*)workshop([0-9]+)?([[:space:]]*)$/\1${TARGET_NAMESPACE}\3/g" \
            "$FILE"

    fi

done

echo
echo "======================================"
echo " Namespace update completed"
echo "======================================"
echo

# ------------------------------------------------------------
# Show resulting namespaces
# ------------------------------------------------------------

echo "Namespaces currently found:"
echo

grep -RhnE \
    --include="*.yaml" \
    --include="*.yml" \
    '^[[:space:]]*namespace:[[:space:]]*workshop([0-9]+)?[[:space:]]*$' \
    "$MANIFEST_DIR" 2>/dev/null || echo "No workshop namespaces found."

echo
echo "Done."
```
