#!/bin/bash
# Load Test Script for LoadTest API on EKS
# This script generates traffic to trigger HPA auto-scaling
#
# Usage:
#   ./scripts/load-test.sh <EXTERNAL_IP> [PERCENT] [REQUESTS] [CONCURRENCY]
#
# Example:
#   ./scripts/load-test.sh a1b2c3.elb.amazonaws.com 70 100 10

set -euo pipefail

EXTERNAL_IP="${1:?Usage: $0 <EXTERNAL_IP> [PERCENT] [REQUESTS] [CONCURRENCY]}"
PERCENT="${2:-50}"
REQUESTS="${3:-50}"
CONCURRENCY="${4:-5}"

API_URL="http://${EXTERNAL_IP}/${PERCENT}"
HEALTH_URL="http://${EXTERNAL_IP}/health"

echo "============================================"
echo "  LoadTest API - Auto-Scaling Demo"
echo "============================================"
echo ""
echo "Target:       ${API_URL}"
echo "CPU Target:   ${PERCENT}%"
echo "Requests:     ${REQUESTS}"
echo "Concurrency:  ${CONCURRENCY}"
echo ""

# Check health first
echo "[1/4] Checking API health..."
HEALTH=$(curl -s "${HEALTH_URL}")
echo "  Health: ${HEALTH}"
echo ""

# Show current HPA state
echo "[2/4] Current HPA state:"
kubectl get hpa loadtest-api-hpa 2>/dev/null || echo "  (kubectl not configured or HPA not found)"
echo ""

# Run load test
echo "[3/4] Starting load test..."
echo "  Sending ${REQUESTS} requests with concurrency ${CONCURRENCY}..."
echo ""

for i in $(seq 1 "${REQUESTS}"); do
    curl -s "${API_URL}" > /dev/null &
    
    # Control concurrency
    if (( i % CONCURRENCY == 0 )); then
        wait
        echo "  Completed ${i}/${REQUESTS} requests..."
    fi
done
wait

echo ""
echo "  All ${REQUESTS} requests completed!"
echo ""

# Show HPA state after load
echo "[4/4] HPA state after load test:"
sleep 5
kubectl get hpa loadtest-api-hpa 2>/dev/null || echo "  (kubectl not configured)"
echo ""
echo "Monitor scaling with:"
echo "  watch kubectl get hpa,pods -l app=loadtest-api"
echo ""
echo "============================================"
echo "  Load test complete!"
echo "============================================"
