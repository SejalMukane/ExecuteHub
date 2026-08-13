# ExecuteHub × Jenkins — Local Setup Guide

This guide wires ExecuteHub (Rails API) to a **local Docker Jenkins** instance so
the Week 8 CI/CD integration can be exercised end-to-end without any cloud
infrastructure.

## 1. Prerequisites

- Docker Desktop running.
- Backend up: `ruby bin\rails server -p 3001` with PostgreSQL + Redis reachable
  (the `docker-compose.dev.yml` stack provides both).
- Frontend (optional, for the CI/CD + Notifications pages):
  `npm run dev` in `frontend/`.
- The Playwright image (only needed for the `executehub-tests` job):
  `docker build -f Dockerfile.playwright -t executehub-playwright:latest .`

## 2. Start the local stack

```powershell
# Stop any older standalone containers so the names don't clash.
docker stop executehub-redis browsercloud-postgres 2>$null

docker compose -f docker-compose.dev.yml up -d
```

| Service | Host URL | Purpose |
|---------|----------|---------|
| Jenkins | `http://localhost:8080` | CI server (UI on 8080, agents on 50000) |
| Redis | `localhost:6379` | Sidekiq queues + Action Cable pubsub |
| PostgreSQL | `localhost:5434` | `executehub_development` DB |

Apply/migrate the backend and confirm it starts:

```powershell
ruby bin\rails db:migrate
ruby bin\rails db:migrate RAILS_ENV=test
ruby bin\rails server -p 3001
```

## 3. Jenkins first run

1. Open `http://localhost:8080`.
2. Unlock with the initial admin password:
   ```powershell
   docker exec executehub-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```
3. Install the **suggested plugins** (this includes Pipeline, Git, Credentials,
   and the Pipeline Utility Steps used by `readJSON`).
4. Create an admin user.

## 4. Create an ExecuteHub CI token

The Jenkinsfile authenticates to ExecuteHub with a **project CI token** (hashed
in the DB, shown exactly once). Create one with an authenticated admin/developer
request:

```powershell
# 1. Sign in and capture the JWT.
$jwt = (Invoke-RestMethod -Method Post -Uri http://localhost:3001/api/v1/login `
  -ContentType application/json `
  -Body '{"email":"you@example.com","password":"yourpassword"}').token

# 2. Create a token for the project (the plaintext is only returned once).
Invoke-RestMethod -Method Post -Uri http://localhost:3001/api/v1/ci_tokens `
  -Headers @{ Authorization = "Bearer $jwt" } -ContentType application/json `
  -Body '{"project_id": 1, "name": "Jenkins"}'
```

Save the returned `token` value — it starts with `eh_` and can never be
recovered. Keep it in a Jenkins **secret text credential** bound to the
`EXECUTEHUB_CI_TOKEN` parameter.

## 5. Backend env vars (set in the `rails server` window)

| Variable | Value | Purpose |
|----------|-------|---------|
| `JENKINS_URL` | `http://localhost:8080` | Jenkins base URL for JenkinsService |
| `JENKINS_USERNAME` | Jenkins user (e.g. `admin`) | Basic-auth user for Jenkins REST calls |
| `JENKINS_API_TOKEN` | Jenkins API token (see below) | Basic-auth token for Jenkins REST calls |
| `JENKINS_JOB_NAME` | `executehub-tests` | The job ExecuteHub triggers/polls |
| `JENKINS_CALLBACK_SECRET` | a long random string | Shared secret for `POST /ci/jenkins/callback` (fails closed when unset) |
| `REDIS_URL` | `redis://localhost:6379/0` (or `.../1`) | Sidekiq + Action Cable (defaults already apply) |

> Generate a Jenkins API token: Jenkins → user → **Configure** → **API Token →
> Add new token**. It is shown once; treat it like a password. JenkinsService
> only reads these five variables — never hardcode credentials.

## 6. Create the Jenkins jobs

### a) `executehub-tests` — the job ExecuteHub triggers

`JenkinsService.trigger_build` calls `JENKINS_JOB_NAME` (default
`executehub-tests`) and polls its result. Create it as a **freestyle project**
with:

- **Build**: `Execute shell`
  ```sh
  docker run --rm --network executehub_default executehub-playwright:latest
  ```
  (The Playwright image already runs `npx playwright test` via its CMD; the
  network lets the container talk to the rest of the compose stack if needed.)

### b) `executehub-pipeline` — the app pipeline (this repo's `Jenkinsfile`)

1. **New Item** → **Pipeline** → name `executehub-pipeline`.
2. **Pipeline → Definition: Pipeline script from SCM**.
3. SCM: **Git**, repository = `https://github.com/SejalMukane/ExecuteHub.git`,
   Script Path = `Jenkinsfile`.
4. **Parameters**: leave the defaults in the Jenkinsfile, or set them on the job
   (see below).
5. First run will hit `EXECUTEHUB_CI_TOKEN` — set it now:

   **Jenkins → Manage Jenkins → Credentials → System → Global** → **Add
   Credentials** → *Secret text* → id `executehub-ci-token`, secret = the `eh_…`
   token from step 4. On the job, add a parameter `EXECUTEHUB_CI_TOKEN` of type
   *Secret text* defaulting to the credential, or reference the credential
   directly in a real setup.

## 7. Parameters on the Jenkinsfile

| Parameter | Default | Notes |
|-----------|---------|-------|
| `EXECUTEHUB_URL` | `http://host.docker.internal:3001` | Jenkins reaches your host Rails server via `host.docker.internal`; use the compose service name if the backend runs in compose too |
| `EXECUTEHUB_PROJECT_ID` | — | Project id that owns the CI token |
| `EXECUTEHUB_CI_TOKEN` | — | Secret text credential |
| `PROJECT_DIR` | `frontend` | Repo sub-directory built in the Install/Build stages |
| `TOTAL_TESTS` | `40` | Test count sent to ExecuteHub (`0` = use suite/config default) |

## 8. End-to-end verification checklist

- [ ] Stack up: `docker compose -f docker-compose.dev.yml ps` → 3 healthy services.
- [ ] Jenkins reachable at `http://localhost:8080`; suggested plugins installed.
- [ ] Backend started with the five `JENKINS_*` vars; `GET /api/v1/health` (or
      `/api/v1/me`) responds.
- [ ] Run **executehub-pipeline**. Stages run Checkout → Install → Build →
      Trigger ExecuteHub → Wait for release gate → Gate check → Deploy (stub).
- [ ] ExecuteHub `/ci-cd` shows a new pipeline for `executehub-pipeline #<n>`
      with a running build + queued test run, and the test run progresses to 100%.
- [ ] Once the run completes, `DeploymentGateService` settles the gate
      (auto-approve if `requires_manual_approval` is false) and the Jenkins
      **Wait for release gate** stage passes. With manual approval required,
      approve it in `/ci-cd/<pipeline>` and re-run; the poll then succeeds.
- [ ] Failure path: trigger a run with failing tests → gate is `blocked` →
      Jenkins **Gate check** stage fails with "Release gate blocked".
- [ ] Rerun a finished build → ExecuteHub returns the **same** pipeline
      (`jenkins:<job>:<build>`) — no duplicates (idempotency).

## 9. Gotchas

- **Callback secret**: `POST /api/v1/ci/jenkins/callback` requires
  `X-Jenkins-Callback-Secret` matching `JENKINS_CALLBACK_SECRET` and fails
  **closed** (401) when the secret is unset. The Jenkinsfile uses the polling
  path, so the callback is optional — both stay consistent because
  `JenkinsBuildCallbackService` owns every Build/Pipeline transition.
- **CSRF crumb**: `JenkinsHttpClient` auto-fetches the crumb for POST/DELETE;
  ensure the Jenkins user has *Overall/Read* so the crumb endpoint is reachable.
- **`host.docker.internal`** only resolves from inside the Jenkins container to
  the host. If you move the backend into compose, change `EXECUTEHUB_URL` to the
  backend service name.
- **Pipeline Utility Steps** plugin is required for `readJSON`.
- Long runs: the **Wait for release gate** stage polls for up to 10 minutes
  (60 × 10s). Bump the loop if your suite takes longer.

## 10. Tearing down

```powershell
docker compose -f docker-compose.dev.yml down
# add -v to also wipe the Jenkins/DB/Redis volumes (destroys job config + data)
