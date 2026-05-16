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

## Paso a Paso

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

```
NAME          STATUS   VOLUME     CAPACITY   ACCESS MODES
jenkins-pvc   Bound    pvc-xxx    5Gi        RWO
```

### 3. Crear el Deployment

```bash
kubectl apply -f deployment.yaml
```

### 4. Verificar que el pod esté Running y Ready

```bash
kubectl get pods -n jenkins -w
```

> ⏳ Jenkins tarda ~2 minutos en iniciar. Esperar hasta ver `1/1 Running`.

```
NAME                       READY   STATUS    RESTARTS
jenkins-7d9f8b6c5d-xxxxx   1/1     Running   0
```

### 5. Obtener la IP de Minikube

```bash
minikube ip
```

### 6. Acceder a Jenkins

Abrir en el browser:

```
http://<minikube_ip>:32000
```

> El puerto `32000` está fijo en el Service para facilitar el acceso.
> No necesitás ejecutar `kubectl get service` para buscarlo cada vez.

### 7. Obtener la contraseña inicial de Admin

```bash
# Obtener el nombre del pod
kubectl get pods -n jenkins

# Ver los logs (la contraseña aparece al inicio)
kubectl logs <pod_name> -n jenkins
```

Buscar el bloque:

```
*************************************************************
Jenkins initial setup is required.
Please use the following password to proceed to installation:

  <TU_CONTRASEÑA_AQUI>

*************************************************************
```

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

```bash
# Ver todos los recursos del namespace
kubectl get all -n jenkins

# Ver los logs en tiempo real
kubectl logs -f <pod_name> -n jenkins

# Describir el pod (útil para debuggear probes o scheduling)
kubectl describe pod <pod_name> -n jenkins

# Ver el estado del PVC
kubectl get pvc -n jenkins

# Reiniciar el deployment (sin perder datos gracias al PVC)
kubectl rollout restart deployment/jenkins -n jenkins

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