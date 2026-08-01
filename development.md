# QualityHub Development Guide

This document explains how to set up and run QualityHub in a local development environment.

## Prerequisites

Before starting, ensure you have the following installed:

- Ruby 3.2+
- Rails 7+
- Node.js 18+
- PostgreSQL 14+
- Redis 7+
- Docker and Docker Compose
- Git

## Repository Structure

```
qualityhub/
├── backend/                 # Ruby on Rails API
├── dashboard/               # React + TypeScript frontend
├── scheduler/               # Test scheduler service
├── aggregator/              # Result aggregator service
├── worker/                  # Dockerized Playwright worker
├── infrastructure/          # Docker Compose, Kubernetes, Terraform
└── docs/                    # Documentation
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/qualityhub.git
cd qualityhub
```

### 2. Start Infrastructure Services

Use Docker Compose to start PostgreSQL, Redis, and MinIO (local S3 alternative):

```bash
docker-compose -f infrastructure/docker-compose.dev.yml up -d
```

This starts:

- PostgreSQL on port 5432
- Redis on port 6379
- MinIO on port 9000 and 9001

### 3. Set Up the Backend

```bash
cd backend
cp .env.example .env
bundle install
rails db:create db:migrate db:seed
rails s
```

The API will be available at `http://localhost:3000`.

### 4. Set Up the Frontend

```bash
cd dashboard
npm install
cp .env.example .env
npm run dev
```

The dashboard will be available at `http://localhost:5173`.

### 5. Start Sidekiq

In a separate terminal:

```bash
cd backend
bundle exec sidekiq
```

### 6. Start the Scheduler and Aggregator

```bash
cd scheduler
bundle install
ruby scheduler.rb
```

```bash
cd aggregator
bundle install
ruby aggregator.rb
```

### 7. Build the Worker Image

```bash
cd worker
docker build -t qualityhub/playwright-worker:dev .
```

## Environment Variables

### Backend

```env
DATABASE_URL=postgresql://postgres:password@localhost:5432/qualityhub_development
REDIS_URL=redis://localhost:6379/0
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
AWS_ENDPOINT=http://localhost:9000
AWS_S3_BUCKET=qualityhub-artifacts
JWT_SECRET=your-jwt-secret
GITHUB_WEBHOOK_SECRET=your-webhook-secret
```

### Frontend

```env
VITE_API_URL=http://localhost:3000/api/v1
VITE_WS_URL=ws://localhost:3000/cable
```

## Running Tests

### Backend Tests

```bash
cd backend
bundle exec rspec
```

### Frontend Tests

```bash
cd dashboard
npm run test
```

### Worker Tests

```bash
cd worker
npx playwright test
```

## Development Workflow

1. Create a feature branch from `main`
2. Make changes and add tests
3. Run the full test suite locally
4. Open a pull request
5. GitHub Actions runs CI checks
6. Merge after approval

## Common Commands

| Task | Command |
| --- | --- |
| Reset database | `rails db:drop db:create db:migrate db:seed` |
| Run Rails console | `rails c` |
| Run a specific test | `bundle exec rspec spec/models/user_spec.rb` |
| Rebuild worker image | `docker build -t qualityhub/playwright-worker:dev .` |
| View logs | `docker-compose -f infrastructure/docker-compose.dev.yml logs -f` |

## Local GitHub Webhook Testing

Use ngrok to expose your local backend:

```bash
ngrok http 3000
```

Then configure the webhook URL in your GitHub repository settings.

## Troubleshooting

### PostgreSQL connection refused

Ensure PostgreSQL is running:

```bash
docker-compose -f infrastructure/docker-compose.dev.yml ps
```

### Redis connection refused

Ensure Redis is running and `REDIS_URL` is correct.

### MinIO bucket does not exist

Create the bucket manually:

```bash
aws --endpoint-url=http://localhost:9000 s3 mb s3://qualityhub-artifacts
```

## Recommended Tools

- RubyMine or VS Code for Ruby development
- Postman or Insomnia for API testing
- TablePlus or pgAdmin for database inspection
- RedisInsight for Redis monitoring

## Next Steps

After the local environment is running:

1. Create a project in the dashboard
2. Connect a GitHub repository
3. Trigger a manual test run
4. Watch the live dashboard and worker execution
