# Ingress - Acceso HTTP/HTTPS a Jenkins

Esta carpeta documenta cómo configurar **Ingress** para acceder a Jenkins usando hostnames en lugar de IP:puerto.

## ¿Qué es Ingress?

**Ingress** es un recurso de Kubernetes que:

- 🌐 **Acceso HTTP/HTTPS**: Expone servicios en el puerto 80/443
- 🔗 **Hostnames**: Accede a Jenkins via `jenkins.local` en lugar de `192.168.49.2:32000`
- 🔄 **Balanceo**: Distribuye tráfico entre múltiples réplicas
- 🔒 **SSL/TLS**: Soporte para certificados HTTPS
- 🚀 **Routing**: Soporta path-based y hostname-based routing

## Ventajas sobre NodePort

| Aspecto | NodePort | Ingress |
|--------|----------|---------|
| **Acceso** | IP:puerto (192.168.49.2:32000) | Hostname (jenkins.local) |
| **Puertos** | 30000-32767 | 80, 443 |
| **URLs** | Corta (http://ip:32000) | Profesional (http://jenkins.local) |
| **SSL/TLS** | Manual | Automático con cert-manager |
| **Escalabilidad** | Limitada | Excelente |

## Setup Rápido

### 1. Habilitar Ingress en Minikube

```bash
# Ejecutar script de setup
./scripts/setup-ingress.sh
```

Este script:
- ✅ Verifica que Minikube esté corriendo
- ✅ Habilita el addon de ingress
- ✅ Configura /etc/hosts con los hostnames
- ✅ Espera a que el controlador esté listo

### 2. Desplegar Jenkins

```bash
# Con Ingress automáticamente
./scripts/deploy-env.sh dev
```

### 3. Acceder a Jenkins

```bash
# Abrir en navegador
http://jenkins-dev.local
http://jenkins-staging.local
http://jenkins.local
```

## Hostnames por Ambiente

| Ambiente | Hostname | Uso |
|----------|----------|-----|
| **Development** | jenkins-dev.local | Desarrollo y testing |
| **Staging** | jenkins-staging.local | Pre-producción |
| **Production** | jenkins.local | Producción |

## Configuración por Ambiente

### Development (dev)

```yaml
Host: jenkins-dev.local
TLS: Deshabilitado (HTTP)
Rate Limiting: Ninguno
Certificado: Opcional
```

**Acceso:**
```bash
http://jenkins-dev.local
```

### Staging

```yaml
Host: jenkins-staging.local
TLS: Habilitado (HTTPS)
Certificado: Let's Encrypt Staging
Rate Limiting: Ninguno
```

**Acceso:**
```bash
https://jenkins-staging.local
```

### Production

```yaml
Host: jenkins.local
TLS: Habilitado (HTTPS)
Certificado: Let's Encrypt Production
Rate Limiting: 100 req/s, 50 RPS
Affinidad: Pod anti-affinity
```

**Acceso:**
```bash
https://jenkins.local
```

## Estructura de Archivos

```
kustomize/
├── base/
│   └── ingress.yaml              # Base Ingress común
└── overlays/
    ├── dev/
    │   └── ingress-patch.yaml    # Dev: HTTP simple
    ├── staging/
    │   └── ingress-patch.yaml    # Staging: HTTPS
    └── prod/
        └── ingress-patch.yaml    # Prod: HTTPS + rate limit
```

## Ver Ingress en Acción

```bash
# Listar todos los Ingress
kubectl get ingress -n jenkins

# Ver detalles del Ingress de Jenkins
kubectl describe ingress jenkins -n jenkins

# Ver los eventos del Ingress
kubectl get events -n jenkins | grep ingress

# Verificar que está en estado Ready
kubectl get ingress jenkins -n jenkins -o wide
```

**Ejemplo de salida:**
```
NAME      CLASS   HOSTS              ADDRESS        PORTS   AGE
jenkins   nginx   jenkins-dev.local  192.168.49.2   80      5m
```

## Troubleshooting

### No puedo acceder a jenkins.local

**Causa:** /etc/hosts no está configurado

**Solución:**
```bash
# Verificar que el host está en /etc/hosts
grep jenkins-dev.local /etc/hosts

# Si no está, agregar manualmente:
echo "192.168.49.2 jenkins-dev.local jenkins-staging.local jenkins.local" | sudo tee -a /etc/hosts

# O ejecutar el script de setup
./scripts/setup-ingress.sh
```

### Ingress no tiene ADDRESS asignada

**Causa:** El controlador ingress aún no está listo

**Solución:**
```bash
# Esperar a que esté listo
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Verificar estado
kubectl get pods -n ingress-nginx
```

### "Connection refused" al acceder a Jenkins

**Causa:** Jenkins pod no está running

**Solución:**
```bash
# Verificar estado del pod
kubectl get pods -n jenkins

# Ver logs
kubectl logs -n jenkins -l app=jenkins

# Reiniciar
kubectl rollout restart deployment/jenkins -n jenkins
```

### DNS no resuelve hostname

**macOS:**
```bash
# Limpiar DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Linux:**
```bash
# Limpiar DNS cache (systemd-resolved)
sudo systemctl restart systemd-resolved

# O con nscd
sudo systemctl restart nscd
```

## Opciones Avanzadas

### Agregar más hostnames

Edita el kustomization.yaml del ambiente:

```yaml
# kustomize/overlays/dev/ingress-patch.yaml
spec:
  rules:
    - host: jenkins-dev.local
      http:
        paths:
          - path: /
            backend:
              service:
                name: jenkins
                port:
                  number: 8080
    - host: jenkins-alt-dev.local  # Nuevo hostname
      http:
        paths:
          - path: /
            backend:
              service:
                name: jenkins
                port:
                  number: 8080
```

### Usar HTTPS en Development

Por defecto dev es HTTP. Para agregar HTTPS:

```yaml
# kustomize/overlays/dev/ingress-patch.yaml
spec:
  tls:
    - hosts:
        - jenkins-dev.local
      secretName: jenkins-dev-tls
  rules:
    - host: jenkins-dev.local
      http:
        paths:
          - path: /
            backend:
              service:
                name: jenkins
                port:
                  number: 8080
```

### Path-based routing

Para servir Jenkins en /jenkins:

```yaml
spec:
  rules:
    - host: jenkins.local
      http:
        paths:
          - path: /jenkins
            pathType: Prefix
            backend:
              service:
                name: jenkins
                port:
                  number: 8080
```

Luego accede a `http://jenkins.local/jenkins`

## Cert-Manager (Certificados Automáticos)

Para usar Let's Encrypt automáticamente:

```bash
# Instalar cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Esperar a que esté listo
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s

# Los certificados se crean automáticamente en staging/prod
```

## Limpieza

```bash
# Eliminar Ingress (mantiene Jenkins)
kubectl delete ingress jenkins -n jenkins

# Eliminar todo (incluye Jenkins)
kubectl delete namespace jenkins

# Deshabilitar ingress addon en Minikube (opcional)
minikube addons disable ingress
```

## Próximos Pasos

### Monitoreo
- Agregar Prometheus + Grafana para monitoreo
- Alertas basadas en métricas

### Seguridad
- Usar sealed-secrets para credenciales
- Network policies para restringir tráfico
- Pod security policies

### Alta Disponibilidad
- Múltiples réplicas de Jenkins
- Shared storage entre réplicas
- Load balancing

### CI/CD
- Integrar con GitHub Actions / GitLab CI
- Desplegar automáticamente a diferentes ambientes
- Validar Ingress con tests

## Recursos Útiles

- [Documentación oficial de Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Cert-Manager](https://cert-manager.io/)
- [Minikube Ingress Setup](https://minikube.sigs.k8s.io/docs/handbook/ingress/)

## Comparación: NodePort vs Ingress vs LoadBalancer

```
┌─────────────────────────────────────────────────────────────┐
│                      Cliente/Browser                         │
├─────────────────────────────────────────────────────────────┤

NodePort:        IP:30000          (192.168.49.2:32000)
                 ↓
                 Service NodePort
                 ↓
                 Jenkins Pod

Ingress:         Hostname          (jenkins.local)
                 ↓
                 Ingress Controller (nginx)
                 ↓
                 Service ClusterIP
                 ↓
                 Jenkins Pod

LoadBalancer:    DNS Name          (jenkins.example.com)
                 ↓
                 Cloud LoadBalancer (AWS/GCP/Azure)
                 ↓
                 Ingress/Service
                 ↓
                 Jenkins Pod
```

**Conclusión:** Ingress es la mejor opción para Kubernetes puro, combinando flexibilidad de NodePort con elegancia de LoadBalancer.
