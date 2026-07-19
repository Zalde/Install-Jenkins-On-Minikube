#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Jenkins on Minikube - Setup Script ===${NC}\n"

# Step 1: Check if minikube is installed
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}❌ minikube is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ minikube and kubectl found${NC}\n"

# Step 2: Start minikube
echo -e "${YELLOW}[2/6] Starting Minikube...${NC}"
if ! minikube status &> /dev/null; then
    echo -e "Starting minikube cluster..."
    minikube start --cpus 2 --memory 2048
    echo -e "${GREEN}✓ Minikube started${NC}"
else
    echo -e "${GREEN}✓ Minikube already running${NC}"
fi

echo ""

# Step 3: Apply setup YAML (Namespace, ServiceAccount, PVC, Service)
echo -e "${YELLOW}[3/6] Creating Namespace, ServiceAccount, PVC and Service...${NC}"
kubectl apply -f jenkins-setup-k8s.yaml
echo -e "${GREEN}✓ Setup resources created${NC}\n"

# Step 4: Wait for PVC to be Bound
echo -e "${YELLOW}[4/6] Waiting for PVC to be Bound...${NC}"
for i in {1..30}; do
    PVC_STATUS=$(kubectl get pvc -n jenkins -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    if [ "$PVC_STATUS" = "Bound" ]; then
        echo -e "${GREEN}✓ PVC is Bound${NC}\n"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

if [ "$PVC_STATUS" != "Bound" ]; then
    echo -e "${RED}❌ PVC failed to bind${NC}"
    exit 1
fi

# Step 5: Apply Deployment
echo -e "${YELLOW}[5/6] Creating Jenkins Deployment...${NC}"
kubectl apply -f deployment.yaml
echo -e "${GREEN}✓ Deployment created${NC}\n"

# Step 6: Wait for pod to be running
echo -e "${YELLOW}[6/6] Waiting for Jenkins pod to be Running...${NC}"
echo -e "${YELLOW}⏳ This may take 1-2 minutes...${NC}\n"

kubectl rollout status deployment/jenkins -n jenkins --timeout=5m

echo ""
echo -e "${GREEN}✓ Jenkins pod is Running and Ready${NC}\n"

# Get minikube IP
MINIKUBE_IP=$(minikube ip)
echo -e "${BLUE}=== Setup Complete ===${NC}\n"
echo -e "Jenkins URL: ${GREEN}http://${MINIKUBE_IP}:32000${NC}"
echo -e "To get the admin password, run:"
echo -e "  ${YELLOW}./scripts/get-admin-password.sh${NC}"
echo ""
echo -e "Useful commands:"
echo -e "  View logs:     ${YELLOW}kubectl logs -f -n jenkins -l app=jenkins${NC}"
echo -e "  Check status:  ${YELLOW}kubectl get pods -n jenkins${NC}"
echo -e "  Cleanup all:   ${YELLOW}./scripts/cleanup.sh${NC}"
