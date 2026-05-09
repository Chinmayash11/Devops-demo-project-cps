#!/bin/bash
# Health check script for the application
# Verifies application health and returns appropriate exit codes

set -e

NAMESPACE="${NAMESPACE:-production-app}"
SERVICE="${SERVICE:-production-app}"
PORT="${PORT:-5000}"
TIMEOUT="${TIMEOUT:-5}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pod_health() {
    local pod_name="$1"
    
    echo -n "Checking pod $pod_name... "
    
    local response=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- \
        curl -s -w "\n%{http_code}" http://localhost:$PORT/health --max-time $TIMEOUT 2>/dev/null || echo -e "\n503")
    
    local status_code=$(echo "$response" | tail -1)
    
    if [ "$status_code" == "200" ]; then
        echo -e "${GREEN}✓ Healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ Unhealthy (HTTP $status_code)${NC}"
        return 1
    fi
}

check_deployment_health() {
    echo "Checking deployment health..."
    
    local deployment_status=$(kubectl rollout status deployment/"$SERVICE" -n "$NAMESPACE" --timeout="${TIMEOUT}s" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Deployment is healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ Deployment is not healthy${NC}"
        echo "$deployment_status"
        return 1
    fi
}

check_pod_readiness() {
    echo "Checking pod readiness..."
    
    local ready_pods=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" \
        --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$ready_pods" ]; then
        echo -e "${RED}✗ No running pods found${NC}"
        return 1
    fi
    
    local all_healthy=true
    for pod in $ready_pods; do
        check_pod_health "$pod" || all_healthy=false
    done
    
    return $([ "$all_healthy" = true ] && echo 0 || echo 1)
}

check_service_endpoints() {
    echo "Checking service endpoints..."
    
    local endpoints=$(kubectl get endpoints "$SERVICE" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}')
    
    if [ -z "$endpoints" ]; then
        echo -e "${RED}✗ No service endpoints found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Service has $( echo $endpoints | wc -w) endpoints${NC}"
    return 0
}

main() {
    echo "================================"
    echo "Application Health Check"
    echo "Namespace: $NAMESPACE"
    echo "Service: $SERVICE"
    echo "================================"
    echo ""
    
    local exit_code=0
    
    check_deployment_health || exit_code=$?
    echo ""
    
    check_service_endpoints || exit_code=$?
    echo ""
    
    check_pod_readiness || exit_code=$?
    echo ""
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}All health checks passed!${NC}"
    else
        echo -e "${RED}Some health checks failed${NC}"
    fi
    
    return $exit_code
}

main "$@"
