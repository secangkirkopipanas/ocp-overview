#!/bin/bash

# Fixed OpenShift cluster URL
OCP_SERVER="https://api.cluster-thslr.thslr.sandbox3529.opentlc.com:6443"

# Check parameters
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    echo
    echo "Example:"
    echo "  $0 user1 'mypassword'"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"

echo "Logging in to OpenShift..."
echo "Cluster: $OCP_SERVER"
echo "User:    $USERNAME"
echo

oc login "$OCP_SERVER" \
    -u "$USERNAME" \
    -p "$PASSWORD"

if [ $? -eq 0 ]; then
    echo
    echo "======================================"
    echo "OpenShift login successful!"
    echo "======================================"
    echo
    oc whoami
    echo
    oc project
else
    echo
    echo "======================================"
    echo "OpenShift login failed!"
    echo "======================================"
    exit 1
fi
