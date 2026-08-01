# ExecuteHub Architecture

This document describes the high-level system architecture of ExecuteHub, a cloud-native distributed test orchestration platform built for large-scale browser test execution.

## Overview

ExecuteHub separates concerns into a control plane, an execution plane, and an observability layer. The architecture follows a **Fan-Out / Fan-In** pattern:

- **Fan-Out:** The scheduler splits a test suite into independent jobs and distributes them across a pool of Playwright workers.
- **Fan-In:** The result aggregator collects worker outputs, merges them, and produces a unified test report.

This design enables parallel execution, horizontal scalability, and fault isolation.

## System Architecture Diagram

```
                           React + TypeScript Dashboard
                                      │
                                      ▼
                           Ruby on Rails Control Plane
        (Authentication • Projects • Test Runs • APIs • Notifications)
                                      │
                                      ▼
                            Scheduler / Orchestrator
                          (Fan-Out Test Distribution)
                                      │
                                      ▼
                             Redis + Sidekiq Queue
                                      │
                                      ▼
                           Kubernetes Worker Manager
                                      │
         ┌──────────────┬──────────────┬──────────────┐
         ▼              ▼              ▼              ▼
  Docker Worker   Docker Worker   Docker Worker   Docker Worker
  + Playwright    + Playwright    + Playwright    + Playwright
         │              │              │              │
         └──────────────┴──────────────┴──────────────┘
                                      │
                     Videos • Screenshots • Traces • Logs
                                      │
                                      ▼
                                    AWS S3
                                      │
                                      ▼
                            Result Aggregator Service
                                      │
                                      ▼
                                PostgreSQL
                                      │
                                      ▼
                    WebSockets → Real-Time Dashboard Updates
                                      │
                                      ▼
         Prometheus • Grafana • Jenkins • GitHub • AWS Monitoring
```

## Component Descriptions

### 1. React + TypeScript Dashboard

The user-facing application where developers and QA engineers interact with ExecuteHub. It provides project management, test run triggering, real-time execution monitoring, failure debugging, and report review.

**Responsibilities:**

- User authentication and project navigation
- Test run creation and history
- Live execution progress and worker status
- Artifact viewer for screenshots, videos, traces, and logs
- Release readiness reports and notifications

### 2. Ruby on Rails Control Plane

The core backend API that manages users, projects, test runs, authentication, authorization, and notifications. It serves as the entry point for all client requests.

**Responsibilities:**

- Authentication and RBAC (Admin, Developer, QA)
- Project and repository management
- Test run lifecycle management
- Webhook handling from GitHub and Jenkins
- Notification dispatch (Slack, Discord, Email)
- REST API for the dashboard

### 3. Scheduler / Orchestrator

The brain of the execution engine. It receives a test run request, analyzes the test suite, and splits it into independent jobs for parallel execution.

**Responsibilities:**

- Parse Playwright configuration and test files
- Determine optimal job size and worker allocation
- Fan-Out: create independent jobs from the test suite
- Enqueue jobs into Redis/Sidekiq
- Handle job dependencies and priorities

### 4. Redis + Sidekiq Queue

The messaging and job queue layer that decouples the scheduler from the workers. Redis stores job definitions, and Sidekiq processes them asynchronously.

**Responsibilities:**

- Store pending, running, and completed job states
- Enable reliable job dispatch and retry logic
- Provide visibility into queue depth and throughput

### 5. Kubernetes Worker Manager

The orchestration layer that manages the lifecycle of Docker workers. It scales worker pods up and down based on queue depth and resource availability.

**Responsibilities:**

- Maintain a pool of Playwright worker pods
- Auto-scale workers based on queue depth
- Restart failed or unhealthy workers
- Isolate test execution environments

### 6. Docker Worker + Playwright

The execution unit. Each worker is a Docker container running Playwright in a clean browser environment.

**Responsibilities:**

- Consume jobs from the Sidekiq queue
- Execute assigned browser tests in isolation
- Capture screenshots, videos, traces, console logs, and network logs
- Report progress and results back to the platform
- Upload artifacts to S3

### 7. AWS S3

Durable object storage for all test artifacts.

**Responsibilities:**

- Store test videos
- Store failure screenshots
- Store Playwright trace files
- Store raw execution logs
- Serve artifacts to the dashboard via pre-signed URLs

### 8. Result Aggregator Service

The Fan-In component. It waits for workers to complete, collects partial results, and merges them into a single coherent report.

**Responsibilities:**

- Collect per-worker test results
- Merge results into a unified report
- Calculate statistics: pass, fail, skip, flaky, duration
- Compute Release Readiness Score
- Store final reports in PostgreSQL

### 9. PostgreSQL Database

The primary relational database for platform data.

**Responsibilities:**

- Store user accounts, teams, and roles
- Store project and repository metadata
- Store test runs, jobs, and reports
- Store artifact references and analytics

### 10. WebSockets / Real-Time Updates

A real-time communication channel that pushes execution progress, worker status, and completion events to connected dashboard clients.

**Responsibilities:**

- Push live progress bars and queue depth
- Notify users when workers complete or fail
- Update test run status without page refresh

### 11. Observability & CI/CD Integrations

External systems that monitor platform health and trigger test executions.

- **Prometheus + Grafana:** Metrics, dashboards, and alerting
- **Jenkins:** CI/CD pipeline integration and deployment gates
- **GitHub:** Source control, webhooks, and PR triggers
- **AWS Monitoring:** CloudWatch and infrastructure health

## Data Flow

### Test Run Execution Flow

1. **Trigger:** A user clicks **Run Tests** or a GitHub webhook is received.
2. **Control Plane:** Rails validates the request and creates a Test Run record.
3. **Scheduler:** The Scheduler reads the test suite and splits it into jobs.
4. **Queue:** Jobs are pushed into Redis/Sidekiq.
5. **Worker Manager:** Kubernetes scales workers based on queue size.
6. **Execution:** Each worker picks a job, runs Playwright tests, captures artifacts, and uploads them to S3.
7. **Reporting:** Workers report job status and metadata back.
8. **Aggregation:** The Result Aggregator merges all results into a report.
9. **Persistence:** Reports and artifact references are stored in PostgreSQL.
10. **Real-Time Updates:** WebSockets push updates to the dashboard.
11. **Notifications:** Slack, Discord, and email alerts are sent to the team.

## Fan-Out / Fan-In Model

### Fan-Out

The Scheduler converts one large test suite into many small independent jobs. Each job contains:

- A subset of tests
- Target browser and configuration
- Worker resource requirements
- Artifact destination

This enables parallel execution and reduces total test suite duration.

### Fan-In

The Result Aggregator collects the outputs from all workers and produces:

- A unified pass/fail summary
- Per-test results with artifacts
- Execution time statistics
- Release Readiness Score
- Recommendations for deployment

## Scalability Considerations

- **Scheduler:** Stateless service; can be horizontally scaled for high request volume.
- **Queue:** Redis/Sidekiq supports distributed workers and persistent job queues.
- **Workers:** Kubernetes Horizontal Pod Autoscaler adjusts worker count based on queue depth.
- **Artifacts:** S3 provides virtually unlimited storage for videos, screenshots, and traces.
- **Database:** PostgreSQL can scale vertically or use read replicas for heavy analytics workloads.

## Reliability Considerations

- **Retry Logic:** Failed jobs are retried with exponential backoff.
- **Worker Heartbeat:** Workers report liveness; unhealthy workers are restarted.
- **Dead Letter Queue:** Persistently failing jobs are isolated for manual inspection.
- **Idempotency:** Job execution and artifact uploads are idempotent to prevent duplicate data.
- **Circuit Breakers:** Downstream failures (S3, DB) do not cascade to the entire system.

## Security Considerations

- **Authentication:** Devise-based user authentication with JWT or session tokens.
- **Authorization:** RBAC ensures users can only access permitted projects and actions.
- **Webhook Security:** GitHub webhook signatures are verified.
- **Isolation:** Each test runs in a fresh Docker container.
- **Secrets:** API keys and credentials are stored securely, never committed to repositories.

## Technology Stack

| Layer | Technology |
| --- | --- |
| Dashboard | React, TypeScript, Tailwind CSS |
| Control Plane API | Ruby on Rails |
| Scheduler | Ruby / Go service |
| Job Queue | Redis, Sidekiq |
| Worker Orchestration | Kubernetes, Helm |
| Browser Workers | Docker, Playwright |
| Artifact Storage | AWS S3 |
| Database | PostgreSQL |
| Real-Time | Action Cable / WebSockets |
| Monitoring | Prometheus, Grafana |
| CI/CD | Jenkins, GitHub Webhooks |

## Future Enhancements

- Smart test splitting based on historical test duration
- Machine learning-based flaky test detection
- Multi-region worker deployment
- Cost-aware scheduling and spot instance support
- Advanced analytics and trend forecasting
