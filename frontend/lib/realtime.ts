import { createConsumer } from "@rails/actioncable";

// ActionCable mount on the backend. The token travels as a query param because
// browsers cannot set Authorization headers on WebSocket upgrade requests.
const CABLE_BASE_URL = process.env.NEXT_PUBLIC_CABLE_URL ?? "http://localhost:3001/cable";

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
}

export interface RunProgressEvent {
  id: number;
  status: string;
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

export interface WorkerEvent {
  id: number;
  worker_name: string;
  status: string;
  last_seen_at: string | null;
  cpu_usage: number | null;
  memory_usage: number | null;
  execution_count: number;
  current_job_id: number | null;
}

export type RealtimeMessage =
  | { type: "job_started" | "job_finished"; job: JobEvent }
  | { type: "run_progress"; test_run: RunProgressEvent }
  | {
      type: "worker_heartbeat" | "worker_offline" | "worker_online";
      worker: WorkerEvent;
    };

// One ActionCable consumer per token so login/logout never cross wires.
const consumers = new Map<string, ReturnType<typeof createConsumer>>();

function cableFor(token: string) {
  let cable = consumers.get(token);
  if (!cable) {
    cable = createConsumer(`${CABLE_BASE_URL}?token=${encodeURIComponent(token)}`);
    consumers.set(token, cable);
  }
  return cable;
}

function subscribe(
  token: string,
  channel: string,
  identifier: Record<string, unknown>,
  onEvent: (message: RealtimeMessage) => void
): () => void {
  const subscription = cableFor(token).subscriptions.create(
    { channel, ...identifier },
    {
      received: (payload: unknown) => {
        if (payload && typeof payload === "object" && "type" in payload) {
          onEvent(payload as RealtimeMessage);
        }
      },
    }
  );
  return () => {
    try {
      subscription.unsubscribe();
    } catch {
      // Subscription may already be gone after a disconnect.
    }
  };
}

export function subscribeWorkers(
  token: string,
  onEvent: (message: RealtimeMessage) => void
): () => void {
  return subscribe(token, "WorkersChannel", {}, onEvent);
}

export function subscribeTestRun(
  token: string,
  runId: number,
  onEvent: (message: RealtimeMessage) => void
): () => void {
  return subscribe(token, "TestRunsChannel", { id: runId }, onEvent);
}

export function subscribeJobs(
  token: string,
  onEvent: (message: RealtimeMessage) => void
): () => void {
  return subscribe(token, "JobsChannel", {}, onEvent);
}
