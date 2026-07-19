# Scripts de Automatización

Esta carpeta contiene scripts bash para automatizar la instalación, configuración y limpieza de Jenkins en Minikube.

## Scripts Disponibles

### 1. `setup.sh`
Automatiza todo el proceso de instalación de Jenkins.

**Qué hace:**
- Verifica que minikube y kubectl estén instalados
- Inicia Minikube (si no está corriendo)
- Aplica los manifests de Kubernetes (Namespace, ServiceAccount, PVC, Service)
- Espera a que el PVC esté en estado `Bound`
- Crea el Deployment de Jenkins
- Espera a que el pod esté en estado `Running`
- Muestra la URL de acceso y próximos pasos

**Uso:**
```bash
./scripts/setup.sh
```

**Tiempo estimado:** 2-3 minutos

**Ejemplo de salida:**
```
=== Jenkins on Minikube - Setup Script ===

[1/6] Checking prerequisites...
✓ minikube and kubectl found

[2/6] Starting Minikube...
✓ Minikube already running

[3/6] Creating Namespace, ServiceAccount, PVC and Service...
✓ Setup resources created

[4/6] Waiting for PVC to be Bound...
✓ PVC is Bound

[5/6] Creating Jenkins Deployment...
✓ Deployment created

[6/6] Waiting for Jenkins pod to be Running...
⏳ This may take 1-2 minutes...
✓ Jenkins pod is Running and Ready

=== Setup Complete ===

Jenkins URL: http://192.168.49.2:32000
To get the admin password, run:
  ./scripts/get-admin-password.sh
```

### 2. `get-admin-password.sh`
Extrae y muestra la contraseña inicial del administrador de Jenkins.

**Uso:**
```bash
./scripts/get-admin-password.sh
```

**Ejemplo de salida:**
```
=== Jenkins Admin Password ===

Getting password from pod: jenkins-7d9f8b6c5d-xxxxx

✓ Admin Password found:

Username: admin
Password: abc123defghijklmnop1234567890

Jenkins URL: http://192.168.49.2:32000
```

### 3. `cleanup.sh`
Elimina todos los recursos de Jenkins (namespace, datos, volúmenes).

**Advertencia:** ⚠️ Esta operación es **destructiva y no se puede deshacer**. Todos los datos se perderán.

**Qué hace:**
- Solicita confirmación antes de proceder
- Elimina el namespace `jenkins` y todos sus recursos
- Opcionalmente detiene Minikube

**Uso:**
```bash
./scripts/cleanup.sh
```

**Ejemplo de salida:**
```
=== Jenkins on Minikube - Cleanup Script ===

⚠️  This will delete the entire jenkins namespace and all its resources
Data in PersistentVolume will be lost

Are you sure? (yes/no): yes

Deleting jenkins namespace...
✓ Jenkins namespace and all resources deleted

Do you also want to stop Minikube? (yes/no): no

Minikube is still running

=== Cleanup Complete ===
```

## Flujo de Uso Recomendado

### Primera instalación:
```bash
# 1. Ejecutar setup.sh (instala todo)
./scripts/setup.sh

# 2. Obtener la contraseña (después del paso 1)
./scripts/get-admin-password.sh

# 3. Abrir en el navegador
# http://<minikube_ip>:32000

# 4. Iniciar sesión con usuario "admin" y la contraseña obtenida
```

### Reiniciar Jenkins:
```bash
# Reiniciar mantiene todos los datos (gracias al PVC)
kubectl rollout restart deployment/jenkins -n jenkins
```

### Limpiar todo:
```bash
# Elimina namespace, datos, volúmenes
./scripts/cleanup.sh
```

## Requisitos

- `minikube` instalado
- `kubectl` instalado
- Docker o equivalente (para que funcione minikube)
- Mínimo 2 CPUs y 2GB RAM disponibles

## Troubleshooting

### Script falla porque minikube no inicia
```bash
# Verificar estado de minikube
minikube status

# Reiniciar minikube
minikube stop
minikube start --cpus 2 --memory 2048
```

### No se puede obtener la contraseña
Jenkins tarda hasta 2 minutos en iniciar. Esperar a que el pod esté `1/1 Running`:
```bash
kubectl get pods -n jenkins -w
```

### Eliminar recursos pero mantener minikube
```bash
# Ejecutar cleanup.sh y elegir "no" cuando pregunte si detener minikube
./scripts/cleanup.sh
```
