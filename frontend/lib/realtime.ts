import { createConsumer } from "@rails/actioncable";

// ActionCable mount on the backend. The token travels as a query param because
// browsers cannot set Authorization headers on WebSocket upgrade requests.
const CABLE_BASE_URL =
  process.env.NEXT_PUBLIC_CABLE_URL ?? "http://localhost:3001/cable";

export interface JobEvent {
  id: number;
  test_run_id: number;
  worker_id: string | null;
  chunk_number: number;
  test_count: number;
  status: string;
  started_at: string | null;
  finished_at: string | null;
  retry_count: number;
  container_id: string | null;
}

export interface WorkerCurrentJob {
  id: number;
  test_run_id: number;
  chunk_number: number;
  test_count: number;
  status: string;
  container_id: string | null;
  started_at: string | null;
  duration_seconds: number | null;
  worker_id: string | null;
}

export interface WorkerEvent {
  id: number;
  worker_name: string;
  status: string;
  last_seen_at: string | null;
  heartbeat_at: string | null;
  cpu_usage: number | null;
  memory_usage: number | null;
  execution_count: number;
  current_job_id: number | null;
  current_job: WorkerCurrentJob | null;
  browser: string | null;
  container_status: string | null;
}

export interface RunProgressEvent {
  id: number;
  status: string;
  project_name: string;
  total_tests: number;
  total_jobs: number;
  queued_jobs: number;
  running_jobs: number;
  completed_jobs: number;
  failed_jobs: number;
  passed_tests: number;
  failed_tests: number;
  total_duration_ms: number | null;
  progress_percentage: number;
  started_at: string | null;
  finished_at: string | null;
}

export interface DashboardMetricsEvent {
  total_projects: number;
  running_test_runs: number;
  queued_jobs: number;
  running_jobs: number;
  completed_jobs: number;
  failed_jobs: number;
  active_workers: number;
  idle_workers: number;
  offline_workers: number;
  average_execution_time: number | null;
  average_queue_wait_time: number;
  worker_utilization: number;
  success_rate: number;
  updated_at: string;
}

export interface QueueMetricsEvent {
  queue_size: number;
  running_jobs: number;
  average_wait_time: number;
  longest_waiting_job: {
    job_id: number;
    enqueued_at: string;
    waiting_seconds: number;
  } | null;
  completed_today: number;
  failed_today: number;
  retry_count: number;
  updated_at: string;
}

export interface ArtifactsEvent {
  job_id: number;
  test_run_id: number;
  artifact_count: number;
  worker_id: string | null;
}

export interface ArtifactEvent {
  id: number;
  job_id: number;
  test_run_id: number;
  artifact_type: string;
  file_name: string | null;
  size: number | null;
  status: string;
}

export interface ReportEvent {
  id: number;
  test_run_id: number;
  total_tests: number;
  passed_tests: number;
  failed_tests: number;
  skipped_tests: number;
  flaky_tests: number;
  duration_ms: number;
  success_rate: number;
  generated_at: string;
}

export interface TestResultEvent {
  id: number;
  job_id: number;
  test_run_id: number;
  test_name: string;
  suite_name: string | null;
  status: string;
  duration_ms: number;
  browser: string | null;
  error_message: string | null;
  retry_count: number;
}

export interface ActivityEvent {
  id: string;
  text: string;
  type: "info" | "success" | "warning" | "error";
  timestamp: string;
}

export interface PipelineEvent {
  id: number;
  project_id: number;
  project_name: string | null;
  name: string;
  provider: string;
  status: string;
  branch: string | null;
  commit_sha: string | null;
  triggered_by: string | null;
  created_at: string | null;
}

export interface DeploymentGateEvent {
  id: number;
  pipeline_id: number;
  test_run_id: number | null;
  project_id: number;
  status: string;
  reason: string | null;
  requires_approval: boolean;
  decided_at: string | null;
  created_at: string;
}

export interface NotificationEvent {
  id: number;
  project_id: number | null;
  test_run_id: number | null;
  pipeline_id: number | null;
  title: string;
  description: string | null;
  category: string;
  read: boolean;
  created_at: string;
}

export type RealtimeMessage =
  | { type: "job_created" | "job_started" | "job_completed" | "job_failed"; job: JobEvent }
  | { type: "test_run_started" | "test_run_completed" | "test_run_progress_updated"; test_run: RunProgressEvent }
  | { type: "worker_registered" | "worker_heartbeat" | "worker_online" | "worker_offline"; worker: WorkerEvent }
  | { type: "queue_updated"; queue: QueueMetricsEvent }
  | { type: "artifacts_uploaded"; artifacts: ArtifactsEvent }
  | { type: "artifact_upload_started" | "artifact_uploaded"; artifact: ArtifactEvent }
  | { type: "artifact_failed"; error: string; artifact: ArtifactEvent }
  | { type: "report_generated"; test_run_id: number; report: ReportEvent }
  | { type: "test_result_completed"; test_result: TestResultEvent }
  | { type: "test_run_analytics_updated"; test_run_id: number }
  | { type: "execution_finished"; test_run_id: number; project_name: string; status: string }
  | { type: "metrics_updated"; metrics: DashboardMetricsEvent; queue: QueueMetricsEvent }
  | {
      type: "pipeline_created" | "pipeline_started" | "pipeline_completed" | "pipeline_test_run_started";
      pipeline: PipelineEvent;
    }
  | {
      type: "deployment_gate_approved" | "deployment_gate_blocked" | "deployment_gate_pending";
      deployment_gate: DeploymentGateEvent;
    }
  | { type: "notification_created"; notification: NotificationEvent };

// One ActionCable consumer per token so login/logout never cross wires.
const consumers = new Map<string, ReturnType<typeof createConsumer>>();

export function cableFor(token: string) {
  let cable = consumers.get(token);
  if (!cable) {
    cable = createConsumer(
      `${CABLE_BASE_URL}?token=${encodeURIComponent(token)}`
    );
    consumers.set(token, cable);
  }
  return cable;
}

export function disconnectCable(token: string) {
  const cable = consumers.get(token);
  if (cable) {
    cable.disconnect();
    consumers.delete(token);
  }
}

export function subscribe(
  token: string,
  channel: string,
  identifier: Record<string, unknown>,
  onEvent: (message: RealtimeMessage) => void,
  onConnectionChange?: (state: ConnectionState) => void
): {
  unsubscribe: () => void;
  connectionState: () => ConnectionState;
} {
  const cable = cableFor(token);
  const connectionState = (): ConnectionState => {
    // @ts-expect-error internal connection state
    const state = cable?.connection?.monitor?.state ?? "disconnected";
    if (state === "connected") return "connected";
    if (state === "connecting") return "connecting";
    if (state === "disconnected" || state === "closed") return "disconnected";
    return "connecting";
  };

  const subscription = cable.subscriptions.create(
    { channel, ...identifier },
    {
      received: (payload: unknown) => {
        if (payload && typeof payload === "object" && "type" in payload) {
          onEvent(payload as RealtimeMessage);
        }
      },
      connected: () => onConnectionChange?.("connected"),
      disconnected: () => onConnectionChange?.("disconnected"),
    }
  );

  return {
    unsubscribe: () => {
      try {
        subscription.unsubscribe();
      } catch {
        // Subscription may already be gone after a disconnect.
      }
    },
    connectionState,
  };
}

export type ConnectionState = "connected" | "connecting" | "disconnected";

export function subscribeDashboard(
  token: string,
  onEvent: (message: RealtimeMessage) => void,
  onConnectionChange?: (state: ConnectionState) => void
) {
  return subscribe(
    token,
    "DashboardChannel",
    {},
    onEvent,
    onConnectionChange
  );
}

export function subscribeQueue(
  token: string,
  onEvent: (message: RealtimeMessage) => void,
  onConnectionChange?: (state: ConnectionState) => void
) {
  return subscribe(
    token,
    "QueueChannel",
    {},
    onEvent,
    onConnectionChange
  );
}

export function subscribeWorkers(
  token: string,
  onEvent: (message: RealtimeMessage) => void,
  onConnectionChange?: (state: ConnectionState) => void
) {
  return subscribe(
    token,
    "WorkerChannel",
    {},
    onEvent,
    onConnectionChange
  );
}

export function subscribeTestRun(
  token: string,
  runId: number,
  onEvent: (message: RealtimeMessage) => void,
  onConnectionChange?: (state: ConnectionState) => void
) {
  return subscribe(
    token,
    "TestRunChannel",
    { id: runId },
    onEvent,
    onConnectionChange
  );
}

export function subscribeJobs(
  token: string,
  onEvent: (message: RealtimeMessage) => void,
  onConnectionChange?: (state: ConnectionState) => void
) {
  return subscribe(
    token,
    "JobsChannel",
    {},
    onEvent,
    onConnectionChange
  );
}
