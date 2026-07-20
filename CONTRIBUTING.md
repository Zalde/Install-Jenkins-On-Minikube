# Contributing to Jenkins on Kubernetes

¡Gracias por tu interés en contribuir! 🎉

Este documento explica cómo contribuir al proyecto.

## Código de Conducta

Este proyecto se adhiere a un código de conducta que todos esperamos que sigan:

- 🤝 Sé respetuoso con otros contribuyentes
- 🎯 Enfócate en el problema, no en la persona
- 📚 Sé receptivo a críticas constructivas
- 🌍 Sé inclusivo con otros

## Cómo Contribuir

### 1. Reportar Bugs

Si encuentras un bug:

1. **Verifica si ya está reportado**: Busca en [Issues](https://github.com/Zalde/Install-Jenkins-On-Minikube/issues)
2. **Crea un issue** con:
   - Descripción clara del problema
   - Pasos para reproducirlo
   - Comportamiento esperado vs. actual
   - Tu entorno (OS, versiones de herramientas)

**Ejemplo:**

```
Title: Jenkins pod no inicia con Kustomize dev

Descripción:
Al ejecutar ./scripts/deploy-env.sh dev, el pod queda en CrashLoopBackOff

Pasos:
1. ./scripts/setup-ingress.sh
2. ./scripts/deploy-env.sh dev
3. kubectl get pods -n jenkins

Esperado: Pod Running
Actual: Pod CrashLoopBackOff

Entorno:
- macOS 12.6
- minikube v1.32.0
- kubectl v1.29.0
- Kustomize v5.0.0
```

### 2. Sugerir Mejoras

Para sugerir mejoras:

1. **Abre un Issue** o **Discussion** con:
   - Descripción clara de la mejora
   - Caso de uso / por qué es útil
   - Posibles implementaciones

2. **Espera feedback** de los mantenedores

### 3. Contribuir Código

#### Prerequisitos

- Fork el repositorio
- Clona tu fork localmente
- Crea una rama de feature

```bash
git clone https://github.com/TU_USUARIO/Install-Jenkins-On-Minikube.git
cd Install-Jenkins-On-Minikube
git checkout -b feature/mi-mejora
```

#### Cambios Esperados

**Scripts bash:**
- ✅ Seguir convenciones de shell
- ✅ Usar funciones para código reutilizable
- ✅ Incluir colores y mensajes claros
- ✅ Validar prerequisitos
- ✅ Manejar errores

**YAML (Kubernetes):**
- ✅ Indentar con 2 espacios
- ✅ Incluir comentarios explicativos
- ✅ Seguir convenciones de naming
- ✅ Incluir labels y annotations
- ✅ Usar namespaces adecuados

**Documentación:**
- ✅ Markdown correcto
- ✅ Enlaces funcionales
- ✅ Ejemplos prácticos
- ✅ Traducciones si aplica

#### Commit Messages

Usa commits claros y descriptivos:

```bash
# ✅ Bueno
git commit -m "Add monitoring stack with Prometheus and Grafana

- Create namespace and ConfigMaps
- Deploy Prometheus with alerts
- Deploy Grafana with datasources
- Add Ingress for access"

# ❌ Evitar
git commit -m "fix stuff"
git commit -m "update files"
git commit -m "wip"
```

#### Pull Request

1. **Pushea tu rama**:
   ```bash
   git push origin feature/mi-mejora
   ```

2. **Abre un PR** con:
   - Título claro y descriptivo
   - Descripción con cambios realizados
   - Referencia a issue relacionado (si existe)
   - Pasos para testar la mejora

3. **Espera review**: Los mantenedores revisarán tu PR

**Ejemplo PR:**

```markdown
## Summary

Agregar soporte para usar imagen custom de Jenkins

## Changes

- Add environment variable JENKINS_IMAGE en deploy-env.sh
- Update kustomize base para soportar image overrides
- Document en README cómo cambiar image

## Testing

```bash
JENKINS_IMAGE=myregistry.com/jenkins:custom ./scripts/deploy-env.sh dev
kubectl get deployment jenkins -n jenkins -o jsonpath='{.spec.template.spec.containers[0].image}'
# Output: myregistry.com/jenkins:custom
```

## Checklist

- [x] Tests passed
- [x] Documentation updated
- [x] No breaking changes
```

### 4. Mejorar Documentación

La documentación es crucial:

- 📝 Corrige typos
- 📚 Agrega ejemplos
- 🌐 Traduce a otros idiomas
- 📖 Mejora claridad

```bash
git commit -m "Improve kustomize documentation with advanced examples"
```

### 5. Traducir

¿Hablas otro idioma? ¡Ayuda a traducir!

- 🇬🇧 Inglés (en progreso)
- 🇪🇸 Español (completo)
- 🇫🇷 Francés (voluntarios bienvenidos)
- 🇵🇹 Portugués (voluntarios bienvenidos)

## Estándares del Proyecto

### Estructura de Directorios

```
project/
├── README.md               # Documentación principal
├── CONTRIBUTING.md         # Esta guía
├── SECURITY.md            # Políticas de seguridad
├── scripts/               # Scripts bash
├── kustomize/             # Configuración Kustomize
├── monitoring/            # Stack de monitoreo
├── jcasc/                 # Jenkins Configuration as Code
├── ingress/               # Ingress configuration
└── *.yaml                 # Manifests base
```

### Naming Conventions

**Scripts bash:**
```bash
scripts/setup.sh                    # Verbo en infinitivo
scripts/setup-ingress.sh            # Kebab-case
scripts/deploy-env.sh
```

**YAML files:**
```yaml
# Descripciones claras
# metadata.name: kebab-case
# labels: kebab-case
# Comentarios útiles
```

**Variables:**
```bash
VARIABLE_NAME              # UPPER_SNAKE_CASE
local_variable_name        # lower_snake_case
functionName()             # camelCase para funciones bash
```

### Testing

Antes de hacer PR:

1. **Prueba localmente**:
   ```bash
   # Limpiar
   ./scripts/cleanup.sh
   
   # Setup
   ./scripts/setup-ingress.sh
   ./scripts/deploy-env.sh dev
   
   # Verificar
   kubectl get pods -n jenkins
   ```

2. **Valida YAML**:
   ```bash
   kubectl apply -f archivo.yaml --dry-run=client
   ```

3. **Valida Kustomize**:
   ```bash
   kubectl kustomize kustomize/overlays/dev
   ```

### Code Review

Cuando se review tu PR:

- 🤝 Sé abierto a sugerencias
- 💬 Responde comentarios con explicaciones claras
- 🔄 Realiza cambios solicitados
- ⚡ Sé proactivo en mejorar

## Áreas Donde Necesitamos Ayuda

### High Priority

- 🔒 Agregar Helm Chart oficial
- 📊 Prometheus Operator integration
- 🔐 Sealed Secrets support
- 📋 Tests automatizados

### Medium Priority

- 🌐 Traducciones
- 📚 Más ejemplos
- 🐛 Bug fixes reportados
- 💡 Mejoras de UX

### Low Priority

- 🎨 Actualizaciones visuales
- 📖 Documentación adicional
- 🔧 Refactoring
- ✨ Mejoras de código

## Roadmap

Ver [Roadmap en README.md](README.md#roadmap)

Contribuciones alineadas con el roadmap son prioritarias.

## License

Contribuyendo aceptas que tu código sea licenciado bajo MIT.

---

## Preguntas?

- 📖 Lee la documentación
- 💬 Abre una Discussion
- 🐛 Reporta issues
- 📧 Contacta a los mantenedores

¡Gracias por contribuir! 🙏
