# Jenkins on Kubernetes (Minikube) 🚀

> **Guía profesional para instalar Jenkins en Kubernetes local** usando Minikube, Kustomize, Ingress, JCasC y Monitoreo.

Orientada a entrenamiento, laboratorios y preparación para ambientes de producción.

---

## 📋 Tabla de Contenidos

- [Overview](#-overview)
- [Pre-requisitos](#️-pre-requisitos)
- [Instalación Rápida](#-instalación-rápida)
- [Arquitectura](#-arquitectura)
- [Guías Detalladas](#-guías-detalladas)
- [Características](#-características)
- [Comandos Útiles](#-comandos-útiles)
- [Troubleshooting](#-troubleshooting)
- [FAQ](#-faq)
- [Roadmap](#️-roadmap)
- [Contribuciones](#-contribuciones)
- [Recursos](#-recursos)
- [Licencia](#-licencia)

---

## 🎯 Overview

Este proyecto proporciona una **instalación profesional de Jenkins en Kubernetes**, perfecta para:

- 🎓 **Aprender Kubernetes**: Experiencia práctica con K8s
- 🔬 **Laboratorios**: Testear pipelines sin afectar producción
- 🚀 **Preparación Production**: Best practices aplicables a prod

### ¿Qué incluye?

| Componente | Descripción | Estado |
|-----------|-------------|--------|
| **Jenkins** | 2.504 LTS con JDK 21 | ✅ Incluido |
| **Kustomize** | Multi-ambiente (dev/staging/prod) | ✅ Incluido |
| **Ingress** | Acceso via hostname (jenkins.local) | ✅ Incluido |
| **JCasC** | Configuración como código en YAML | ✅ Incluido |
| **Prometheus** | Métricas y alertas | ✅ Incluido |
| **Grafana** | Dashboards visuales | ✅ Incluido |
| **Scripts** | Automatización completa | ✅ Incluido |

---

## ⚙️ Pre-requisitos

| Herramienta | Versión | Instalación |
|-----------|---------|-------------|
| **Docker** | 20.10+ | [docker.com](https://www.docker.com/) |
| **Minikube** | v1.32+ | [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io/docs/start) |
| **kubectl** | v1.29+ | [kubernetes.io](https://kubernetes.io/docs/tasks/tools) |
| **Kustomize** | v5.0+ | `brew install kustomize` |

### Requisitos de Máquina

- **CPU**: 2+ cores
- **RAM**: 4GB mínimo (6GB recomendado)
- **Disk**: 20GB libre
- **OS**: macOS, Linux o Windows (WSL2)

### Verificar Instalación

```bash
# Verificar todas las herramientas
docker --version     # Docker version 20.10+
minikube version     # minikube version v1.32+
kubectl version      # Client version v1.29+
kustomize version    # v5.0+
```

---

## 🚀 Instalación Rápida

### Opción A: Simple (Recomendado para aprender)

Para aprender sin complicaciones extra:

```bash
# 1. Ejecutar setup
./scripts/setup.sh

# 2. Obtener contraseña
./scripts/get-admin-password.sh

# 3. Abrir en navegador
http://<minikube_ip>:32000
```

⏱️ **Tiempo**: ~3 minutos

### Opción B: Profesional (Recomendado para labs)

Para setup similar a production:

```bash
# 1. Habilitar Ingress (una sola vez)
./scripts/setup-ingress.sh

# 2. Instalar monitoreo (una sola vez)
./scripts/setup-monitoring.sh

# 3. Desplegar Jenkins por ambiente
./scripts/deploy-env.sh dev        # http://jenkins-dev.local
./scripts/deploy-env.sh staging    # https://jenkins-staging.local
./scripts/deploy-env.sh prod       # https://jenkins.local

# 4. Obtener credenciales
./scripts/get-admin-password.sh

# 5. Acceder a dashboards
http://grafana.local               # Monitoreo (admin/admin123)
http://prometheus.local            # Alertas
```

⏱️ **Tiempo**: ~5 minutos

### Opción C: Manual (Recomendado para entender detalles)

Ver sección [Paso a Paso Manual](#paso-a-paso-manual-alternativa)

---

## 🏗️ Arquitectura

### Componentes y Conexiones

```
┌─────────────────────────────────────────────────────────────────┐
│                    Minikube Kubernetes Cluster                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   INGRESS CONTROLLER (NGINX)            │   │
│  │              Hostnames: jenkins*.local                  │   │
│  └────┬─────────────────┬──────────────────┬───────────────┘   │
│       │                 │                  │                   │
│       ▼                 ▼                  ▼                   │
│  ┌─────────┐    ┌────────────┐      ┌──────────┐              │
│  │ Jenkins │    │ Prometheus │      │ Grafana  │              │
│  │ :8080   │    │  :9090     │      │  :3000   │              │
│  │ ├ PVC   │    │            │      │          │              │
│  │ └ JCasC │    │ ├ Alerts   │      │ ├ K8s    │              │
│  │         │    │ └ Targets  │      │ ├ Jenkins│              │
│  │ Env:dev │    │            │      │ └ Apps   │              │
│  │ staging │    │ Scrape 15s │      │          │              │
│  │ prod    │    │            │      │ Login:   │              │
│  │         │    │            │      │ admin/   │              │
│  │Resources│    │ Storage:   │      │ admin123 │              │
│  │ ├ CPU   │    │ 30d        │      │          │              │
│  │ ├ Memory│    │            │      │Datasource│              │
│  │ └ PVC   │    └──────────────────────────────┘              │
│  │         │           ▲                                      │
│  │ Probes  │           │ Query                                │
│  │ ├ Ready │           │                                      │
│  │ └ Live  │    ┌──────┴─────┐                               │
│  │         │    │ Prometheus │                               │
│  │Kustomize│    │ API :9090  │                               │
│  │ ├ Base  │    └────────────┘                               │
│  │ └ Devop │                                                 │
│  └─────────┘    ┌──────────────────────────────┐             │
│                 │ Kubernetes API / Kubelet     │             │
│                 │ (Metrics + Node Info)        │             │
│                 └──────────────────────────────┘             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

        ║ Acceso Local (Host)                                    
        ║                                                        
    ┌───╨─────────────────────────┐                             
    │   Browser / kubectl cli     │                             
    ├─────────────────────────────┤                             
    │ http://jenkins-dev.local    │ → Jenkins Dev              
    │ https://jenkins.local       │ → Jenkins Prod             
    │ http://grafana.local        │ → Monitoreo               
    │ http://prometheus.local     │ → Alertas                 
    └─────────────────────────────┘                             
```

### Stack Tecnológico

```
Frontend/UI
├── Browser (cualquiera)
└── Jenkins Web (puerto 8080)

Observabilidad
├── Prometheus (métricas)
├── Grafana (dashboards)
└── Alertas

Orquestación
├── Kubernetes (minikube)
├── Kustomize (config)
└── Ingress (routing)

Jenkins
├── JCasC (configuración)
├── Persistent Volume (datos)
└── Security Context (permiso no-root)
```

---

## 📖 Guías Detalladas

### Guía Rápida: Setup Simple

**Para**: Aprender rápido, testear, laboratorios

```bash
./scripts/setup.sh
./scripts/get-admin-password.sh
# Acceder: http://<minikube_ip>:32000
```

👉 Ver: [`scripts/README.md`](scripts/README.md)

### Guía Profesional: Multi-Ambiente

**Para**: Simular dev/staging/prod, usar en equipo

```bash
# 1. Setup inicial (primera vez)
./scripts/setup-ingress.sh

# 2. Desplegar a ambiente específico
./scripts/deploy-env.sh dev

# 3. Modificar configuración
kubectl kustomize kustomize/overlays/dev  # Ver cambios
kubectl apply -k kustomize/overlays/dev   # Aplicar
```

👉 Ver: [`kustomize/README.md`](kustomize/README.md)

### Guía: Acceso Profesional

**Para**: Usar hostnames en lugar de IP:puerto

```bash
./scripts/setup-ingress.sh
# Acceder: http://jenkins-dev.local
```

👉 Ver: [`ingress/README.md`](ingress/README.md)

### Guía: Configuración como Código

**Para**: Versionear configuración de Jenkins en Git

```bash
# Editar configuración
kubectl edit configmap jenkins-casc-config -n jenkins

# Reiniciar para aplicar
kubectl rollout restart deployment/jenkins -n jenkins
```

👉 Ver: [`jcasc/README.md`](jcasc/README.md)

### Guía: Monitoreo y Alertas

**Para**: Visualizar métricas, recibir alertas

```bash
./scripts/setup-monitoring.sh
# Acceder: http://grafana.local (admin/admin123)
```

👉 Ver: [`monitoring/README.md`](monitoring/README.md)

## Paso a Paso Manual (Alternativa)

Si prefieres hacer cada paso manualmente:

```bash
# 1. Iniciar Minikube
minikube start --cpus 2 --memory 2048

# 2. Crear recursos base
kubectl apply -f jenkins-setup-k8s.yaml

# 3. Aplicar configuración JCasC
kubectl apply -f jcasc/configmap.yaml

# 4. Crear Deployment
kubectl apply -f deployment.yaml

# 5. Habilitar Ingress (opcional)
./scripts/setup-ingress.sh
kubectl apply -f kustomize/base/ingress.yaml

# 6. Verificar estado
kubectl get pods -n jenkins
kubectl logs -f -n jenkins -l app=jenkins
```

---

## ⭐ Características

### Security (Seguridad)

| Característica | Descripción | Beneficio |
|---|---|---|
| **Non-root** | Jenkins corre como UID 1000 | No puede acceder a archivos del host |
| **ServiceAccount** | Dedicado, no usa `default` | Principio de mínimo privilegio |
| **SecurityContext** | Restricciones a nivel pod | Previene escalada de privilegios |
| **Resource Limits** | CPU/Memory definidos | Evita que pod consuma todo el nodo |

### Reliability (Confiabilidad)

| Característica | Descripción | Beneficio |
|---|---|---|
| **Persistent Volume** | 5Gi de almacenamiento | No pierdes datos al reiniciar |
| **Readiness Probe** | Verifica `/login` | K8s sabe cuándo está listo |
| **Liveness Probe** | Reinicia si falla | Jenkins se recupera automáticamente |
| **Resource Requests** | Reserva recursos | Jenkins siempre tiene recursos suficientes |

### Operability (Operabilidad)

| Característica | Descripción | Beneficio |
|---|---|---|
| **Automation Scripts** | setup.sh, deploy-env.sh | Setup en segundos sin errores |
| **JCasC** | Configuración versionada | Reproducibilidad garantizada |
| **Kustomize** | Multi-ambiente | Dev/staging/prod en código |
| **Ingress** | Hostnames profesionales | `jenkins.local` en lugar de IP:puerto |
| **Prometheus+Grafana** | Monitoreo completo | Visibilidad total del sistema |

---

## 🛠️ Comandos Útiles

### Instalación

```bash
# Setup automático (simple)
./scripts/setup.sh

# Setup profesional
./scripts/setup-ingress.sh
./scripts/setup-monitoring.sh
./scripts/deploy-env.sh dev

# Obtener credenciales
./scripts/get-admin-password.sh

# Limpiar todo
./scripts/cleanup.sh
```

### Jenkins

```bash
# Ver estado
kubectl get pods -n jenkins
kubectl get svc -n jenkins
kubectl get pvc -n jenkins

# Ver logs
kubectl logs -f deployment/jenkins -n jenkins

# Ejecutar comando en pod
kubectl exec -it <pod_name> -n jenkins -- bash

# Ver/editar configuración
kubectl get configmap jenkins-casc-config -n jenkins -o yaml
kubectl edit configmap jenkins-casc-config -n jenkins

# Reiniciar
kubectl rollout restart deployment/jenkins -n jenkins

# Port-forward (acceso directo)
kubectl port-forward svc/jenkins -n jenkins 8080:8080
```

### Kustomize

```bash
# Ver YAML generado (sin aplicar)
kubectl kustomize kustomize/overlays/dev
kubectl kustomize kustomize/overlays/staging

# Aplicar directamente
kubectl apply -k kustomize/overlays/dev

# Validar YAML
kubectl kustomize kustomize/overlays/dev | kubectl apply -f - --dry-run=client
```

### Monitoreo

```bash
# Ver estado
kubectl get pods -n monitoring

# Ver logs
kubectl logs -f deployment/prometheus -n monitoring
kubectl logs -f deployment/grafana -n monitoring

# Acceder
http://grafana.local          # Con Ingress
kubectl port-forward svc/grafana -n monitoring 3000:3000  # Sin Ingress

# Ver alertas
http://prometheus.local/alerts
```

### Ingress

```bash
# Ver Ingress
kubectl get ingress -n jenkins -n monitoring

# Describir
kubectl describe ingress jenkins -n jenkins

# Ver eventos
kubectl get events -n jenkins
```

---

## 🔧 Troubleshooting

### Jenkins no inicia

**Síntomas**: Pod en `Pending` o `CrashLoopBackOff`

**Soluciones**:

```bash
# 1. Ver detalles del error
kubectl describe pod <pod_name> -n jenkins
kubectl logs <pod_name> -n jenkins

# 2. Verificar PVC
kubectl get pvc -n jenkins
kubectl describe pvc jenkins-pvc -n jenkins

# 3. Verificar recursos disponibles
kubectl top nodes
kubectl top pods -n jenkins

# 4. Reiniciar
kubectl rollout restart deployment/jenkins -n jenkins
```

### No puedo acceder a jenkins.local

**Síntomas**: `Connection refused` o `Name not resolved`

**Soluciones**:

```bash
# 1. Verificar que el hostname está en /etc/hosts
grep jenkins-dev.local /etc/hosts

# 2. Si no está, ejecutar:
./scripts/setup-ingress.sh

# 3. O agregarlo manualmente:
echo "$(minikube ip) jenkins-dev.local jenkins-staging.local jenkins.local" | sudo tee -a /etc/hosts

# 4. En macOS, limpiar DNS:
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Prometheus no scrapia Jenkins

**Síntomas**: Jenkins no aparece en Prometheus

**Soluciones**:

```bash
# 1. Verificar que Jenkins está corriendo
kubectl get pods -n jenkins

# 2. Verificar configuración de Prometheus
kubectl get configmap prometheus-config -n monitoring -o yaml

# 3. Verificar que el pod tiene anotaciones
kubectl describe pod -n jenkins -l app=jenkins

# 4. Revisar logs de Prometheus
kubectl logs -f deployment/prometheus -n monitoring
```

### Ingress no funciona

**Síntomas**: Ingress sin ADDRESS o no responde

**Soluciones**:

```bash
# 1. Verificar addon
minikube addons list | grep ingress

# 2. Si no está habilitado:
minikube addons enable ingress
sleep 30

# 3. Verificar ingress controller
kubectl get pods -n ingress-nginx

# 4. Describir ingress
kubectl describe ingress jenkins -n jenkins
```

---

## ❓ FAQ

### ¿Puedo usar esto en producción?

**Respuesta**: Parcialmente.

**Recomendaciones para producción**:
- ✅ Usar el stack (Kustomize, JCasC, Ingress, Monitoreo)
- ✅ Usar en AKS/EKS/GKE en lugar de Minikube
- ⚠️ Agregar Helm Chart oficial de Jenkins
- ⚠️ Usar Prometheus Operator en lugar de configuración manual
- ⚠️ Agregar cert-manager para certificados automáticos
- ⚠️ Agregar persistencia distribuida (no local)
- ⚠️ Configurar backups de PVC

Ver: [Roadmap](#roadmap)

### ¿Qué versión de Jenkins es?

**Respuesta**: Jenkins 2.504 LTS con JDK 21 (LTS hasta 2026)

Para cambiar, edita `deployment.yaml`:

```yaml
image: jenkins/jenkins:2.504-jdk21  # Cambiar aquí
```

Ver: https://hub.docker.com/r/jenkins/jenkins

### ¿Cómo agregar plugins a Jenkins?

**Opción 1: UI (Manual)**

1. Acceder a Jenkins
2. Manage → Plugin Manager
3. Buscar e instalar

**Opción 2: JCasC (Infraestructura como código)**

Edita `jcasc/configmap.yaml`:

```yaml
jenkins:
  plugins:
    - workflow-aggregator:latest
    - git:latest
    - github:latest
```

Luego:

```bash
kubectl apply -f jcasc/configmap.yaml
kubectl rollout restart deployment/jenkins -n jenkins
```

### ¿Cómo cambiar recursos (CPU/Memory)?

Edita `kustomize/overlays/<env>/kustomization.yaml`:

```yaml
- op: replace
  path: /spec/template/spec/containers/0/resources/limits/cpu
  value: "2"  # Cambiar aquí
```

Luego:

```bash
./scripts/deploy-env.sh <env>
```

### ¿Puedo tener múltiples Jenkins corriendo?

**Sí**. Crea un overlay adicional:

```bash
mkdir kustomize/overlays/test
# Copiar archivos de dev
cp kustomize/overlays/dev/* kustomize/overlays/test/

# Modificar hostname en ingress-patch.yaml
sed -i 's/jenkins-dev.local/jenkins-test.local/g' kustomize/overlays/test/ingress-patch.yaml

# Desplegar
./scripts/deploy-env.sh test
```

### ¿Cómo resetear Jenkins?

```bash
# Opción 1: Borrar solo datos (no PVC)
kubectl exec -it <pod_name> -n jenkins -- rm -rf /var/jenkins_home/*

# Opción 2: Borrar PVC (pierde todo)
kubectl delete pvc jenkins-pvc -n jenkins
kubectl delete pod -n jenkins -l app=jenkins
```

### ¿Cómo hacer backup de Jenkins?

```bash
# Backup datos de Jenkins
kubectl exec deployment/jenkins -n jenkins -- tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home/

# Descargar
kubectl cp jenkins/<pod_name>:/tmp/jenkins-backup.tar.gz ./jenkins-backup.tar.gz

# Restaurar
kubectl cp ./jenkins-backup.tar.gz jenkins/<pod_name>:/tmp/
kubectl exec -it <pod_name> -n jenkins -- tar xzf /tmp/jenkins-backup.tar.gz -C /
```

---

## 🗺️ Roadmap

### Fase 1: Core (✅ Completado)

- ✅ Jenkins básico en Kubernetes
- ✅ Kustomize multi-ambiente
- ✅ Ingress y HTTPS
- ✅ JCasC
- ✅ Monitoreo (Prometheus + Grafana)
- ✅ Scripts de automatización

### Fase 2: Production Ready (🔄 En Progreso)

- 🔄 Helm Chart oficial
- 🔄 Backup automático
- 🔄 Sealed Secrets
- 🔄 Network Policies
- 🔄 Pod Disruption Budgets

### Fase 3: Enterprise (📋 Planeado)

- 📋 Jenkins Controller + Agents
- 📋 Prometheus Operator
- 📋 Alertmanager
- 📋 ELK Stack (logs)
- 📋 GitOps (ArgoCD)
- 📋 Multi-cluster

### Fase 4: Advanced (💭 Futuro)

- 💭 Jenkins X
- 💭 Pipeline as Code (Jenkinsfile)
- 💭 Integration tests
- 💭 Performance testing
- 💭 Disaster recovery

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas!

### Cómo Contribuir

1. Fork el repo
2. Crea una rama: `git checkout -b feature/mi-mejora`
3. Commit: `git commit -m "Descripción"`
4. Push: `git push origin feature/mi-mejora`
5. Abre un Pull Request

### Mejoras Buscadas

- 📖 Documentación (traducciones, ejemplos)
- 🐛 Bug fixes
- 🎨 Mejoras de UX
- ⚡ Performance
- 🔒 Seguridad
- 🧪 Tests

---

## 📚 Recursos

### Documentación

- 📄 [`CONTRIBUTING.md`](CONTRIBUTING.md) - Cómo contribuir al proyecto
- 📄 [`SECURITY.md`](SECURITY.md) - Políticas y mejores prácticas de seguridad
- 📄 [`ARCHITECTURE.md`](ARCHITECTURE.md) - Guía detallada de arquitectura
- 📄 [`scripts/README.md`](scripts/README.md) - Scripts de automatización
- 📄 [`jcasc/README.md`](jcasc/README.md) - Jenkins Configuration as Code
- 📄 [`kustomize/README.md`](kustomize/README.md) - Multi-ambiente con Kustomize
- 📄 [`ingress/README.md`](ingress/README.md) - Ingress y acceso profesional
- 📄 [`monitoring/README.md`](monitoring/README.md) - Prometheus + Grafana

### Enlaces Externos

- [Jenkins Oficial](https://jenkins.io/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Minikube Docs](https://minikube.sigs.k8s.io/docs/)
- [Kustomize Reference](https://kubectl.docs.kubernetes.io/guides/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)

---

## 📝 Mejoras Respecto a Versiones Anteriores

| Aspecto | Antes | Ahora | Impacto |
|---------|-------|-------|--------|
| **JDK** | 11 (EOL) | 21 (LTS 2026) | ✅ Seguridad actualizada |
| **Tag** | `lts` (flotante) | `2.504-jdk21` (fijo) | ✅ Reproducibilidad |
| **Storage** | `emptyDir` | `PersistentVolumeClaim` | ✅ Datos persistentes |
| **ServiceAccount** | default | jenkins (dedicado) | ✅ Seguridad |
| **Security** | root | non-root (UID 1000) | ✅ Best practices |
| **Limits** | ninguno | CPU/Memory | ✅ Estabilidad |
| **Probes** | ninguno | Ready + Liveness | ✅ Reliability |
| **Config** | UI manual | JCasC YAML | ✅ Infrastructure as Code |
| **Ambientes** | 1 (manual) | 3 (Kustomize) | ✅ Escalabilidad |
| **Ingress** | NodePort | Ingress + Hostnames | ✅ Production-like |
| **Monitoreo** | ninguno | Prometheus + Grafana | ✅ Observabilidad |

---

## 📞 Support

¿Preguntas o problemas?

- 📖 Ver [Troubleshooting](#troubleshooting)
- ❓ Revisar [FAQ](#faq)
- 📚 Leer documentación en cada directorio
- 🐛 Abrir un [Issue](https://github.com/Zalde/Install-Jenkins-On-Minikube/issues)
- 💬 Iniciar una [Discussion](https://github.com/Zalde/Install-Jenkins-On-Minikube/discussions)

---

## 📄 Licencia

Este proyecto está bajo la licencia MIT.

---

## 🙏 Agradecimientos

- Comunidad de Jenkins
- Comunidad de Kubernetes
- Minikube team
- Prometheus y Grafana communities

---

**Última actualización**: Julio 2026

Happy containerizing! 🐳🚀
