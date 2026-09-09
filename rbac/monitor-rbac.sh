echo
echo "=========================================="
echo "Verifying permissions"
echo "=========================================="

for i in {1..10}; do
  USER="user${i}"
  NAMESPACE="workshop${i}"

  SM=$(oc auth can-i create servicemonitors.monitoring.coreos.com \
    --as="${USER}" -n "${NAMESPACE}")

  PM=$(oc auth can-i create podmonitors.monitoring.coreos.com \
    --as="${USER}" -n "${NAMESPACE}")

  echo "${USER} -> ${NAMESPACE}: ServiceMonitor=${SM}, PodMonitor=${PM}"
done