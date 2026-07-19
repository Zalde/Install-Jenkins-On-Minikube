#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default environment
ENVIRONMENT="${1:-dev}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: ./scripts/deploy-env.sh [dev|staging|prod]"
    exit 1
fi

echo -e "${BLUE}=== Jenkins Deployment with Kustomize ===${NC}\n"
echo -e "${YELLOW}Environment: ${GREEN}$ENVIRONMENT${NC}\n"

# Step 1: Check if minikube is installed
echo -e "${YELLOW}[1/4] Checking prerequisites...${NC}"
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}❌ minikube is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

if ! command -v kustomize &> /dev/null; then
    echo -e "${RED}❌ kustomize is not installed${NC}"
    echo "Install from: https://kubectl.docs.kubernetes.io/installation/kustomize/"
    exit 1
fi

echo -e "${GREEN}✓ All tools found${NC}\n"

# Step 2: Start minikube
echo -e "${YELLOW}[2/4] Starting Minikube...${NC}"
if ! minikube status &> /dev/null; then
    echo -e "Starting minikube cluster..."
    minikube start --cpus 2 --memory 2048
    echo -e "${GREEN}✓ Minikube started${NC}"
else
    echo -e "${GREEN}✓ Minikube already running${NC}"
fi

echo ""

# Step 3: Build and apply with kustomize
echo -e "${YELLOW}[3/4] Building and applying kustomize configuration...${NC}"
echo -e "Applying: ${GREEN}kustomize/overlays/$ENVIRONMENT${NC}\n"

kubectl apply -k "kustomize/overlays/$ENVIRONMENT"

echo -e "${GREEN}✓ Configuration applied${NC}\n"

# Step 4: Wait for pod to be running
echo -e "${YELLOW}[4/4] Waiting for Jenkins pod to be Running...${NC}"
echo -e "${YELLOW}⏳ This may take 1-2 minutes...${NC}\n"

kubectl rollout status deployment/jenkins -n jenkins --timeout=5m

echo ""
echo -e "${GREEN}✓ Jenkins pod is Running and Ready${NC}\n"

# Get minikube IP
MINIKUBE_IP=$(minikube ip)
echo -e "${BLUE}=== Deployment Complete ===${NC}\n"
echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
echo -e "Jenkins URL: ${GREEN}http://${MINIKUBE_IP}:32000${NC}"
echo -e "To get the admin password, run:"
echo -e "  ${YELLOW}./scripts/get-admin-password.sh${NC}"
echo ""
echo -e "Useful commands:"
echo -e "  View logs:     ${YELLOW}kubectl logs -f -n jenkins -l app=jenkins${NC}"
echo -e "  Check status:  ${YELLOW}kubectl get pods -n jenkins${NC}"
echo -e "  Preview YAML:  ${YELLOW}kubectl kustomize kustomize/overlays/$ENVIRONMENT${NC}"
echo -e "  Cleanup all:   ${YELLOW}./scripts/cleanup.sh${NC}"
