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

## Infraestructura con Terraform

La carpeta `terraform/` contiene todo lo necesario para provisionar la infraestructura en AWS:

- VPC con subnets públicas e internet gateway
- Cluster EKS con authentication mode API + ConfigMap
- Node group (2x t3.medium por defecto)
- Repositorio ECR con lifecycle policy (mantiene últimas 10 imágenes)
- Access entry para el IAM user de GitHub Actions

### Desplegar infraestructura

```bash
cd terraform

# Inicializar
terraform init

# Ver qué se va a crear
terraform plan

# Aplicar
terraform apply
```

Esto tarda ~15 minutos (principalmente el cluster EKS).

### Variables de Terraform

| Variable | Default | Descripción |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | Región de AWS |
| `cluster_name` | `githubActions-EKS` | Nombre del cluster EKS |
| `ecr_repository_name` | `loadtest-api` | Nombre del repo ECR |
| `github_iam_user_arn` | `arn:aws:iam::231629457413:user/josejmosqueraf@unicauca.edu.co` | ARN del IAM user de GitHub Actions |
| `node_instance_type` | `t3.medium` | Tipo de instancia para los nodos |
| `node_desired_size` | `2` | Número de nodos deseados |

Para usar valores diferentes:

```bash
terraform apply -var="cluster_name=mi-cluster" -var="node_instance_type=t3.small"
```

### Destruir infraestructura

```bash
terraform destroy
```

## CI/CD con GitHub Actions

El pipeline (`.github/workflows/deploy.yml`) se dispara manualmente desde GitHub Actions.

### Configurar secrets en GitHub

1. Ve a tu repo → Settings → Environments → crear environment "AWS"
2. Agrega estos secrets en el environment:

| Secret | Descripción |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | Access key del IAM user |
| `AWS_SECRET_ACCESS_KEY` | Secret key del IAM user |

### Ejecutar el pipeline

GitHub → Actions → "Build & Deploy to EKS" → Run workflow

### Qué hace el pipeline

1. Autentica con AWS usando access keys
2. Construye la imagen Docker y la sube a ECR (tag: SHA del commit)
3. Configura kubectl para el cluster EKS
4. Aplica los manifiestos de Kubernetes
5. Espera a que el rollout complete (timeout: 120s)

### Verificar el despliegue

```bash
aws eks update-kubeconfig --region us-east-1 --name githubActions-EKS
kubectl get pods
kubectl get svc loadtest-api
```

La columna `EXTERNAL-IP` del service es la URL de tu API.

## Kubernetes

- `k8s/deployment.yaml` — Deployment + Service (LoadBalancer) con health checks y resource limits
- `k8s/hpa.yaml` — Autoescalado de 1 a 10 réplicas cuando CPU promedio > 50%

## Estructura del proyecto

```
├── .github/workflows/deploy.yml   # CI/CD pipeline
├── k8s/
│   ├── deployment.yaml            # Deployment + Service
│   └── hpa.yaml                   # HPA
├── terraform/
│   ├── versions.tf                # Provider y versiones
│   ├── variables.tf               # Variables configurables
│   ├── vpc.tf                     # VPC, subnets, IGW
│   ├── eks.tf                     # Cluster EKS + access entry
│   ├── nodes.tf                   # Node group
│   ├── ecr.tf                     # ECR repository
│   └── outputs.tf                 # Outputs útiles
├── app.py                         # API Flask
├── Dockerfile
├── docker-compose.yml
└── requirements.txt
```
