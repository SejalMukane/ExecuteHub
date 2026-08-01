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
  created_at: string;
}

export interface AuthResponse {
  user: User;
  token: string;
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
};
