# BrowserCloud Lite — Progress Tracker

> Keeps track of what has been implemented. Update this file after every meaningful change.

**Last updated:** 31 July 2026

---

## Project Overview

BrowserCloud Lite is a cloud-native platform that launches isolated browser sessions on demand. Backend: Ruby on Rails API. Frontend: Next.js. Database: PostgreSQL. Later phases add Docker/Kubernetes orchestration, Jenkins CI/CD, and AWS deployment.

---

## Phase 1 — Foundation: Authentication & Dashboard

**Status:** ✅ Complete

### Frontend (Next.js 16, App Router)

| Page | Route | Status |
|------|-------|--------|
| Landing page | `/` | ✅ Done |
| Login page | `/login` | ✅ Done — wired to backend |
| Register page | `/register` | ✅ Done — wired to backend |
| Dashboard | `/dashboard` | ✅ Done — protected route, real user data |
| Profile page | `/profile` | ✅ Done — edit name/email/password |

### Backend (Ruby on Rails 8.1, API-only)

| Endpoint | Method | Description | Status |
|----------|--------|-------------|--------|
| `/api/v1/register` | POST | Create account → returns user + JWT | ✅ Done |
| `/api/v1/login` | POST | Sign in → returns user + JWT | ✅ Done |
| `/api/v1/logout` | POST | Logout (stateless JWT, 204) | ✅ Done |
| `/api/v1/me` | GET | Current user from Bearer token | ✅ Done |
| `/api/v1/profile` | PUT/PATCH | Update name, email, password | ✅ Done |

### Database (PostgreSQL)

| Table | Columns | Status |
|-------|---------|--------|
| `users` | id, name, email, password_digest, created_at, updated_at | ✅ Done |

- Email has a **unique index**
- Passwords hashed via `bcrypt` (`has_secure_password`)
- Email format validation

### Authentication

- **JWT** (HS256, 24h expiry) via `jwt` gem
- Token stored in `localStorage` → login persistence
- `Authenticatable` concern protects routes (redirects to `/login` if unauthenticated)
- CORS enabled for all origins (dev)

### Key Files — Backend

- `backend/app/models/user.rb`
- `backend/app/controllers/api/v1/auth_controller.rb`
- `backend/app/controllers/concerns/authenticatable.rb`
- `backend/app/services/jwt_service.rb`
- `backend/config/routes.rb`
- `backend/config/database.yml`

### Key Files — Frontend

- `frontend/lib/api.ts` — API client (register, login, logout, me, updateProfile)
- `frontend/context/AuthContext.tsx` — auth state + token persistence
- `frontend/app/{login,register,dashboard,profile}/page.tsx`

---

## Phase 2 — Browser Session Management

**Status:** ✅ Complete (database records only — no Chrome launch yet)

### Database (PostgreSQL)

| Table | Columns | Notes |
|-------|---------|-------|
| `browser_sessions` | id, user_id (FK), browser_name, status, start_time, end_time, container_id, created_at, updated_at | Status defaults to `running`, start_time auto-set on create |
| `browser_images` | id, name, version, tag, created_at, updated_at | Seeded: Chrome 128, Chrome 127, Firefox 129 |

- `User` has_many `browser_sessions` (one user → many sessions)
- `BrowserSession` belongs_to `user`; statuses: pending, running, completed, failed, expired, terminated
- `container_id` exists but stays empty for now (container provisioning comes later)

### Backend APIs

| Endpoint | Method | Description | Status |
|----------|--------|-------------|--------|
| `/api/v1/session/start` | POST | Create a running session record | ✅ Done |
| `/api/v1/session` | GET | List current user's sessions (newest first) | ✅ Done |
| `/api/v1/session/:id` | DELETE | Terminate a session (sets end_time, status=terminated) | ✅ Done |
| `/api/v1/browser-images` | GET | List available browser images | ✅ Done |

### Frontend Dashboard

- **Active Session panel** — green "Running Session" card with live `00:01` elapsed timer + Stop button when a session is active
- **Start Browser panel** — shows available browser (Chrome) with "Start Browser" button when idle
- **Session History table** — session #, browser, status badge, started time, duration (live for running), stop/delete action
- **Stats** — active sessions, total sessions, avg duration, available browsers

### Key Files

- `backend/app/models/browser_session.rb` — duration/elapsed helpers
- `backend/app/models/browser_image.rb`
- `backend/app/controllers/api/v1/sessions_controller.rb` — start, index, destroy, images
- `frontend/app/dashboard/page.tsx` — full session UI + timer
- `frontend/lib/api.ts` — listBrowserImages, startSession, listSessions, stopSession

---

## Infrastructure Decisions

| Item | Choice | Notes |
|------|--------|-------|
| Ruby version | 3.3.11 | Installed via winget (`C:\Ruby33-x64`) |
| Rails version | 8.1.3.1 | API-only mode |
| Database | PostgreSQL 16.14 | Runs in Docker container `browsercloud-postgres` |
| DB port | `5434` | Native Windows PostgreSQL 18 occupies port `5432` |
| DB credentials | `browsercloud` / `browsercloud_dev` | Dev only |
| Frontend server | `http://localhost:3000` | `npm run dev` |
| Backend server | `http://localhost:3001` | `ruby bin\rails server -p 3001` |
| API base URL | `http://localhost:3001/api/v1` | Set via `NEXT_PUBLIC_API_URL` |

### PostgreSQL Quick Reference

```powershell
# View data
docker exec -e PGPASSWORD=browsercloud_dev -it browsercloud-postgres psql -U browsercloud -d browsercloud_development

# Stop / start container
docker stop browsercloud-postgres
docker start browsercloud-postgres
```

### Environment Variable Overrides (database.yml)

`DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME`

---

## How to Run

```powershell
# 1. Start PostgreSQL (Docker Desktop must be running)
docker start browsercloud-postgres

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

---

## Next Steps (Planned)

- [x] Browser session CRUD + provisioning endpoints ✅
- [ ] Docker container orchestration for Chrome browsers
- [ ] Redis queue (Sidekiq) for session creation/cleanup
- [ ] ActionCable real-time session status
- [ ] Session history, idle cleanup, reports
- [ ] Docker Compose local stack
- [ ] Kubernetes + Jenkins + AWS deployment
- [ ] Prometheus/Grafana monitoring
