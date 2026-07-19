#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Jenkins Ingress Setup ===${NC}\n"

# Step 1: Check if minikube is running
echo -e "${YELLOW}[1/3] Checking if Minikube is running...${NC}"
if ! minikube status &> /dev/null; then
    echo -e "${RED}❌ Minikube is not running${NC}"
    echo "Run: minikube start"
    exit 1
fi
echo -e "${GREEN}✓ Minikube is running${NC}\n"

# Step 2: Enable ingress addon in minikube
echo -e "${YELLOW}[2/3] Enabling ingress addon in Minikube...${NC}"
if minikube addons list | grep -q "ingress\s*: enabled"; then
    echo -e "${GREEN}✓ Ingress addon already enabled${NC}"
else
    echo "Enabling ingress addon..."
    minikube addons enable ingress
    echo -e "${GREEN}✓ Ingress addon enabled${NC}"
    echo -e "${YELLOW}Waiting for ingress controller to be ready (30 seconds)...${NC}"
    sleep 30
fi

echo ""

# Step 3: Configure /etc/hosts
echo -e "${YELLOW}[3/3] Configuring /etc/hosts for Jenkins hostnames...${NC}"

MINIKUBE_IP=$(minikube ip)
HOSTS_FILE="/etc/hosts"

# Check if running on macOS or Linux
OS_TYPE=$(uname)

# Entries to add
HOSTS_ENTRIES=(
    "jenkins-dev.local"
    "jenkins-staging.local"
    "jenkins.local"
)

# Add entries to /etc/hosts
for HOSTNAME in "${HOSTS_ENTRIES[@]}"; do
    # Check if entry already exists
    if grep -q "$MINIKUBE_IP.*$HOSTNAME" "$HOSTS_FILE"; then
        echo -e "${GREEN}✓ $HOSTNAME already in $HOSTS_FILE${NC}"
    else
        echo -e "${YELLOW}Adding $HOSTNAME to $HOSTS_FILE...${NC}"
        echo "$MINIKUBE_IP $HOSTNAME" | sudo tee -a "$HOSTS_FILE" > /dev/null
        echo -e "${GREEN}✓ Added $HOSTNAME${NC}"
    fi
done

echo ""
echo -e "${GREEN}✓ Ingress setup complete!${NC}\n"

echo -e "${BLUE}=== Next Steps ===${NC}\n"
echo "Deploy Jenkins with:"
echo -e "  ${YELLOW}./scripts/deploy-env.sh dev${NC}"
echo ""
echo "Then access Jenkins at:"
echo -e "  ${GREEN}http://jenkins-dev.local${NC}"
echo -e "  ${GREEN}http://jenkins-staging.local${NC}"
echo -e "  ${GREEN}http://jenkins.local${NC}"
echo ""
echo "Note: These hostnames resolve to Minikube IP: $MINIKUBE_IP"
echo ""
echo "To check ingress status:"
echo -e "  ${YELLOW}kubectl get ingress -n jenkins${NC}"
echo -e "  ${YELLOW}kubectl describe ingress jenkins -n jenkins${NC}"
