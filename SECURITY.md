# Security Policy

## Seguridad en este Proyecto

Este documento explica cómo se manejan la seguridad en Jenkins on Kubernetes.

**Importante**: Este proyecto está diseñado para **laboratorios y entrenamiento**, no es production-ready por defecto. Ver sección [Producción](#seguridad-en-producción).

---

## 🔒 Seguridad Implementada

### Kubernetes Security

| Medida | Descripción | Ubicación |
|--------|-------------|-----------|
| **Non-root** | Jenkins corre como UID 1000 | `deployment.yaml` |
| **SecurityContext** | Previene escalada de privilegios | `deployment.yaml` |
| **ServiceAccount** | Dedicado, no usa default | `jenkins-setup-k8s.yaml` |
| **RBAC** | Permisos limitados a roles | `monitoring/prometheus/deployment.yaml` |
| **Resource Limits** | CPU/Memory restringidos | `deployment.yaml` / `kustomize/overlays/*/kustomization.yaml` |
| **Network Policy** | (Futuro) Restringir tráfico | |

### Jenkins Security

| Medida | Descripción | Ubicación |
|--------|-------------|-----------|
| **Anonymous Disabled** | Solo usuarios autenticados | `jcasc/configmap.yaml` |
| **CSRF Protection** | Habilitado por defecto | Jenkins config |
| **JCasC** | Configuración inmutable | `jcasc/` |
| **Version Pinning** | Imagen exacta (no flotante) | `deployment.yaml` |

### Data Security

| Medida | Descripción | Ubicación |
|--------|-------------|-----------|
| **Encryption at rest** | (Futuro) Sealed Secrets | |
| **Encryption in transit** | HTTPS en Ingress (prod) | `kustomize/overlays/prod/ingress-patch.yaml` |
| **Backup** | (Futuro) Automated backups | |
| **Retention** | 30 días de métricas | `monitoring/prometheus/configmap.yaml` |

---

## ⚠️ Seguridad Actual (Limitaciones)

### No Recomendado para Producción

- ❌ **Minikube local**: Aislamiento limitado
- ❌ **emptyDir para logs**: Se pierden al reiniciar
- ❌ **Admin password simple**: `admin123` en Grafana
- ❌ **HTTP en dev**: Sin HTTPS
- ❌ **No Sealed Secrets**: Credenciales en ConfigMaps
- ❌ **No Network Policies**: Tráfico abierto entre pods
- ❌ **Almacenamiento local**: Sin replicación

### Vulnerabilidades Conocidas

#### 1. Credenciales en ConfigMaps

**Problema**: Credenciales guardadas en plain text

**Mitigación Actual**:
```bash
kubectl get configmap jenkins-casc-config -n jenkins -o yaml
# ⚠️ Credenciales visibles
```

**Solución Production**:
```bash
# Usar Sealed Secrets
brew install sealed-secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/sealed-secrets-0.18.0.yaml

# Encriptar secretos
echo -n mypassword | kubectl create secret generic my-secret \
  --dry-run=client --from-file=/dev/stdin | \
  kubeseal -o yaml
```

#### 2. Storage Local (Minikube)

**Problema**: PVC local, sin replicación

**Mitigación**:
```bash
# Backup manual
kubectl exec deployment/jenkins -n jenkins -- \
  tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home/

# Para Producción: Usar EBS, GCS, etc.
```

#### 3. Default Credentials

**Problema**: Password simple de admin

**Mitigación**:
```bash
# Cambiar contraseña después del setup
# 1. Acceder a Jenkins
# 2. Manage → Users → admin → Configure
# 3. Cambiar contraseña
```

---

## 🛡️ Seguridad en Producción

### Cambios Recomendados

#### 1. Usar Cluster Managed (no Minikube)

```yaml
# Production clusters
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
          secret: "mypassword"  # ❌ Peligroso

# Hacer:
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: jenkins-secrets
spec:
  encryptedData:
    github-token: AgCPk3DKs...  # ✅ Encriptado
```

#### 3. Usar Network Policies

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

#### 5. Pod Security Standards

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

#### 6. Scanning de Imágenes

```bash
# Usar Trivy para verificar vulnerabilidades
trivy image jenkins/jenkins:2.504-jdk21

# Agregar a CI/CD
# .github/workflows/security.yml
name: Security Scan
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

#### 8. Secrets Encryption at Rest

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
git commit -m "Add password"  # ❌

# No usar plain text
kubectl set env deployment/jenkins ADMIN_PASS=password123  # ❌

# No hardcodear
password: "admin123"  # ❌

# No compartir entre ambientes
export PASSWORD="mypass"  # ❌
```

### ✅ SÍ Hacer

```bash
# Usar Kubernetes Secrets
kubectl create secret generic jenkins-secret \
  --from-literal=admin-password=$(openssl rand -base64 32)

# O Sealed Secrets (production)
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
# 2. Admin → Settings → Change Password
```

---

## 🔍 Auditoría y Logs

### Habilitar Auditoría en Kubernetes

```bash
# Ver eventos
kubectl get events -n jenkins -w

# Ver logs de API server
kubectl logs -n kube-system <apiserver-pod>

# Habilitar audit logging en kubeadm
--audit-log-path=/var/log/kubernetes/audit.log
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
```

### Monitoreo de Seguridad

```bash
# Ver intentos de acceso denegados
kubectl logs -f deployment/jenkins -n jenkins | grep -i "access denied"

# Alertas de Prometheus para seguridad
# En monitoring/prometheus/configmap.yaml
- alert: UnauthorizedAPIAccess
  expr: increase(apiserver_audit_event_total{verb="get",user_username!~"system:.*"}[5m]) > 10
```

---

## 📋 Checklist de Seguridad Pre-Producción

Antes de usar en producción:

### Infrastructure
- [ ] Usar cluster managed (EKS, AKS, GKE)
- [ ] Habilitar RBAC
- [ ] Configurar Network Policies
- [ ] Habilitar Pod Security Standards
- [ ] Encriptar secrets at rest
- [ ] Encriptar tráfico (HTTPS)

### Container
- [ ] Escanear imágenes con Trivy
- [ ] Usar distroless si es posible
- [ ] Limitar permisos (non-root)
- [ ] Remover debugging tools
- [ ] Firmar imágenes

### Secrets
- [ ] Usar Sealed Secrets o Vault
- [ ] Rotar credenciales regularmente
- [ ] No guardar en Git
- [ ] Usar RBAC para acceso
- [ ] Auditar acceso a secrets

### Monitoring
- [ ] Prometheus + Grafana
- [ ] Alertmanager para notificaciones
- [ ] Loki para logs centralizados
- [ ] Auditoría de cambios
- [ ] Security scanning en CI/CD

### Compliance
- [ ] Cumplir con compliance requerido (SOC2, PCI, etc.)
- [ ] Documentar políticas de seguridad
- [ ] Realizar penetration testing
- [ ] Incident response plan
- [ ] Disaster recovery plan

---

## 🚨 Reportar Vulnerabilidades

Si encuentras una vulnerabilidad de seguridad:

1. **NO abras un issue público**
2. **Envía un email privado** a: adrian@elizalde.net.ar
3. **Incluye**:
   - Descripción de la vulnerabilidad
   - Pasos para reproducir
   - Impacto potencial
   - Sugerencias de fix (si tienes)

La vulnerabilidad será investigada y parcheada de forma discreta.

---

## 📚 Referencias

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/cis-benchmarks/)
- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [Jenkins Security Documentation](https://www.jenkins.io/doc/book/security/)

---

**Última actualización**: Julio 2026

¡Seguridad es responsabilidad de todos! 🔒
