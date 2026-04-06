import { requireAuth } from '@/lib/auth';
import { ProfileForm } from '@/components/profile-form';

export default async function ProfilePage() {
  const { user, token } = await requireAuth();

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Profilo</h1>

      <div className="max-w-2xl">
        {/* User info summary */}
        <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-6 mb-6">
          <div className="flex items-center gap-4 mb-4">
            <div className="w-16 h-16 rounded-full bg-[#4F8CFF]/20 flex items-center justify-center text-[#4F8CFF] text-2xl font-bold">
              {(user.name || user.email)[0].toUpperCase()}
            </div>
            <div>
              <p className="text-lg font-semibold">{user.name || 'Utente'}</p>
              <p className="text-sm text-[#8B8B9E]">{user.email}</p>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="p-3 rounded-lg bg-[#16213E]">
              <p className="text-xs text-[#8B8B9E]">Crediti AI</p>
              <p className="text-lg font-bold text-[#4F8CFF]">{user.ai_credits}</p>
            </div>
            <div className="p-3 rounded-lg bg-[#16213E]">
              <p className="text-xs text-[#8B8B9E]">Membro dal</p>
              <p className="text-sm font-medium">
                {new Date(user.created_at).toLocaleDateString('it-IT', {
                  day: '2-digit',
                  month: 'long',
                  year: 'numeric',
                })}
              </p>
            </div>
          </div>
        </div>

        {/* Edit form */}
        <ProfileForm user={user} token={token} />
      </div>
    </div>
  );
}
