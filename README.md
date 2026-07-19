# Jenkins on Kubernetes (Minikube)

Guía paso a paso para instalar Jenkins en un entorno local con Minikube.
Orientada a entrenamiento y laboratorios.

---

## Pre-requisitos

| Herramienta | Versión mínima | Instalación |
|-------------|---------------|-------------|
| minikube    | v1.32+        | https://minikube.sigs.k8s.io/docs/start |
| kubectl     | v1.29+        | https://kubernetes.io/docs/tasks/tools  |

---

## Arquitectura del laboratorio

```
[Browser] → minikube_ip:32000
                  │
            [NodePort Service]
                  │
           [Jenkins Pod :8080]
                  │
         [PersistentVolume 5Gi]
         (jenkins_home persistente)
```

---

## Instalación Rápida (Recomendado)

### Opción 1: Setup Simple
Para instalación rápida con valores por defecto:

```bash
./scripts/setup.sh
# Acceder: http://<minikube_ip>:32000
```

### Opción 2: Con Kustomize + Ingress (Recomendado)
Para desplegar con Ingress y configuración por ambiente:

```bash
# 1. Setup Ingress (una sola vez)
./scripts/setup-ingress.sh

# 2. Desplegar en el ambiente deseado
./scripts/deploy-env.sh dev        # http://jenkins-dev.local
./scripts/deploy-env.sh staging    # https://jenkins-staging.local
./scripts/deploy-env.sh prod       # https://jenkins.local
```

> 💡 Ingress permite acceso via hostnames profesionales. Ver [`ingress/README.md`](ingress/README.md)

### Obtener Credenciales

Después de cualquier instalación:

```bash
./scripts/get-admin-password.sh
```

> 💡 Para más detalles sobre los scripts, ver [`scripts/README.md`](scripts/README.md)

---

## Paso a Paso Manual (Alternativa)

Si prefieres ejecutar cada paso manualmente:

### 1. Iniciar Minikube

```bash
minikube start
```

### 2. Crear Namespace, ServiceAccount, PVC y Service

```bash
kubectl apply -f jenkins-setup-k8s.yaml
```

Verifica que el PVC quede en estado `Bound`:

```bash
kubectl get pvc -n jenkins
```

### 3. Crear ConfigMap con JCasC (Opcional pero recomendado)

```bash
kubectl apply -f jcasc/configmap.yaml
```

> 💡 Esto aplica la configuración de Jenkins via Configuration as Code

### 4. Crear el Deployment

```bash
kubectl apply -f deployment.yaml
```

### 5. Verificar que el pod esté Running y Ready

```bash
kubectl get pods -n jenkins -w
```

> ⏳ Jenkins tarda ~2 minutos en iniciar. Esperar hasta ver `1/1 Running`.

### 6. Acceder a Jenkins

```bash
# Obtener IP de Minikube
minikube ip

# Abrir en el navegador
http://<minikube_ip>:32000
```

### 7. Obtener la contraseña inicial

```bash
./scripts/get-admin-password.sh
```

---

## Ingress - Acceso HTTP/HTTPS

**Ingress** proporciona acceso profesional a Jenkins via hostnames en lugar de IP:puerto:

- 🌐 **Hostnames**: `jenkins-dev.local`, `jenkins-staging.local`, `jenkins.local`
- 🔒 **HTTPS**: SSL/TLS automático en staging y production
- 🚀 **Routing**: Path-based y hostname-based
- 📊 **Rate Limiting**: Control de tráfico en production

### Setup Rápido

```bash
# Habilitar Ingress en Minikube (una sola vez)
./scripts/setup-ingress.sh

# Acceder a Jenkins
http://jenkins-dev.local      # Development
https://jenkins-staging.local # Staging (HTTPS)
https://jenkins.local         # Production (HTTPS)
```

> 💡 Comparación: NodePort (IP:puerto) vs Ingress (hostname). Ver [`ingress/README.md`](ingress/README.md)

---

## Kustomize - Múltiples Ambientes

**Kustomize** permite mantener una configuración base común y aplicar variaciones por ambiente (dev/staging/prod) sin duplicar YAML:

```
kustomize/
├── base/               # Configuración común para todos los ambientes
└── overlays/           # Variaciones específicas por ambiente
    ├── dev/            # Desarrollo: recursos bajos, logs DEBUG
    ├── staging/        # Staging: config similar a producción
    └── prod/           # Producción: recursos altos, logs WARN
```

### Desplegar por Ambiente

```bash
# Development (para aprender/testear)
./scripts/deploy-env.sh dev

# Staging (pre-producción)
./scripts/deploy-env.sh staging

# Production
./scripts/deploy-env.sh prod
```

### Ver Configuración Generada

```bash
# Sin aplicar cambios (dry-run)
kubectl kustomize kustomize/overlays/dev
```

Para más detalles: [`kustomize/README.md`](kustomize/README.md)

---

## Jenkins Configuration as Code (JCasC)

La configuración de Jenkins se puede gestionar completamente via YAML, permitiendo:

- 📝 **Versionable en Git**: Toda la configuración está en código
- 🔄 **Reproducible**: Mismo YAML = Mismo Jenkins
- 🚀 **Automatizable**: Se aplica al iniciar el pod
- 🔍 **Auditable**: Ver exactamente qué cambió y quién lo hizo

### Estructura de JCasC

```
jcasc/
├── README.md              # Documentación de JCasC
├── configmap.yaml         # ConfigMap que monta la configuración en K8s
└── jenkins.yaml           # Archivo de referencia con ejemplos
```

### Usar JCasC

La configuración se monta automáticamente:
1. El archivo `jcasc/configmap.yaml` crea un ConfigMap en K8s
2. El Deployment monta este ConfigMap en `/var/jenkins_home/casc_configs`
3. Jenkins lo lee automáticamente al iniciar (via env var `CASC_JENKINS_CONFIG`)

### Modificar la Configuración

```bash
# Editar la configuración
kubectl edit configmap jenkins-casc-config -n jenkins

# Reiniciar Jenkins para aplicar cambios
kubectl rollout restart deployment/jenkins -n jenkins
```

Para más detalles: [`jcasc/README.md`](jcasc/README.md)

---

## ¿Qué mejoró respecto a la versión anterior?

| Aspecto           | Antes                        | Ahora                          | Por qué importa |
|-------------------|------------------------------|--------------------------------|-----------------|
| **JDK**           | JDK 11 (EOL)                 | JDK 21 (LTS activo)            | JDK 11 ya no recibe parches de seguridad |
| **Tag de imagen** | `lts` (flotante)             | `2.504-jdk21` (fijo)           | Tags flotantes rompen la reproducibilidad |
| **Almacenamiento**| `emptyDir` (volátil)         | `PersistentVolumeClaim` (5Gi)  | Con emptyDir perdés todo al reiniciar el pod |
| **ServiceAccount**| default                      | Dedicado `jenkins`             | Principio de mínimo privilegio |
| **SecurityContext**| Corre como root             | Non-root (UID 1000)            | Buena práctica de seguridad en contenedores |
| **Recursos**      | Sin límites                  | Requests + Limits definidos    | Sin límites el pod puede consumir todo el nodo |
| **Readiness Probe**| Ninguna                     | HTTP GET /login                | K8s sabe cuándo Jenkins realmente está listo |
| **Liveness Probe** | Ninguna                     | HTTP GET /login                | K8s reinicia el pod si Jenkins deja de responder |
| **Puerto agentes**| No expuesto                  | NodePort 32001                 | Necesario para conectar Jenkins agents |

---

## Comandos útiles

### Usando Scripts (Recomendado)

```bash
# 1. Setup Ingress (una sola vez)
./scripts/setup-ingress.sh

# 2. Instalación: Simple
./scripts/setup.sh

# 2. Instalación: Con Kustomize (ambiente-específico)
./scripts/deploy-env.sh dev      # Development
./scripts/deploy-env.sh staging  # Staging
./scripts/deploy-env.sh prod     # Production

# 3. Obtener contraseña de admin
./scripts/get-admin-password.sh

# Cleanup
./scripts/cleanup.sh
```

### Comandos Kustomize

```bash
# Ver YAML generado (sin aplicar)
kubectl kustomize kustomize/overlays/dev
kubectl kustomize kustomize/overlays/staging
kubectl kustomize kustomize/overlays/prod

# Aplicar directamente
kubectl apply -k kustomize/overlays/dev
```

### Comandos kubectl directos

```bash
# Ver todos los recursos del namespace
kubectl get all -n jenkins

# Ver los logs en tiempo real
kubectl logs -f -n jenkins -l app=jenkins

# Describir el pod (útil para debuggear probes o scheduling)
kubectl describe pod -n jenkins -l app=jenkins

# Ver el estado del PVC
kubectl get pvc -n jenkins

# Reiniciar el deployment (sin perder datos gracias al PVC)
kubectl rollout restart deployment/jenkins -n jenkins

# Ver/editar la configuración JCasC
kubectl get configmap jenkins-casc-config -n jenkins -o yaml
kubectl edit configmap jenkins-casc-config -n jenkins

# Eliminar todo el laboratorio
kubectl delete namespace jenkins
```

---

## Troubleshooting

### El pod queda en `Pending`
```bash
kubectl describe pod <pod_name> -n jenkins
```
Causas comunes:
- El PVC no quedó en estado `Bound` → verificar con `kubectl get pvc -n jenkins`
- Recursos insuficientes en Minikube → `minikube start --cpus 2 --memory 2048`

### El pod queda en `CrashLoopBackOff`
```bash
kubectl logs <pod_name> -n jenkins --previous
```
Causa común: problema de permisos en el volumen.
Solución temporal para labs:
```bash
kubectl patch deployment jenkins -n jenkins \
  --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/securityContext"}]'
```

### No puedo acceder al browser
- Verificar que Minikube está corriendo: `minikube status`
- Verificar la IP: `minikube ip`
- Verificar el Service: `kubectl get svc -n jenkins`
- Alternativa: `minikube service jenkins -n jenkins --url`

---

## Próximos pasos sugeridos

Una vez que domines esta instalación, te recomendamos explorar:

- **[Helm Chart oficial de Jenkins](https://github.com/jenkinsci/helm-charts)** — instalación configurable con un solo comando
- **[Jenkins Configuration as Code (JCasC)](https://www.jenkins.io/projects/jcasc/)** — toda la config de Jenkins en YAML versionado en Git
- **[Kubernetes Plugin para Jenkins](https://plugins.jenkins.io/kubernetes/)** — agentes efímeros como pods bajo demanda
- **[Jenkins Operator](https://jenkinsci.github.io/kubernetes-operator/)** — gestión de Jenkins como Custom Resource en K8s