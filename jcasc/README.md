# Jenkins Configuration as Code (JCasC)

Esta carpeta contiene la configuración de Jenkins en formato YAML, permitiendo versionarla y aplicarla de forma automatizada.

## ¿Qué es JCasC?

**Jenkins Configuration as Code** es un plugin que permite configurar Jenkins completamente via archivos YAML, sin necesidad de hacer clic en la UI. Los beneficios son:

- ✅ Configuración versionada en Git
- ✅ Reproducibilidad: misma config = mismo Jenkins
- ✅ Infrastructure as Code (IaC): aplicar config automaticamente
- ✅ Fácil de auditar cambios
- ✅ Compartible entre equipos

## Archivos

### `configmap.yaml`
ConfigMap de Kubernetes que monta la configuración JCasC en el pod de Jenkins.

**Contenido:**
- `jenkins.yaml`: Configuración de seguridad, autorización, ubicación del sistema, etc.

**Cómo se usa:**
1. Se aplica en K8s: `kubectl apply -f jcasc/configmap.yaml`
2. Se monta en el pod: `/var/jenkins_home/casc_configs/jenkins.yaml`
3. Jenkins lo lee automáticamente al iniciar (via env var `CASC_JENKINS_CONFIG`)

### `jenkins.yaml`
Archivo de referencia con ejemplos de configuración. Este es el contenido que va dentro del ConfigMap.

**Secciones principales:**
```yaml
jenkins:               # Configuración del core de Jenkins
unclassified:         # Configuración de plugins
credentials:          # Credenciales y secretos
security:             # Configuración de seguridad
```

## Cómo usar

### 1. Aplicar la configuración durante setup
La configuración JCasC se aplica automáticamente cuando ejecutas:

```bash
./scripts/setup.sh
```

Este script:
1. Crea el ConfigMap con la configuración
2. Actualiza el Deployment para montarlo
3. Jenkins lee la configuración al iniciar

### 2. Modificar la configuración existente

Si Jenkins ya está corriendo y quieres cambiar la configuración:

```bash
# Editar el ConfigMap
kubectl edit configmap jenkins-casc-config -n jenkins

# Reiniciar Jenkins para aplicar cambios
kubectl rollout restart deployment/jenkins -n jenkins
```

### 3. Agregar nuevas configuraciones

Edita `jcasc/configmap.yaml` y agrega nuevas secciones bajo `data.jenkins.yaml`:

```yaml
jenkins:
  systemMessage: "Mi mensaje"
  # ... más configuración
  
  # Agregar nueva sección
  myPlugin:
    someOption: value
```

Luego aplica:
```bash
kubectl apply -f jcasc/configmap.yaml
kubectl rollout restart deployment/jenkins -n jenkins
```

## Ejemplos de Configuración

### Sistema básico
```yaml
jenkins:
  systemMessage: "Welcome to Jenkins"
  crumbIssuer:
    standard:
      excludeClientIPFromCrumb: true
```

### Security Realm (autenticación)
```yaml
jenkins:
  securityRealm:
    local:                    # Jenkins user database
      allowsSignup: false
    # Alternativas:
    # saml:                   # SAML 2.0
    # ldap:                   # LDAP
```

### Authorization Strategy (permisos)
```yaml
jenkins:
  authorizationStrategy:
    projectMatrix:
      permissions:
        - "Overall/Administer:admin"
        - "Overall/Read:authenticated"
        - "Job/Build:developers"
```

### Email / Mailer
```yaml
unclassified:
  mailer:
    smtp:
      host: "smtp.example.com"
      port: 587
      replyToAddress: "jenkins@example.com"
```

### Credenciales
```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              id: "github-credentials"
              username: "my-username"
              password: "${GITHUB_PASSWORD}"  # Desde env var
```

## Variables de Entorno

Puedes usar variables de entorno en la configuración con la sintaxis `${VAR_NAME}`:

```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          - plaintext:
              secret: "${SECRET_TOKEN:-default_value}"
```

Para setear variables de entorno en el pod, edita el Deployment:

```bash
kubectl edit deployment jenkins -n jenkins

# Agregar bajo spec.template.spec.containers[0].env:
env:
  - name: SECRET_TOKEN
    valueFrom:
      secretKeyRef:
        name: jenkins-secrets
        key: token
```

## Validación

Para verificar que tu YAML es válido, puedes usar online:
- https://www.yamllint.com/
- O instalar localmente: `pip install yamllint`

```bash
yamllint jcasc/configmap.yaml
```

## Recursos Oficiales

- [Jenkins CasC Documentation](https://jenkins.io/projects/jcasc/)
- [JCasC Configuration Examples](https://github.com/jenkinsci/configuration-as-code-plugin/tree/master/demos)
- [Jenkins Helm Chart](https://github.com/jenkinsci/helm-charts) - Usa JCasC por defecto

## Troubleshooting

### La configuración no se aplica
1. Verificar que el ConfigMap exista:
   ```bash
   kubectl get configmap jenkins-casc-config -n jenkins
   ```

2. Verificar que esté montado en el pod:
   ```bash
   kubectl describe pod -n jenkins -l app=jenkins
   ```

3. Ver logs de Jenkins:
   ```bash
   kubectl logs -f -n jenkins -l app=jenkins | grep -i casc
   ```

### El pod crashea después de cambiar config
1. Ver logs de error:
   ```bash
   kubectl logs --previous -n jenkins -l app=jenkins
   ```

2. Revertir cambios:
   ```bash
   kubectl rollout undo deployment/jenkins -n jenkins
   ```

### Sintaxis YAML inválida
Usar un validador online o `yamllint` para verificar antes de aplicar.

## Próximos Pasos

Una vez cómodo con JCasC, considera:
- Usar [Kustomize](https://kustomize.io/) para manejar múltiples ambientes
- Usar [Helm Charts oficiales de Jenkins](https://github.com/jenkinsci/helm-charts)
- Integrar con CI/CD para validar y aplicar cambios automáticamente
- Usar [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) para manejar credenciales de forma segura
