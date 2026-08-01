# ExecuteHub

A cloud-native platform that launches **isolated browser sessions on demand** through a simple REST API. Users sign up, log in, and spin up clean, ephemeral browser environments from a web dashboard — the foundation of a scalable browser infrastructure platform.

## Overview

ExecuteHub acts as the control plane for browser session provisioning. Instead of running browsers on your own machine, sessions are created as isolated, reproducible environments and managed centrally. The current build covers the full foundation: authentication, user profiles, and browser session lifecycle management.

This is Phase 1 of a larger platform. Later phases add Docker/Kubernetes orchestration, Redis-backed queueing, and AWS deployment.

## Current Features (Week 1 — Foundation & Authentication ✅)

### Backend (Ruby on Rails API)

- Rails API-only project with PostgreSQL
- Authentication via **JWT** (HS256, 24h expiry) with bcrypt password hashing
- `User` model with unique email index and validation
- `Team` model — auto-created per user (`<Name>'s Team`)
- `Project` model — create, list, update, delete projects
- **RBAC** — `admin`, `developer`, `qa` roles; write actions restricted to admin/developer
- REST APIs for register, login, logout, current user, profile updates, and project CRUD
- Browser session management: start, list, terminate sessions
- Browser image catalog (Chrome, Firefox versions)

### Frontend (Next.js + TypeScript + Tailwind CSS)

- Landing page
- Login and Register pages (wired to the backend)
- Protected dashboard with real user data
- Sidebar navigation: Dashboard, Projects, Browser Sessions, Profile
- Projects page: create, list, and delete projects (RBAC-aware)
- Browser session panel: start a browser, live elapsed timer, stop
- Session history table with status badges
- Profile page (edit name / email / password)
- Stats: active sessions, total sessions, avg duration, available browsers

### Deliverable

✅ Users can sign up, log in, create projects, and navigate the dashboard.

## Tech Stack

| Layer | Technology |
| --- | --- |
| Frontend | Next.js (App Router), React, TypeScript, Tailwind CSS |
| Backend | Ruby on Rails 8.1 (API-only) |
| Database | PostgreSQL 16 |
| Auth | JWT + bcrypt (`has_secure_password`) |
| Real-Time (planned) | Action Cable / WebSockets |
| Orchestration (planned) | Docker, Kubernetes |
| Queue (planned) | Redis, Sidekiq |

## Project Structure

```
executehub/
├── backend/                 # Ruby on Rails API (control plane)
│   ├── app/controllers/api/v1/  # Auth + session endpoints
│   ├── app/models/               # User, BrowserSession, BrowserImage
│   └── config/
└── frontend/                # Next.js + TypeScript dashboard
    ├── app/                 # Pages (landing, login, register, dashboard, profile)
    ├── context/             # AuthContext (token persistence)
    └── lib/                 # API client
```

## Getting Started

Detailed setup instructions are in `PROGRESS.md` (How to Run section).

1. Start PostgreSQL: `docker start executehub-postgres`
2. Start backend (from `backend/`): `ruby bin\rails server -p 3001`
3. Start frontend (from `frontend/`): `npm run dev`
4. Open `http://localhost:3000` → register → dashboard.

## Roadmap

- [x] Week 1 — Project foundation & authentication
- [ ] Docker container orchestration for browser sessions
- [ ] Redis queue (Sidekiq) for session creation/cleanup
- [ ] ActionCable real-time session status
- [ ] Session history, idle cleanup, reports
- [ ] Docker Compose local stack
- [ ] Kubernetes + Jenkins + AWS deployment
- [ ] Prometheus/Grafana monitoring

## License

This project is for educational and portfolio purposes.
