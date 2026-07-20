#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Jenkins Monitoring Setup (Prometheus + Grafana) ===${NC}\n"

# Step 1: Check if kubectl is installed
echo -e "${YELLOW}[1/3] Checking prerequisites...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}\n"

# Step 2: Create monitoring namespace and deploy Prometheus
echo -e "${YELLOW}[2/3] Deploying Prometheus...${NC}"
kubectl apply -f monitoring/namespace.yaml
kubectl apply -f monitoring/prometheus/configmap.yaml
kubectl apply -f monitoring/prometheus/deployment.yaml
echo -e "${GREEN}✓ Prometheus deployed${NC}\n"

# Step 3: Deploy Grafana and setup Ingress
echo -e "${YELLOW}[3/3] Deploying Grafana and Ingress...${NC}"
kubectl apply -f monitoring/grafana/configmap.yaml
kubectl apply -f monitoring/ingress.yaml
echo -e "${GREEN}✓ Grafana and Ingress deployed${NC}\n"

# Wait for deployments
echo -e "${YELLOW}Waiting for monitoring stack to be ready...${NC}"
kubectl rollout status deployment/prometheus -n monitoring --timeout=2m || true
kubectl rollout status deployment/grafana -n monitoring --timeout=2m || true

echo ""
echo -e "${GREEN}✓ Monitoring stack is ready!${NC}\n"

echo -e "${BLUE}=== Access Points ===${NC}\n"
echo -e "Prometheus:"
echo -e "  URL: ${GREEN}http://prometheus.local${NC}"
echo -e "  Port: 9090"
echo ""
echo -e "Grafana:"
echo -e "  URL: ${GREEN}http://grafana.local${NC}"
echo -e "  Port: 3000"
echo -e "  Username: ${YELLOW}admin${NC}"
echo -e "  Password: ${YELLOW}admin123${NC}"
echo ""
echo -e "${BLUE}=== Next Steps ===${NC}\n"
echo "1. Add hosts to /etc/hosts:"
echo -e "   ${YELLOW}echo '\$(minikube ip) prometheus.local grafana.local' | sudo tee -a /etc/hosts${NC}"
echo ""
echo "2. Or run:"
echo -e "   ${YELLOW}./scripts/setup-ingress.sh${NC}"
echo ""
echo "3. Open in browser:"
echo -e "   ${GREEN}http://grafana.local${NC}"
echo ""
echo "4. Login and add Prometheus datasource:"
echo -e "   URL: http://prometheus.monitoring.svc.cluster.local:9090"
echo ""
echo "5. Create dashboards or import from:"
echo -e "   https://grafana.com/grafana/dashboards"
echo -e "   (Search for: Kubernetes, Jenkins, Prometheus)"
