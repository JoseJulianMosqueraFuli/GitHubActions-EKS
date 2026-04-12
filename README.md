# Loadtest API

API de carga de CPU para pruebas de autoescalado en Kubernetes. Genera carga de CPU al porcentaje indicado durante 10 segundos.

## Endpoints

| Ruta | Descripción |
|------|-------------|
| `GET /health` | Health check |
| `GET /<percent>` | Genera carga de CPU al porcentaje indicado (1-100) |

## Ejecución local

```bash
docker compose up --build
```

La API estará disponible en `http://localhost:8080`.

```bash
# Health check
curl http://localhost:8080/health

# Generar 50% de carga de CPU por 10 segundos
curl http://localhost:8080/50
```

## Despliegue a AWS (EKS)

El proyecto incluye un pipeline de GitHub Actions que construye la imagen Docker, la sube a ECR y despliega a un cluster de EKS.

### Prerequisitos en AWS

1. **Cluster de EKS** funcionando (nombre por defecto: `loadtest-cluster`)
2. **Repositorio en ECR** llamado `loadtest-api`
3. **IAM Role para GitHub Actions** con OIDC y los siguientes permisos:
   - `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`
   - Acceso al cluster EKS (`eks:DescribeCluster`, `eks:ListClusters`)
