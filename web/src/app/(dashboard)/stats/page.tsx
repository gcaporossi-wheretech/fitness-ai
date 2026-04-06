import { requireAuth } from '@/lib/auth';
import { analyticsApi } from '@/lib/api';
import type { AnalyticsSummary } from '@/lib/api';
import { ProgressChart, VolumeChart, AdherenceRing } from '@/components/stats-charts';

function SummaryCard({
  title,
  value,
  subtitle,
  color,
}: {
  title: string;
  value: string | number;
  subtitle?: string;
  color: string;
}) {
  return (
    <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-4">
      <p className="text-xs text-[#8B8B9E] mb-1">{title}</p>
      <p className={`text-2xl font-bold ${color}`}>{value}</p>
      {subtitle && <p className="text-xs text-[#8B8B9E] mt-1">{subtitle}</p>}
    </div>
  );
}

export default async function StatsPage() {
  const { token } = await requireAuth();

  let summary: AnalyticsSummary | null = null;
  let progressData: { date: string; max_weight: number; avg_weight: number }[] = [];
  let volumeData: { period: string; muscle_group: string; total_volume: number }[] = [];
  let adherence = { planned: 0, completed: 0, rate: 0 };
  let error: string | null = null;

  try {
    summary = await analyticsApi.getSummary(token);
  } catch (e) {
    error = e instanceof Error ? e.message : 'Errore nel caricamento statistiche';
  }

  try {
    const progressResult = await analyticsApi.getProgress(token, 'Bench Press', 90);
    progressData = progressResult.data_points || [];
  } catch {
    // Progress data optional
  }

  try {
    const volumeResult = await analyticsApi.getVolume(token, 30, 'week');
    volumeData = volumeResult.data_points || [];
  } catch {
    // Volume data optional
  }

  try {
    adherence = await analyticsApi.getAdherence(token, 30);
  } catch {
    // Adherence data optional
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Statistiche</h1>

      {error && (
        <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4 mb-4">
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      {/* Summary cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <SummaryCard
          title="Sessioni totali"
          value={summary?.total_sessions ?? 0}
          color="text-[#4F8CFF]"
        />
        <SummaryCard
          title="Volume totale"
          value={summary?.total_volume_kg ? `${Math.round(summary.total_volume_kg)} kg` : '0 kg'}
          color="text-[#00D4AA]"
        />
        <SummaryCard
          title="Streak attuale"
          value={summary?.current_streak ?? 0}
          subtitle={`Record: ${summary?.longest_streak ?? 0}`}
          color="text-[#FFB800]"
        />
        <SummaryCard
          title="Media durata"
          value={summary?.avg_duration_minutes ? `${Math.round(summary.avg_duration_minutes)} min` : '-'}
          color="text-[#4F8CFF]"
        />
      </div>

      {/* Activity this period */}
      <div className="grid grid-cols-2 gap-4 mb-8">
        <SummaryCard
          title="Questa settimana"
          value={summary?.sessions_this_week ?? 0}
          subtitle="sessioni"
          color="text-[#00D4AA]"
        />
        <SummaryCard
          title="Questo mese"
          value={summary?.sessions_this_month ?? 0}
          subtitle="sessioni"
          color="text-[#00D4AA]"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-4">
          <ProgressChart
            data={progressData}
            exerciseName={summary?.favorite_exercise || 'Bench Press'}
          />
        </div>
        <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-4">
          <VolumeChart data={volumeData} />
        </div>
      </div>

      {/* Adherence */}
      <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-6 flex justify-center">
        <AdherenceRing
          rate={adherence.rate}
          planned={adherence.planned}
          completed={adherence.completed}
        />
      </div>
    </div>
  );
}
