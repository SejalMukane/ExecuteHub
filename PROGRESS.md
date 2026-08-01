# ExecuteHub — Progress Tracker

> Keeps track of what has been implemented. Update this file after every meaningful change.

**Last updated:** 1 August 2026

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
docker stop executehub-postgres
docker start executehub-postgres
```

### Environment Variable Overrides (database.yml)

`DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME`

---

## How to Run

```powershell
# 1. Start PostgreSQL (Docker Desktop must be running)
docker start executehub-postgres

# 2. Start backend (from backend/)
$env:Path += ";C:\Ruby33-x64\bin"
ruby bin\rails server -p 3001

# 3. Start frontend (from frontend/)
npm run dev
```

Open `http://localhost:3000` → register → dashboard.

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
- [ ] Docker container orchestration for Chrome browsers
- [ ] Redis queue (Sidekiq) for session creation/cleanup
- [ ] ActionCable real-time session status
- [ ] Session history, idle cleanup, reports
- [ ] Docker Compose local stack
- [ ] Kubernetes + Jenkins + AWS deployment
- [ ] Prometheus/Grafana monitoring
