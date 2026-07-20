# Contribuyendo a Jenkins en Kubernetes

¡Gracias por tu interés en contribuir! 🎉

Este documento explica cómo contribuir al proyecto.

## Código de Conducta

Este proyecto se adhiere a un código de conducta que todos esperamos que sigan:

- 🤝 Sé respetuoso con otros contribuyentes
- 🎯 Enfócate en el problema, no en la persona
- 📚 Sé receptivo a críticas constructivas
- 🌍 Sé inclusivo con otros

## Cómo Contribuir

### 1. Reportar Errores

Si encuentras un error:

1. **Verifica si ya está reportado**: Busca en [Issues](https://github.com/Zalde/Install-Jenkins-On-Minikube/issues)
2. **Crea un issue** con:
   - Descripción clara del problema
   - Pasos para reproducirlo
   - Comportamiento esperado vs. actual
   - Tu entorno (OS, versiones de herramientas)

**Ejemplo:**

```
Título: Pod de Jenkins no inicia con Kustomize dev

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

1. **Abre un Issue** o **Discusión** con:
   - Descripción clara de la mejora
   - Caso de uso / por qué es útil
   - Posibles implementaciones

2. **Espera retroalimentación** de los mantenedores

### 3. Contribuir Código

#### Prerequisitos

- Hacer fork del repositorio
- Clonar tu fork localmente
- Crear una rama de feature

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
- ✅ Seguir convenciones de nombres
- ✅ Incluir etiquetas y anotaciones
- ✅ Usar namespaces adecuados

**Documentación:**
- ✅ Markdown correcto
- ✅ Enlaces funcionales
- ✅ Ejemplos prácticos
- ✅ Traducciones si aplica

#### Mensajes de Commit

Usa commits claros y descriptivos:

```bash
# ✅ Bueno
git commit -m "Agregar stack de monitoreo con Prometheus y Grafana

- Crear namespace y ConfigMaps
- Desplegar Prometheus con alertas
- Desplegar Grafana con datasources
- Agregar Ingress para acceso"

# ❌ Evitar
git commit -m "corregir cosas"
git commit -m "actualizar archivos"
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
   - Pasos para probar la mejora

3. **Espera revisión**: Los mantenedores revisarán tu PR

**Ejemplo de PR:**

```markdown
## Resumen

Agregar soporte para usar imagen personalizada de Jenkins

## Cambios

- Agregar variable de entorno JENKINS_IMAGE en deploy-env.sh
- Actualizar base de kustomize para soportar overrides de imagen
- Documentar en README cómo cambiar imagen

## Pruebas

```bash
JENKINS_IMAGE=miregistry.com/jenkins:personalizado ./scripts/deploy-env.sh dev
kubectl get deployment jenkins -n jenkins -o jsonpath='{.spec.template.spec.containers[0].image}'
# Resultado: miregistry.com/jenkins:personalizado
```

## Lista de Verificación

- [x] Tests pasados
- [x] Documentación actualizada
- [x] Sin cambios que rompan compatibilidad
```

### 4. Mejorar Documentación

La documentación es crucial:

- 📝 Corrige errores tipográficos
- 📚 Agrega ejemplos
- 🌐 Traduce a otros idiomas
- 📖 Mejora claridad

```bash
git commit -m "Mejorar documentación de kustomize con ejemplos avanzados"
```

### 5. Traducir

¿Hablas otro idioma? ¡Ayuda a traducir!

- 🇪🇸 Español (completo)
- 🇬🇧 Inglés (en progreso)
- 🇫🇷 Francés (se buscan voluntarios)
- 🇵🇹 Portugués (se buscan voluntarios)

## Estándares del Proyecto

### Estructura de Directorios

```
proyecto/
├── README.md               # Documentación principal
├── CONTRIBUTING.md         # Esta guía
├── SECURITY.md            # Políticas de seguridad
├── scripts/               # Scripts bash
├── kustomize/             # Configuración Kustomize
├── monitoring/            # Stack de monitoreo
├── jcasc/                 # Jenkins Configuration as Code
├── ingress/               # Configuración de Ingress
└── *.yaml                 # Manifests base
```

### Convenciones de Nombres

**Scripts bash:**
```bash
scripts/setup.sh                    # Verbo en infinitivo
scripts/setup-ingress.sh            # Kebab-case
scripts/deploy-env.sh
```

**Archivos YAML:**
```yaml
# Descripciones claras
# metadata.name: kebab-case
# labels: kebab-case
# Comentarios útiles
```

**Variables:**
```bash
NOMBRE_VARIABLE              # MAYÚSCULAS_CON_GUIONES
variable_local               # minúsculas_con_guiones
nombreFuncion()              # camelCase para funciones bash
```

### Pruebas

Antes de hacer un PR:

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

### Revisión de Código

Cuando se revise tu PR:

- 🤝 Sé abierto a sugerencias
- 💬 Responde comentarios con explicaciones claras
- 🔄 Realiza cambios solicitados
- ⚡ Sé proactivo en mejorar

## Áreas Donde Necesitamos Ayuda

### Prioridad Alta

- 🔒 Agregar Helm Chart oficial
- 📊 Integración con Prometheus Operator
- 🔐 Soporte para Sealed Secrets
- 📋 Tests automatizados

### Prioridad Media

- 🌐 Traducciones
- 📚 Más ejemplos
- 🐛 Corrección de errores reportados
- 💡 Mejoras de experiencia

### Prioridad Baja

- 🎨 Actualizaciones visuales
- 📖 Documentación adicional
- 🔧 Refactorización
- ✨ Mejoras de código

## Mapa de Ruta

Ver [Roadmap en README.md](README.md#️-roadmap)

Las contribuciones alineadas con el mapa de ruta tienen prioridad.

---

## ¿Preguntas?

- 📖 Lee la documentación
- 💬 Abre una Discusión
- 🐛 Reporta issues
- 📧 Contacta a los mantenedores

¡Gracias por contribuir! 🙏
