# ExecuteHub — Progress Tracker

> Keeps track of what has been implemented. Update this file after every meaningful change.

**Last updated:** 2 August 2026 (Week 5 in progress — distributed execution)
---

## Project Overview

ExecuteHub is a cloud-native platform that launches isolated browser sessions on demand. Backend: Ruby on Rails API. Frontend: Next.js + TypeScript + Tailwind. Database: PostgreSQL. Later phases add Docker/Kubernetes orchestration, Redis queueing, and AWS deployment.

---

## Week 1 — Project Foundation & Authentication

**Status:** ✅ Complete

**Goal:** Build the foundation of the platform.

### Backend

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Set up Ruby on Rails project | Rails 8.1.3.1, API-only mode | ✅ Done |
| Configure PostgreSQL | PostgreSQL 16.14 in Docker (`executehub-postgres`, port 5434) | ✅ Done |
| Set up authentication | JWT (HS256, 24h expiry) + bcrypt (`has_secure_password`) | ✅ Done |
| Create User model | `users` table: id, name, email, role, team_id, password_digest, timestamps | ✅ Done |
| Create Team model | `teams` table: id, name, timestamps | ✅ Done |
| Create Project model | `projects` table: id, name, description, repository_url, user_id, team_id, timestamps | ✅ Done |
| Build REST APIs | Auth + projects + sessions endpoints | ✅ Done |
| Implement RBAC (Admin, Developer, QA) | `role` column + `admin?`/`developer?`/`qa?` helpers; write actions restricted to admin/developer | ✅ Done |

### Frontend

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Set up React + TypeScript + Tailwind | Next.js 16 (App Router) + TypeScript + Tailwind CSS v4 | ✅ Done |
| Build authentication pages | `/login`, `/register` — wired to backend | ✅ Done |
| Create dashboard layout | Protected `/dashboard` with top bar + sidebar nav | ✅ Done |
| Add sidebar navigation | Dashboard sidebar: Dashboard, Projects, Browser Sessions, Profile | ✅ Done |
| Build project listing page | `/projects` — create + list + delete projects (write gated by RBAC) | ✅ Done |
| Create user profile page | `/profile` — edit name/email/password | ✅ Done |

### Deliverable

✅ Users can sign up, log in, create projects, and navigate the dashboard.

---

### Backend APIs

| Endpoint | Method | Description | Status |
|----------|--------|-------------|--------|
| `/api/v1/register` | POST | Create account → returns user + JWT | ✅ Done |
| `/api/v1/login` | POST | Sign in → returns user + JWT | ✅ Done |
| `/api/v1/logout` | POST | Logout (stateless JWT, 204) | ✅ Done |
| `/api/v1/me` | GET | Current user from Bearer token | ✅ Done |
| `/api/v1/profile` | PUT/PATCH | Update name, email, password | ✅ Done |
| `/api/v1/session/start` | POST | Create a running session record | ✅ Done |
| `/api/v1/session` | GET | List current user's sessions (newest first) | ✅ Done |
| `/api/v1/session/:id` | DELETE | Terminate a session (sets end_time, status=terminated) | ✅ Done |
| `/api/v1/browser-images` | GET | List available browser images | ✅ Done |
| `/api/v1/projects` | GET | List visible projects (own + team) | ✅ Done |
| `/api/v1/projects/:id` | GET | Show project details | ✅ Done |
| `/api/v1/projects` | POST | Create project (admin/developer only) | ✅ Done |
| `/api/v1/projects/:id` | PUT/PATCH | Update project (admin/developer only) | ✅ Done |
| `/api/v1/projects/:id` | DELETE | Delete project (admin/developer only) | ✅ Done |

### Database (PostgreSQL)

| Table | Columns | Status |
|-------|---------|--------|
| `users` | id, name, email, role, team_id, password_digest, created_at, updated_at | ✅ Done |
| `teams` | id, name, created_at, updated_at | ✅ Done |
| `projects` | id, name, description, repository_url, user_id, team_id, created_at, updated_at | ✅ Done |
| `browser_sessions` | id, user_id (FK), browser_name, status, start_time, end_time, container_id, created_at, updated_at | ✅ Done |
| `browser_images` | id, name, version, tag, created_at, updated_at | ✅ Done (seeded) |

- Email has a **unique index**
- Passwords hashed via `bcrypt` (`has_secure_password`)
- Email format validation
- `User` has_many `browser_sessions` and `projects`; `Team` has_many `users` and `projects`
- `User#role` — `admin`, `developer`, `qa` (default `developer`)
- `browser_sessions` statuses: pending, running, completed, failed, expired, terminated

### Authentication

- **JWT** (HS256, 24h expiry) via `jwt` gem
- Token stored in `localStorage` → login persistence
- `Authenticatable` concern protects routes (redirects to `/login` if unauthenticated)
- CORS enabled for all origins (dev)

### Dashboard

> ⚠️ **Temporary dashboard** — a spec for the full dashboard has been provided (summary cards, live test runs, worker pool, queue, infrastructure health, recent activity). This is a placeholder until the real dashboard is built.

- **Sidebar navigation** — Dashboard, Projects, Browser Sessions, Profile, Help & Support
- **Top Summary Cards** — Total Projects (live), Active Test Runs, Pending Queue, Active Workers, Success Rate (24h)
- **Live Test Runs** — table with progress bars + status badges
- **Worker Pool** — worker/browser/status table with Active/Idle/Failed counts
- **Queue Status** — jobs waiting + average wait time
- **Infrastructure Health** — Rails API, Redis, PostgreSQL, Kubernetes, Worker Pool
- **Recent Activity** — run completions, webhooks, worker spawns, notifications
- **Active Session panel** — green "Running Session" card with live `00:01` elapsed timer + Stop button when a session is active
- **Start Browser panel** — shows available browser (Chrome) with "Start Browser" button when idle
- **Session History table** — session #, browser, status badge, started time, duration (live for running), stop/delete action

> Note: Test Runs / Worker Pool / Queue / Infrastructure cards currently use static placeholder data — they need backend models (next phase).

### Projects

- **Create project** — name, description, repository URL; writes gated to admin/developer
- **Project listing** — table with icon, name, description, repo, created time
- **Delete project** — trash action; QA users are read-only
- Default team auto-created per user (`<Name>'s Team`)

### Landing Page

- Hero: "Isolated browsers. Zero setup."
- v1.0 badge + Get Started CTA
- Feature grid: Secure Authentication, Browser Sessions, Live Dashboard, Profile Management
- Dark theme preserved (black + neutral, white accent buttons)

### Key Files — Backend

- `backend/app/models/user.rb` (role + RBAC helpers)
- `backend/app/models/team.rb`
- `backend/app/models/project.rb`
- `backend/app/models/browser_session.rb`
- `backend/app/models/browser_image.rb`
- `backend/app/controllers/api/v1/auth_controller.rb`
- `backend/app/controllers/api/v1/projects_controller.rb`
- `backend/app/controllers/api/v1/sessions_controller.rb`
- `backend/app/controllers/concerns/authenticatable.rb`
- `backend/app/services/jwt_service.rb`
- `backend/config/routes.rb`
- `backend/config/database.yml`

### Key Files — Frontend

- `frontend/lib/api.ts` — API client (register, login, logout, me, updateProfile, sessions, images, projects)
- `frontend/context/AuthContext.tsx` — auth state + token persistence
- `frontend/app/page.tsx` — landing page
- `frontend/app/{login,register,dashboard,projects,profile}/page.tsx`

---

## Week 2 — GitHub Integration & Project Management

**Status:** ✅ Complete

**Goal:** Connect GitHub repositories to projects.

### Backend

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Implement GitHub OAuth | OAuth2 device-style flow via GitHub web app; `/github/oauth/start` returns signed `state` (JWT carrying `user_id`), `/github/oauth/callback` exchanges the code for a token, upserts a `GithubIntegration`, redirects to frontend | ✅ Done |
| Build repository connection flow | `GET /github/repositories` lists the user's GitHub repos; `POST /github/repositories` links a repo to a project (stores metadata) and registers a webhook | ✅ Done |
| Register GitHub webhooks | Creates a repo webhook (`push`, `pull_request`) at `GITHUB_WEBHOOK_URL/<slug>` with a per-webhook random secret | ✅ Done |
| Verify webhook signatures | `GithubWebhookSignature` verifies `X-Hub-Signature-256` (HMAC-SHA256) with constant-time comparison; invalid signatures are recorded and rejected (401); payloads for the wrong repo are rejected (403) | ✅ Done |
| Store repository metadata | `github_repositories` stores full_name, html_url, clone/ssh URL, default branch, private flag, description; deliveries are stored in `github_webhook_deliveries` | ✅ Done |

### Frontend

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Add Connect GitHub button | On `/projects` header — starts OAuth; shows connected badge `@login` once linked; success/error banners via `?github=` query param | ✅ Done |
| Build repository selection UI | Modal on project detail page with searchable repo list (private lock icon, description) | ✅ Done |
| Create project settings page | `/projects/[id]` — edit name/description/repo URL, connect/disconnect GitHub account | ✅ Done |
| Add repository information page | `/projects/[id]` GitHub card — repo metadata, webhook status (events, payload URL, last delivery), disconnect, and a recent webhook deliveries table (event, delivery id, signature verified, branch, time) | ✅ Done |

### Deliverable

✅ GitHub repositories can be connected and webhooks are received successfully.

### Backend APIs (new)

| Endpoint | Method | Description | Status |
|----------|--------|-------------|--------|
| `/api/v1/github/oauth/start` | GET | Return GitHub authorize URL with signed state (auth required) | ✅ Done |
| `/api/v1/github/oauth/callback` | GET | Exchange code → token, store integration, redirect to frontend | ✅ Done |
| `/api/v1/github/status` | GET | `{ connected, login }` for current user | ✅ Done |
| `/api/v1/github/disconnect` | DELETE | Remove integration + linked repos/webhooks (best-effort GitHub cleanup) | ✅ Done |
| `/api/v1/github/repositories` | GET | List user's GitHub repositories | ✅ Done |
| `/api/v1/github/repositories` | POST | Connect a repo to a project + register webhook | ✅ Done |
| `/api/v1/github/repositories` | DELETE | Disconnect repo (removes webhook) | ✅ Done |
| `/api/v1/github/projects/:project_id/repository` | GET | Project repo + webhook + recent deliveries | ✅ Done |
| `/api/v1/github/webhooks/:slug` | POST | Public webhook receiver — verifies signature, records delivery | ✅ Done |

### Database (new tables)

| Table | Columns | Notes |
|-------|---------|-------|
| `github_integrations` | user_id, github_user_id, github_login, access_token, scope | one per user |
| `github_repositories` | project_id (unique), github_integration_id, github_repo_id (unique), full_name (unique), html_url, clone_url, ssh_url, default_branch, description, private | one per project |
| `github_webhooks` | github_repository_id, github_webhook_id, slug (unique), url, secret, events, active, last_delivery_at | per-repo; slug identifies the receiver |
| `github_webhook_deliveries` | github_webhook_id, delivery_id, event, signature_valid, payload (jsonb), received_at | audit of received events |

### GitHub Setup (required for live testing)

The live OAuth + webhook flow needs a GitHub **OAuth App** and a publicly reachable webhook URL. Everything else (repo connection, webhook signature verification) can be tested locally without it.

#### Step 1 — Create a GitHub OAuth App

1. GitHub → **Settings → Developer settings → OAuth Apps → New OAuth App**
2. **Application name:** ExecuteHub (or anything)
3. **Homepage URL:** `http://localhost:3000`
4. **Authorization callback URL:** `http://localhost:3001/api/v1/github/oauth/callback` — this must match `GITHUB_REDIRECT_URI` exactly, otherwise GitHub returns `redirect_uri mismatch`
5. Click **Register application**
6. Copy the **Client ID** and generate a **Client secret** on the app's page

#### Step 2 — Set the backend env vars

These are read from the environment at startup, so set them **in the same PowerShell window** before `rails server`:

```powershell
$env:GITHUB_CLIENT_ID = "<client id>"
$env:GITHUB_CLIENT_SECRET = "<client secret>"
$env:GITHUB_REDIRECT_URI = "http://localhost:3001/api/v1/github/oauth/callback"   # default if unset
$env:GITHUB_SCOPE = "repo read:user"                                              # default if unset
$env:FRONTEND_URL = "http://localhost:3000"                                       # default if unset
$env:GITHUB_WEBHOOK_URL = "https://<tunnel-host>/api/v1/github/webhooks"          # MUST be public https
$env:GITHUB_WEBHOOK_EVENTS = "push,pull_request"                                  # default if unset
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `GITHUB_CLIENT_ID` | — (required) | OAuth App client id |
| `GITHUB_CLIENT_SECRET` | — (required) | OAuth App client secret |
| `GITHUB_REDIRECT_URI` | `http://localhost:3001/api/v1/github/oauth/callback` | Must match the OAuth App callback URL |
| `GITHUB_SCOPE` | `repo read:user` | Grants repo access (webhooks + listing) and user profile |
| `GITHUB_WEBHOOK_URL` | `http://localhost:3001/api/v1/github/webhooks` | Base URL where GitHub posts events; the app appends `/<webhook-slug>` |
| `GITHUB_WEBHOOK_EVENTS` | `push,pull_request` | Comma-separated events registered on each webhook |
| `FRONTEND_URL` | `http://localhost:3000` | Where OAuth callback redirects the browser after auth |

#### Step 3 — Expose the webhook endpoint to GitHub

GitHub cannot reach `localhost`, so `GITHUB_WEBHOOK_URL` must be a public HTTPS URL that tunnels to the Rails server:

- **ngrok:** `ngrok http 3001` → set `GITHUB_WEBHOOK_URL = "https://<random>.ngrok-free.app/api/v1/github/webhooks"`
- **smee:** `npx smee-client --url https://smee.io/<channel> --path /api/v1/github/webhooks --port 3001` (smee forwards to localhost without exposing a real hostname)

`backend/config/environments/development.rb` already whitelists `*.ngrok-free.dev` / `*.ngrok-free.app` hosts so Rails' `HostAuthorization` doesn't reject tunnel requests.

#### Step 4 — Run and verify

```powershell
docker start browsercloud-postgres            # if not already running
ruby bin\rails db:migrate                     # apply the 4 GitHub migrations
ruby bin\rails server -p 3001                 # backend (env vars must be set in this window)
npm run dev                                   # frontend (from frontend/)
```

**Verification checklist (full flow):**

- [ ] `/projects` → **Connect GitHub** → lands on `github.com/login/oauth/authorize?...` with a signed `state`
- [ ] Authorize → browser redirects back to `/projects?github=connected` and the `@<login>` badge appears
- [ ] `/projects/<id>` → **Connect a repository** → repo list loads → pick a repo → webhook is created
- [ ] Webhook card shows **Active**, the payload URL `<GITHUB_WEBHOOK_URL>/<slug>`, and events
- [ ] Push to the repo (or GitHub → repo Settings → Webhooks → **Redeliver**) → the **Recent Webhook Deliveries** table shows a row with **Verified**
- [ ] Send an unsigned/invalid request → a row appears with **Failed** (signature check)

### Local webhook testing (no tunnel needed)

`backend/script/simulate_webhook.rb` builds a fake push payload, signs it with the stored secret, and POSTs it to the local receiver:

```powershell
ruby bin\rails runner script/simulate_webhook.rb testslug123 push
# valid signature   -> 200
# invalid signature -> 401
```

Verified during development: valid signature → 200 + delivery stored; invalid signature → 401 (recorded as `signature_valid: false`); payload for a different repo → 403.

### Key Files — GitHub Integration

- `backend/app/models/github_integration.rb`, `github_repository.rb`, `github_webhook.rb`, `github_webhook_delivery.rb`
- `backend/app/services/github_service.rb` — GitHub REST API client (Net::HTTP, no extra gems)
- `backend/app/services/github_webhook_signature.rb` — HMAC-SHA256 verification
- `backend/app/controllers/api/v1/github_auth_controller.rb` — OAuth start/callback/status/disconnect
- `backend/app/controllers/api/v1/github_repositories_controller.rb` — list/connect/disconnect/show
- `backend/app/controllers/api/v1/github_webhooks_controller.rb` — public webhook receiver
- `backend/script/simulate_webhook.rb` — local webhook simulator
- `frontend/components/GithubIcon.tsx` — GitHub logo SVG (brand icons removed from lucide-react)
- `frontend/lib/api.ts` — `github*` API methods
- `frontend/app/projects/page.tsx` — Connect GitHub button + status badge
- `frontend/app/projects/[id]/page.tsx` — project settings + repository info + repo selection modal + deliveries

---

## Week 3 — Test Scheduling & Queueing

**Status:** ✅ Complete

**Goal:** Build the orchestration layer that schedules and queues test-execution jobs.

### Backend

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| TestRun model | `test_runs` table (project_id FK, branch, commit_sha, status, total_tests, total_jobs, completed_jobs, failed_jobs, queued_jobs, progress_percentage, started_at, finished_at); statuses `queued/scheduling/running/completed/failed/cancelled`; validates project + branch + total_tests > 0; `recent` scope (newest first) | ✅ Done |
| Job model | `jobs` table (test_run_id FK, chunk_number unique per run, status, worker_id, error_message, started_at, finished_at); statuses `queued/running/completed/failed/retrying`; `mark_running!/mark_completed!/mark_failed!/mark_retrying!` helpers; worker identity `sidekiq:<pid>` | ✅ Done |
| Chunking / fan-out scheduler | `TestScheduler` — splits `total_tests` into chunks of `chunk_size` (configurable, default 20), creates a Job per chunk, enqueues `TestExecutionWorker.perform_async(job.id)`, logs every step, updates run counters + status | ✅ Done |
| Redis + Sidekiq queue | `test_execution` queue (priority 3), `default` (priority 1); concurrency 5; `config/executehub.yml` (chunk_size, worker_simulate_delay), `sidekiq.rb` initializer (REDIS_URL default `redis://localhost:6379/0`), `config/sidekiq.yml` | ✅ Done |
| Test execution worker | `TestExecutionWorker` (queue `test_execution`, retry 3) — marks job running, simulates work (`worker_simulate_delay`), marks job completed/failed, updates run progress via `TestRunProgressUpdater` | ✅ Done |
| Progress tracking | `TestRunProgressUpdater` — recomputes job counters from the DB, `progress = completed/total*100`, transitions run to running/completed/failed | ✅ Done |
| Queue dashboard service | `QueueDashboard` — queued/running from Sidekiq API, completed/failed from the `jobs` table | ✅ Done |
| Test suites | `test_suites` table + `TestSuite` model (name, description, total_tests); seeded suites (Smoke Tests=120, Regression=850, Checkout=52); `test_runs.test_suite_id` FK; creating a run with `test_suite_id` auto-derives the test count so the scheduler chunks automatically; explicit `total_tests` still overrides | ✅ Done |

### Backend APIs (new)

| Endpoint | Method | Description | Status |
|----------|--------|-------------|--------|
| `/api/v1/projects/:project_id/test_runs` | POST | Create test run → chunks into jobs → enqueue (admin/developer only) | ✅ Done |
| `/api/v1/test_runs/:id` | GET | Run details + jobs + progress (auth) | ✅ Done |
| `/api/v1/test_runs` | GET | List runs newest first (visible projects) | ✅ Done |
| `/api/v1/test_runs/suites` | GET | List test suites (id, name, description, total_tests) | ✅ Done |
| `/api/v1/queue` | GET | Queue stats: queued/running/completed/failed jobs | ✅ Done |

### Frontend

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Test Runs page | `/test-runs` — table (run #, project, branch/commit, status badge, jobs, progress bar), 5s auto-refresh | ✅ Done |
| Test Run detail page | `/test-runs/[id]` — run info, stats cards, job list with status badges | ✅ Done |
| Queue dashboard page | `/queue` — 4 stat cards (queued/running/completed/failed) + throughput, 5s auto-refresh | ✅ Done |
| Run Test UI | Project detail `/projects/[id]` — Run Test button + modal (Test Suite dropdown, Branch, Commit SHA optional, manual test count) → redirects to run detail | ✅ Done |
| Status badges | `StatusBadge` component — Queued/Retrying=blue, Running/Scheduling=yellow, Completed=green, Failed=red + `ProgressBar` | ✅ Done |
| Shared shell + nav | `DashboardShell` — sidebar nav now includes Test Runs + Queue on all pages | ✅ Done |

### Deliverable

✅ Test runs are created via the API, split into jobs, queued on Redis/Sidekiq, processed by the worker, and progress is tracked to 100%. Verified live end-to-end (create run → 5 jobs → worker processes → `status=completed`, `progress=100.0%`, queue drained).

### Database (new tables)

| Table | Columns | Notes |
|-------|---------|-------|
| `test_runs` | project_id (FK), test_suite_id (FK), branch, commit_sha (nullable), status, total_tests, total_jobs, completed_jobs, failed_jobs, queued_jobs, progress_percentage, started_at, finished_at | statuses queued/scheduling/running/completed/failed/cancelled |
| `jobs` | test_run_id (FK), chunk_number (unique per run), status, worker_id, error_message, started_at, finished_at | statuses queued/running/completed/failed/retrying |
| `test_suites` | name (unique), description, total_tests | seeded: Smoke Tests=120, Regression=850, Checkout=52 |

### Testing

- **RSpec (59 examples, 0 failures)** — TestRun model, Job model, TestScheduler service, TestRunProgressUpdater service, TestExecutionWorker, TestRuns API, Queue API (queue spec stubs Sidekiq primitives).
- **Smoke test** `backend/script/smoke_orchestration.rb` — end-to-end scheduler/worker flow against real Redis (passes).
- **Frontend** — `npx tsc --noEmit` clean; `npm run build` passes.

### Key Files — Backend

- `backend/app/models/test_run.rb`, `job.rb`, `test_suite.rb` (+ `project.rb` `has_many :test_runs`)
- `backend/app/services/test_scheduler.rb`, `test_run_progress_updater.rb`, `queue_dashboard.rb`
- `backend/app/workers/test_execution_worker.rb`
- `backend/app/controllers/api/v1/test_runs_controller.rb`, `queue_controller.rb`
- `backend/config/executehub.yml`, `backend/config/sidekiq.yml`, `backend/config/initializers/sidekiq.rb`
- `backend/db/migrate/20260801190004_create_test_runs.rb`, `20260801190005_create_jobs.rb`, `20260801200001_create_test_suites.rb`, `20260801200002_make_commit_sha_nullable_on_test_runs.rb`
- `backend/db/seeds.rb` — browser images + test suites
- `backend/script/smoke_orchestration.rb`

### Key Files — Frontend

- `frontend/lib/api.ts` — TestRun/Job/QueueStats types + `createTestRun/listTestRuns/getTestRun/getQueueStats`
- `frontend/components/DashboardShell.tsx`, `StatusBadge.tsx`
- `frontend/app/test-runs/page.tsx`, `frontend/app/test-runs/[id]/page.tsx`, `frontend/app/queue/page.tsx`
- `frontend/app/projects/[id]/page.tsx` — Run Test modal (suite dropdown, branch, optional commit)

---

## Week 4 — Real Browser Execution in Docker

**Status:** ✅ Complete

**Goal:** Replace the fake worker sleep with real Playwright execution inside isolated Docker containers — capturing logs, artifacts and execution summaries, persisting them to the DB, exposing APIs, and adding a live Workers page in the frontend.

### Backend

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Playwright sample project | `/playwright-runner` — `homepage.spec.ts` + `login.spec.ts`, config with trace on, video on, screenshots on failure and a JSON reporter writing `artifacts/test-results.json`; `@playwright/test` pinned to exact `1.61.1` (caret would pull 1.62.1 and mismatch the base image's browser revision) | ✅ Done |
| Reusable Docker image | `Dockerfile.playwright` — from `mcr.microsoft.com/playwright:v1.61.1-noble`, `npm ci` cached layer, `CMD ["npx","playwright","test"]`; verified: `2 passed (10.1s)` | ✅ Done |
| Docker service | `DockerService` — the only Docker-aware class: `create/start/stream_logs/exit_code/copy/destroy` via Open3 argument arrays (no shell); `DockerError` + `Container` struct | ✅ Done |
| Execution orchestration | `WorkerExecutor` — owns the full job lifecycle: mark running → create/start container → stream Playwright output into `ExecutionLog`s → mark uploading_artifacts → `docker cp` artifacts → parse JSON report → persist summary + artifacts → completed/failed → `TestRunProgressUpdater` → destroy container (ensure). No Sidekiq logic in the service | ✅ Done |
| Worker wiring | `TestExecutionWorker` delegates to `WorkerExecutor.execute(job)` with a rescue safety net that marks failed + re-raises | ✅ Done |
| Job lifecycle fields | Migration adds `container_id`, `passed_tests`, `failed_tests`, `duration_ms`, `error_message` to `jobs`; `uploading_artifacts` status added | ✅ Done |
| ExecutionLog model | `execution_logs` table (job FK, level, message, timestamp auto-stamped); `chronological`/`reverse_chronological` scopes | ✅ Done |
| Artifact model + store | `artifacts` table (job FK, artifact_type screenshot/video/trace, path, size); `ArtifactStore` centralises layout `storage/artifacts/job_XX/artifacts/...` with `relative`/`resolve` | ✅ Done |
| Playwright report parser | `PlaywrightOutputParser` — flattens suites → specs → tests, maps Playwright statuses (expected/unexpected/flaky/skipped), scans `*.png`/`*.webm`/`*.zip` | ✅ Done |
| Jobs + Artifacts APIs | `GET /api/v1/jobs/:id` (job + logs + artifacts + summary), `GET /api/v1/jobs/:id/logs`, `GET /api/v1/jobs/:id/artifacts`, `GET /api/v1/artifacts/:id/file` (streams bytes); project-scoped visibility | ✅ Done |
| End-to-end smoke | `backend/script/smoke_execution.rb` — drives the real pipeline (Job → Docker → Playwright → logs → artifacts → parser → DB) and asserts completed state, persisted summary/artifacts and run progress | ✅ Done |
| RSpec coverage | `docker_service_spec.rb` (stubs `Open3`) + `worker_executor_spec.rb` (stubs DockerService/parser/store) | ✅ Done |

### Frontend

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Workers / Job Details page | `/test-runs/[id]/jobs/[jobId]` — worker card (name, container id, status, current test, started, duration, CPU/memory placeholders), status cards, live progress bar, tabs Overview / Execution Logs (2s auto-refresh, newest at bottom) / Artifacts (screenshot preview, video player, trace download) / Summary; job rows link from the run detail page | ✅ Done |

### Deliverable

✅ A queued test run now produces real Playwright executions inside per-job Docker containers. `Job` transitions running → uploading_artifacts → completed with `passed_tests`/`failed_tests`/`duration_ms` persisted, Playwright output streamed into `ExecutionLog`s, screenshots/videos/traces copied to `storage/artifacts/job_XX/` and served through the API, and the frontend Workers page shows it all live. `SMOKE EXECUTION PASSED` (2 passed, 4 artifacts, run 100%).

### Database (new/changed)

| Table | Columns | Notes |
|-------|---------|-------|
| `jobs` (changed) | + container_id, passed_tests, failed_tests, duration_ms, error_message | statuses now include `uploading_artifacts` |
| `execution_logs` | job_id (FK), level (info/warn/error), message, timestamp | append-only audit |
| `artifacts` | job_id (FK), artifact_type (screenshot/video/trace), path, size | path relative to `storage/artifacts` |

### Gotchas found by the smoke test

- `config_for` returns `ActiveSupport::OrderedOptions` — top-level `[]` is key-indifferent, but nested values are plain symbol-keyed hashes, so `settings["image"]` returned `nil` (empty image → "no implicit conversion of nil into String"). Fix: `with_indifferent_access` in `WorkerExecutor#settings`.
- Three latent `docker` vs `@docker` NameErrors (`start`, `stream_logs`, `exit_code`) were only caught by the real smoke run — Part 13 specs (written after) pin the exact calls.
- Blank / ANSI-only lines streamed from Playwright violated `ExecutionLog`'s `message` presence validation → `log` now skips blank messages.
- Latent pre-existing bug (noted, out of scope): `TestScheduler` reads `chunk_size` via `OrderedOptions#fetch("chunk_size", 20)`, which is NOT key-indifferent and silently always returns the default `20`. Use `Rails.configuration.executehub["chunk_size"]` if chunk size ever needs to differ from the default.

### Testing

- **RSpec (118 examples, 0 failures)** — incl. new `DockerService` (10) and `WorkerExecutor` (8) specs.
- **Smoke test** `backend/script/smoke_execution.rb` — real Docker execution, passes (job completed, summary + 4 artifacts persisted, run progress 100%).
- **Frontend** — `npx tsc --noEmit` clean; eslint clean for new files; `npm run build` passes.

### Live verification (browser + Docker Desktop)

Verified end-to-end against the running stack (frontend `:3000`, backend `:3001`, Sidekiq, PostgreSQL, Redis):

- **Run #22** — `total_tests: 40` → 2 jobs, each ran the real 2-test Playwright suite in its own container in parallel. Both `completed`: `passed=2 failed=0`, durations ~16.8s/~16.9s, 14 `ExecutionLog` lines each (`Starting execution for Job #128` … `Container removed`), and 4 artifacts each (2 traces + 2 videos) persisted + served via the API. Run progress 100%.
- **Docker Desktop** — during execution the containers are visible as `executehub-job-<id>-<hex>` running `executehub-playwright:latest` (e.g. `executehub-job-142-971dd787`), then disappear within ~10s because `WorkerExecutor` destroys them in an `ensure` block after each job.
- **Workers page** — `http://localhost:3000/test-runs/22` → job → live status card, Execution Logs tab (2s auto-refresh), Artifacts tab (video player + trace download).

**Gotcha:** a long-running Sidekiq does **not** reload code in development. Jobs failed instantly with empty `error_message` because Sidekiq was still running the pre-fix `WorkerExecutor` (started before the Part 12 bug fixes). Fix: stop it and restart `bundle exec sidekiq -C config\sidekiq.yml` after changing worker code.

### Key Files

- `playwright-runner/` — sample Playwright project (`package.json`, `playwright.config.ts`, `tests/`)
- `Dockerfile.playwright` — reusable Playwright image
- `backend/app/services/worker_executor.rb`, `docker_service.rb`, `artifact_store.rb`, `playwright_output_parser.rb`
- `backend/app/models/execution_log.rb`, `artifact.rb` (+ `job.rb` lifecycle helpers)
- `backend/app/controllers/api/v1/jobs_controller.rb`, `artifacts_controller.rb`
- `backend/script/smoke_execution.rb`
- `backend/spec/services/docker_service_spec.rb`, `worker_executor_spec.rb`
- `frontend/app/test-runs/[id]/jobs/[jobId]/page.tsx`, `frontend/lib/api.ts`

### Build & run (Week 4)

```powershell
# 1. Build the Playwright image (once)
docker build -f Dockerfile.playwright -t executehub-playwright:latest .

# 2. Apply migrations (dev + test)
ruby bin\rails db:migrate
ruby bin\rails db:migrate RAILS_ENV=test

# 3. Smoke the real pipeline (Docker must be running)
ruby bin\rails runner script/smoke_execution.rb
# -> SMOKE EXECUTION PASSED

# 4. Run specs
bundle exec rspec   # 118 examples, 0 failures
```

---

## Week 5 — Distributed Execution Platform

**Status:** 🔄 In progress

**Goal:** Transform ExecuteHub into a true distributed execution platform — multiple workers executing jobs concurrently with fault tolerance, worker monitoring, retries, result aggregation and live dashboards. Workers still run locally via Docker (no Kubernetes yet).

### Part 3 — Fan-In Result Aggregator ✅

- New `app/services/result_aggregator.rb`: waits until every Job of a TestRun is terminal, then aggregates results → updates the TestRun → generates the final summary (passed/failed tests, total duration, screenshots, videos, overall status). Idempotent + `with_lock` for the last-two-jobs race.
- `test_runs` gains summary columns: `passed_tests`, `failed_tests`, `total_duration_ms`, `total_screenshots`, `total_videos`.
- `TestRunProgressUpdater` now delegates terminal transitions to `ResultAggregator` (automatic fan-in on every job completion).
- TestRuns API now serializes the summary fields.
- `spec/services/result_aggregator_spec.rb` (9 examples): waits for all terminal, sums tests/duration, counts artifacts, completed vs failed, idempotency.

### Part 2 — Fan-Out Execution ✅

- `TestScheduler` refactored into explicit steps: `create_jobs` (chunk + persist) → `dispatch_jobs` (push every Job into Redis immediately via `TestExecutionWorker.perform_async`).
- Scheduler stays lightweight: no execution logic, no result aggregation, no worker assignment — it only creates Jobs and queues every one.
- Counters are reset on reschedule (`completed_jobs`/`failed_jobs` = 0).
- New specs: fan-out dispatches every job into the queue immediately; scheduler never executes anything.

### Part 1 — Multiple Concurrent Workers ✅

- Sidekiq runs `:concurrency: 5` worker threads (`config/sidekiq.yml`), each mapping 1:1 to a logical worker (Worker-01..Worker-05).
- `config/executehub.yml` gains `worker_pool_size`, `heartbeat_interval_seconds`, `heartbeat_stale_seconds`, `max_job_retries`, `retry_delay_seconds`, `worker_execution_timeout_seconds`.
- `TestRunProgressUpdater` now marks a run `running` as soon as any job leaves the queue (previously it stayed `queued` until a job was actively running).
- `spec/workers/multiple_workers_spec.rb` proves N jobs from the same run execute simultaneously (max concurrent overlap > 1) and never block each other.

---

## Infrastructure Decisions

| Item | Choice | Notes |
|------|--------|-------|
| Ruby version | 3.3.11 | Installed via winget (`C:\Ruby33-x64`) |
| Rails version | 8.1.3.1 | API-only mode |
| Database | PostgreSQL 16.14 | Runs in Docker container `executehub-postgres` |
| DB port | `5434` | Native Windows PostgreSQL 18 occupies port `5432` |
| DB credentials | `executehub` / `executehub_dev` | Dev only |
| Frontend server | `http://localhost:3000` | `npm run dev` |
| Backend server | `http://localhost:3001` | `ruby bin\rails server -p 3001` |
| API base URL | `http://localhost:3001/api/v1` | Set via `NEXT_PUBLIC_API_URL` |

### PostgreSQL Quick Reference

```powershell
# View data
docker exec -e PGPASSWORD=executehub_dev -it executehub-postgres psql -U executehub -d executehub_development

# Stop / start container
docker stop browsercloud-postgres
docker start browsercloud-postgres
```

### Environment Variable Overrides (database.yml)

`DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME`

---

## How to Run

> Implementation is in progress — these commands start the full dev stack with everything implemented so far (Week 4 complete). Docker Desktop must be running for PostgreSQL and real browser execution.

```powershell
# 1. Docker Desktop must be running, then start PostgreSQL (port 5434)
docker start browsercloud-postgres

# 2. Start backend (from backend/) — Ruby on PATH first
$env:Path += ";C:\Ruby33-x64\bin"
ruby bin\rails server -p 3001

# 3. Start Sidekiq worker (processes test-run jobs) — separate window, from backend/
#    IMPORTANT: restart Sidekiq after any worker code change (it does not reload code in dev)
bundle exec sidekiq -C config\sidekiq.yml

# 4. Start frontend (from frontend/)
npm run dev
```

Open `http://localhost:3000` → register → dashboard.

> - **Redis** must be available for Sidekiq (default `redis://localhost:6379/0`).
> - **GitHub env vars** (`GITHUB_CLIENT_ID`/`GITHUB_CLIENT_SECRET`/`GITHUB_WEBHOOK_URL`, …) are only needed to test OAuth/webhooks — set them in the backend window before `rails server` (see GitHub Setup section above). Not required to start the app.
> - Real test runs additionally need Docker Desktop + the built image: `docker build -f Dockerfile.playwright -t executehub-playwright:latest .`

---

## Known Notes / Gotchas

- `rails` command is not on PATH by default — use `ruby bin\rails` or add `C:\Ruby33-x64\bin` to PATH.
- EnterpriseDB blocks automated PostgreSQL downloads (403) — we use the Docker image instead.
- SQLite was used briefly in Week 1 as a stopgap; fully replaced by PostgreSQL.
- Project renamed from **QualityHub** to **ExecuteHub** (name, docs, landing page, dashboard updated; theme unchanged).
- The DB container is still named `browsercloud-postgres`; the role/database inside are now `executehub` / `executehub_development`.

---

## Next Steps (Planned)

- [x] Week 1 — Foundation & Authentication ✅ (Rails, PostgreSQL, JWT auth, User + Team + Project models, REST APIs, RBAC, auth pages, dashboard + sidebar, projects page, profile page)
- [x] Week 2 — GitHub Integration & Project Management ✅ (GitHub OAuth, repo connection flow, webhook registration + signature verification, repo metadata storage, Connect GitHub button, repo selection UI, project settings page, repository info page)
- [x] Week 3 — Test Scheduling & Queueing ✅ (TestRun + Job models, chunking scheduler, Redis/Sidekiq `test_execution` queue, log-only worker, progress tracking, Test Runs + Queue API, Run Test UI, Test Runs + Queue pages, RSpec coverage)
- [x] Week 4 — Real Browser Execution in Docker ✅ (Playwright runner + Dockerfile, DockerService + WorkerExecutor, real execution in isolated containers, ExecutionLog + Artifact models + ArtifactStore, report parser, Jobs/Artifacts APIs, Workers page, RSpec + smoke coverage)
- [ ] Session history, idle cleanup, reports
- [ ] ActionCable real-time session status
- [ ] Docker Compose local stack
- [ ] Kubernetes + Jenkins + AWS deployment
- [ ] Prometheus/Grafana monitoring
