#!/bin/bash
# Troubleshooting script for common EKS and application issues

NAMESPACE="${NAMESPACE:-production-app}"
SERVICE="${SERVICE:-production-app}"

diagnose_pods() {
    echo "=== POD DIAGNOSTICS ==="
    echo "Pods in namespace $NAMESPACE:"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    echo ""
    echo "Pod events:"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp'
    
    echo ""
    echo "Failed pods details:"
    kubectl get pods -n "$NAMESPACE" \
        --field-selector=status.phase!=Running,status.phase!=Succeeded \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | \
        while read pod; do
            echo "Pod: $pod"
            kubectl describe pod "$pod" -n "$NAMESPACE"
            echo "---"
        done
}

diagnose_nodes() {
    echo "=== NODE DIAGNOSTICS ==="
    echo "Node status:"
    kubectl get nodes -o wide
    
    echo ""
    echo "Node details:"
    kubectl describe nodes
    
    echo ""
    echo "Node capacity:"
    kubectl top nodes
}

diagnose_services() {
    echo "=== SERVICE DIAGNOSTICS ==="
    echo "Services:"
    kubectl get svc -n "$NAMESPACE"
    
    echo ""
    echo "Endpoints:"
    kubectl get endpoints -n "$NAMESPACE"
    
    echo ""
    echo "Ingress:"
    kubectl get ingress -n "$NAMESPACE"
}

diagnose_logs() {
    echo "=== APPLICATION LOGS ==="
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" \
        --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $pods; do
        echo "Logs from $pod (last 50 lines):"
        kubectl logs -n "$NAMESPACE" "$pod" --tail=50 --timestamps=true
        echo "---"
    done
}

check_resources() {
    echo "=== RESOURCE USAGE ==="
    echo "Pod resource usage:"
    kubectl top pods -n "$NAMESPACE"
    
    echo ""
    echo "Node resource usage:"
    kubectl top nodes
}

check_hpa() {
    echo "=== HORIZONTAL POD AUTOSCALER ==="
    kubectl get hpa -n "$NAMESPACE" -o wide
    
    echo ""
    echo "HPA details:"
    kubectl describe hpa -n "$NAMESPACE"
}

main() {
    echo "========================================"
    echo "EKS Cluster Troubleshooting Diagnostics"
    echo "========================================"
    echo "Namespace: $NAMESPACE"
    echo "Service: $SERVICE"
    echo "Timestamp: $(date)"
    echo ""
    
    diagnose_pods
    echo ""
    
    diagnose_nodes
    echo ""
    
    diagnose_services
    echo ""
    
    diagnose_logs
    echo ""
    
    check_resources
    echo ""
    
    check_hpa
    
    echo ""
    echo "========================================"
    echo "Diagnostics completed"
    echo "========================================"
}

main
