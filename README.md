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

```bash
curl http://localhost:8080/health
curl http://localhost:8080/50
```

## Paso a paso: Despliegue a AWS EKS desde GitHub Actions

### Paso 1 — Crear el repositorio ECR en AWS

```bash
aws ecr create-repository \
  --repository-name loadtest-api \
  --region us-east-1
```

Anota el URI del repositorio que te devuelve (algo como `123456789012.dkr.ecr.us-east-1.amazonaws.com/loadtest-api`).

### Paso 2 — Crear el cluster EKS (si no lo tienes)

```bash
# Instalar eksctl si no lo tienes: https://eksctl.io/installation/
eksctl create cluster \
  --name loadtest-cluster \
  --region us-east-1 \
  --nodes 2 \
  --node-type t3.medium
```

Esto tarda ~15 minutos. Si ya tienes un cluster, asegúrate de que el nombre coincida con `EKS_CLUSTER_NAME` en el workflow.

### Paso 3 — Crear un IAM User para GitHub Actions

```bash
aws iam create-user --user-name github-actions-deployer

aws iam attach-user-policy \
  --user-name github-actions-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

aws iam attach-user-policy \
  --user-name github-actions-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

Además, necesitas que el user pueda ejecutar `kubectl` contra el cluster. Agrega el user al `aws-auth` ConfigMap del cluster:

```bash
eksctl create iamidentitymapping \
  --cluster loadtest-cluster \
  --region us-east-1 \
  --arn arn:aws:iam::<ACCOUNT_ID>:user/github-actions-deployer \
  --group system:masters \
  --username github-actions-deployer
```

Luego genera las access keys:

```bash
aws iam create-access-key --user-name github-actions-deployer
```

Esto te devuelve `AccessKeyId` y `SecretAccessKey`. Guárdalos, los necesitas en el siguiente paso.

### Paso 4 — Configurar secrets en GitHub

1. Ve a tu repositorio en GitHub
2. Settings → Secrets and variables → Actions
3. Click en "New repository secret" y crea estos dos:

| Secret | Valor |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | El `AccessKeyId` del paso anterior |
| `AWS_SECRET_ACCESS_KEY` | El `SecretAccessKey` del paso anterior |

### Paso 5 — Ajustar variables del workflow (si es necesario)

Abre `.github/workflows/deploy.yml` y verifica que estas variables coincidan con tu setup:

```yaml
env:
  AWS_REGION: us-east-1          # Tu región
  ECR_REPOSITORY: loadtest-api   # Nombre del repo ECR (paso 1)
  EKS_CLUSTER_NAME: loadtest-cluster  # Nombre del cluster (paso 2)
  K8S_NAMESPACE: default         # Namespace de K8s
```

### Paso 6 — Push y desplegar

```bash
git add .
git commit -m "Add CI/CD pipeline for EKS"
git push origin main
```

El pipeline se dispara automáticamente en push a `main`. También puedes dispararlo manualmente desde GitHub → Actions → "Build & Deploy to EKS" → Run workflow.

### Paso 7 — Verificar el despliegue

```bash
# Configurar kubectl local
aws eks update-kubeconfig --region us-east-1 --name loadtest-cluster

# Ver pods
kubectl get pods

# Ver el servicio y obtener la URL del LoadBalancer
kubectl get svc loadtest-api
```

La columna `EXTERNAL-IP` del servicio es la URL de tu API. Puede tardar 2-3 minutos en asignarse.

```bash
curl http://<EXTERNAL-IP>/health
curl http://<EXTERNAL-IP>/50
```

## Qué hace el pipeline

1. Se dispara en push a `main` o manualmente
2. Autentica con AWS usando access keys (secrets de GitHub)
3. Construye la imagen Docker y la sube a ECR con tag del SHA del commit
4. Configura kubectl para el cluster EKS
5. Aplica los manifiestos de Kubernetes con la imagen nueva
6. Espera a que el rollout complete (timeout: 120s)

## Kubernetes

- `k8s/deployment.yaml` — Deployment + Service (LoadBalancer) con health checks y resource limits
- `k8s/hpa.yaml` — Autoescalado de 1 a 10 réplicas cuando CPU > 50%

## Estructura

```
├── .github/workflows/deploy.yml   # CI/CD pipeline
├── k8s/
│   ├── deployment.yaml            # Deployment + Service
│   └── hpa.yaml                   # HPA
├── app.py                         # API Flask
├── Dockerfile
├── docker-compose.yml
└── requirements.txt
```
