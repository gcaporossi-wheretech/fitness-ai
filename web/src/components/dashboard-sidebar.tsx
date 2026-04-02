'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import type { UserProfile } from '@/lib/api';

interface DashboardSidebarProps {
  user: UserProfile;
}

const navItems = [
  { href: '/', label: 'Dashboard', icon: '📊' },
  { href: '/workouts', label: 'Allenamenti', icon: '💪' },
  { href: '/stats', label: 'Statistiche', icon: '📈' },
  { href: '/profile', label: 'Profilo', icon: '👤' },
];

export function DashboardSidebar({ user }: DashboardSidebarProps) {
  const pathname = usePathname();
  const router = useRouter();

  async function handleLogout() {
    await fetch('/api/auth/logout', { method: 'POST' });
    router.push('/login');
    router.refresh();
  }

  return (
    <aside className="w-64 bg-[#1A1A2E] border-r border-[#4F8CFF]/10 flex flex-col">
      {/* Logo */}
      <div className="p-6">
        <h1 className="text-xl font-black bg-gradient-to-r from-[#4F8CFF] to-[#00D4AA] bg-clip-text text-transparent">
          FitnessAI
        </h1>
        <p className="text-xs text-[#8B8B9E] mt-1">Dashboard</p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3">
        {navItems.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg mb-1 text-sm transition-colors ${
                isActive
                  ? 'bg-[#4F8CFF]/15 text-[#4F8CFF] font-medium'
                  : 'text-[#8B8B9E] hover:text-white hover:bg-white/5'
              }`}
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          );
        })}
      </nav>

      {/* User section */}
      <div className="p-4 border-t border-[#4F8CFF]/10">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-8 h-8 rounded-full bg-[#4F8CFF]/20 flex items-center justify-center text-[#4F8CFF] text-sm font-bold">
            {(user.name || user.email)[0].toUpperCase()}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium truncate">
              {user.name || user.email}
            </p>
            <p className="text-xs text-[#8B8B9E] truncate">{user.email}</p>
          </div>
        </div>
        <button
          onClick={handleLogout}
          className="w-full text-left text-sm text-[#8B8B9E] hover:text-[#FF4757] transition-colors px-3 py-2 rounded-lg hover:bg-[#FF4757]/10"
        >
          Esci
        </button>
      </div>
    </aside>
  );
}
