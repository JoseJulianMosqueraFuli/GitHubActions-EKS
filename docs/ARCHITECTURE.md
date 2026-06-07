# Architecture - GitHubActions-EKS

## System Overview

End-to-end Cloud Infrastructure project demonstrating CI/CD with GitHub Actions deploying containerized applications to Amazon EKS with auto-scaling capabilities.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEVELOPER WORKFLOW                                  │
│                                                                               │
│   [Developer] ──push──► [GitHub] ──trigger──► [GitHub Actions]                │
│                                                       │                       │
│                                                       ▼                       │
│                                              ┌────────────────┐               │
│                                              │  Build Docker   │               │
│                                              │  Push to ECR    │               │
│                                              └───────┬────────┘               │
│                                                      │                        │
└──────────────────────────────────────────────────────┼────────────────────────┘
                                                       │
                                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD                                        │
│                                                                               │
│   ┌─────────────┐         ┌──────────────────────────────────────────┐       │
│   │     ECR     │         │           VPC (10.0.0.0/16)              │       │
│   │  Registry   │─image──►│                                          │       │
│   │             │         │  ┌────────────────────────────────────┐  │       │
│   └─────────────┘         │  │         EKS Cluster                │  │       │
│                           │  │                                    │  │       │
│                           │  │  ┌──────────┐    ┌──────────┐     │  │       │
│                           │  │  │  Node 1  │    │  Node 2  │     │  │       │
│                           │  │  │ t3.medium│    │ t3.medium│     │  │       │
│                           │  │  │          │    │          │     │  │       │
│                           │  │  │ ┌──────┐ │    │ ┌──────┐ │     │  │       │
│                           │  │  │ │ Pod  │ │    │ │ Pod  │ │     │  │       │
│                           │  │  │ │ API  │ │    │ │ API  │ │     │  │       │
│                           │  │  │ └──────┘ │    │ └──────┘ │     │  │       │
│                           │  │  └──────────┘    └──────────┘     │  │       │
│                           │  │          │              │          │  │       │
│                           │  │          └──────┬───────┘          │  │       │
│                           │  │                 │                  │  │       │
│                           │  │          ┌──────┴───────┐          │  │       │
│                           │  │          │  Service LB  │          │  │       │
│                           │  │          │  (port 80)   │          │  │       │
│                           │  │          └──────┬───────┘          │  │       │
│                           │  │                 │                  │  │       │
│                           │  │          ┌──────┴───────┐          │  │       │
│                           │  │          │     HPA      │          │  │       │
│                           │  │          │ 1-10 replicas│          │  │       │
│                           │  │          │ CPU > 50%    │          │  │       │
│                           │  │          └──────────────┘          │  │       │
│                           │  └────────────────────────────────────┘  │       │
│                           │                                          │       │
│                           │  ┌──────────────┐  ┌──────────────┐      │       │
│                           │  │ Subnet Pub 1 │  │ Subnet Pub 2 │      │       │
│                           │  │ us-east-1a   │  │ us-east-1b   │      │       │
│                           │  └──────────────┘  └──────────────┘      │       │
│                           │         │                  │             │       │
│                           │         └────────┬─────────┘             │       │
│                           │                  │                       │       │
│                           │         ┌────────┴────────┐              │       │
│                           │         │ Internet Gateway│              │       │
│                           │         └────────┬────────┘              │       │
│                           └──────────────────┼───────────────────────┘       │
│                                              │                               │
└──────────────────────────────────────────────┼───────────────────────────────┘
                                               │
                                               ▼
                                        ┌──────────────┐
                                        │   Internet   │
                                        │   (Users)    │
                                        └──────────────┘
```

## CI/CD Pipeline Flow

```
┌─────────┐     ┌──────────────┐     ┌───────────┐     ┌──────────┐     ┌─────────┐
│  Push   │────►│  GitHub      │────►│  Build &  │────►│  Update  │────►│ Deploy  │
│  Code   │     │  Actions     │     │  Push ECR │     │ kubeconfig│    │  to EKS │
└─────────┘     └──────────────┘     └───────────┘     └──────────┘     └─────────┘
                      │                                                       │
                      │                                                       ▼
                      │                                              ┌─────────────────┐
                      │                                              │  kubectl apply   │
                      │                                              │  deployment.yaml │
                      │                                              │  hpa.yaml        │
                      │                                              └────────┬────────┘
                      │                                                       │
                      │                                                       ▼
                      │                                              ┌─────────────────┐
                      └─────────────────────────────────────────────►│ Rollout Status  │
                                                                     │ (timeout: 120s) │
                                                                     └─────────────────┘
```

## Auto-Scaling Behavior

```
                    CPU Usage Over Time
    100% ┤
         │                    ╭──╮
     80% ┤               ╭───╯  ╰───╮
         │           ╭───╯           ╰───╮
     50% ┤─ ─ ─ ─ ─╱─ ─ ─THRESHOLD─ ─ ─ ╲─ ─ ─ ─ ─
         │      ╭──╯                       ╰──╮
     20% ┤──────╯                              ╰──────
         │
      0% ┤
         └────────────────────────────────────────────── Time
              │         │                   │
              │         ▼                   ▼
              │    Scale UP (2 pods/60s)  Scale DOWN (1 pod/60s)
              ▼
         1 replica                     Back to min

    Replicas: 1 ──► 3 ──► 5 ──► 7 ──► 5 ──► 3 ──► 1
```

## Terraform Infrastructure

| Resource | Purpose | Configuration |
|----------|---------|---------------|
| VPC | Network isolation | 10.0.0.0/16, 2 public subnets |
| Internet Gateway | Public access | Attached to VPC |
| EKS Cluster | Container orchestration | v1.28+, API auth mode |
| Node Group | Worker nodes | 2x t3.medium, auto-scaling |
| ECR | Container registry | Lifecycle: keep last 10 images |
| IAM Access Entry | CI/CD access | GitHub Actions IAM user |

## Cost Estimation (Monthly)

| Resource | Cost |
|----------|------|
| EKS Control Plane | ~$73 |
| 2x t3.medium nodes | ~$60 |
| Load Balancer | ~$16 |
| ECR Storage | ~$1 |
| Data Transfer | ~$5 |
| **Total** | **~$155/month** |

> **Tip**: Destroy with `terraform destroy` when not in use for demos.
