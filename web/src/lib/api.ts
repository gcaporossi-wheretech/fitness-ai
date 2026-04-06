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

// ============================================================
// Auth API
// ============================================================

export interface AuthResponse {
  user: UserProfile;
  tokens: { access_token: string; refresh_token: string; token_type: string };
}

export interface UserProfile {
  id: string;
  email: string;
  name: string | null;
  age: number | null;
  goals: Record<string, string> | null;
  limitations: Record<string, string> | null;
  ai_credits: number;
  language: string;
  created_at: string;
}

export interface CreditsResponse {
  credits: number;
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

  updateProfile: (token: string, data: Partial<Pick<UserProfile, 'name' | 'age' | 'goals' | 'limitations' | 'language'>>) =>
    apiFetch<UserProfile>('/auth/me', {
      method: 'PATCH',
      token,
      body: JSON.stringify(data),
    }),

  getCredits: (token: string) =>
    apiFetch<CreditsResponse>('/auth/credits', { token }),

  refresh: (refreshToken: string) =>
    apiFetch<{ access_token: string; refresh_token: string }>('/auth/refresh', {
      method: 'POST',
      body: JSON.stringify({ refresh_token: refreshToken }),
    }),
};

// ============================================================
// Workouts API
// ============================================================

export interface WorkoutSession {
  id: string;
  plan_id: string | null;
  day_name: string | null;
  started_at: string;
  completed_at: string | null;
  duration_seconds: number | null;
  exercises: ExerciseLog[];
  notes: string | null;
}

export interface ExerciseLog {
  name: string;
  sets: SetLog[];
  muscle_groups?: string[];
}

export interface SetLog {
  reps: number;
  weight_kg: number;
  completed: boolean;
}

export interface WorkoutPlan {
  id: string;
  name: string;
  description: string | null;
  days: Record<string, unknown>[];
  source: string | null;
  is_active: boolean;
  created_at: string;
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
    apiFetch<PaginatedResponse<WorkoutSession>>(
      `/workouts/sessions?page=${page}&per_page=${perPage}`,
      { token },
    ),

  listPlans: (token: string) =>
    apiFetch<PaginatedResponse<WorkoutPlan>>('/workouts/plans', { token }),
};

// ============================================================
// Analytics API
// ============================================================

export interface AnalyticsSummary {
  total_sessions: number;
  total_volume_kg: number;
  current_streak: number;
  longest_streak: number;
  favorite_exercise: string | null;
  avg_duration_minutes: number;
  sessions_this_week: number;
  sessions_this_month: number;
}

export interface ProgressDataPoint {
  date: string;
  max_weight: number;
  avg_weight: number;
  total_volume: number;
}

export interface VolumeDataPoint {
  period: string;
  muscle_group: string;
  total_volume: number;
  total_sets: number;
}

export interface AdherenceData {
  planned: number;
  completed: number;
  rate: number;
}

export const analyticsApi = {
  getSummary: (token: string) =>
    apiFetch<AnalyticsSummary>('/analytics/summary', { token }),

  getProgress: (token: string, exerciseName: string, days = 90) =>
    apiFetch<{ data_points: ProgressDataPoint[] }>(
      `/analytics/progress/${encodeURIComponent(exerciseName)}?days=${days}`,
      { token },
    ),

  getVolume: (token: string, days = 30, groupBy = 'week') =>
    apiFetch<{ data_points: VolumeDataPoint[] }>(
      `/analytics/volume?days=${days}&group_by=${groupBy}`,
      { token },
    ),

  getAdherence: (token: string, days = 30) =>
    apiFetch<AdherenceData>(
      `/analytics/adherence?days=${days}`,
      { token },
    ),
};
