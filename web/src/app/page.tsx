import { redirect } from 'next/navigation';
import { getAccessToken } from '@/lib/auth';

/** Root page redirects based on auth state. */
export default async function RootPage() {
  const token = await getAccessToken();
  if (token) {
    redirect('/dashboard');
  } else {
    redirect('/login');
  }
}
