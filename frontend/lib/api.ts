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
  status: "queued" | "running" | "completed" | "failed" | "retrying";
  started_at: string | null;
  finished_at: string | null;
  retry_count: number;
}

export interface TestRun {
  id: number;
  project_id: number;
  project_name: string;
  branch: string;
  commit_sha: string;
  status: TestRunStatus;
  total_tests: number;
  total_jobs: number;
  completed_jobs: number;
  failed_jobs: number;
  queued_jobs: number;
  progress_percentage: number;
  started_at: string | null;
  finished_at: string | null;
  created_at: string;
  jobs?: Job[];
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
    data: { branch: string; commit_sha: string; total_tests: number }
  ) =>
    request<{ test_run: TestRun }>(`/projects/${projectId}/test_runs`, {
      method: "POST",
      token,
      body: {
        branch: data.branch,
        commit_sha: data.commit_sha,
        total_tests: data.total_tests,
      },
    }),

  listTestRuns: (token: string) =>
    request<{ test_runs: TestRun[] }>("/test_runs", { token }),

  getTestRun: (token: string, id: number) =>
    request<{ test_run: TestRun }>(`/test_runs/${id}`, { token }),

  getQueueStats: (token: string) =>
    request<{ queue: QueueStats }>("/queue", { token }),
};
