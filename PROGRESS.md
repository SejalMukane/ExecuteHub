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
- [ ] Docker container orchestration for Chrome browsers
- [ ] Redis queue (Sidekiq) for session creation/cleanup
- [ ] ActionCable real-time session status
- [ ] Session history, idle cleanup, reports
- [ ] Docker Compose local stack
- [ ] Kubernetes + Jenkins + AWS deployment
- [ ] Prometheus/Grafana monitoring
