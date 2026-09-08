#!/bin/bash

# ============================================================
# OpenShift Workshop - Namespace & RBAC Setup
#
# Creates:
#   workshop1  -> user1
#   workshop2  -> user2
#   ...
#   workshop10 -> user10
#
# Permissions:
#   Pods
#   Deployments
#   StatefulSets
#   ReplicaSets
#   DaemonSets
#   Services
#   Routes
#   Ingress
#   CronJobs
#   Secrets
#   ConfigMaps
#   HorizontalPodAutoscalers
#   PodDisruptionBudgets
#   PersistentVolumeClaims
#
# Usage:
#   ./setup-workshop-rbac.sh
#
# Requirements:
#   - oc CLI
#   - Cluster-admin privileges
# ============================================================

set -e

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

USERS=10
ROLE_NAME="workshop-user"

# ------------------------------------------------------------
# Check OpenShift login
# ------------------------------------------------------------

if ! oc whoami >/dev/null 2>&1; then
    echo
    echo "ERROR: You are not logged in to OpenShift."
    echo
    echo "Please login first:"
    echo
    echo "  oc login <API_SERVER>"
    echo
    exit 1
fi

CURRENT_USER=$(oc whoami)

echo
echo "=============================================="
echo " OpenShift Workshop Namespace & RBAC Setup"
echo "=============================================="
echo
echo "Logged in as: $CURRENT_USER"
echo
echo "This script will create:"
echo
echo "  workshop1  -> user1"
echo "  workshop2  -> user2"
echo "  ..."
echo "  workshop10 -> user10"
echo

# ------------------------------------------------------------
# Confirmation
# ------------------------------------------------------------

printf "Continue? [y/N] "
read -r CONFIRM

case "$CONFIRM" in
    y|Y|yes|YES)
        ;;
    *)
        echo "Cancelled."
        exit 0
        ;;
esac

echo

# ------------------------------------------------------------
# Create namespaces and RBAC
# ------------------------------------------------------------

for i in $(seq 1 "$USERS")
do

    USERNAME="user${i}"
    NAMESPACE="workshop${i}"

    echo "=============================================="
    echo "Processing $USERNAME"
    echo "Namespace: $NAMESPACE"
    echo "=============================================="

    # --------------------------------------------------------
    # Create namespace
    # --------------------------------------------------------

    if oc get namespace "$NAMESPACE" >/dev/null 2>&1; then
        echo "Namespace already exists: $NAMESPACE"
    else
        echo "Creating namespace: $NAMESPACE"
        oc create namespace "$NAMESPACE"
    fi

    # --------------------------------------------------------
    # Create Role
    # --------------------------------------------------------

    echo "Creating Role: $ROLE_NAME"

    cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${ROLE_NAME}
  namespace: ${NAMESPACE}
rules:

  # Pods
  - apiGroups: [""]
    resources:
      - pods
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # Services
  - apiGroups: [""]
    resources:
      - services
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # ConfigMaps
  - apiGroups: [""]
    resources:
      - configmaps
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # Secrets
  - apiGroups: [""]
    resources:
      - secrets
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # PersistentVolumeClaims
  - apiGroups: [""]
    resources:
      - persistentvolumeclaims
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # Deployments
  - apiGroups: ["apps"]
    resources:
      - deployments
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # StatefulSets
  - apiGroups: ["apps"]
    resources:
      - statefulsets
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # ReplicaSets
  - apiGroups: ["apps"]
    resources:
      - replicasets
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # DaemonSets
  - apiGroups: ["apps"]
    resources:
      - daemonsets
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # OpenShift Routes
  - apiGroups: ["route.openshift.io"]
    resources:
      - routes
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # Kubernetes Ingress
  - apiGroups: ["networking.k8s.io"]
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # CronJobs
  - apiGroups: ["batch"]
    resources:
      - cronjobs
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # HorizontalPodAutoscaler
  - apiGroups: ["autoscaling"]
    resources:
      - horizontalpodautoscalers
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  # PodDisruptionBudget
  - apiGroups: ["policy"]
    resources:
      - poddisruptionbudgets
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete
EOF

    # --------------------------------------------------------
    # Create RoleBinding
    # --------------------------------------------------------

    echo "Binding $USERNAME to $NAMESPACE"

    cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${USERNAME}
  namespace: ${NAMESPACE}
subjects:
  - kind: User
    name: ${USERNAME}
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: ${ROLE_NAME}
  apiGroup: rbac.authorization.k8s.io
EOF

    echo
    echo "Completed:"
    echo "  User      : $USERNAME"
    echo "  Namespace : $NAMESPACE"
    echo "  Role      : $ROLE_NAME"
    echo

done

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "=============================================="
echo " Setup Completed"
echo "=============================================="
echo

printf "%-15s %-15s %-20s\n" "USER" "NAMESPACE" "ROLE"
printf "%-15s %-15s %-20s\n" "----" "---------" "----"

for i in $(seq 1 "$USERS")
do
    printf "%-15s %-15s %-20s\n" \
        "user${i}" \
        "workshop${i}" \
        "$ROLE_NAME"
done

echo
echo "=============================================="
echo " Verification"
echo "=============================================="
echo

for i in $(seq 1 "$USERS")
do

    USERNAME="user${i}"
    NAMESPACE="workshop${i}"

    echo "[$USERNAME -> $NAMESPACE]"

    oc get rolebinding \
        "$USERNAME" \
        -n "$NAMESPACE" \
        -o jsonpath='{.subjects[0].name} -> {.roleRef.name}' \
        2>/dev/null || echo "RoleBinding not found"

    echo
done

echo
echo "All workshop namespaces and RBAC permissions are ready."
echo
