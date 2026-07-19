#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Jenkins on Minikube - Cleanup Script ===${NC}\n"

echo -e "${YELLOW}⚠️  This will delete the entire jenkins namespace and all its resources${NC}"
echo -e "${YELLOW}Data in PersistentVolume will be lost${NC}\n"

read -p "Are you sure? (yes/no): " -r REPLY
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

echo -e "${YELLOW}Deleting jenkins namespace...${NC}"
kubectl delete namespace jenkins --ignore-not-found=true

echo -e "${GREEN}✓ Jenkins namespace and all resources deleted${NC}\n"

read -p "Do you also want to stop Minikube? (yes/no): " -r REPLY
echo
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Stopping Minikube...${NC}"
    minikube stop
    echo -e "${GREEN}✓ Minikube stopped${NC}"
else
    echo -e "${GREEN}Minikube is still running${NC}"
fi

echo ""
echo -e "${GREEN}=== Cleanup Complete ===${NC}"
