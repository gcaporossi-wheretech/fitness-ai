/**
 * API client for the FitnessAI backend.
 * All requests go through Traefik API gateway.
 */

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost';

interface FetchOptions extends RequestInit {
  token?: string;
}

export class ApiError extends Error {
  constructor(
    public statusCode: number,
    public detail: string,
  ) {
    super(detail);
    this.name = 'ApiError';
  }
}

async function apiFetch<T>(path: string, options: FetchOptions = {}): Promise<T> {
  const { token, ...fetchOptions } = options;

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(fetchOptions.headers as Record<string, string> || {}),
  };

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...fetchOptions,
    headers,
  });

  if (!response.ok) {
    let detail = `HTTP ${response.status}`;
    try {
      const data = await response.json();
      detail = data.detail || data.message || detail;
    } catch {
      // ignore parse error
    }
    throw new ApiError(response.status, detail);
  }

  if (response.status === 204) return undefined as T;
  return response.json();
}

// Auth API
export interface AuthResponse {
  user: UserProfile;
  tokens: { access_token: string; refresh_token: string; token_type: string };
}

export interface UserProfile {
  id: string;
  email: string;
  name: string | null;
  age: number | null;
  ai_credits: number;
  language: string;
  created_at: string;
}

export const authApi = {
  login: (email: string, password: string) =>
    apiFetch<AuthResponse>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }),

  register: (email: string, password: string, name?: string) =>
    apiFetch<AuthResponse>('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ email, password, name }),
    }),

  getProfile: (token: string) =>
    apiFetch<UserProfile>('/auth/me', { token }),

  refresh: (refreshToken: string) =>
    apiFetch<{ access_token: string; refresh_token: string }>('/auth/refresh', {
      method: 'POST',
      body: JSON.stringify({ refresh_token: refreshToken }),
    }),
};

// Workouts API
export interface WorkoutSession {
  id: string;
  plan_id: string | null;
  day_name: string | null;
  started_at: string;
  completed_at: string | null;
  duration_seconds: number | null;
  exercises: Record<string, unknown>[];
  notes: string | null;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  per_page: number;
  pages: number;
}

export const workoutsApi = {
  listSessions: (token: string, page = 1, perPage = 20) =>
    apiFetch<PaginatedResponse<WorkoutSession>>(`/workouts/sessions?page=${page}&per_page=${perPage}`, { token }),

  listPlans: (token: string) =>
    apiFetch<PaginatedResponse<Record<string, unknown>>>('/workouts/plans', { token }),
};

// Analytics API
export const analyticsApi = {
  getSummary: (token: string) =>
    apiFetch<Record<string, unknown>>('/analytics/summary', { token }),

  getProgress: (token: string, days = 90) =>
    apiFetch<Record<string, unknown>>(`/analytics/progress?days=${days}`, { token }),

  getVolume: (token: string, days = 30) =>
    apiFetch<Record<string, unknown>>(`/analytics/volume?days=${days}`, { token }),
};
