# Architecture Guide

Documentación detallada de la arquitectura de Jenkins on Kubernetes.

---

## Visión General

```
┌──────────────────────────────────────────────────────────────────┐
│                    MINIKUBE KUBERNETES                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              INGRESS CONTROLLER (NGINX)                 │   │
│  │  Routes: jenkins*.local → Services                      │   │
│  └──────────────────┬──────────────────────────────────────┘   │
│                     │                                           │
│     ┌───────────────┼────────────────────┬──────────────────┐   │
│     ▼               ▼                    ▼                  ▼   │
│  ┌─────────┐   ┌──────────┐         ┌─────────┐      ┌────────┐
│  │ Jenkins │   │Prometheus│         │ Grafana │      │ Config │
│  │ :8080   │   │  :9090   │         │ :3000   │      │ Servers│
│  │         │   │          │         │         │      │        │
│  │ Pods    │   │ Time-     │         │ Dashbd  │      │ DNS    │
│  │ PVC     │   │ series DB │         │ Access  │      │ etc    │
│  │ Config  │   │          │         │ Control │      │        │
│  └────┬────┘   └──────────┘         └────┬────┘      └────────┘
│       │                                   │
│       │                    ┌──────────────┘
│       │                    │ Query
│       │            ┌───────┴────────┐
│       │            │  Prometheus    │
│       └────────────┤  API :9090     │
│  Scrape metrics    │                │
│  15 segundos       └────────────────┘
│       │
│       ▼
│  ┌─────────────────────────────────────────┐
│  │ Kubernetes API / Kubelet                │
│  │ • Métricas de nodos                     │
│  │ • Estado de pods                        │
│  │ • Uso de recursos                       │
│  └─────────────────────────────────────────┘
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

             ║ Host Machine (Laptop/Server)
             ║
        ┌────╨────────────────────────┐
        │   /etc/hosts                │
        │ 127.0.0.1 jenkins.local     │
        │ 127.0.0.1 grafana.local     │
        │ 127.0.0.1 prometheus.local  │
        └────┬───────────────────────┘
             │ Browser requests
             ▼
        ┌─────────────────────┐
        │   Minikube IP       │
        │  192.168.49.2:80    │
        └─────────────────────┘
```

---

## Componentes Principales

### 1. Jenkins

**Propósito**: CI/CD server principal

**Ubicación**: `jenkins` namespace

**Configuración**:
```yaml
Deployment: jenkins
  Image: jenkins/jenkins:2.504-jdk21
  Replicas: 1
  Port: 8080
  
Resources:
  Requests: 500m CPU, 512Mi RAM
  Limits: 1 CPU, 1Gi RAM

Storage:
  PVC: jenkins-pvc (5Gi)
  Mount: /var/jenkins_home

Configuration:
  JCasC: /var/jenkins_home/casc_configs
  Secrets: jenkins-casc-config (ConfigMap)

Security:
  User: jenkins (UID 1000)
  readinessProbe: /login (60s initial)
  livenessProbe: /login (120s initial)
```

**Data Flow**:
```
Jenkins Pod
├── Startup → Load JCasC from ConfigMap
├── Running → Accept requests via Service
└── Storage → PVC persiste datos
```

### 2. Kustomize

**Propósito**: Gestionar configuración multi-ambiente

**Estructura**:
```
kustomize/
├── base/
│   ├── kustomization.yaml       # Referencia todos los manifests
│   ├── ingress.yaml             # Ingress base
│   ├── jenkins-setup-k8s.yaml   # (symlink) Namespace, SA, PVC, Service
│   ├── deployment.yaml          # (symlink) Jenkins Deployment
│   └── jcasc/configmap.yaml     # (symlink) JCasC Config
│
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml       # Patches para dev
    │   ├── ingress-patch.yaml       # Hostname: jenkins-dev.local
    │   └── (patchesJson6902)        # Recursos bajos para dev
    │
    ├── staging/
    │   ├── kustomization.yaml       # Patches para staging
    │   ├── ingress-patch.yaml       # Hostname: jenkins-staging.local
    │   └── (patchesJson6902)        # Recursos medios
    │
    └── prod/
        ├── kustomization.yaml       # Patches para production
        ├── ingress-patch.yaml       # Hostname: jenkins.local + HTTPS
        └── (patchesJson6902)        # Recursos altos + rate limiting
```

**Build Process**:
```
kubectl kustomize kustomize/overlays/dev
    ↓
Leer: kustomize/overlays/dev/kustomization.yaml
    ↓
Resolver bases: ../../base/kustomization.yaml
    ↓
Leer resources desde base
    ↓
Aplicar patchesJson6902 de overlay
    ↓
Generar YAML final combinado
    ↓
Mostrar resultado
```

### 3. Ingress (NGINX)

**Propósito**: Exponer Jenkins y monitoreo via HTTP/HTTPS

**Configuración Base**:
```yaml
Host: jenkins.local
Path: /
Backend: jenkins:8080

Annotations:
  nginx.ingress.kubernetes.io/proxy-body-size: "0"
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
```

**Variaciones por Ambiente**:
- **dev**: HTTP, sin HTTPS
- **staging**: HTTPS con cert-manager staging
- **prod**: HTTPS con cert-manager production, rate limiting

**Request Flow**:
```
Browser → jenkins.local:80
    ↓
Minikube IP:80 (NGINX Ingress)
    ↓
Route rule: host=jenkins.local → service:jenkins:8080
    ↓
Jenkins Service (ClusterIP)
    ↓
Jenkins Pod:8080
```

### 4. JCasC (Jenkins Configuration as Code)

**Propósito**: Configurar Jenkins via YAML

**Ubicación**: `jcasc/configmap.yaml`

**Estructura**:
```yaml
jenkins:
  systemMessage: "..."        # Mensaje del sistema
  securityRealm:              # Autenticación
  authorizationStrategy:      # Autorización
  crumbIssuer:                # CSRF protection

unclassified:
  location:                   # URL del servidor
  mailer:                     # Email config
  
credentials:                  # Credenciales
  system:
    domainCredentials: [...]

security:                     # Seguridad general
  apiToken:
  scriptApproval:
```

**Cargar en Jenkins**:
```
Jenkins startup
    ↓
Env var: CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs
    ↓
Jenkins lee ConfigMap montado
    ↓
Aplica configuración
    ↓
No se puede cambiar via UI (inmutable)
```

### 5. Prometheus

**Propósito**: Recolectar métricas de Jenkins y Kubernetes

**Ubicación**: `monitoring` namespace

**Configuración**:
```yaml
scrape_configs:
  - job_name: prometheus       # Auto-monitoring
  - job_name: kubernetes-apiservers
  - job_name: kubernetes-nodes
  - job_name: kubernetes-pods
  - job_name: jenkins          # Jenkins metrics

alert_rules:
  - JenkinsPodDown             # Alerta si pod cae
  - JenkinsHighMemory          # >90% RAM
  - JenkinsHighCPU             # >80% CPU
  - KubernetesNodeNotReady
  - KubernetesPVCFull
```

**Storage**:
```
emptyDir {}  # Datos temporales (se pierden al reiniciar)
Retention: 30 días de métricas
```

**Scraping**:
```
Prometheus Pod
    ↓ (cada 15s)
Obtener targets desde:
  • kubernetes-apiservers
  • kubernetes-nodes
  • kubernetes-pods
  • Static config (jenkins)
    ↓
POST /metrics (o custom path)
    ↓
Parse métricas (formato Prometheus)
    ↓
Guardar en TSDB
    ↓
Mantener por 30 días
```

### 6. Grafana

**Propósito**: Visualizar métricas en dashboards

**Ubicación**: `monitoring` namespace

**Configuración**:
```yaml
datasources:
  - name: Prometheus
    url: http://prometheus:9090
    type: prometheus

Users:
  admin: admin123 (⚠️ Cambiar después)

Access:
  Anonymous: true (viewers)
  Required auth: false para dashboards
```

**Architecture**:
```
Grafana Pod
    ↓
Datasource Prometheus: http://prometheus:9090
    ↓
Query metrics (PromQL)
    ↓
Render dashboards
    ↓
Access via http://grafana.local:3000
```

---

## Flujo de Datos

### Setup Flow

```
Usuario ejecuta:
    ./scripts/setup-ingress.sh
        ↓
    1. Verifica minikube y kubectl
    2. Habilita addon ingress en minikube
    3. Agrega hosts a /etc/hosts
    4. Espera ingress controller ready
    ✓ Listo para desplegar

Usuario ejecuta:
    ./scripts/deploy-env.sh dev
        ↓
    1. Verifica prerequisites
    2. Ejecuta: kubectl kustomize kustomize/overlays/dev
        ↓
        Genera YAML combinado
    3. Aplica: kubectl apply -k kustomize/overlays/dev
        ↓
        Crea recursos en cluster
        • Namespace jenkins
        • PVC jenkins-pvc
        • ConfigMap jenkins-casc-config
        • Service jenkins
        • Deployment jenkins
        • Ingress jenkins
    4. Espera rollout status
    5. Muestra URL de acceso
```

### Runtime Flow

```
User accede a: http://jenkins-dev.local
    ↓
DNS resuelve a: minikube IP (192.168.49.2)
    ↓
NGINX Ingress recibe request en puerto 80
    ↓
Busca regla: Host=jenkins-dev.local
    ↓
Ruta a: Service jenkins (jenkins namespace)
    ↓
ClusterIP del Service (usualmente 10.x.x.x)
    ↓
Selecciona pod con label: app=jenkins
    ↓
Balanceo de carga (round-robin si hay múltiples)
    ↓
Envía a Jenkins Pod:8080
    ↓
Jenkins responde con UI
    ↓
Renderiza en navegador
```

### Monitoring Flow

```
Prometheus Pod (cada 15s)
    ↓
Ejecuta queries de scrape
    ↓
    ├─ kubernetes-apiservers:6443/metrics
    │   └─ Kubernetes API metrics
    │
    ├─ kubernetes-nodes:kubelet:10250/metrics
    │   └─ Node metrics (CPU, memory)
    │
    ├─ kubernetes-pods:8080/prometheus
    │   └─ Jenkins metrics (builds, executors)
    │
    └─ localhost:9090/metrics
        └─ Prometheus self-monitoring

    ↓ (Parse y valida)
    ↓ (Guarda en TSDB)
    ↓ (Mantiene 30 días)

Grafana (usuario)
    ↓
Query: http://prometheus:9090/api/v1/query
    ↓
PromQL: rate(jenkins_builds_success_total[5m])
    ↓
Prometheus ejecuta query
    ↓
Devuelve series temporales
    ↓
Grafana renderiza gráfico
    ↓
Usuario ve dashboard
```

---

## Decisiones de Arquitectura

### 1. ¿Por qué Minikube y no K3s?

| Aspecto | Minikube | K3s |
|---------|----------|-----|
| Setup | 1 comando | 1 comando |
| Recurso | ~2GB | ~512MB |
| Complejidad | Simple | Simple |
| Production-like | Bueno | Mejor |
| Desarrollo | Excelente | Bueno |
| **Elegimos** | ✅ | - |

**Razón**: Mejor balance entre simplicidad y producción-like.

### 2. ¿Por qué Kustomize y no Helm?

| Aspecto | Kustomize | Helm |
|---------|-----------|------|
| Curva aprendizaje | Baja | Media |
| YAML nativo | ✅ | Templates |
| Reusabilidad | Base + Overlays | Charts |
| Package manager | No | Sí |
| Production | Posible | Mejor |
| **Elegimos** | ✅ | - |

**Razón**: Mejor para aprender Kubernetes. Helm disponible como opción later.

### 3. ¿Por qué JCasC y no UI manual?

| Aspecto | JCasC | UI Manual |
|---------|-------|-----------|
| Reproducibilidad | ✅ | ❌ |
| Versionable | ✅ | ❌ |
| Colaboración | ✅ | ❌ |
| Automatización | ✅ | ❌ |
| Curva aprendizaje | Media | Baja |
| **Elegimos** | ✅ | - |

**Razón**: Infrastructure as Code, no reinventar la rueda.

### 4. ¿Por qué Ingress y no solo NodePort?

| Aspecto | Ingress | NodePort |
|---------|---------|----------|
| Profesional | ✅ | ❌ |
| Hostnames | ✅ | ❌ |
| HTTPS | ✅ | Manua |
| Producción | ✅ | ❌ |
| Complejidad | Media | Baja |
| **Elegimos** | ✅ | - |

**Razón**: Production-like, preparación para prod.

---

## Escalabilidad

### Horizontal (Múltiples Pods)

```yaml
# Actual (1 replica)
spec:
  replicas: 1

# Para escalabilidad
spec:
  replicas: 3

# Con PersistentVolume compartido
# Nota: Jenkins es stateful, requiere:
# - ReadWriteMany volume
# - O Jenkins distributed (master + agents)
```

### Vertical (Más recursos)

```yaml
# En kustomize/overlays/prod/kustomization.yaml
- op: replace
  path: /spec/template/spec/containers/0/resources/limits/cpu
  value: "4"
- op: replace
  path: /spec/template/spec/containers/0/resources/limits/memory
  value: "4Gi"
```

### Agents Distribuidos

```
Jenkins Master Pod
    │
    ├─ Agent 1 Pod (Kubernetes agent plugin)
    ├─ Agent 2 Pod
    ├─ Agent 3 Pod
    └─ External agents (JNLP)
```

---

## Performance

### Optimizaciones Implementadas

- **Readiness Probe**: Evita tráfico a pod que no está listo
- **Resource Requests**: Garantiza recursos suficientes
- **Resource Limits**: Previene que consume todo
- **emptyDir para cache**: Más rápido que PVC

### Bottlenecks Potenciales

1. **PVC I/O**: Jenkins home es disk-intensive
   - Solución: Usar SSD storage class
   
2. **Single Pod**: Un pod puede ser bottleneck
   - Solución: Usar Jenkins agents distribuidos

3. **Storage Network**: Especialmente en cloud
   - Solución: Usar local volumes con replicación

---

## High Availability (Future)

```
┌─────────────────────────────────────────┐
│      Jenkins Kubernetes Cluster         │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │     Jenkins Master Pod (1)      │   │
│  └──────────────┬──────────────────┘   │
│                 │                      │
│         ┌───────┼───────┐              │
│         ▼       ▼       ▼              │
│    ┌────────────────────────────┐     │
│    │ Agent Pods (Kubernetes)    │     │
│    │ ├─ Build agent 1           │     │
│    │ ├─ Build agent 2           │     │
│    │ └─ Build agent 3           │     │
│    └────────────────────────────┘     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Shared Storage (ReadWriteMany)  │   │
│  │ ├─ EBS (AWS)                    │   │
│  │ ├─ GCP PD (Google)              │   │
│  │ └─ NFS (On-premise)             │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

---

## Disaster Recovery

### Backup Strategy

```
Automated Backup (futuro)
    ↓
Cada 24h:
    1. Snapshot de PVC
    2. Exportar jenkins_home a S3/GCS
    3. Retener últimas 30 backups

Recovery:
    1. Restore PVC desde snapshot
    2. O rebuild desde código (JCasC)
```

### Recovery Time Objective (RTO)

- **Actual**: ~5 minutos (redeploy)
- **Con backups**: ~10 minutos (restore + verify)

### Recovery Point Objective (RPO)

- **Actual**: Ninguno (datos persistentes)
- **Con snapshots**: 24 horas máximo

---

## Monitoring Strategy

```
Levels of Monitoring:

Level 1: Infrastructure (Prometheus)
  ├─ CPU/Memory/Disk
  ├─ Network I/O
  └─ Pod status

Level 2: Application (Jenkins metrics)
  ├─ Build count/success rate
  ├─ Build duration
  ├─ Executor usage
  └─ Queue length

Level 3: User Experience
  ├─ UI availability
  ├─ Response time
  └─ Error rates

Visualization: Grafana
Alerting: Prometheus Alertmanager (futuro)
Logging: ELK Stack (futuro)
```

---

## Cost Optimization

### Current (Minikube Local)

- **Infrastructure**: $0 (local machine)
- **Storage**: Local disk
- **Network**: Localhost
- **Total**: $0

### For Production (EKS Example)

```
EKS Control Plane: $0.10/hour = $73/month
Compute (3 nodes t3.medium): $0.0416 * 3 * 730 = ~$91/month
Storage (50GB EBS gp3): ~$5/month
Network: ~$10/month (variable)
Total: ~$180/month
```

**Optimizaciones**:
- Usar Spot instances (-70% cost)
- Reserved instances (-40% cost)
- Auto-scaling (scale-down en off-hours)
- Right-sizing (elegir tamaño correcto)

---

Este documento se actualiza conforme evoluciona la arquitectura.

**Última actualización**: Julio 2026
