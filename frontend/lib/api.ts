const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001/api/v1";

export class ApiError extends Error {
  status: number;
  errors?: string[];

  constructor(status: number, message: string, errors?: string[]) {
    super(message);
    this.status = status;
    this.errors = errors;
  }
}

async function request<T>(
  path: string,
  options: { method?: string; body?: unknown; token?: string | null } = {}
): Promise<T> {
  const { method = "GET", body, token } = options;

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    let message = "Something went wrong";
    let errors: string[] | undefined;
    try {
      const data = await response.json();
      if (data.error) message = data.error;
      if (data.errors) errors = data.errors;
    } catch {
      // ignore parse errors
    }
    throw new ApiError(response.status, message, errors);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return response.json() as Promise<T>;
}

export interface User {
  id: number;
  name: string;
  email: string;
  role: string;
  team_id: number | null;
  created_at: string;
}

export interface AuthResponse {
  user: User;
  token: string;
}

export interface Project {
  id: number;
  name: string;
  description: string | null;
  repository_url: string | null;
  team_id: number | null;
  user_id: number | null;
  created_at: string;
}

export interface BrowserImage {
  id: number;
  name: string;
  version: string;
  tag: string;
}

export interface BrowserSession {
  id: number;
  browser_name: string;
  status: string;
  start_time: string | null;
  end_time: string | null;
  container_id: string | null;
  elapsed: number;
  created_at: string;
}

export interface GithubStatus {
  connected: boolean;
  login: string | null;
}

export interface GithubRepositoryOption {
  id: number;
  full_name: string;
  html_url: string;
  private: boolean;
  description: string | null;
  default_branch: string | null;
}

export interface GithubWebhookInfo {
  id: number;
  github_webhook_id: number | null;
  url: string | null;
  events: string[];
  active: boolean;
  last_delivery_at: string | null;
}

export interface GithubRepository {
  id: number;
  full_name: string;
  html_url: string;
  clone_url: string | null;
  ssh_url: string | null;
  default_branch: string | null;
  private: boolean;
  description: string | null;
  created_at: string;
  webhook: GithubWebhookInfo | null;
}

export interface GithubDelivery {
  id: number;
  delivery_id: string | null;
  event: string | null;
  signature_valid: boolean;
  received_at: string | null;
  payload: Record<string, unknown> | null;
}

export interface GithubRepositoryResponse {
  github_repository: GithubRepository | null;
  deliveries: GithubDelivery[];
}

export type TestRunStatus =
  | "queued"
  | "scheduling"
  | "running"
  | "completed"
  | "failed"
  | "cancelled";

export interface Job {
  id: number;
  test_run_id: number;
  worker_id: string | null;
  chunk_number: number;
  test_count: number;
  status: "queued" | "running" | "uploading_artifacts" | "completed" | "failed" | "retrying";
  started_at: string | null;
  finished_at: string | null;
  retry_count: number;
}

export interface ExecutionLog {
  id: number;
  timestamp: string;
  level: "info" | "warn" | "error";
  message: string;
}

export type ArtifactType = "screenshot" | "video" | "trace" | "log" | "report";
export type ArtifactStatus = "pending" | "uploading" | "uploaded" | "failed";

export interface Artifact {
  id: number;
  job_id: number;
  test_run_id: number;
  artifact_type: ArtifactType;
  file_name: string;
  s3_key: string;
  content_type: string;
  file_size: number;
  checksum: string | null;
  status: ArtifactStatus;
  storage_backend: "s3" | "local";
  created_at: string;
}

export interface ArtifactUrlResponse {
  url: string | null;
  expires_in: number;
  storage_backend: "s3" | "local";
}

export interface JobSummary {
  passed: number;
  failed: number;
  duration_ms: number | null;
  exit_status: string;
}

export interface TestReport {
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

export type TestResultStatus = "passed" | "failed" | "skipped" | "flaky";

export interface TestResult {
  id: number;
  job_id: number;
  test_run_id: number;
  test_name: string;
  suite_name: string | null;
  status: TestResultStatus;
  duration_ms: number;
  browser: string | null;
  error_message: string | null;
  retry_count: number;
  started_at: string | null;
  finished_at: string | null;
  worker: string | null;
}

export interface TestResultDetail extends TestResult {
  stack_trace: string | null;
  artifacts: Artifact[];
  logs: ExecutionLog[];
}

export interface AnalyticsOverview {
  success_rate: number;
  failure_rate: number;
  average_execution_duration_ms: number | null;
  average_test_duration_ms: number | null;
  tests_executed: number;
  tests_passed: number;
  tests_failed: number;
  tests_skipped: number;
  flaky_test_count: number;
  retry_rate: number;
  worker_utilization: number;
  total_test_runs: number;
  completed_test_runs: number;
  failed_test_runs: number;
}

export interface SuccessRatePoint {
  date: string;
  success_rate: number;
}

export interface DurationPoint {
  date: string;
  average_execution_duration_ms: number | null;
}

export interface TestsPerDayPoint {
  date: string;
  tests_executed: number;
}

export interface NamedCount {
  name: string;
  count: number;
}

export interface AnalyticsHistory {
  success_rate_over_time: SuccessRatePoint[];
  failure_rate_over_time: SuccessRatePoint[];
  average_execution_duration: DurationPoint[];
  tests_executed_per_day: TestsPerDayPoint[];
  flaky_tests: number;
  most_failing_tests: NamedCount[];
  most_failing_suites: NamedCount[];
}

export interface AnalyticsResponse {
  overview: AnalyticsOverview;
  history: AnalyticsHistory;
}

export interface JobDetail extends Job {
  container_id: string | null;
  passed_tests: number;
  failed_tests: number;
  duration_ms: number | null;
  duration_seconds: number | null;
  error_message: string | null;
  logs?: ExecutionLog[];
  artifacts?: Artifact[];
  summary?: JobSummary;
}

export interface TestSuite {
  id: number;
  name: string;
  description: string | null;
  total_tests: number;
}

export interface TestRun {
  id: number;
  project_id: number;
  project_name: string;
  branch: string;
  commit_sha: string | null;
  test_suite: TestSuite | null;
  status: TestRunStatus;
  total_tests: number;
  total_jobs: number;
  completed_jobs: number;
  failed_jobs: number;
  queued_jobs: number;
  running_jobs: number;
  passed_tests: number;
  failed_tests: number;
  total_duration_ms: number | null;
  total_screenshots: number;
  total_videos: number;
  progress_percentage: number;
  started_at: string | null;
  finished_at: string | null;
  created_at: string;
  jobs?: Job[];
}

export type TestRunProgress = Omit<TestRun, "jobs" | "project_name" | "branch" | "commit_sha" | "test_suite" | "created_at">;

export type WorkerStatus = "idle" | "busy" | "offline";

export interface WorkerCurrentJob {
  id: number;
  test_run_id: number;
  chunk_number: number;
  test_count: number;
  status: string;
  container_id: string | null;
  started_at: string | null;
}

export interface Worker {
  id: number;
  worker_name: string;
  status: WorkerStatus;
  last_seen_at: string | null;
  cpu_usage: number | null;
  memory_usage: number | null;
  execution_count: number;
  current_job: WorkerCurrentJob | null;
}

export interface WorkerCounts {
  total: number;
  idle: number;
  busy: number;
  offline: number;
}

export interface WorkerPoolResponse {
  counts: WorkerCounts;
  workers: Worker[];
}

export interface QueueStats {
  queued_jobs: number;
  running_jobs: number;
  completed_jobs: number;
  failed_jobs: number;
}

export const api = {
  register: (name: string, email: string, password: string, passwordConfirmation: string) =>
    request<AuthResponse>("/register", {
      method: "POST",
      body: { name, email, password, password_confirmation: passwordConfirmation },
    }),

  login: (email: string, password: string) =>
    request<AuthResponse>("/login", { method: "POST", body: { email, password } }),

  logout: (token: string) =>
    request<{ user: User }>("/logout", { method: "POST", token }),

  me: (token: string) => request<{ user: User }>("/me", { token }),

  updateProfile: (
    token: string,
    data: { name: string; email: string; password?: string; passwordConfirmation?: string }
  ) =>
    request<{ user: User }>("/profile", {
      method: "PUT",
      token,
      body: {
        name: data.name,
        email: data.email,
        ...(data.password ? { password: data.password, password_confirmation: data.passwordConfirmation ?? data.password } : {}),
      },
    }),

  listBrowserImages: (token: string) =>
    request<{ browser_images: BrowserImage[] }>("/browser-images", { token }),

  startSession: (token: string, browserName: string) =>
    request<{ session: BrowserSession }>("/session/start", {
      method: "POST",
      token,
      body: { browser_name: browserName },
    }),

  listSessions: (token: string) =>
    request<{ sessions: BrowserSession[] }>("/session", { token }),

  stopSession: (token: string, id: number) =>
    request<{ session: BrowserSession }>(`/session/${id}`, { method: "DELETE", token }),

  listProjects: (token: string) =>
    request<{ projects: Project[] }>("/projects", { token }),

  createProject: (
    token: string,
    data: { name: string; description?: string; repositoryUrl?: string }
  ) =>
    request<{ project: Project }>("/projects", {
      method: "POST",
      token,
      body: {
        project: {
          name: data.name,
          description: data.description,
          repository_url: data.repositoryUrl,
        },
      },
    }),

  updateProject: (
    token: string,
    id: number,
    data: { name: string; description?: string; repositoryUrl?: string }
  ) =>
    request<{ project: Project }>(`/projects/${id}`, {
      method: "PUT",
      token,
      body: {
        project: {
          name: data.name,
          description: data.description,
          repository_url: data.repositoryUrl,
        },
      },
    }),

  deleteProject: (token: string, id: number) =>
    request<{ project: Project }>(`/projects/${id}`, { method: "DELETE", token }),

  githubStatus: (token: string) =>
    request<GithubStatus>("/github/status", { token }),

  githubOAuthStart: (token: string) =>
    request<{ url: string }>("/github/oauth/start", { token }),

  githubDisconnect: (token: string) =>
    request<undefined>("/github/disconnect", { method: "DELETE", token }),

  listGithubRepositories: (token: string) =>
    request<{ repositories: GithubRepositoryOption[] }>("/github/repositories", { token }),

  connectGithubRepository: (token: string, projectId: number, fullName: string) =>
    request<{ github_repository: GithubRepository }>("/github/repositories", {
      method: "POST",
      token,
      body: { project_id: projectId, full_name: fullName },
    }),

  disconnectGithubRepository: (token: string, projectId: number) =>
    request<undefined>("/github/repositories", {
      method: "DELETE",
      token,
      body: { project_id: projectId },
    }),

  getGithubRepository: (token: string, projectId: number) =>
    request<GithubRepositoryResponse>(
      `/github/projects/${projectId}/repository`,
      { token }
    ),

  createTestRun: (
    token: string,
    projectId: number,
    data: { branch: string; commit_sha?: string; total_tests?: number; test_suite_id?: number }
  ) =>
    request<{ test_run: TestRun }>(`/projects/${projectId}/test_runs`, {
      method: "POST",
      token,
      body: {
        branch: data.branch,
        commit_sha: data.commit_sha,
        total_tests: data.total_tests,
        test_suite_id: data.test_suite_id,
      },
    }),

  listTestSuites: (token: string) =>
    request<{ test_suites: TestSuite[] }>("/test_runs/suites", { token }),

  listTestRuns: (token: string) =>
    request<{ test_runs: TestRun[] }>("/test_runs", { token }),

  getTestRun: (token: string, id: number) =>
    request<{ test_run: TestRun }>(`/test_runs/${id}`, { token }),

  getJob: (token: string, id: number) =>
    request<{ job: JobDetail }>(`/jobs/${id}`, { token }),

  getJobLogs: (token: string, id: number) =>
    request<{ logs: ExecutionLog[] }>(`/jobs/${id}/logs`, { token }),

  getJobArtifacts: (token: string, id: number) =>
    request<{ artifacts: Artifact[] }>(`/jobs/${id}/artifacts`, { token }),

  listArtifacts: (token: string) =>
    request<{ artifacts: Artifact[] }>("/artifacts", { token }),

  getArtifact: (token: string, id: number) =>
    request<{ artifact: Artifact }>(`/artifacts/${id}`, { token }),

  getArtifactUrl: (token: string, id: number) =>
    request<ArtifactUrlResponse>(`/artifacts/${id}/url`, { token }),

  deleteArtifact: (token: string, id: number) =>
    request<undefined>(`/artifacts/${id}`, { method: "DELETE", token }),

  retryArtifact: (token: string, id: number) =>
    request<{ artifact: Artifact }>(`/artifacts/${id}/retry`, { method: "POST", token }),

  getTestRunReport: (token: string, id: number) =>
    request<{ test_run: TestRun; test_report: TestReport | null; test_results: TestResult[] }>(
      `/test_runs/${id}/report`,
      { token }
    ),

  getTestRunResults: (token: string, id: number) =>
    request<{ test_results: TestResult[] }>(`/test_runs/${id}/results`, { token }),

  getTestRunAnalytics: (token: string, id: number) =>
    request<AnalyticsResponse>(`/test_runs/${id}/analytics`, { token }),

  getTestResult: (token: string, id: number) =>
    request<{ test_result: TestResultDetail }>(`/test_results/${id}`, { token }),

  getAnalytics: (token: string, days = 30) =>
    request<AnalyticsResponse>(`/analytics?days=${days}`, { token }),

  getProjectAnalytics: (token: string, projectId: number, days = 30) =>
    request<AnalyticsResponse>(`/projects/${projectId}/analytics?days=${days}`, { token }),

  getArtifactFile: async (token: string, id: number): Promise<Blob> => {
    const response = await fetch(`${API_BASE_URL}/artifacts/${id}/file`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!response.ok) {
      throw new ApiError(response.status, "Failed to load artifact");
    }
    return response.blob();
  },

  getQueueStats: (token: string) =>
    request<{ queue: QueueStats }>("/queue", { token }),

  listWorkers: (token: string) =>
    request<WorkerPoolResponse>("/workers", { token }),

  getWorker: (token: string, id: number) =>
    request<{ worker: Worker }>(`/workers/${id}`, { token }),

  getTestRunProgress: (token: string, id: number) =>
    request<{ test_run: TestRunProgress }>(`/test_runs/${id}/progress`, { token }),
};
