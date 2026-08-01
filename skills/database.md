# ExecuteHub Database Design

This document describes the PostgreSQL database schema that powers ExecuteHub.

## Overview

The database stores user and team information, project configuration, test runs, jobs, artifacts, notifications, and analytics. It is designed to support the full test orchestration lifecycle.

## Entity Relationship Diagram

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  teams   │────▶│  users   │◀────│ projects │
└──────────┘     └──────────┘     └──────────┘
                                        │
                                        ▼
                                 ┌──────────┐
                                 │ test_runs│
                                 └──────────┘
                                        │
                          ┌─────────────┼─────────────┐
                          ▼             ▼             ▼
                       ┌──────┐    ┌────────┐    ┌──────────┐
                       │ jobs │    │ reports│    │ artifacts│
                       └──────┘    └────────┘    └──────────┘
                          │
                          ▼
                    ┌────────────┐
                    │job_results │
                    └────────────┘
```

## Tables

### teams

Stores organization or team information.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| name | varchar | Team name |
| slug | varchar | Unique URL-friendly identifier |
| created_at | timestamp | Creation time |
| updated_at | timestamp | Last update time |

### users

Stores platform user accounts.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| team_id | bigint | Foreign key to teams |
| email | varchar | Unique email address |
| encrypted_password | varchar | Hashed password |
| name | varchar | Full name |
| role | enum | admin, developer, qa, viewer |
| created_at | timestamp | Creation time |
| updated_at | timestamp | Last update time |

### projects

Stores projects under test.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| team_id | bigint | Foreign key to teams |
| name | varchar | Project name |
| repository_url | varchar | GitHub repository URL |
| default_branch | varchar | Default Git branch |
| playwright_config_path | varchar | Path to Playwright config |
| created_at | timestamp | Creation time |
| updated_at | timestamp | Last update time |

### repositories

Stores connected repository metadata.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| project_id | bigint | Foreign key to projects |
| github_repo_id | bigint | GitHub repository ID |
| webhook_secret | varchar | Secret for verifying webhooks |
| access_token_encrypted | text | Encrypted GitHub access token |
| created_at | timestamp | Creation time |

### test_runs

Stores a single execution of a test suite.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| project_id | bigint | Foreign key to projects |
| branch | varchar | Git branch tested |
| commit_sha | varchar | Git commit SHA |
| status | enum | queued, preparing, running, completed, failed, cancelled |
| trigger | enum | manual, github_push, github_pr, jenkins, api |
| total_tests | integer | Total number of tests |
| passed | integer | Number of passed tests |
| failed | integer | Number of failed tests |
| skipped | integer | Number of skipped tests |
| flaky | integer | Number of flaky tests |
| duration_seconds | integer | Total execution time |
| release_readiness_score | integer | Score from 0 to 100 |
| started_at | timestamp | Execution start time |
| completed_at | timestamp | Execution completion time |
| created_at | timestamp | Creation time |
| updated_at | timestamp | Last update time |

### jobs

Stores individual work units created by the scheduler.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| test_run_id | bigint | Foreign key to test_runs |
| worker_id | varchar | Assigned worker identifier |
| status | enum | queued, running, completed, failed, cancelled |
| test_files | jsonb | List of test files in this job |
| browser | varchar | Target browser |
| retry_count | integer | Number of retry attempts |
| started_at | timestamp | Job start time |
| completed_at | timestamp | Job completion time |
| created_at | timestamp | Creation time |
| updated_at | timestamp | Last update time |

### job_results

Stores detailed test results for each job.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| job_id | bigint | Foreign key to jobs |
| test_name | varchar | Test case name |
| status | enum | passed, failed, skipped, flaky |
| duration_ms | integer | Test execution time in milliseconds |
| error_message | text | Failure message |
| stack_trace | text | Stack trace on failure |
| retry_count | integer | Number of retries for this test |
| created_at | timestamp | Creation time |

### artifacts

Stores references to uploaded test artifacts in S3.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| job_id | bigint | Foreign key to jobs |
| job_result_id | bigint | Foreign key to job_results |
| artifact_type | enum | screenshot, video, trace, log, network |
| filename | varchar | Original filename |
| s3_key | varchar | S3 object key |
| s3_bucket | varchar | S3 bucket name |
| file_size_bytes | bigint | File size in bytes |
| created_at | timestamp | Upload time |

### notifications

Stores user notifications.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| user_id | bigint | Foreign key to users |
| notification_type | enum | email, slack, discord |
| event_type | enum | test_run_started, test_run_completed, worker_failed, deployment_gate |
| title | varchar | Notification title |
| message | text | Notification body |
| read_at | timestamp | Read timestamp |
| created_at | timestamp | Creation time |

### worker_heartbeats

Tracks worker liveness.

| Column | Type | Description |
| --- | --- | --- |
| id | bigint | Primary key |
| worker_id | varchar | Worker identifier |
| status | enum | idle, busy, unhealthy, terminated |
| current_job_id | bigint | Currently assigned job |
| last_heartbeat_at | timestamp | Last heartbeat timestamp |
| created_at | timestamp | Creation time |
| updated_at | timestamp | Last update time |

## Indexes

Key indexes for performance:

```sql
CREATE INDEX idx_test_runs_project_id ON test_runs(project_id);
CREATE INDEX idx_test_runs_status ON test_runs(status);
CREATE INDEX idx_jobs_test_run_id ON jobs(test_run_id);
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_job_results_job_id ON job_results(job_id);
CREATE INDEX idx_job_results_status ON job_results(status);
CREATE INDEX idx_artifacts_job_id ON artifacts(job_id);
CREATE INDEX idx_artifacts_type ON artifacts(artifact_type);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read_at ON notifications(read_at);
```

## Data Retention

- Raw worker logs: 30 days
- Screenshots and videos: 90 days
- Test run metadata: 1 year
- Analytics aggregates: indefinitely

## Scaling Considerations

- Large `job_results` tables can be partitioned by `created_at`.
- Artifact metadata remains small; actual files are stored in S3.
- Frequent reads on active test runs are optimized with indexes and caching.

## Migrations

Database migrations are managed with Rails Active Record migrations and version-controlled in:

```
backend/db/migrate/
```
