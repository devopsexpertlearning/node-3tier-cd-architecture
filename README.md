# Node.js 3-Tier Application — Continuous Delivery Architecture on AWS

> Toptal DevOps Engineering Task — Production-grade CI/CD architecture for a scalable, secure 3-tier Node.js application deployed on Amazon EKS with full infrastructure-as-code, automated deployments, observability, and disaster recovery.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Architecture Diagram](#architecture-diagram)
- [Technology Stack](#technology-stack)
- [Infrastructure Components](#infrastructure-components)
- [CI/CD Pipelines](#cicd-pipelines)
- [Security Design](#security-design)
- [Observability & Logging](#observability--logging)
- [Backup & Disaster Recovery](#backup--disaster-recovery)
- [CDN & Content Distribution](#cdn--content-distribution)
- [High Availability & Zero-Downtime Deployments](#high-availability--zero-downtime-deployments)
- [Local Development](#local-development)
- [Repository Structure](#repository-structure)
- [GitHub Secrets & Variables Setup](#github-secrets--variables-setup)
- [Deployment Guide](#deployment-guide)
- [Operational Scripts](#operational-scripts)
- [Requirements Checklist](#requirements-checklist)

---

## Architecture Overview

The application is a classic 3-tier architecture:

```
Internet
    │
    ▼
CloudFront (CDN)
    │
    ▼
Application Load Balancer (public subnets)
    │
    ├──► /api/*  ──► API Service  ──► EKS Fargate Pod (api-deployment)
    │                                        │
    └──► /*      ──► Web Service  ──► EKS Fargate Pod (web-deployment)
                                             │
                                  Private Subnet
                                             │
                                             ▼
                                  RDS PostgreSQL (private subnets, no internet access)
```

**Key design decisions:**

| Requirement | Implementation |
|---|---|
| Web + API exposed to internet | ALB (public subnets) → CloudFront CDN |
| DB not accessible from internet | RDS in private subnets, SG allows only EKS pod SG |
| Handle server failures | EKS Fargate (managed nodes) + HPA (min 2 replicas) |
| Zero-downtime updates | RollingUpdate strategy (maxUnavailable=0), rollback on failure |
| Fully automated deployment | GitHub Actions 5-stage pipeline |
| Daily backups | RDS automated backups (7-day retention) + Velero for EKS |
| Centralised logs | CloudWatch Logs via Fargate log router (Fluent Bit) + ADOT |
| Historical metrics | CloudWatch metrics + ADOT (OpenTelemetry) collector |
| CDN | AWS CloudFront with origin pointing to ALB |
| IaC | Terraform — 13 modular components, remote state in S3 |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           AWS Cloud (us-east-1)                     │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                   VPC (10.0.0.0/16)                         │   │
│   │                                                             │   │
│   │  ┌──────────────────────────┐  ┌─────────────────────────┐ │   │
│   │  │   Public Subnets          │  │   Private Subnets       │ │   │
│   │  │  10.0.1.0/24             │  │  10.0.10.0/24           │ │   │
│   │  │  10.0.2.0/24             │  │  10.0.20.0/24           │ │   │
│   │  │                          │  │                         │ │   │
│   │  │  ┌────────────────────┐  │  │  ┌───────────────────┐  │ │   │
│   │  │  │  ALB               │  │  │  │  EKS Fargate      │  │ │   │
│   │  │  │  (web-api-alb)     │  │  │  │  ┌─────────────┐  │  │ │   │
│   │  │  │  Port 80/443       │  │  │  │  │ api-deploy  │  │  │ │   │
│   │  │  │  /api/* → api:3001 │──┼──┼──┤  │ (2-10 pods) │  │  │ │   │
│   │  │  │  /* → web:3000     │  │  │  │  └─────────────┘  │  │ │   │
│   │  │  └────────────────────┘  │  │  │  ┌─────────────┐  │  │ │   │
│   │  │                          │  │  │  │ web-deploy  │  │  │ │   │
│   │  │  ┌────────────────────┐  │  │  │  │ (2-10 pods) │  │  │ │   │
│   │  │  │  NAT Gateway       │  │  │  │  └─────────────┘  │  │ │   │
│   │  │  └────────────────────┘  │  │  └───────────────────┘  │ │   │
│   │  └──────────────────────────┘  │                         │ │   │
│   │                                │  ┌───────────────────┐  │ │   │
│   │                                │  │  RDS PostgreSQL    │  │ │   │
│   │                                │  │  (db.t3.micro)     │  │ │   │
│   │                                │  │  Port 5432        │  │ │   │
│   │                                │  └───────────────────┘  │ │   │
│   │                                └─────────────────────────┘ │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐    │
│   │  ECR         │  │  S3 Buckets  │  │  CloudWatch           │    │
│   │  api repo    │  │  - tf state  │  │  - Log groups         │    │
│   │  web repo    │  │  - alb logs  │  │  - RDS alarms         │    │
│   └──────────────┘  │  - velero    │  │  - ALB alarms         │    │
│                     │  - tf plans  │  └───────────────────────┘    │
│                     └──────────────┘                                │
└─────────────────────────────────────────────────────────────────────┘
         ▲
         │ HTTPS
         │
┌────────────────┐
│  CloudFront    │  ← Global CDN (PriceClass_100)
│  Distribution  │    Static assets cached (stylesheets, images)
│                │    Dynamic content pass-through (TTL=0)
└────────────────┘
         ▲
         │
    End Users
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| **Frontend** | Node.js 24, Express.js, Jade templates |
| **Backend API** | Node.js 24, Express.js, pg (PostgreSQL client) |
| **Database** | PostgreSQL 17 (RDS managed) |
| **Containers** | Docker (node:24-alpine multi-stage builds) |
| **Orchestration** | Kubernetes on AWS EKS (Fargate) |
| **Ingress** | Envoy Gateway (HTTPRoute) + AWS ALB |
| **IaC** | Terraform >= 1.10 with modular design |
| **CI/CD** | GitHub Actions |
| **Image Registry** | Amazon ECR |
| **Image Security** | Trivy vulnerability scanning (CRITICAL gate) |
| **CDN** | AWS CloudFront |
| **Monitoring** | CloudWatch + ADOT (OpenTelemetry) + Metrics Server |
| **Backup** | RDS automated backups + Velero (EKS backup) |
| **Secrets** | AWS Secrets Manager → Kubernetes secrets |
| **Logging** | CloudWatch Logs via Fargate Fluent Bit log router |

---

## Infrastructure Components

All infrastructure is provisioned via Terraform (`terraform/environments/dev/`). The architecture uses **13 Terraform modules**:

### Modules

| Module | Purpose |
|---|---|
| `vpc` | VPC, public/private subnets, IGW, NAT Gateway, route tables |
| `security-groups` | SGs for EKS cluster, EKS pods, ALB, RDS — zero-trust between tiers |
| `iam` | IAM roles for EKS, Fargate execution, IRSA, ALB controller |
| `eks` | EKS cluster (1.33), OIDC provider for IRSA |
| `fargate-profile` | Fargate profiles: k8s-core, web-api, k8s-logs-monitoring |
| `eks-addons-helm` | Metrics Server, Envoy Gateway, Velero, ADOT collector |
| `ecr` | ECR repositories (api, web) with time-based lifecycle policy (1 day dev) |
| `s3` | S3 buckets: ALB access logs, Velero backups, Terraform state |
| `rds` | PostgreSQL 17 RDS with encryption, automated backups, Secrets Manager |
| `alb` | ALB with target groups for web (port 3000) and api (port 3001) |
| `cloudfront` | CloudFront CDN with static asset caching behaviors |
| `cloudwatch` | CloudWatch log groups, RDS/ALB alarms, SNS notifications |

### Remote State

Terraform state is stored remotely in S3 with DynamoDB locking:

```
s3://devopsexpert-shared/terraform/environments/dev/terraform.tfstate
```

---

## CI/CD Pipelines

Two independent GitHub Actions workflows handle infrastructure and application deployments separately.

### 1. Terraform Pipeline (`.github/workflows/terraform.yaml`)

Triggers on changes to `terraform/environments/dev/**`:

```
Push/PR to main
       │
       ▼
  ┌─────────┐
  │VALIDATE │  terraform fmt, init, validate
  └────┬────┘
       │
       ▼
  ┌─────────┐
  │  PLAN   │  terraform plan → artifact + S3 audit trail
  └────┬────┘       (savedplan/environments/dev/tfplan-{date-time})
       │
       ▼ (push to main only)
  ┌─────────┐
  │  APPLY  │  ← GitHub Environment approval gate (environment: dev)
  └─────────┘  Downloads exact plan from S3 → terraform apply
```

**Enterprise features:**
- Plan binary saved to S3 for audit: `s3://devopsexpert-shared/savedplan/environments/dev/tfplan-{timestamp}`
- Apply downloads the exact approved plan — prevents plan/apply race condition
- S3 metadata tagged with `run_id`, `sha`, `actor`, `apply_outcome`, `applied_at`
- Manual approval gate via GitHub Environment protection rules
- PR comments show full plan output (60KB truncation guard)
- Concurrency lock prevents concurrent Terraform runs (no state corruption)

### 2. Application Deploy Pipeline (`.github/workflows/deploy.yaml`)

Triggers on changes to `api/**`, `web/**`, `k8s/**`:

```
Push to main
       │
       ▼
  ┌──────────┐
  │[1] TEST  │  npm ci + npm test (api + web, Node.js 24)
  └────┬─────┘
       │
       ├──────────────────────────┐
       ▼                          ▼
  ┌──────────┐            ┌──────────┐
  │[2] BUILD │            │[2] BUILD │   Docker Buildx → tar artifact
  │    API   │            │    WEB   │   GHA layer cache
  └────┬─────┘            └────┬─────┘   Image tag: {run_id}-{short_sha}
       │                       │
       ▼                       ▼
  ┌──────────┐            ┌──────────┐
  │[3] SCAN  │            │[3] SCAN  │   Trivy CRITICAL severity gate
  │    API   │            │    WEB   │   Scans tar — never touches ECR
  └────┬─────┘            └────┬─────┘
       │                       │
       ▼                       ▼
  ┌──────────┐            ┌──────────┐
  │[4] PUSH  │            │[4] PUSH  │   docker load → docker push ECR
  │    API   │            │    WEB   │   Only after clean scan
  └────┬─────┘            └────┬─────┘
       └──────────┬────────────┘
                  ▼
           ┌───────────┐
           │[5] DEPLOY │  kubeconfig → db-credentials sync → db-init job
           │  to EKS   │  → envsubst manifests → kubectl apply
           └─────┬─────┘  → rollout verify → rollback on failure
```

**Security in the image pipeline:**
- Images are built → exported as `.tar` → scanned by Trivy → pushed to ECR only if clean
- The exact artifact that was scanned is the one pushed (no rebuild between stages)
- CRITICAL vulnerabilities block the entire pipeline

**Zero-downtime deploy:**
- Rolling update: `maxUnavailable: 0`, `maxSurge: 1`
- Readiness probes prevent traffic routing to unhealthy pods
- Automatic rollback (`kubectl rollout undo`) if rollout verification fails

---

## Security Design

### Network Security

```
Internet → CloudFront → ALB (public subnets, SG: 80/443 open)
                         │
                    EKS Pods (private subnets, SG: VPC CIDR only)
                         │
                    RDS (private subnets, SG: EKS pod SG only, port 5432)
```

- RDS has **no public IP** and **no internet gateway route**
- EKS pods run in private subnets, outbound via NAT Gateway
- Security groups enforce least-privilege traffic rules

### Secret Management

- RDS password generated and stored in **AWS Secrets Manager**
- At deploy time, the pipeline fetches credentials from Secrets Manager and creates a Kubernetes secret:
  ```yaml
  kubectl create secret generic db-credentials \
    --from-literal=host=... \
    --from-literal=username=... \
    --from-literal=password=... \
    --from-literal=dbname=...
  ```
- Secrets are never stored in git or environment variables in plain text

### Container Security

- Images built from `node:24-alpine` (minimal attack surface)
- Containers run as non-root user (`node`)
- Trivy CRITICAL vulnerability gate blocks deployment of vulnerable images
- ECR lifecycle policy removes images older than 1 day (dev) to limit exposure

### AWS Credentials

- GitHub Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
- Scoped per environment using GitHub Environments (`dev`)

---

## Observability & Logging

### Logs

All logs are shipped to **Amazon CloudWatch Logs** — nothing stays on hosts.

| Source | Destination |
|---|---|
| EKS Fargate pods (api, web) | CloudWatch via Fargate Fluent Bit log router |
| EKS control plane | CloudWatch: api, audit, authenticator, controllerManager, scheduler |
| RDS PostgreSQL | CloudWatch via RDS enhanced monitoring |
| ALB access logs | S3 bucket (`node-3tier-dev-alb-logs`) |

Log retention: 30 days (configurable via `cloudwatch_log_retention_days` in tfvars).

### Metrics

- **Kubernetes metrics**: Metrics Server (HPA CPU-based autoscaling)
- **Application metrics**: ADOT (AWS Distro for OpenTelemetry) collector deployed via Helm — scrapes pods and ships to CloudWatch
- **Database metrics**: RDS Performance Insights enabled

### Alarms

CloudWatch alarms configured for:
- RDS: CPU, storage, connection count
- ALB: 5xx error rate, target response time, unhealthy host count

Alarm notifications sent to SNS → email (`alarm_email` in tfvars).

---

## Backup & Disaster Recovery

### Database Backups (RDS)

| Feature | Configuration |
|---|---|
| Automated daily backups | Enabled, 7-day retention |
| Backup window | 03:00–04:00 UTC |
| Point-in-time recovery | Supported (within retention window) |
| Cross-region replication | Configurable (`rds_automated_backups_replication_region`) |
| Multi-AZ | Configurable (`multi_az = true` for production) |

### Kubernetes State Backups (Velero)

- **Velero** deployed via Helm on EKS
- Backs up all Kubernetes resources and persistent volumes
- Backups stored in S3: `node-3tier-dev-velero-backup`
- Schedule configurable via `enable_velero_schedule` in tfvars

### Terraform State

- Remote state in S3 with versioning
- DynamoDB table for state locking (prevents concurrent state corruption)
- Approved plan binaries archived in S3 for full audit trail

---

## CDN & Content Distribution

AWS **CloudFront** distribution sits in front of the ALB:

| Behavior | Cache TTL | Path |
|---|---|---|
| Default (dynamic) | 0s (pass-through) | `/*` |
| Static stylesheets | 1h min / 24h default / 7d max | `/stylesheets/*` |
| Static images | 1h min / 24h default / 7d max | `/images/*` |

**Configuration:**
- Origin: ALB (HTTP only, CloudFront handles HTTPS termination)
- Viewer protocol: redirect HTTP → HTTPS
- IPv6: enabled
- Price class: `PriceClass_100` (US, Canada, Europe — lowest latency to most users)
- Deployment: `wait_for_deployment: true` to ensure readiness before pipeline completes

---

## High Availability & Zero-Downtime Deployments

### Pod-level HA

```yaml
# Both api and web deployments
replicas: 2          # minimum running at all times
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0  # never reduce below 2 running pods
    maxSurge: 1        # add 1 new pod before removing old
```

### Autoscaling (HPA)

```yaml
minReplicas: 2
maxReplicas: 10
targetCPUUtilizationPercentage: 70
```

Pods scale automatically under load. Metrics Server provides CPU metrics to HPA.

### Health Checks

```yaml
readinessProbe:
  httpGet: { path: /api/status, port: 3001 }
  initialDelaySeconds: 5
  periodSeconds: 10

livenessProbe:
  httpGet: { path: /api/status, port: 3001 }
  initialDelaySeconds: 15
  periodSeconds: 20
```

Traffic is only routed to pods that pass readiness checks. Failed pods are restarted by the liveness probe.

### Fargate (Managed Nodes)

EKS Fargate eliminates node management — AWS handles instance failures, patching, and replacement. No EC2 nodes to manage or monitor.

### Automatic Rollback

If the deployment pipeline's rollout verification fails (300s timeout):

```bash
kubectl rollout undo deployment/api-deployment -n node-3tier-app
kubectl rollout undo deployment/web-deployment -n node-3tier-app
```

---

## Local Development

### Prerequisites

- Docker Desktop
- `docker compose` v2+

### Start locally

```bash
# Clone the repo
git clone <repo-url>
cd node-3tier-cd-architecture

# Start all services (PostgreSQL + API + Web)
docker compose -f docker-compose-local.yml --env-file .env-local up --build

# Access
# Web:  http://localhost:3000
# API:  http://localhost:3001/api/status
# API:  http://localhost:3001/api/messages
```

The database is automatically initialised with `db/init.sql` on first start.

### Environment variables (`.env-local`)

```
POSTGRES_USER=3tierapp
POSTGRES_PASSWORD=password
POSTGRES_DB=appdb
DBUSER=3tierapp
DBPASS=password
DB=appdb
DBHOST=db
DBPORT=5432
PORT=3001
API_HOST=http://api:3001
WEB_PORT=3000
```

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy.yaml          # App CI/CD: test → build → scan → push → deploy
│       └── terraform.yaml       # IaC: validate → plan → apply
│
├── api/                         # Express.js REST API (Node.js 24)
│   ├── Dockerfile               # Multi-stage, node:24-alpine, non-root user
│   ├── .dockerignore
│   ├── app.js                   # Routes: /api/status, /api/messages
│   ├── bin/www                  # HTTP server entrypoint
│   └── package.json
│
├── web/                         # Express.js web frontend (Node.js 24)
│   ├── Dockerfile               # Multi-stage, node:24-alpine, non-root user
│   ├── .dockerignore
│   ├── app.js
│   ├── bin/www
│   ├── routes/index.js
│   ├── views/                   # Jade templates
│   └── package.json
│
├── db/
│   └── init.sql                 # CREATE TABLE IF NOT EXISTS messages (idempotent)
│
├── k8s/
│   ├── 01-namespace.yaml        # node-3tier-app namespace
│   ├── 02-api.yaml              # API Deployment + ClusterIP Service
│   ├── 03-web.yaml              # Web Deployment + ClusterIP Service
│   ├── 04-httproute.yaml        # Envoy Gateway HTTPRoute (/* and /api/*)
│   ├── 05-hpa.yaml              # HPA for api + web (2-10 replicas, CPU 70%)
│   └── 06-db-init.yaml          # Job: runs init.sql against RDS on deploy
│
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── main.tf          # Orchestrates all 13 modules
│   │       ├── variables.tf
│   │       ├── terraform.tfvars # Dev environment values
│   │       ├── providers.tf
│   │       ├── backend.tf       # Remote state: S3 + DynamoDB
│   │       ├── outputs.tf
│   │       └── versions.tf      # TF >= 1.10, AWS ~5.0
│   └── modules/
│       ├── vpc/
│       ├── security-groups/
│       ├── iam/
│       ├── eks/
│       ├── fargate-profile/
│       ├── eks-addons-helm/
│       ├── ecr/
│       ├── s3/
│       ├── rds/
│       ├── alb/
│       ├── cloudfront/
│       └── cloudwatch/
│
├── scripts/
│   ├── start.sh                 # Apply all k8s manifests + wait for readiness
│   ├── deploy.sh                # Rolling restart for a single tier
│   ├── scale.sh                 # Emergency manual scaling (bypasses HPA)
│   └── stop.sh                  # Tear down all k8s resources
│
├── docker-compose-local.yml     # Local dev: builds from Dockerfiles
├── docker-compose-cicd.yml      # CI/CD: uses pre-built ECR images
├── .gitattributes               # LF line endings enforced (cross-platform)
└── .gitignore
```

---

## GitHub Secrets & Variables Setup

### Repository Secrets (Settings → Secrets → Actions)

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_SESSION_TOKEN` | Session token (if using temporary credentials) |
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |

### Repository Variables (Settings → Variables → Actions)

| Variable | Example Value |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `ECR_REPOSITORY_API` | `api` |
| `ECR_REPOSITORY_WEB` | `web` |
| `EKS_CLUSTER_NAME` | `node-3tier-dev` |
| `PROJECT_NAME` | `node-3tier` |
| `RDS_SECRET_NAME` | `node-3tier-appdb-dev-rds-creds-none` (get exact name: `aws secretsmanager list-secrets --region us-east-1 --query "SecretList[?contains(Name, 'node-3tier')].Name" --output table`) |

### Environment Variables (Settings → Environments → dev)

| Variable | Value |
|---|---|
| `APPROVAL_EMAIL` | Email address of the approver shown in console |

### GitHub Environment Setup (for Terraform approval gate)

1. Go to **Settings → Environments → New environment** → name it `dev`
2. Enable **Required reviewers** → add yourself or your team
3. Save protection rules

This pauses the Terraform `apply` job until manually approved.

---

## Deployment Guide

### First-time Infrastructure Provisioning

```bash
cd terraform/environments/dev

# Initialise backend
terraform init

# Review what will be created
terraform plan

# Apply (creates VPC, EKS, RDS, ALB, CloudFront, ECR, etc.)
terraform apply
```

> In the GitHub Actions pipeline, the apply job requires manual approval via the GitHub Environment protection rule.

### Application Deployment

Push changes to `main` branch in any of these paths:

- `api/**` — triggers test → build → scan → push → deploy
- `web/**` — same
- `k8s/**` — skips build/scan/push, deploys manifests directly

### Manual Operations

```bash
# Deploy a specific tier manually
./scripts/deploy.sh api
./scripts/deploy.sh web

# Emergency scale
./scripts/scale.sh api 5
./scripts/scale.sh web 3

# Full teardown
./scripts/stop.sh
```

---

## Operational Scripts

| Script | Usage | Description |
|---|---|---|
| `scripts/start.sh` | `./start.sh` | Apply all k8s manifests, wait for pod readiness |
| `scripts/deploy.sh` | `./deploy.sh <api\|web>` | Trigger rolling restart for a tier |
| `scripts/scale.sh` | `./scale.sh <api\|web> <n>` | Scale to `n` replicas (temporarily removes HPA) |
| `scripts/stop.sh` | `./stop.sh` | Delete all application k8s resources |

---

## Requirements Checklist

| Requirement | Status | Implementation |
|---|---|---|
| Web + API exposed to internet | ✅ | ALB (public subnets) → CloudFront |
| DB not accessible from internet | ✅ | RDS in private subnets, SG allows only EKS pod SG |
| IaC for all resources | ✅ | Terraform 13 modules, all resources defined |
| Handle server failures | ✅ | EKS Fargate (managed), HPA min 2 replicas |
| Zero-downtime updates | ✅ | RollingUpdate maxUnavailable=0, rollback on failure |
| Fully automated deployment | ✅ | GitHub Actions 5-stage pipeline |
| Tests in pipeline | ✅ | npm test runs for api + web in Stage 1 |
| Daily database backups | ✅ | RDS automated backups, 7-day retention |
| Logs accessible (not on hosts) | ✅ | CloudWatch Logs via Fargate Fluent Bit |
| Historical metrics | ✅ | CloudWatch + ADOT (OpenTelemetry) |
| CDN for content distribution | ✅ | AWS CloudFront with static asset caching |
| Deploy on major cloud provider | ✅ | AWS (us-east-1) |
| Backup mutable storage | ✅ | RDS backups + Velero for EKS state |

---

## Source Application

Base application: [node-3tier-app2](https://git.toptal.com/henrique/node-3tier-app2)
