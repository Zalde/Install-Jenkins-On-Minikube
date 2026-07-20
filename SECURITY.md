# Política de Seguridad

## Seguridad en este Proyecto

Este documento explica cómo se manejan la seguridad en Jenkins en Kubernetes.

**Importante**: Este proyecto está diseñado para **laboratorios y entrenamiento**, no es production-ready por defecto. Ver sección [Seguridad en Producción](#seguridad-en-producción).

---

## 🔒 Seguridad Implementada

### Seguridad de Kubernetes

| Medida | Descripción | Ubicación |
|--------|-------------|-----------|
| **No root** | Jenkins se ejecuta como UID 1000 | `deployment.yaml` |
| **SecurityContext** | Previene escalada de privilegios | `deployment.yaml` |
| **ServiceAccount** | Dedicado, no usa default | `jenkins-setup-k8s.yaml` |
| **RBAC** | Permisos limitados a roles | `monitoring/prometheus/deployment.yaml` |
| **Límites de Recursos** | CPU/Memory restringidos | `deployment.yaml` / `kustomize/overlays/*/kustomization.yaml` |
| **Políticas de Red** | (Futuro) Restringir tráfico | |

### Seguridad de Jenkins

| Medida | Descripción | Ubicación |
|--------|-------------|-----------|
| **Sin Anónimos** | Solo usuarios autenticados | `jcasc/configmap.yaml` |
| **Protección CSRF** | Habilitada por defecto | Configuración Jenkins |
| **JCasC** | Configuración inmutable | `jcasc/` |
| **Pin de Versión** | Imagen exacta (no flotante) | `deployment.yaml` |

### Seguridad de Datos

| Medida | Descripción | Ubicación |
|--------|-------------|-----------|
| **Encriptación en reposo** | (Futuro) Sealed Secrets | |
| **Encriptación en tránsito** | HTTPS en Ingress (prod) | `kustomize/overlays/prod/ingress-patch.yaml` |
| **Respaldo** | (Futuro) Respaldos automáticos | |
| **Retención** | 30 días de métricas | `monitoring/prometheus/configmap.yaml` |

---

## ⚠️ Limitaciones Actuales de Seguridad

### No Recomendado para Producción

- ❌ **Minikube local**: Aislamiento limitado
- ❌ **emptyDir para logs**: Se pierden al reiniciar
- ❌ **Contraseña simple**: `admin123` en Grafana
- ❌ **HTTP en dev**: Sin HTTPS
- ❌ **Sin Sealed Secrets**: Credenciales en ConfigMaps
- ❌ **Sin Políticas de Red**: Tráfico abierto entre pods
- ❌ **Almacenamiento local**: Sin replicación

### Vulnerabilidades Conocidas

#### 1. Credenciales en ConfigMaps

**Problema**: Credenciales guardadas en texto plano

**Mitigación Actual**:
```bash
kubectl get configmap jenkins-casc-config -n jenkins -o yaml
# ⚠️ Credenciales visibles
```

**Solución Producción**:
```bash
# Usar Sealed Secrets
brew install sealed-secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/sealed-secrets-0.18.0.yaml

# Encriptar secretos
echo -n micontraseña | kubectl create secret generic mi-secret \
  --dry-run=client --from-file=/dev/stdin | \
  kubeseal -o yaml
```

#### 2. Almacenamiento Local (Minikube)

**Problema**: PVC local, sin replicación

**Mitigación**:
```bash
# Respaldo manual
kubectl exec deployment/jenkins -n jenkins -- \
  tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home/

# Para Producción: Usar EBS, GCS, etc.
```

#### 3. Credenciales Por Defecto

**Problema**: Contraseña simple de admin

**Mitigación**:
```bash
# Cambiar contraseña después del setup
# 1. Acceder a Jenkins
# 2. Administrar → Usuarios → admin → Configurar
# 3. Cambiar contraseña
```

---

## 🛡️ Seguridad en Producción

### Cambios Recomendados

#### 1. Usar Cluster Administrado (no Minikube)

```yaml
# Clusters production
- EKS (Amazon)
- AKS (Microsoft)
- GKE (Google)
- On-premise (Kubernetes nativo)
```

#### 2. Agregar Sealed Secrets

```bash
# Instalar
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets -n kube-system sealed-secrets/sealed-secrets

# Usar en JCasC
# En lugar de:
credentials:
  system:
    domainCredentials:
      - plaintext:
          secret: "micontraseña"  # ❌ Peligroso

# Hacer:
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: jenkins-secrets
spec:
  encryptedData:
    github-token: AgCPk3DKs...  # ✅ Encriptado
```

#### 3. Usar Políticas de Red

```yaml
# Restringir tráfico entre pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: jenkins-netpol
  namespace: jenkins
spec:
  podSelector:
    matchLabels:
      app: jenkins
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - port: 8080
  egress:
    - to:
        - podSelector: {}
      ports:
        - port: 8080
```

#### 4. RBAC Granular

```yaml
# En lugar de permisos amplios
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: jenkins
spec:
  rules:
    # Solo lo que Jenkins necesita
    - apiGroups: [""]
      resources: ["pods", "pods/log"]
      verbs: ["get", "list", "watch", "create"]
    - apiGroups: [""]
      resources: ["pods/exec"]
      verbs: ["create"]
```

#### 5. Estándares de Seguridad de Pods

```yaml
# Kubernetes 1.25+
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: jenkins-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
```

#### 6. Escaneo de Imágenes

```bash
# Usar Trivy para verificar vulnerabilidades
trivy image jenkins/jenkins:2.504-jdk21

# Agregar a CI/CD
# .github/workflows/security.yml
name: Escaneo de Seguridad
on: [push]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'jenkins/jenkins:2.504-jdk21'
```

#### 7. Certificados TLS

```bash
# Instalar cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace

# Usar Let's Encrypt
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

#### 8. Encriptación de Secretos en Reposo

```yaml
# Encriptar secrets en etcd
# En apiserver:
# --encryption-provider-config=/etc/kubernetes/encryption.yaml

apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ...
      - identity: {}
```

---

## 🔑 Manejo de Secretos

### ❌ NO Hacer

```bash
# No guardar en Git
git add secret.yaml
git commit -m "Agregar contraseña"  # ❌

# No usar texto plano
kubectl set env deployment/jenkins ADMIN_PASS=password123  # ❌

# No hardcodear
password: "admin123"  # ❌

# No compartir entre ambientes
export PASSWORD="mipass"  # ❌
```

### ✅ SÍ Hacer

```bash
# Usar Kubernetes Secrets
kubectl create secret generic jenkins-secret \
  --from-literal=admin-password=$(openssl rand -base64 32)

# O Sealed Secrets (producción)
kubectl create secret generic jenkins-secret \
  --from-literal=admin-password=... | \
  kubeseal -o yaml > sealed-secret.yaml

# Referencia en manifest
env:
  - name: ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: jenkins-secret
        key: admin-password

# Para Grafana, cambiar después del setup
# 1. Acceder a Grafana
# 2. Admin → Configuración → Cambiar Contraseña
```

---

## 🔍 Auditoría y Logs

### Habilitar Auditoría en Kubernetes

```bash
# Ver eventos
kubectl get events -n jenkins -w

# Ver logs del servidor API
kubectl logs -n kube-system <apiserver-pod>

# Habilitar audit logging en kubeadm
--audit-log-path=/var/log/kubernetes/audit.log
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
```

### Monitoreo de Seguridad

```bash
# Ver intentos de acceso denegados
kubectl logs -f deployment/jenkins -n jenkins | grep -i "acceso denegado"

# Alertas de Prometheus para seguridad
# En monitoring/prometheus/configmap.yaml
- alert: AccesoNoAutorizado
  expr: increase(apiserver_audit_event_total{verb="get",user_username!~"system:.*"}[5m]) > 10
```

---

## 📋 Lista de Verificación Pre-Producción

Antes de usar en producción:

### Infraestructura
- [ ] Usar cluster administrado (EKS, AKS, GKE)
- [ ] Habilitar RBAC
- [ ] Configurar Políticas de Red
- [ ] Habilitar Estándares de Seguridad de Pods
- [ ] Encriptar secretos en reposo
- [ ] Encriptar tráfico (HTTPS)

### Contenedores
- [ ] Escanear imágenes con Trivy
- [ ] Usar distroless si es posible
- [ ] Limitar permisos (no root)
- [ ] Remover herramientas de debugging
- [ ] Firmar imágenes

### Secretos
- [ ] Usar Sealed Secrets o Vault
- [ ] Rotar credenciales regularmente
- [ ] No guardar en Git
- [ ] Usar RBAC para acceso
- [ ] Auditar acceso a secretos

### Monitoreo
- [ ] Prometheus + Grafana
- [ ] Alertmanager para notificaciones
- [ ] Loki para logs centralizados
- [ ] Auditoría de cambios
- [ ] Escaneo de seguridad en CI/CD

### Cumplimiento
- [ ] Cumplir con cumplimiento requerido (SOC2, PCI, etc.)
- [ ] Documentar políticas de seguridad
- [ ] Realizar pruebas de penetración
- [ ] Plan de respuesta a incidentes
- [ ] Plan de recuperación ante desastres

---

## 🚨 Reportar Vulnerabilidades

Si encuentras una vulnerabilidad de seguridad:

1. **NO abras un issue público**
2. **Envía un email privado** a: adrian@elizalde.net.ar
3. **Incluye**:
   - Descripción de la vulnerabilidad
   - Pasos para reproducir
   - Impacto potencial
   - Sugerencias de corrección (si tienes)

La vulnerabilidad será investigada y parcheada de forma discreta.

---

## 📚 Referencias

- [Mejores Prácticas de Seguridad en Kubernetes](https://kubernetes.io/docs/concepts/security/)
- [Hoja de Trucos de Seguridad de Kubernetes de OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
- [Comparativa CIS de Kubernetes](https://www.cisecurity.org/cis-benchmarks/)
- [Documentación de Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Documentación de Seguridad de Jenkins](https://www.jenkins.io/doc/book/security/)

---

**Última actualización**: Julio 2026

¡La seguridad es responsabilidad de todos! 🔒
