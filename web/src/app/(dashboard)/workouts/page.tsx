import { requireAuth } from '@/lib/auth';
import { workoutsApi } from '@/lib/api';
import type { WorkoutSession } from '@/lib/api';

function formatDuration(seconds: number | null): string {
  if (!seconds) return '-';
  const mins = Math.floor(seconds / 60);
  if (mins < 60) return `${mins}min`;
  const hrs = Math.floor(mins / 60);
  const remainMins = mins % 60;
  return `${hrs}h ${remainMins}min`;
}

function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString('it-IT', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

function formatTime(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleTimeString('it-IT', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

function countTotalSets(exercises: WorkoutSession['exercises']): number {
  if (!Array.isArray(exercises)) return 0;
  return exercises.reduce((acc, ex) => {
    const sets = Array.isArray(ex.sets) ? ex.sets.length : 0;
    return acc + sets;
  }, 0);
}

function totalVolume(exercises: WorkoutSession['exercises']): number {
  if (!Array.isArray(exercises)) return 0;
  return exercises.reduce((acc, ex) => {
    if (!Array.isArray(ex.sets)) return acc;
    return acc + ex.sets.reduce((setAcc: number, s: { reps?: number; weight_kg?: number }) => {
      return setAcc + (s.reps || 0) * (s.weight_kg || 0);
    }, 0);
  }, 0);
}

function SessionCard({ session }: { session: WorkoutSession }) {
  const exercises = Array.isArray(session.exercises) ? session.exercises : [];
  const volume = totalVolume(session.exercises);
  const sets = countTotalSets(session.exercises);

  return (
    <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-4">
      <div className="flex items-center justify-between mb-3">
        <div>
          <p className="font-semibold">
            {session.day_name || 'Sessione libera'}
          </p>
          <p className="text-xs text-[#8B8B9E]">
            {formatDate(session.started_at)} alle {formatTime(session.started_at)}
          </p>
        </div>
        <span className="text-xs px-2 py-1 rounded bg-[#4F8CFF]/10 text-[#4F8CFF]">
          {formatDuration(session.duration_seconds)}
        </span>
      </div>

      <div className="grid grid-cols-3 gap-2 mb-3">
        <div className="text-center p-2 rounded bg-[#16213E]">
          <p className="text-lg font-bold text-[#4F8CFF]">{exercises.length}</p>
          <p className="text-xs text-[#8B8B9E]">Esercizi</p>
        </div>
        <div className="text-center p-2 rounded bg-[#16213E]">
          <p className="text-lg font-bold text-[#00D4AA]">{sets}</p>
          <p className="text-xs text-[#8B8B9E]">Serie</p>
        </div>
        <div className="text-center p-2 rounded bg-[#16213E]">
          <p className="text-lg font-bold text-[#FFB800]">
            {volume > 0 ? `${Math.round(volume)}` : '-'}
          </p>
          <p className="text-xs text-[#8B8B9E]">Volume kg</p>
        </div>
      </div>

      {exercises.length > 0 && (
        <div className="space-y-1">
          {exercises.slice(0, 4).map((ex, i) => (
            <p key={i} className="text-sm text-[#8B8B9E]">
              {ex.name || 'Esercizio'}{' '}
              {Array.isArray(ex.sets) && (
                <span className="text-[#4F8CFF]">
                  {ex.sets.length} x {ex.sets[0]?.reps || '-'}
                </span>
              )}
            </p>
          ))}
          {exercises.length > 4 && (
            <p className="text-xs text-[#8B8B9E]">
              +{exercises.length - 4} altri esercizi
            </p>
          )}
        </div>
      )}

      {session.notes && (
        <p className="mt-2 text-xs text-[#8B8B9E] italic border-t border-[#4F8CFF]/5 pt-2">
          {session.notes}
        </p>
      )}
    </div>
  );
}

export default async function WorkoutsPage() {
  const { token } = await requireAuth();

  let sessions: WorkoutSession[] = [];
  let total = 0;
  let error: string | null = null;

  try {
    const data = await workoutsApi.listSessions(token, 1, 50);
    sessions = data.items;
    total = data.total;
  } catch (e) {
    error = e instanceof Error ? e.message : 'Errore nel caricamento';
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold">Allenamenti</h1>
          <p className="text-sm text-[#8B8B9E]">
            {total} sessioni totali
          </p>
        </div>
      </div>

      {error && (
        <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4 mb-4">
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      {sessions.length === 0 && !error && (
        <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-8 text-center">
          <p className="text-[#8B8B9E]">Nessun allenamento registrato</p>
          <p className="text-sm text-[#8B8B9E] mt-2">
            Completa un allenamento dall&apos;app mobile per vederlo qui.
          </p>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {sessions.map((session) => (
          <SessionCard key={session.id} session={session} />
        ))}
      </div>
    </div>
  );
}
