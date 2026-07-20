# Guía de Arquitectura

Documentación detallada de la arquitectura de Jenkins en Kubernetes.

---

## Visión General

```
┌──────────────────────────────────────────────────────────────────┐
│                    MINIKUBE KUBERNETES                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         CONTROLADOR DE INGRESS (NGINX)                  │   │
│  │  Rutas: jenkins*.local → Servicios                      │   │
│  └──────────────────┬──────────────────────────────────────┘   │
│                     │                                           │
│     ┌───────────────┼────────────────────┬──────────────────┐   │
│     ▼               ▼                    ▼                  ▼   │
│  ┌─────────┐   ┌──────────┐         ┌─────────┐      ┌────────┐
│  │ Jenkins │   │Prometheus│         │ Grafana │      │ Config │
│  │ :8080   │   │  :9090   │         │ :3000   │      │Servers │
│  │         │   │          │         │         │      │        │
│  │ Pods    │   │ BD de    │         │ Panel   │      │ DNS    │
│  │ PVC     │   │ series   │         │ Acceso  │      │ etc    │
│  │ Config  │   │ tiempo   │         │ Control │      │        │
│  └────┬────┘   └──────────┘         └────┬────┘      └────────┘
│       │                                   │
│       │                    ┌──────────────┘
│       │                    │ Consulta
│       │            ┌───────┴────────┐
│       │            │  Prometheus    │
│       └────────────┤  API :9090     │
│  Scrap de métricas │                │
│  cada 15 segundos  └────────────────┘
│       │
│       ▼
│  ┌─────────────────────────────────────────┐
│  │ API de Kubernetes / Kubelet             │
│  │ • Métricas de nodos                     │
│  │ • Estado de pods                        │
│  │ • Uso de recursos                       │
│  └─────────────────────────────────────────┘
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

        ║ Máquina Host (Laptop/Servidor)
        ║
   ┌────╨──────────────────────────┐
   │   /etc/hosts                  │
   │ 127.0.0.1 jenkins.local       │
   │ 127.0.0.1 grafana.local       │
   │ 127.0.0.1 prometheus.local    │
   └────┬───────────────────────────┘
        │ Solicitudes del navegador
        ▼
   ┌─────────────────────┐
   │   IP de Minikube    │
   │  192.168.49.2:80    │
   └─────────────────────┘
```

---

## Componentes Principales

### 1. Jenkins

**Propósito**: Servidor principal de CI/CD

**Ubicación**: Namespace `jenkins`

**Configuración**:
```yaml
Deployment: jenkins
  Imagen: jenkins/jenkins:2.504-jdk21
  Réplicas: 1
  Puerto: 8080
  
Recursos:
  Solicitudes: 500m CPU, 512Mi RAM
  Límites: 1 CPU, 1Gi RAM

Almacenamiento:
  PVC: jenkins-pvc (5Gi)
  Montaje: /var/jenkins_home

Configuración:
  JCasC: /var/jenkins_home/casc_configs
  Secretos: jenkins-casc-config (ConfigMap)

Seguridad:
  Usuario: jenkins (UID 1000)
  readinessProbe: /login (60s inicial)
  livenessProbe: /login (120s inicial)
```

**Flujo de Datos**:
```
Pod de Jenkins
├── Inicio → Cargar JCasC desde ConfigMap
├── Ejecutando → Aceptar solicitudes via Servicio
└── Almacenamiento → PVC persiste datos
```

### 2. Kustomize

**Propósito**: Gestionar configuración multi-ambiente

**Estructura**:
```
kustomize/
├── base/
│   ├── kustomization.yaml       # Referencia todos los manifests
│   ├── ingress.yaml             # Ingress base
│   ├── jenkins-setup-k8s.yaml   # (enlace) Namespace, SA, PVC, Servicio
│   ├── deployment.yaml          # (enlace) Deployment
│   └── jcasc/configmap.yaml     # (enlace) Configuración JCasC
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
        ├── kustomization.yaml       # Patches para producción
        ├── ingress-patch.yaml       # Hostname: jenkins.local + HTTPS
        └── (patchesJson6902)        # Recursos altos + rate limiting
```

**Proceso de Construcción**:
```
kubectl kustomize kustomize/overlays/dev
    ↓
Leer: kustomize/overlays/dev/kustomization.yaml
    ↓
Resolver bases: ../../base/kustomization.yaml
    ↓
Leer recursos desde base
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
Ruta: /
Backend: jenkins:8080

Anotaciones:
  nginx.ingress.kubernetes.io/proxy-body-size: "0"
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
```

**Variaciones por Ambiente**:
- **dev**: HTTP, sin HTTPS
- **staging**: HTTPS con cert-manager staging
- **prod**: HTTPS con cert-manager producción, rate limiting

**Flujo de Solicitud**:
```
Navegador → jenkins.local:80
    ↓
IP de Minikube:80 (NGINX Ingress)
    ↓
Regla de ruta: host=jenkins.local → servicio:jenkins:8080
    ↓
Servicio de Jenkins (ClusterIP)
    ↓
Pod de Jenkins:8080
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
  crumbIssuer:                # Protección CSRF

unclassified:
  location:                   # URL del servidor
  mailer:                     # Configuración de email
  
credentials:                  # Credenciales
  system:
    domainCredentials: [...]

security:                     # Seguridad general
  apiToken:
  scriptApproval:
```

**Cargar en Jenkins**:
```
Inicio de Jenkins
    ↓
Variable de entorno: CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs
    ↓
Jenkins lee ConfigMap montado
    ↓
Aplica configuración
    ↓
No se puede cambiar via UI (inmutable)
```

### 5. Prometheus

**Propósito**: Recolectar métricas de Jenkins y Kubernetes

**Ubicación**: Namespace `monitoring`

**Configuración**:
```yaml
scrape_configs:
  - job_name: prometheus       # Auto-monitoreo
  - job_name: kubernetes-apiservers
  - job_name: kubernetes-nodes
  - job_name: kubernetes-pods
  - job_name: jenkins          # Métricas de Jenkins

alert_rules:
  - JenkinsPodDown             # Alerta si el pod cae
  - JenkinsHighMemory          # >90% RAM
  - JenkinsHighCPU             # >80% CPU
  - KubernetesNodeNotReady
  - KubernetesPVCFull
```

**Almacenamiento**:
```
emptyDir {}  # Datos temporales (se pierden al reiniciar)
Retención: 30 días de métricas
```

**Scraping**:
```
Pod de Prometheus
    ↓ (cada 15s)
Obtener targets desde:
  • kubernetes-apiservers
  • kubernetes-nodes
  • kubernetes-pods
  • Configuración estática (jenkins)
    ↓
POST /metrics (o ruta personalizada)
    ↓
Analizar métricas (formato Prometheus)
    ↓
Guardar en TSDB
    ↓
Mantener por 30 días
```

### 6. Grafana

**Propósito**: Visualizar métricas en paneles

**Ubicación**: Namespace `monitoring`

**Configuración**:
```yaml
datasources:
  - name: Prometheus
    url: http://prometheus:9090
    type: prometheus

Usuarios:
  admin: admin123 (⚠️ Cambiar después)

Acceso:
  Anónimo: true (viewers)
  Autenticación requerida: false para paneles
```

**Arquitectura**:
```
Pod de Grafana
    ↓
Datasource Prometheus: http://prometheus:9090
    ↓
Consultar métricas (PromQL)
    ↓
Renderizar paneles
    ↓
Acceso via http://grafana.local:3000
```

---

## Flujo de Datos

### Flujo de Setup

```
Usuario ejecuta:
    ./scripts/setup-ingress.sh
        ↓
    1. Verifica minikube y kubectl
    2. Habilita addon ingress en minikube
    3. Agrega hosts a /etc/hosts
    4. Espera que controlador ingress esté listo
    ✓ Listo para desplegar

Usuario ejecuta:
    ./scripts/deploy-env.sh dev
        ↓
    1. Verifica prerequisitos
    2. Ejecuta: kubectl kustomize kustomize/overlays/dev
        ↓
        Genera YAML combinado
    3. Aplica: kubectl apply -k kustomize/overlays/dev
        ↓
        Crea recursos en cluster
        • Namespace jenkins
        • PVC jenkins-pvc
        • ConfigMap jenkins-casc-config
        • Servicio jenkins
        • Deployment jenkins
        • Ingress jenkins
    4. Espera estado de rollout
    5. Muestra URL de acceso
```

### Flujo de Runtime

```
Usuario accede a: http://jenkins-dev.local
    ↓
DNS resuelve a: IP de minikube (192.168.49.2)
    ↓
NGINX Ingress recibe solicitud en puerto 80
    ↓
Busca regla: Host=jenkins-dev.local
    ↓
Ruta a: Servicio jenkins (namespace jenkins)
    ↓
ClusterIP del Servicio (usualmente 10.x.x.x)
    ↓
Selecciona pod con etiqueta: app=jenkins
    ↓
Balanceo de carga (round-robin si hay múltiples)
    ↓
Envía a Pod de Jenkins:8080
    ↓
Jenkins responde con UI
    ↓
Se renderiza en navegador
```

### Flujo de Monitoreo

```
Pod de Prometheus (cada 15s)
    ↓
Ejecuta queries de scrape
    ↓
    ├─ kubernetes-apiservers:6443/metrics
    │   └─ Métricas de API de Kubernetes
    │
    ├─ kubernetes-nodes:kubelet:10250/metrics
    │   └─ Métricas de nodos (CPU, memoria)
    │
    ├─ kubernetes-pods:8080/prometheus
    │   └─ Métricas de Jenkins (builds, ejecutores)
    │
    └─ localhost:9090/metrics
        └─ Auto-monitoreo de Prometheus

    ↓ (Analizar y validar)
    ↓ (Guardar en TSDB)
    ↓ (Mantener 30 días)

Grafana (usuario)
    ↓
Consulta: http://prometheus:9090/api/v1/query
    ↓
PromQL: rate(jenkins_builds_success_total[5m])
    ↓
Prometheus ejecuta consulta
    ↓
Devuelve series temporales
    ↓
Grafana renderiza gráfico
    ↓
Usuario ve panel
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

**Razón**: Mejor balance entre simplicidad y production-like.

### 2. ¿Por qué Kustomize y no Helm?

| Aspecto | Kustomize | Helm |
|---------|-----------|------|
| Curva de aprendizaje | Baja | Media |
| YAML nativo | ✅ | Templates |
| Reusabilidad | Base + Overlays | Charts |
| Gestor de paquetes | No | Sí |
| Producción | Posible | Mejor |
| **Elegimos** | ✅ | - |

**Razón**: Mejor para aprender Kubernetes. Helm disponible como opción posterior.

### 3. ¿Por qué JCasC y no UI manual?

| Aspecto | JCasC | UI Manual |
|---------|-------|-----------|
| Reproducibilidad | ✅ | ❌ |
| Versionable | ✅ | ❌ |
| Colaboración | ✅ | ❌ |
| Automatización | ✅ | ❌ |
| Curva de aprendizaje | Media | Baja |
| **Elegimos** | ✅ | - |

**Razón**: Infrastructure as Code, no reinventar la rueda.

### 4. ¿Por qué Ingress y no solo NodePort?

| Aspecto | Ingress | NodePort |
|---------|---------|----------|
| Profesional | ✅ | ❌ |
| Hostnames | ✅ | ❌ |
| HTTPS | ✅ | Manual |
| Producción | ✅ | ❌ |
| Complejidad | Media | Baja |
| **Elegimos** | ✅ | - |

**Razón**: Production-like, preparación para prod.

---

## Escalabilidad

### Horizontal (Múltiples Pods)

```yaml
# Actual (1 réplica)
spec:
  replicas: 1

# Para escalabilidad
spec:
  replicas: 3

# Con PersistentVolume compartido
# Nota: Jenkins es stateful, requiere:
# - Volumen ReadWriteMany
# - O Jenkins distribuido (master + agentes)
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

### Agentes Distribuidos

```
Pod Master de Jenkins
    │
    ├─ Pod Agente 1 (Plugin de Kubernetes)
    ├─ Pod Agente 2
    ├─ Pod Agente 3
    └─ Agentes externos (JNLP)
```

---

## Rendimiento

### Optimizaciones Implementadas

- **Readiness Probe**: Evita tráfico a pod que no está listo
- **Resource Requests**: Garantiza recursos suficientes
- **Resource Limits**: Previene que consuma todo
- **emptyDir para cache**: Más rápido que PVC

### Cuellos de Botella Potenciales

1. **I/O de PVC**: Jenkins home requiere mucho acceso a disco
   - Solución: Usar clase de almacenamiento SSD
   
2. **Pod Único**: Un pod puede ser cuello de botella
   - Solución: Usar agentes de Jenkins distribuidos

3. **Almacenamiento en Red**: Especialmente en cloud
   - Solución: Usar volúmenes locales con replicación

---

## Alta Disponibilidad (Futuro)

```
┌─────────────────────────────────────────┐
│      Cluster Kubernetes Jenkins         │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Pod Master de Jenkins (1)      │   │
│  └──────────────┬──────────────────┘   │
│                 │                      │
│         ┌───────┼───────┐              │
│         ▼       ▼       ▼              │
│    ┌────────────────────────────┐     │
│    │ Pods Agente (Kubernetes)   │     │
│    │ ├─ Agente de build 1       │     │
│    │ ├─ Agente de build 2       │     │
│    │ └─ Agente de build 3       │     │
│    └────────────────────────────┘     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Almacenamiento Compartido       │   │
│  │ (ReadWriteMany)                 │   │
│  │ ├─ EBS (AWS)                    │   │
│  │ ├─ PD de GCP (Google)           │   │
│  │ └─ NFS (On-premise)             │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

---

## Recuperación ante Desastres

### Estrategia de Respaldo

```
Respaldo Automatizado (futuro)
    ↓
Cada 24h:
    1. Snapshot de PVC
    2. Exportar jenkins_home a S3/GCS
    3. Retener últimos 30 respaldos

Recuperación:
    1. Restaurar PVC desde snapshot
    2. O reconstruir desde código (JCasC)
```

### Objetivo de Tiempo de Recuperación (RTO)

- **Actual**: ~5 minutos (redeployment)
- **Con respaldos**: ~10 minutos (restaurar + verificar)

### Objetivo de Punto de Recuperación (RPO)

- **Actual**: Ninguno (datos persistentes)
- **Con snapshots**: 24 horas máximo

---

## Estrategia de Monitoreo

```
Niveles de Monitoreo:

Nivel 1: Infraestructura (Prometheus)
  ├─ CPU/Memoria/Disco
  ├─ I/O de Red
  └─ Estado de pods

Nivel 2: Aplicación (Métricas de Jenkins)
  ├─ Conteo de builds/tasa de éxito
  ├─ Duración de builds
  ├─ Uso de ejecutores
  └─ Longitud de cola

Nivel 3: Experiencia del Usuario
  ├─ Disponibilidad de UI
  ├─ Tiempo de respuesta
  └─ Tasas de error

Visualización: Grafana
Alertas: Prometheus Alertmanager (futuro)
Logging: Pila ELK (futuro)
```

---

## Optimización de Costos

### Actual (Minikube Local)

- **Infraestructura**: $0 (máquina local)
- **Almacenamiento**: Disco local
- **Red**: Localhost
- **Total**: $0

### Para Producción (Ejemplo EKS)

```
Plano de Control EKS: $0.10/hora = $73/mes
Cómputo (3 nodos t3.medium): $0.0416 * 3 * 730 = ~$91/mes
Almacenamiento (50GB EBS gp3): ~$5/mes
Red: ~$10/mes (variable)
Total: ~$180/mes
```

**Optimizaciones**:
- Usar instancias Spot (-70% costo)
- Instancias Reservadas (-40% costo)
- Auto-scaling (reducir en horas no laborales)
- Dimensionamiento correcto (elegir tamaño adecuado)

---

Este documento se actualiza conforme evoluciona la arquitectura.

**Última actualización**: Julio 2026
