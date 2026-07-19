#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Jenkins Admin Password ===${NC}\n"

# Get pod name
POD_NAME=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}❌ No Jenkins pod found in jenkins namespace${NC}"
    echo "Make sure Jenkins is deployed. Run: ./scripts/setup.sh"
    exit 1
fi

echo -e "${YELLOW}Getting password from pod: ${GREEN}${POD_NAME}${NC}\n"

# Extract password from logs
PASSWORD=$(kubectl logs "$POD_NAME" -n jenkins 2>/dev/null | grep -A 5 "Jenkins initial setup is required" | grep -oP '(?<=\n\s{2})\w+(?=\n)' | head -1)

if [ -z "$PASSWORD" ]; then
    echo -e "${YELLOW}Password not found in logs yet (Jenkins may still be initializing)${NC}"
    echo -e "${YELLOW}Watching logs... (Ctrl+C to exit)${NC}\n"
    kubectl logs -f "$POD_NAME" -n jenkins 2>/dev/null | grep -A 5 "Jenkins initial setup is required" &
    GREP_PID=$!
    sleep 10
    kill $GREP_PID 2>/dev/null || true
    exit 0
fi

echo -e "${GREEN}✓ Admin Password found:${NC}\n"
echo -e "${BLUE}Username: admin${NC}"
echo -e "${BLUE}Password: ${GREEN}${PASSWORD}${NC}\n"

# Get minikube IP and Jenkins URL
MINIKUBE_IP=$(minikube ip)
echo -e "${YELLOW}Jenkins URL: ${GREEN}http://${MINIKUBE_IP}:32000${NC}\n"
