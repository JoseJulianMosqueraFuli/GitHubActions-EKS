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

### Configurar OIDC entre GitHub y AWS

```bash
# Crear el identity provider de GitHub en AWS
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Crear un IAM Role con trust policy para tu repositorio:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<GITHUB_ORG>/<REPO_NAME>:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### Secrets en GitHub

Configurar en Settings > Secrets and variables > Actions:

| Secret | Descripción |
|--------|-------------|
| `AWS_ROLE_ARN` | ARN del IAM Role creado (ej: `arn:aws:iam::123456789012:role/github-actions-eks`) |

### Variables del workflow

Editar en `.github/workflows/deploy.yml` si tu setup difiere:

| Variable | Default | Descripción |
|----------|---------|-------------|
| `AWS_REGION` | `us-east-1` | Región de AWS |
| `ECR_REPOSITORY` | `loadtest-api` | Nombre del repo en ECR |
| `EKS_CLUSTER_NAME` | `loadtest-cluster` | Nombre del cluster EKS |
| `K8S_NAMESPACE` | `default` | Namespace de Kubernetes |

### Flujo del pipeline

1. Se dispara en push a `main` o manualmente via `workflow_dispatch`
2. Autentica con AWS usando OIDC (sin access keys)
3. Construye la imagen Docker y la sube a ECR con tag del SHA del commit
4. Actualiza kubeconfig para el cluster EKS
5. Aplica los manifiestos de Kubernetes con la imagen nueva
6. Espera a que el rollout complete (timeout: 120s)

## Kubernetes

Los manifiestos en `k8s/` incluyen:

- **deployment.yaml**: Deployment con health checks (readiness + liveness) y resource limits + Service tipo LoadBalancer
- **hpa.yaml**: HorizontalPodAutoscaler que escala de 1 a 10 réplicas cuando el CPU promedio supera 50%

## Estructura del proyecto

```
├── .github/workflows/deploy.yml   # CI/CD pipeline
├── k8s/
│   ├── deployment.yaml            # Deployment + Service
│   └── hpa.yaml                   # Autoescalado horizontal
├── app.py                         # API Flask
├── Dockerfile
├── docker-compose.yml             # Ejecución local
└── requirements.txt
```
