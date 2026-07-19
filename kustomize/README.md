# Kustomize - Gestión de Múltiples Ambientes

Esta carpeta contiene configuraciones de Kubernetes usando **Kustomize**, permitiendo mantener una base común y aplicar variaciones por ambiente sin duplicar YAML.

## ¿Qué es Kustomize?

**Kustomize** es una herramienta nativa de Kubernetes que permite:

- 📝 **Reutilizar YAML**: Base común + patches por ambiente
- 🔧 **Sin duplicación**: Un solo lugar para cambios comunes
- 🎯 **Ambiente-específico**: Dev, Staging, Prod con sus propios valores
- 🚀 **Simple**: Solo YAML, sin templates ni lenguajes especiales
- 📦 **Integrado en kubectl**: `kubectl apply -k` es todo lo que necesitas

## Estructura

```
kustomize/
├── README.md                    # Esta documentación
├── base/                        # Configuración base común
│   └── kustomization.yaml
└── overlays/                    # Variaciones por ambiente
    ├── dev/
    │   └── kustomization.yaml   # Dev: recursos bajos, más logs
    ├── staging/
    │   └── kustomization.yaml   # Staging: config similar a prod
    └── prod/
        └── kustomization.yaml   # Prod: recursos altos, menos logs
```

## Ambientes Disponibles

### 🟦 Development (dev)
- **Replicas**: 1
- **CPU**: 250m requests, 500m limits
- **Memory**: 256Mi requests, 512Mi limits
- **Probes**: Tiempos reducidos
- **Logs**: DEBUG
- **Caso de uso**: Desarrollo local, testing rápido

### 🟩 Staging
- **Replicas**: 1
- **CPU**: 500m requests, 1 limit
- **Memory**: 512Mi requests, 1Gi limits
- **Probes**: Tiempos moderados
- **Logs**: INFO
- **Caso de uso**: Validación pre-producción

### 🟥 Production (prod)
- **Replicas**: 1
- **CPU**: 1 request, 2 limits
- **Memory**: 1Gi requests, 2Gi limits
- **Probes**: Tiempos conservadores
- **Logs**: WARN
- **Affinidad**: Anti-afinidad preferida
- **Caso de uso**: Producción real

## Cómo Usar

### Instalación (si no tienes kustomize)

```bash
# macOS
brew install kustomize

# Linux
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

# O desde el script
./scripts/deploy-env.sh dev
```

### Desplegar a un Ambiente

```bash
# Development (recomendado para aprender)
./scripts/deploy-env.sh dev

# Staging
./scripts/deploy-env.sh staging

# Production
./scripts/deploy-env.sh prod
```

### Ver el YAML Generado (sin aplicar)

```bash
# Ver qué se aplicaría en dev
kubectl kustomize kustomize/overlays/dev

# Ver staging
kubectl kustomize kustomize/overlays/staging

# Ver prod
kubectl kustomize kustomize/overlays/prod
```

### Comparar Ambientes

```bash
# Diferencias entre dev y staging
diff <(kubectl kustomize kustomize/overlays/dev) <(kubectl kustomize kustomize/overlays/staging)
```

### Aplicar Directamente con kubectl

```bash
# Sin script
kubectl apply -k kustomize/overlays/dev
kubectl apply -k kustomize/overlays/staging
kubectl apply -k kustomize/overlays/prod
```

## Cómo Funciona

### Base (kustomize/base/)
Referencia los archivos originales:
- `jenkins-setup-k8s.yaml` - Namespace, ServiceAccount, PVC, Service
- `deployment.yaml` - Deployment
- `jcasc/configmap.yaml` - Configuración de Jenkins

### Overlays (kustomize/overlays/*)
Cada overlay:
1. Importa la base
2. Aplica patches JSON 6902 para cambiar valores
3. Agrega labels/annotations específicas del ambiente
4. Modifica resources, replicas, probes según necesidad

## Ejemplos de Personalización

### Cambiar Replicas en Production

Edita `kustomize/overlays/prod/kustomization.yaml`:

```yaml
patchesJson6902:
  - target:
      kind: Deployment
      name: jenkins
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3  # 3 replicas en prod
```

Luego aplica:
```bash
kubectl apply -k kustomize/overlays/prod
```

### Agregar Variables de Entorno por Ambiente

```yaml
configMapGenerator:
  - name: jenkins-casc-config-dev
    literals:
      - BACKUP_ENABLED=false
      - DEBUG_MODE=true
```

### Cambiar Image Tag por Ambiente

```yaml
images:
  - name: jenkins/jenkins
    newName: jenkins/jenkins
    newTag: 2.504-jdk21-dev  # Dev usa imagen con extras
```

## Operaciones Comunes

### Listar todos los recursos que se aplicarían

```bash
kubectl kustomize kustomize/overlays/dev
```

### Secar (dry-run) antes de aplicar

```bash
kubectl apply -k kustomize/overlays/dev --dry-run=client
```

### Aplicar solo un namespace específico

```bash
kubectl apply -k kustomize/overlays/dev -n jenkins
```

### Eliminar un overlay completo

```bash
kubectl delete -k kustomize/overlays/dev
```

## Migrando desde setup.sh a Kustomize

Si antes usabas:
```bash
./scripts/setup.sh
```

Ahora puedes usar:
```bash
# Para desarrollo
./scripts/deploy-env.sh dev

# O directamente con kubectl
kubectl apply -k kustomize/overlays/dev
```

Los cambios que hacías en `deployment.yaml` ahora los haces en el overlay correspondiente:
- **Dev**: `kustomize/overlays/dev/kustomization.yaml`
- **Staging**: `kustomize/overlays/staging/kustomization.yaml`
- **Prod**: `kustomize/overlays/prod/kustomization.yaml`

## Próximos Pasos

### Agregar Más Personalización

- Cambiar réplicas dinámicamente
- Agregar service de monitoreo por ambiente
- Configurar Ingress diferente por ambiente
- Variables de entorno por ambiente

### Validar Configuración

```bash
# Instalar kubeval
brew install kubeval

# Validar el YAML generado
kubectl kustomize kustomize/overlays/dev | kubeval
```

### Integrar con CI/CD

- Pre-commit: validar YAML antes de pushear
- CI: ejecutar `kustomize build` en PR
- CD: desplegar automáticamente con `kubectl apply -k`

### Sealed Secrets para Credenciales

Para manejar secretos de forma segura:
```bash
brew install sealed-secrets

# Crear secreto sellado
echo -n mypassword | kubectl create secret generic my-secret --dry-run=client --from-file=/dev/stdin | kubeseal -o yaml
```

## Recursos Útiles

- [Documentación oficial de Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [Kustomize por Ejemplos](https://github.com/kubernetes-sigs/kustomize/tree/master/examples)
- [JSON Patch RFC 6902](https://tools.ietf.org/html/rfc6902)
- [Kubectl Kustomize Documentation](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/)

## Troubleshooting

### "command not found: kustomize"

Instala Kustomize:
```bash
brew install kustomize  # macOS
```

### Error "base not found"

Verifica que los paths en `bases` son relativos al archivo `kustomization.yaml`:
```yaml
bases:
  - ../../base  # Correcto (sube 2 niveles)
  # No:
  # - ./base     # Incorrecto
```

### ConfigMap hash mismatch

Los ConfigMaps tienen un hash automático. Si ves errores de hash:
```bash
kubectl rollout restart deployment/jenkins -n jenkins
```

### Quiero ver exactamente qué se va a aplicar

```bash
kubectl kustomize kustomize/overlays/dev > preview.yaml
# Edita preview.yaml
kubectl apply -f preview.yaml
```
