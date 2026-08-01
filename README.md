# QualityHub

A cloud-native distributed test orchestration platform that enables engineering teams to execute large-scale end-to-end (E2E) browser test suites efficiently across a scalable pool of isolated browser workers.

## Overview

QualityHub acts as the control plane for large-scale browser test execution. When code is pushed to GitHub or a run is triggered manually, the platform splits the test suite into smaller independent jobs, distributes them across Docker-based Playwright workers running on Kubernetes, executes them in parallel, and aggregates the results into a single comprehensive report.

By replacing sequential test execution with a distributed Fan-Out/Fan-In model, QualityHub significantly reduces test suite runtime while providing rich debugging artifacts for every failure.

## Why QualityHub

Running hundreds or thousands of E2E tests sequentially on a single machine is slow, expensive, and hard to debug. QualityHub addresses this by:

- Distributing tests across a pool of isolated browser workers
- Executing tests in parallel using containerized Playwright environments
- Uploading videos, screenshots, traces, console logs, and network logs to durable object storage
- Aggregating worker results into a unified report with a Release Readiness Score
- Providing real-time monitoring through a React-based dashboard

## High-Level Architecture

```
                           Developer / QA Engineer
                                      │
                          GitHub Push / Manual Trigger
                                      │
                                      ▼
                         React + TypeScript Dashboard
                                      │
                                      ▼
                           Ruby on Rails Control Plane
          (Authentication • Projects • APIs • Test Runs • RBAC)
                                      │
                                      ▼
                             Test Scheduler Service
                     (Fan-Out: Split Suite into Small Jobs)
                                      │
                                      ▼
                             Redis + Sidekiq Queue
                                      │
                                      ▼
                         Kubernetes Worker Manager
                                      │
             ┌──────────────┬──────────────┬──────────────┐
             ▼              ▼              ▼              ▼
      Docker Worker    Docker Worker   Docker Worker   Docker Worker
      + Playwright     + Playwright    + Playwright    + Playwright
      (20 Tests)       (20 Tests)      (20 Tests)      (20 Tests)
             │              │              │              │
             └──────────────┴──────────────┴──────────────┘
                                      │
                           Upload Artifacts (Videos,
                     Screenshots, Traces, Console Logs)
                                      │
                                      ▼
                                   AWS S3
                                      │
                                      ▼
                         Result Aggregator Service
                  (Fan-In: Merge All Worker Results)
                                      │
                                      ▼
                            PostgreSQL Database
        (Projects • Test Runs • Reports • Artifacts • Analytics)
                                      │
                                      ▼
                         Real-Time Dashboard (WebSockets)
                                      │
                                      ▼
                Notifications • Reports • Release Readiness Score
                                      │
                                      ▼
               Prometheus + Grafana + Jenkins + AWS Monitoring
```

## Core Engineering Concepts

- **Distributed Systems** — Fan-Out/Fan-In execution model
- **Parallel Processing** — Thousands of browser tests executed concurrently
- **Containerization** — Docker-based isolated Playwright workers
- **Container Orchestration** — Kubernetes-managed worker pools
- **Asynchronous Processing** — Redis and Sidekiq job queues
- **Cloud Infrastructure** — AWS EC2/EKS, RDS, S3
- **CI/CD Integration** — Jenkins and GitHub Webhooks
- **Real-Time Communication** — WebSockets and SSE for live execution updates
- **Scalable Backend** — Ruby on Rails with PostgreSQL
- **Observability** — Prometheus, Grafana, and centralized metrics
- **Artifact Management** — Videos, screenshots, traces, and logs
- **System Design Patterns** — Scheduler, Worker Pool, Queue, Result Aggregator, Retry Mechanism, Auto Scaling

## Tech Stack

| Layer | Technology |
| --- | --- |
| Frontend Dashboard | React, TypeScript, WebSockets |
| Control Plane API | Ruby on Rails |
| Background Jobs | Sidekiq, Redis |
| Scheduler & Aggregator | Ruby / Go services (event-driven) |
| Browser Workers | Docker, Playwright, Kubernetes |
| Object Storage | AWS S3 |
| Database | PostgreSQL |
| CI/CD | Jenkins, GitHub Webhooks |
| Monitoring | Prometheus, Grafana, AWS CloudWatch |
| Notifications | Slack, Discord, Email |

## Key Features

- **Distributed Test Execution** — Split large test suites into small jobs and run them across many isolated workers.
- **Real-Time Progress Monitoring** — Track worker status, queue depth, and test progress live.
- **Rich Failure Artifacts** — Automatically collect videos, screenshots, Playwright traces, console logs, and network logs.
- **Result Aggregation** — Merge worker results into a single report with pass/fail statistics and trends.
- **Release Readiness Score** — Compute an overall quality score based on test outcomes, coverage, and historical stability.
- **CI/CD Integration** — Trigger test runs automatically from GitHub pushes or Jenkins pipelines.
- **Notifications** — Send alerts through Slack, Discord, or email when runs complete or critical tests fail.
- **Observability** — Monitor platform health, worker utilization, queue depth, and execution latency.

## System Flow

1. **Trigger** — A test run is triggered by a GitHub push, Jenkins pipeline, or manual action in the dashboard.
2. **Scheduling** — The Rails control plane creates a test execution request and forwards it to the Scheduler.
3. **Fan-Out** — The Scheduler splits the test suite into independent jobs and places them in the Redis/Sidekiq queue.
4. **Execution** — Kubernetes-managed Docker workers consume jobs, run Playwright tests in isolation, and upload artifacts to S3.
5. **Fan-In** — The Result Aggregator collects worker results, merges them into a unified report, and computes statistics.
6. **Persistence** — Reports, artifacts, and analytics are stored in PostgreSQL and S3.
7. **Presentation** — The dashboard displays real-time updates, failure details, trace replays, and historical trends.
8. **Notification** — Stakeholders receive alerts based on run completion and configured rules.

## Project Structure

```
qualityhub/
├── backend/                 # Ruby on Rails control plane API
├── scheduler/               # Test scheduler service (Fan-Out)
├── aggregator/              # Result aggregator service (Fan-In)
├── worker/                  # Dockerized Playwright worker
├── dashboard/               # React + TypeScript frontend
├── infrastructure/          # Terraform / Kubernetes / Helm manifests
├── docs/                    # Architecture and design documents
└── README.md
```

## Getting Started

This project is under active development. Detailed setup instructions for each component will be added as the implementation progresses.

## Roadmap

- [ ] Rails control plane API with projects, test runs, and RBAC
- [ ] Sidekiq-based job queue and scheduler service
- [ ] Dockerized Playwright worker with artifact upload to S3
- [ ] Result aggregator and Release Readiness Score calculation
- [ ] React dashboard with real-time updates
- [ ] GitHub webhook and Jenkins integration
- [ ] Prometheus and Grafana monitoring
- [ ] Slack, Discord, and email notifications
- [ ] Kubernetes deployment manifests

## License

This project is for educational and portfolio purposes.
