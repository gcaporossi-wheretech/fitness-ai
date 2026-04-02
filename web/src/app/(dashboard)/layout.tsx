import { requireAuth } from '@/lib/auth';
import { DashboardSidebar } from '@/components/dashboard-sidebar';

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { user } = await requireAuth();

  return (
    <div className="flex h-screen">
      <DashboardSidebar user={user} />
      <main className="flex-1 overflow-y-auto p-6">{children}</main>
    </div>
  );
}
