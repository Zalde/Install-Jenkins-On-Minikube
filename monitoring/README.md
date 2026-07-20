# Monitoreo - Prometheus + Grafana

Esta carpeta contiene configuración para monitorear Jenkins y Kubernetes con **Prometheus** (recolección de métricas) y **Grafana** (visualización).

## ¿Qué es Prometheus y Grafana?

### Prometheus
- 📊 **Time-series database**: Base de datos especializada en métricas temporales
- 🔍 **Scraping**: Recolecta métricas de targets automáticamente
- 🚨 **Alerting**: Genera alertas basadas en reglas
- 📈 **PromQL**: Lenguaje para consultas de métricas

### Grafana
- 📉 **Visualización**: Dashboards hermosos e interactivos
- 📊 **Multi-source**: Soporta Prometheus, InfluxDB, Elasticsearch, etc.
- 🔔 **Alertas**: Integración con Prometheus para alertas
- 🎨 **Templating**: Dashboards dinámicos con variables

## Arquitectura

```
┌────────────────────────────────────────────┐
│           Kubernetes Cluster               │
├────────────────────────────────────────────┤
│                                            │
│  ┌─────────────────┐   ┌────────────────┐  │
│  │   Jenkins Pod   │   │ Prometheus Pod │  │
│  │  :8080          │   │  :9090         │  │
│  │                 │   │                │  │
│  │ /prometheus ◄───┼───┤ /metrics       │  │
│  └─────────────────┘   └────────────────┘  │
│                             ▲               │
│                    ┌────────┴──────────┐   │
│                    │ Scrape 15s        │   │
│                    └────────┬──────────┘   │
│                             │              │
│  ┌──────────────────────────┴──────────┐  │
│  │     Kubernetes Metrics (kubelet)    │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  ┌────────────────────────────────────┐   │
│  │      Grafana Pod                   │   │
│  │      :3000 ◄─── Query ────────┐    │   │
│  │                               │    │   │
│  │      Dashboards               │    │   │
│  │      - Jenkins Metrics        │    │   │
│  │      - Kubernetes Health      │    │   │
│  │      - Resource Usage         │    │   │
│  └───────────────────────────────┼────┘   │
│                                  │        │
│                         ┌────────┴──────┐ │
│                         │  Prometheus   │ │
│                         │  localhost:9090
│                         └───────────────┘ │
│                                            │
└────────────────────────────────────────────┘

        User Browser
            │
        ┌───┴──────────────────────────┐
        │                              │
  http://prometheus.local       http://grafana.local
        │                              │
```

## Setup Rápido

### 1. Habilitar Ingress (si no lo has hecho)

```bash
./scripts/setup-ingress.sh
```

### 2. Instalar Prometheus + Grafana

```bash
./scripts/setup-monitoring.sh
```

Este script:
- ✅ Crea namespace de monitoring
- ✅ Despliega Prometheus con configuración
- ✅ Despliega Grafana pre-configurado
- ✅ Configura Ingress para acceso
- ✅ Espera a que esté listo

### 3. Acceder

**Prometheus:**
```
http://prometheus.local
```

**Grafana:**
```
http://grafana.local
Username: admin
Password: admin123
```

## Qué se Monitorea

### Jenkins
- 📊 Queue length (trabajos en cola)
- ✅ Build success/failure rate
- ⏱️ Build duration
- 🔧 Executor usage
- 💾 Memory usage
- ⚠️ Alertas: Pod down, high memory/CPU

### Kubernetes
- 🐳 Pod CPU/Memory usage
- 🖥️ Node health status
- 💾 PVC (PersistentVolumeClaim) usage
- 🔌 Network I/O
- ⚠️ Alertas: Node not ready, PVC full

## Métrica de Ejemplo: Jenkins Build Time

Prometheus query para ver duración promedio de builds:

```promql
# Ver duración promedio de builds en los últimos 5 minutos
rate(jenkins_builds_duration_milliseconds_sum[5m]) / rate(jenkins_builds_duration_milliseconds_count[5m])

# Ver tasa de builds exitosos
rate(jenkins_builds_success_total[5m])

# Ver queue length
jenkins_queue_size
```

## Métricas de Kubernetes Disponibles

Sin Prometheus Operator, se usan métricas estándar:

```promql
# CPU usage
container_cpu_usage_seconds_total{pod="jenkins-*"}

# Memory usage
container_memory_usage_bytes{pod="jenkins-*"}

# Network I/O
container_network_receive_bytes_total{pod="jenkins-*"}

# PVC usage
kubelet_volume_stats_used_bytes{persistentvolumeclaim="jenkins-pvc"}
```

## Alertas Configuradas

El archivo `monitoring/prometheus/configmap.yaml` define alertas:

| Alerta | Condición | Severidad |
|--------|-----------|-----------|
| **JenkinsPodDown** | Pod unreachable 5m | 🔴 Critical |
| **JenkinsHighMemory** | >90% memory usage | 🟠 Warning |
| **JenkinsHighCPU** | >80% CPU for 10m | 🟠 Warning |
| **NodeNotReady** | Node unready 5m | 🔴 Critical |
| **PVCFull** | >90% capacity | 🟠 Warning |

Ver alertas en:
```
http://prometheus.local/alerts
```

## Crear Dashboards en Grafana

### Dashboard Manual

1. Acceder a Grafana: `http://grafana.local`
2. Login: `admin` / `admin123`
3. Click en `+` → `Dashboard`
4. Add panel
5. Elegir datasource: `Prometheus`
6. Escribir query PromQL

**Ejemplo de panel:**

```json
{
  "title": "Jenkins Queue Length",
  "targets": [
    {
      "expr": "jenkins_queue_size",
      "refId": "A"
    }
  ],
  "type": "graph"
}
```

### Importar Dashboard Existente

1. Click en `+` → `Import`
2. Buscar dashboard ID en https://grafana.com/grafana/dashboards
3. Dashboard recomendados:
   - **1860**: Node Exporter Full
   - **3662**: Prometheus 2.0 Stats
   - **6417**: Jenkins CI/CD
   - **7589**: Kubernetes Cluster Monitoring

## Estructura de Archivos

```
monitoring/
├── README.md                           # Esta documentación
├── namespace.yaml                      # Namespace "monitoring"
├── ingress.yaml                        # Ingress para Prometheus/Grafana
├── prometheus/
│   ├── configmap.yaml                  # Config + alertas de Prometheus
│   └── deployment.yaml                 # Deployment + Service + RBAC
├── grafana/
│   └── configmap.yaml                  # Config + deployment de Grafana
└── dashboards/
    └── (JSON files de dashboards)
```

## Troubleshooting

### Prometheus no scrapia Jenkins

**Causa:** Jenkins pod no tiene la anotación de scrape

**Solución:**
```bash
# Agregar anotación al pod
kubectl patch deployment jenkins -n jenkins -p \
  '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true"}}}}}'

# O manualmente en Deployment:
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/prometheus"
```

### Grafana no conecta a Prometheus

**Causa:** Datasource mal configurada

**Solución:**
1. Acceder a Grafana
2. Configuration → Data Sources
3. Verificar URL: `http://prometheus.monitoring.svc.cluster.local:9090`
4. Click "Test & Save"

### Alertas no se disparan

**Causa:** Alertmanager no está configurado

**Solución:** Las alertas se muestran en Prometheus pero no se envían:
```
http://prometheus.local/alerts
```

Para notificaciones, configurar Alertmanager:
```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

## Próximos Pasos

### Alertmanager
Para enviar notificaciones (email, Slack, PagerDuty):

```bash
# Instalar Alertmanager
kubectl create deployment alertmanager \
  --image=prom/alertmanager:latest \
  -n monitoring

# Configurar routing
```

### Prometheus Operator
Para gestión más profesional (CRDs):

```bash
# Instalar Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring
```

Ventajas:
- ServiceMonitor CRDs para scrape automático
- PrometheusRule para alertas
- Dashboards pre-configurados

### Loki (Logs)
Para agregar logs a Grafana:

```bash
# Instalar Loki
helm install loki grafana/loki-stack \
  -n monitoring
```

### Trace Tracking (Jaeger)
Para tracing distribuido:

```bash
# Instalar Jaeger
kubectl create deployment jaeger \
  --image=jaegertracing/all-in-one:latest \
  -n monitoring
```

## Limpieza

```bash
# Eliminar monitoring stack
kubectl delete namespace monitoring

# O solo Prometheus/Grafana dejando el namespace
kubectl delete deployment prometheus grafana -n monitoring
kubectl delete configmap prometheus-config grafana-config -n monitoring
```

## Recursos Útiles

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Dashboards Library](https://grafana.com/grafana/dashboards)

## Métricas Jenkins Populares

Si usas el plugin `Prometheus Metrics Plugin` en Jenkins:

```promql
# Compilaciones totales
jenkins_builds_success_total
jenkins_builds_failed_total

# Duración de compilaciones
jenkins_builds_duration_milliseconds

# Ejecutores
jenkins_executor_free
jenkins_executor_busy

# Queue
jenkins_queue_size
jenkins_queue_waiting_duration_milliseconds

# Cambios de trabajo
jenkins_jobs_total
jenkins_jobs_active
```

## Comandos Útiles

```bash
# Ver pods de monitoring
kubectl get pods -n monitoring

# Ver logs de Prometheus
kubectl logs deployment/prometheus -n monitoring

# Ver logs de Grafana
kubectl logs deployment/grafana -n monitoring

# Port-forward (alternativa a Ingress)
kubectl port-forward svc/prometheus -n monitoring 9090:9090
kubectl port-forward svc/grafana -n monitoring 3000:3000

# Ver métricas en tiempo real
kubectl exec prometheus-pod -n monitoring -- \
  promtool query instant 'up'

# Validar config de Prometheus
kubectl exec prometheus-pod -n monitoring -- \
  promtool check config /etc/prometheus/prometheus.yml
```
