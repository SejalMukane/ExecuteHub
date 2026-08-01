# QualityHub Backend

This document describes the backend architecture, services, and responsibilities that power QualityHub.

## Overview

The QualityHub backend is composed of multiple services working together:

```
Ruby on Rails Control Plane
        │
        ├── Scheduler / Orchestrator Service
        ├── Worker Manager
        ├── Result Aggregator Service
        └── Notification Service
```

## Ruby on Rails Control Plane

The control plane is the central API layer built with Ruby on Rails. It handles authentication, project management, test run lifecycle, and external integrations.

### Responsibilities

- User authentication and authorization
- Project and team management
- GitHub webhook handling
- Jenkins integration
- Test run creation and status tracking
- Dashboard REST API
- Real-time WebSocket broadcasts

### Key Models

- `User` — platform users with roles
- `Team` — organization or team grouping
- `Project` — application under test
- `Repository` — GitHub repository metadata
- `TestRun` — a single execution of a test suite
- `Job` — a unit of work assigned to a worker
- `Artifact` — reference to uploaded test artifacts
- `Notification` — user alerts and messages

### Directory Structure

```
backend/
├── app/
│   ├── controllers/
│   │   ├── api/v1/
│   │   └── webhooks/
│   ├── models/
│   ├── services/
│   ├── channels/
│   └── jobs/
├── config/
├── db/
├── spec/
└── Dockerfile
```

## Scheduler / Orchestrator Service

The scheduler is responsible for the Fan-Out phase of distributed execution. It takes a test run request and produces independent jobs that can be executed in parallel.

### Responsibilities

- Clone or pull the target repository
- Parse Playwright configuration
- Discover test files and their dependencies
- Group tests into optimal job chunks
- Determine target browsers and devices
- Enqueue jobs into Redis/Sidekiq

### Job Sizing Strategies

| Strategy | Description |
| --- | --- |
| File-based | Each test file becomes one job |
| Spec-based | Each test case becomes one job |
| Duration-aware | Uses historical data to balance job duration |
| Browser-sharded | Separate jobs per browser |

### Example Job Payload

```json
{
  "job_id": "job-1234",
  "test_run_id": 154,
  "project_id": 7,
  "repository_url": "https://github.com/acme/ecommerce",
  "commit_sha": "a1b2c3d4",
  "test_files": ["tests/login.spec.ts", "tests/checkout.spec.ts"],
  "browser": "chromium",
  "worker_image": "qualityhub/playwright-worker:v1",
  "artifact_prefix": "test-runs/154/job-1234/"
}
```

## Worker Manager

The worker manager provisions and monitors Docker-based Playwright workers. In production, this is backed by Kubernetes.

### Responsibilities

- Monitor queue depth
- Scale worker pods based on demand
- Register worker metadata
- Track worker health through heartbeats
- Restart or terminate unhealthy workers

### Scaling Logic

```
if queue_depth > available_workers * threshold:
    scale_up_workers()

if idle_workers > threshold and queue_depth == 0:
    scale_down_workers()
```

## Result Aggregator Service

The aggregator handles the Fan-In phase. It collects results from all workers and produces a unified test report.

### Responsibilities

- Listen for job completion events
- Collect per-job test results
- Merge results into a single report
- Calculate execution statistics
- Compute Release Readiness Score
- Store aggregated report in PostgreSQL
- Trigger notifications

### Aggregation Steps

1. Receive job completion event
2. Validate result payload
3. Update test run progress
4. Check if all jobs are complete
5. Compute final statistics
6. Calculate Release Readiness Score
7. Mark test run as completed
8. Send notifications

## Notification Service

The notification service dispatches alerts to users and external systems.

### Channels

- Email (SMTP)
- Slack (incoming webhooks)
- Discord (incoming webhooks)

### Triggers

- Test run started
- Test run completed
- Critical test failed
- Worker became unhealthy
- Deployment gate passed or blocked

## Background Jobs

Sidekiq workers handle asynchronous tasks:

| Job | Purpose |
| --- | --- |
| `ScheduleTestRunJob` | Triggered when a test run is created |
| `ProcessGitHubWebhookJob` | Handle GitHub events |
| `ProcessJenkinsWebhookJob` | Handle Jenkins events |
| `AggregateResultsJob` | Merge results when jobs complete |
| `SendNotificationJob` | Dispatch alerts |
| `CleanupArtifactsJob` | Remove old artifacts based on retention policy |

## Inter-Service Communication

| Pattern | Use Case |
| --- | --- |
| REST API | Dashboard and external integrations |
| Redis/Sidekiq | Asynchronous job processing |
| WebSockets | Real-time dashboard updates |
| Webhooks | GitHub and Jenkins integration |
| S3 Events | Artifact processing (optional) |

## Configuration

Backend services use environment variables:

```bash
DATABASE_URL=postgresql://user:pass@localhost:5432/qualityhub
REDIS_URL=redis://localhost:6379/0
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_S3_BUCKET=qualityhub-artifacts
GITHUB_WEBHOOK_SECRET=...
JWT_SECRET=...
```

## Error Handling

- All service errors are logged centrally
- Failed jobs are retried up to 3 times
- Unrecoverable failures are sent to a dead-letter queue
- Alerting rules notify the team on repeated failures

## Testing

The backend includes:

- Unit tests for services and models (RSpec)
- Request specs for API endpoints
- Background job tests
- Integration tests for GitHub webhooks
