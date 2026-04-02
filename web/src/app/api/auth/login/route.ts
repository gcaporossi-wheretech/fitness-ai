import { NextResponse } from 'next/server';
import { authApi } from '@/lib/api';
import { setTokens } from '@/lib/auth';

export async function POST(request: Request) {
  try {
    const { email, password } = await request.json();
    const data = await authApi.login(email, password);

    await setTokens(data.tokens.access_token, data.tokens.refresh_token);

    return NextResponse.json({ user: data.user });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Login failed';
    return NextResponse.json({ error: message }, { status: 401 });
  }
}
