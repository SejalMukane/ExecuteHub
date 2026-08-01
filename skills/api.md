# ExecuteHub API Design

This document defines the REST API contracts used by the ExecuteHub control plane. The API enables the dashboard, GitHub webhooks, Jenkins, and workers to interact with the platform.

## Base URL

```
https://api.executehub.io/v1
```

## Authentication

Most endpoints require authentication using a Bearer token.

```http
Authorization: Bearer <jwt_token>
```

## Content Type

```http
Content-Type: application/json
```

---

## Authentication

### POST /auth/login

Authenticate a user and return a JWT.

**Request:**

```json
{
  "email": "user@example.com",
  "password": "securepassword"
}
```

**Response:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "role": "developer"
  }
}
```

### POST /auth/register

Register a new user.

**Request:**

```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "securepassword",
  "team_name": "Engineering"
}
```

---

## Projects

### GET /projects

List all projects accessible to the current user.

**Response:**

```json
{
  "projects": [
    {
      "id": 1,
      "name": "E-Commerce App",
      "repository_url": "https://github.com/acme/ecommerce",
      "default_branch": "main",
      "created_at": "2025-01-10T10:00:00Z",
      "role": "admin"
    }
  ]
}
```

### POST /projects

Create a new project.

**Request:**

```json
{
  "name": "E-Commerce App",
  "repository_url": "https://github.com/acme/ecommerce",
  "default_branch": "main",
  "playwright_config_path": "playwright.config.ts"
}
```

### GET /projects/:id

Get project details.

### PATCH /projects/:id

Update project settings.

### DELETE /projects/:id

Delete a project.

---

## Test Runs

### GET /projects/:id/test_runs

List test runs for a project.

**Response:**

```json
{
  "test_runs": [
    {
      "id": 154,
      "status": "running",
      "total_tests": 1000,
      "passed": 670,
      "failed": 0,
      "pending": 330,
      "started_at": "2025-01-15T09:00:00Z",
      "duration_seconds": 142
    }
  ]
}
```

### POST /projects/:id/test_runs

Trigger a new test run.

**Request:**

```json
{
  "branch": "main",
  "commit_sha": "a1b2c3d4",
  "trigger": "manual"
}
```

**Response:**

```json
{
  "id": 154,
  "status": "queued",
  "message": "Test run created and scheduled"
}
```

### GET /test_runs/:id

Get detailed test run information.

**Response:**

```json
{
  "id": 154,
  "status": "completed",
  "branch": "main",
  "commit_sha": "a1b2c3d4",
  "total_tests": 1000,
  "passed": 995,
  "failed": 5,
  "skipped": 0,
  "duration_seconds": 222,
  "release_readiness_score": 91,
  "created_at": "2025-01-15T09:00:00Z",
  "completed_at": "2025-01-15T09:04:42Z"
}
```

### GET /test_runs/:id/jobs

List jobs for a test run.

### POST /test_runs/:id/cancel

Cancel a running test run.

---

## Workers

### GET /workers

List active workers.

**Response:**

```json
{
  "workers": [
    {
      "id": "worker-1",
      "status": "busy",
      "current_job_id": 42,
      "last_heartbeat_at": "2025-01-15T09:03:00Z"
    }
  ]
}
```

### GET /worker_pools

List worker pool status and utilization.

---

## Artifacts

### GET /jobs/:id/artifacts

List artifacts for a job.

**Response:**

```json
{
  "artifacts": [
    {
      "id": 99,
      "type": "screenshot",
      "filename": "login-failure.png",
      "url": "https://s3.amazonaws.com/.../login-failure.png?signature=...",
      "created_at": "2025-01-15T09:02:00Z"
    }
  ]
}
```

---

## Webhooks

### POST /webhooks/github

Receive GitHub push and pull request events.

**Headers:**

```http
X-GitHub-Event: push
X-Hub-Signature-256: sha256=...
```

**Request:**

```json
{
  "ref": "refs/heads/main",
  "repository": {
    "clone_url": "https://github.com/acme/ecommerce"
  },
  "head_commit": {
    "id": "a1b2c3d4"
  }
}
```

### POST /webhooks/jenkins

Receive Jenkins build completion events.

---

## Notifications

### GET /notifications

List notifications for the current user.

### PATCH /notifications/:id/read

Mark a notification as read.

---

## Worker Internal API

These endpoints are used by workers to report progress and results.

### POST /internal/jobs/:id/heartbeat

Report worker heartbeat.

### POST /internal/jobs/:id/complete

Report job completion with results.

**Request:**

```json
{
  "status": "failed",
  "results": [
    {
      "test_name": "login.spec.ts",
      "status": "failed",
      "duration_ms": 1234,
      "error_message": "Timeout waiting for selector",
      "artifact_keys": ["screenshots/login-failure.png"]
    }
  ]
}
```

### POST /internal/jobs/:id/artifacts

Register uploaded artifacts.

---

## Real-Time API

Real-time updates are delivered via WebSockets on:

```
wss://api.executehub.io/cable
```

### Channels

- `TestRunChannel` — subscribe to test run progress
- `WorkerChannel` — subscribe to worker status updates
- `NotificationChannel` — subscribe to user notifications

### Example Subscription

```json
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"TestRunChannel\",\"test_run_id\":154}"
}
```

---

## Error Handling

All errors follow a consistent format:

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Authentication required"
  }
}
```

### Common HTTP Status Codes

| Code | Meaning |
| --- | --- |
| 200 | Success |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 422 | Validation Error |
| 500 | Internal Server Error |

## Rate Limiting

API requests are rate-limited per user:

- 1,000 requests per minute for authenticated users
- 60 requests per minute for unauthenticated users

## Versioning

The current API version is `v1`. Future breaking changes will be introduced under `v2`.
