# ExecuteHub Frontend

This document describes the React + TypeScript frontend of ExecuteHub.

## Overview

The frontend is a single-page application that provides an interactive dashboard for managing projects, triggering test runs, monitoring execution in real time, and debugging failures.

## Tech Stack

| Layer | Technology |
| --- | --- |
| Framework | React 18 |
| Language | TypeScript |
| Styling | Tailwind CSS |
| State Management | Zustand or Redux Toolkit |
| Routing | React Router |
| API Client | Axios |
| Real-Time | Action Cable / WebSockets |
| Charts | Recharts |
| Icons | Lucide React |
| Build Tool | Vite |

## Project Structure

```
dashboard/
├── public/
├── src/
│   ├── api/                 # API client and endpoints
│   ├── components/          # Reusable UI components
│   ├── hooks/               # Custom React hooks
│   ├── pages/               # Top-level page components
│   ├── stores/              # Zustand/Redux state stores
│   ├── types/               # TypeScript interfaces
│   ├── utils/               # Utility functions
│   ├── channels/            # WebSocket channel subscriptions
│   └── main.tsx             # Application entry point
├── index.html
├── package.json
├── tsconfig.json
└── vite.config.ts
```

## Core Pages

### Authentication Pages

- `/login` — User login
- `/register` — User registration
- `/forgot-password` — Password reset request

### Dashboard Pages

- `/` — Main dashboard with overview widgets
- `/projects` — Project listing
- `/projects/:id` — Project details
- `/projects/new` — Create new project
- `/test-runs/:id` — Test run details and live progress
- `/test-runs/:id/jobs` — Job list for a test run
- `/workers` — Worker pool status
- `/artifacts` — Artifact browser
- `/reports` — Historical reports and analytics
- `/notifications` — User notifications
- `/settings` — User and project settings

## Key Components

### Layout Components

- `Sidebar` — Navigation sidebar
- `Topbar` — Header with user menu and notifications
- `PageContainer` — Consistent page padding and layout

### Dashboard Components

- `StatCard` — Metric summary cards
- `ProgressBar` — Test run progress visualization
- `WorkerStatusGrid` — Live worker status cards
- `QueueDepthChart` — Queue depth over time
- `RecentTestRunsTable` — List of recent test runs

### Test Run Components

- `TestRunHeader` — Status, branch, commit, duration
- `TestMatrix` — Pass/fail matrix by browser and test
- `JobList` — Jobs with status and logs
- `ArtifactViewer` — Screenshots, videos, traces
- `ConsoleLogViewer` — Browser console output
- `NetworkLogViewer` — Network request logs

### Real-Time Components

- `LiveProgress` — Updates automatically via WebSockets
- `WorkerHeartbeat` — Shows worker liveness
- `NotificationToast` — In-app notifications

## State Management

The frontend uses a centralized store for shared state.

### Stores

- `authStore` — User authentication and session
- `projectStore` — Projects list and active project
- `testRunStore` — Current and historical test runs
- `workerStore` — Worker pool state
- `notificationStore` — User notifications

## API Integration

API requests are organized by domain:

```typescript
// src/api/testRuns.ts
export const getTestRun = (id: string) =>
  apiClient.get(`/test_runs/${id}`);

export const createTestRun = (projectId: string, data: CreateTestRunPayload) =>
  apiClient.post(`/projects/${projectId}/test_runs`, data);

export const cancelTestRun = (id: string) =>
  apiClient.post(`/test_runs/${id}/cancel`);
```

## Real-Time Updates

WebSocket subscriptions push live events to the dashboard.

```typescript
// src/channels/testRunChannel.ts
export const subscribeToTestRun = (testRunId: string, onUpdate: (data: any) => void) => {
  const cable = createConsumer(import.meta.env.VITE_WS_URL);
  return cable.subscriptions.create(
    { channel: 'TestRunChannel', test_run_id: testRunId },
    {
      received: onUpdate,
    }
  );
};
```

### Event Types

- `test_run.status_changed`
- `job.started`
- `job.completed`
- `worker.heartbeat`
- `artifact.uploaded`
- `notification.received`

## Routing

```typescript
// src/App.tsx
<Routes>
  <Route path="/login" element={<LoginPage />} />
  <Route path="/" element={<DashboardLayout />}>
    <Route index element={<DashboardPage />} />
    <Route path="projects" element={<ProjectsPage />} />
    <Route path="projects/:id" element={<ProjectDetailsPage />} />
    <Route path="test-runs/:id" element={<TestRunPage />} />
    <Route path="workers" element={<WorkersPage />} />
    <Route path="reports" element={<ReportsPage />} />
    <Route path="settings" element={<SettingsPage />} />
  </Route>
</Routes>
```

## Error Handling

- API errors are caught by a global Axios interceptor
- UI displays toast notifications for failures
- Route-level error boundaries prevent full app crashes
- Network disconnections show a reconnection banner

## Accessibility

- Semantic HTML elements
- ARIA labels for interactive components
- Keyboard navigation support
- Focus indicators

## Responsive Design

The dashboard is responsive and works on:

- Desktop workstations
- Laptops
- Tablets

Mobile support is limited to viewing status and notifications.

## Build and Deployment

```bash
# Development
npm run dev

# Production build
npm run build

# Preview production build
npm run preview
```

The production build is served as static files from an Nginx or S3 + CloudFront distribution.
