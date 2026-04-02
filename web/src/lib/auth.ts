/**
 * Auth utilities for the Next.js dashboard.
 * Tokens stored in cookies (httpOnly in production, accessible for SSR).
 */

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { authApi } from './api';

const ACCESS_TOKEN_KEY = 'fitness_ai_access_token';
const REFRESH_TOKEN_KEY = 'fitness_ai_refresh_token';

/** Get the current access token from cookies. */
export async function getAccessToken(): Promise<string | null> {
  const cookieStore = await cookies();
  return cookieStore.get(ACCESS_TOKEN_KEY)?.value || null;
}

/** Set auth tokens in cookies. */
export async function setTokens(accessToken: string, refreshToken: string): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(ACCESS_TOKEN_KEY, accessToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 15, // 15 minutes
    path: '/',
  });
  cookieStore.set(REFRESH_TOKEN_KEY, refreshToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7, // 7 days
    path: '/',
  });
}

/** Clear auth tokens (logout). */
export async function clearTokens(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.delete(ACCESS_TOKEN_KEY);
  cookieStore.delete(REFRESH_TOKEN_KEY);
}

/** Get authenticated user or redirect to login. */
export async function requireAuth() {
  const token = await getAccessToken();
  if (!token) {
    redirect('/login');
  }

  try {
    const user = await authApi.getProfile(token);
    return { user, token };
  } catch {
    // Try refresh
    const cookieStore = await cookies();
    const refreshToken = cookieStore.get(REFRESH_TOKEN_KEY)?.value;
    if (refreshToken) {
      try {
        const tokens = await authApi.refresh(refreshToken);
        await setTokens(tokens.access_token, tokens.refresh_token);
        const user = await authApi.getProfile(tokens.access_token);
        return { user, token: tokens.access_token };
      } catch {
        await clearTokens();
      }
    }
    redirect('/login');
  }
}
