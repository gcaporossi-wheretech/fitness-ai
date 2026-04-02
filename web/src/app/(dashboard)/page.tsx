import { requireAuth } from '@/lib/auth';

export default async function DashboardPage() {
  const { user } = await requireAuth();

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">
        Ciao{user.name ? `, ${user.name}` : ''}!
      </h1>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <StatCard
          title="Crediti AI"
          value={`${user.ai_credits}`}
          icon="✨"
          color="from-[#4F8CFF] to-[#4F8CFF]/50"
        />
        <StatCard
          title="Account"
          value={user.email}
          icon="📧"
          color="from-[#00D4AA] to-[#00D4AA]/50"
        />
        <StatCard
          title="Lingua"
          value={user.language === 'it' ? 'Italiano' : 'English'}
          icon="🌍"
          color="from-[#FFB800] to-[#FFB800]/50"
        />
      </div>

      <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-6">
        <h2 className="text-lg font-semibold mb-4">Inizia</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <ActionCard
            title="Visualizza Allenamenti"
            description="Guarda il tuo storico workout"
            href="/workouts"
          />
          <ActionCard
            title="Statistiche"
            description="Analizza i tuoi progressi"
            href="/stats"
          />
        </div>
      </div>
    </div>
  );
}

function StatCard({
  title,
  value,
  icon,
  color,
}: {
  title: string;
  value: string;
  icon: string;
  color: string;
}) {
  return (
    <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-4">
      <div className="flex items-center gap-3">
        <div
          className={`w-10 h-10 rounded-lg bg-gradient-to-br ${color} flex items-center justify-center text-lg`}
        >
          {icon}
        </div>
        <div>
          <p className="text-xs text-[#8B8B9E]">{title}</p>
          <p className="text-sm font-semibold truncate">{value}</p>
        </div>
      </div>
    </div>
  );
}

function ActionCard({
  title,
  description,
  href,
}: {
  title: string;
  description: string;
  href: string;
}) {
  return (
    <a
      href={href}
      className="block p-4 rounded-lg bg-[#16213E] hover:bg-[#16213E]/80 transition-colors border border-transparent hover:border-[#4F8CFF]/20"
    >
      <h3 className="font-medium mb-1">{title}</h3>
      <p className="text-sm text-[#8B8B9E]">{description}</p>
    </a>
  );
}
