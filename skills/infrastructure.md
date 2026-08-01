# ExecuteHub Infrastructure

This document describes the cloud infrastructure, containerization, orchestration, and observability setup for ExecuteHub.

## Overview

ExecuteHub is designed to run on AWS using containerized services managed by Kubernetes. Local development uses Docker Compose to simulate the production stack.

## Infrastructure Stack

| Layer | Technology |
| --- | --- |
| Cloud Provider | AWS |
| Compute | EC2 / EKS |
| Container Runtime | Docker |
| Orchestration | Kubernetes + Helm |
| Database | Amazon RDS for PostgreSQL |
| Cache & Queue | Amazon ElastiCache for Redis |
| Object Storage | Amazon S3 |
| Load Balancer | AWS Application Load Balancer |
| DNS | Amazon Route 53 |
| CDN | Amazon CloudFront |
| Monitoring | Prometheus + Grafana + CloudWatch |
| Secrets | AWS Secrets Manager |
| CI/CD | GitHub Actions + Jenkins |
| Infrastructure as Code | Terraform |

## Local Development Infrastructure

The local stack is managed with Docker Compose.

### Services

- `postgres` — PostgreSQL database
- `redis` — Redis cache and job queue
- `minio` — Local S3-compatible object storage
- `backend` — Rails API
- `dashboard` — React frontend dev server
- `scheduler` — Test scheduler service
- `aggregator` — Result aggregator service
- `worker` — Playwright worker

### Docker Compose File

```yaml
# infrastructure/docker-compose.dev.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: executehub_development
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
```

## AWS Production Infrastructure

### Compute

- **EKS Cluster** — Runs Rails API, scheduler, aggregator, and dashboard static files
- **EC2 Worker Nodes** — Kubernetes nodes for Playwright worker pods
- **Fargate (optional)** — For stateless services like scheduler and aggregator

### Database

- **Amazon RDS PostgreSQL** — Primary transactional database
- **Read Replicas** — For reporting and analytics queries

### Cache & Queue

- **Amazon ElastiCache Redis** — Sidekiq job queue and WebSocket pub/sub adapter

### Object Storage

- **Amazon S3** — Artifact storage
- **S3 Lifecycle Policies** — Move old artifacts to Glacier or delete after retention period
- **CloudFront** — Serve artifacts with pre-signed URLs

### Networking

- **VPC** — Isolated network for all resources
- **Subnets** — Public and private subnets across multiple availability zones
- **Application Load Balancer** — Routes traffic to Rails API and dashboard
- **Route 53** — DNS and domain management

## Kubernetes Architecture

### Namespaces

```yaml
namespaces:
  - executehub-production
  - executehub-staging
  - executehub-monitoring
```

### Deployments

- `rails-api` — Control plane API
- `scheduler` — Test scheduler
- `aggregator` — Result aggregator
- `dashboard` — Static files served by Nginx
- `sidekiq` — Background job workers

### Worker Pool

Workers run as a Kubernetes Deployment or Job:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: playwright-worker
spec:
  replicas: 5
  template:
    spec:
      containers:
        - name: worker
          image: executehub/playwright-worker:v1
          env:
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: executehub-secrets
                  key: redis_url
```

### Auto Scaling

- **HPA for API** — Scale based on CPU and request rate
- **HPA for Workers** — Scale based on Sidekiq queue depth
- **Cluster Autoscaler** — Add or remove nodes based on pod demand

## Terraform Modules

```
infrastructure/terraform/
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── rds/
│   ├── elasticache/
│   ├── s3/
│   └── alb/
├── environments/
│   ├── development/
│   ├── staging/
│   └── production/
└── main.tf
```

## Helm Charts

```
infrastructure/helm/
├── executehub/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── hpa.yaml
│       └── ingress.yaml
```

## CI/CD Pipeline

### GitHub Actions

- Lint and test pull requests
- Build Docker images
- Push images to Amazon ECR
- Deploy to staging on merge
- Deploy to production on tag

### Jenkins Integration

- Trigger ExecuteHub test runs from Jenkins pipelines
- Block deployments if Release Readiness Score is too low
- Receive build status updates

## Monitoring and Alerting

### Prometheus

Scrapes metrics from:

- Rails API
- Sidekiq
- Workers
- Kubernetes nodes
- Redis
- PostgreSQL (via exporter)

### Grafana Dashboards

- Platform overview
- Worker utilization
- Queue depth
- Test execution latency
- Error rates
- Infrastructure health

### CloudWatch

- AWS service-level metrics
- RDS performance
- ElastiCache metrics
- S3 request metrics

### Alerts

Alerting rules notify the team when:

- Queue depth exceeds threshold
- Worker failure rate spikes
- API error rate increases
- Database CPU is high
- Disk space is low

## Security

- All services run in private subnets except the load balancer
- Secrets are stored in AWS Secrets Manager
- Pod security policies restrict container privileges
- Network policies control inter-service communication
- S3 buckets are private with pre-signed URL access
- SSL/TLS termination at the load balancer

## Cost Optimization

- Use Spot instances for worker pods when possible
- Archive old artifacts to Glacier
- Scale workers to zero during idle periods
- Use Fargate for infrequent services
- Monitor and right-size RDS instances

## Deployment Checklist

- [ ] Provision AWS infrastructure with Terraform
- [ ] Build and push Docker images to ECR
- [ ] Deploy Helm charts to EKS
- [ ] Configure DNS and SSL certificates
- [ ] Set up monitoring and alerting
- [ ] Verify GitHub and Jenkins integrations
- [ ] Run end-to-end smoke tests
