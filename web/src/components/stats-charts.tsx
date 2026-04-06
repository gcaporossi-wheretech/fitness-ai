'use client';

import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

interface ProgressChartProps {
  data: { date: string; max_weight: number; avg_weight: number }[];
  exerciseName: string;
}

export function ProgressChart({ data, exerciseName }: ProgressChartProps) {
  if (data.length === 0) {
    return (
      <div className="h-64 flex items-center justify-center text-[#8B8B9E]">
        Nessun dato di progressione disponibile
      </div>
    );
  }

  const formatted = data.map((d) => ({
    ...d,
    date: new Date(d.date).toLocaleDateString('it-IT', {
      day: '2-digit',
      month: 'short',
    }),
  }));

  return (
    <div>
      <h3 className="text-sm font-medium text-[#8B8B9E] mb-3">
        Progressione: {exerciseName}
      </h3>
      <ResponsiveContainer width="100%" height={240}>
        <AreaChart data={formatted}>
          <defs>
            <linearGradient id="gradMax" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#4F8CFF" stopOpacity={0.3} />
              <stop offset="95%" stopColor="#4F8CFF" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#1A1A2E" />
          <XAxis
            dataKey="date"
            stroke="#8B8B9E"
            fontSize={11}
            tickLine={false}
          />
          <YAxis
            stroke="#8B8B9E"
            fontSize={11}
            tickLine={false}
            unit=" kg"
          />
          <Tooltip
            contentStyle={{
              backgroundColor: '#1A1A2E',
              border: '1px solid rgba(79, 140, 255, 0.1)',
              borderRadius: '8px',
              color: '#fff',
              fontSize: '12px',
            }}
          />
          <Area
            type="monotone"
            dataKey="max_weight"
            stroke="#4F8CFF"
            fillOpacity={1}
            fill="url(#gradMax)"
            name="Max (kg)"
          />
          <Area
            type="monotone"
            dataKey="avg_weight"
            stroke="#00D4AA"
            fillOpacity={0.1}
            fill="#00D4AA"
            name="Media (kg)"
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

interface VolumeChartProps {
  data: { period: string; muscle_group: string; total_volume: number }[];
}

export function VolumeChart({ data }: VolumeChartProps) {
  if (data.length === 0) {
    return (
      <div className="h-64 flex items-center justify-center text-[#8B8B9E]">
        Nessun dato di volume disponibile
      </div>
    );
  }

  // Group by muscle group and sum volumes
  const grouped = data.reduce(
    (acc, d) => {
      const group = d.muscle_group || 'Altro';
      acc[group] = (acc[group] || 0) + d.total_volume;
      return acc;
    },
    {} as Record<string, number>,
  );

  const chartData = Object.entries(grouped)
    .map(([name, volume]) => ({ name, volume: Math.round(volume) }))
    .sort((a, b) => b.volume - a.volume)
    .slice(0, 8);

  return (
    <div>
      <h3 className="text-sm font-medium text-[#8B8B9E] mb-3">
        Volume per gruppo muscolare
      </h3>
      <ResponsiveContainer width="100%" height={240}>
        <BarChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" stroke="#1A1A2E" />
          <XAxis
            dataKey="name"
            stroke="#8B8B9E"
            fontSize={11}
            tickLine={false}
            angle={-20}
            textAnchor="end"
          />
          <YAxis
            stroke="#8B8B9E"
            fontSize={11}
            tickLine={false}
            unit=" kg"
          />
          <Tooltip
            contentStyle={{
              backgroundColor: '#1A1A2E',
              border: '1px solid rgba(79, 140, 255, 0.1)',
              borderRadius: '8px',
              color: '#fff',
              fontSize: '12px',
            }}
          />
          <Bar
            dataKey="volume"
            fill="#4F8CFF"
            radius={[4, 4, 0, 0]}
            name="Volume (kg)"
          />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

interface AdherenceRingProps {
  rate: number;
  planned: number;
  completed: number;
}

export function AdherenceRing({ rate, planned, completed }: AdherenceRingProps) {
  const percentage = Math.round(rate * 100);
  const circumference = 2 * Math.PI * 45;
  const strokeDashoffset = circumference - (rate * circumference);

  let color = '#FF4757'; // red
  if (percentage >= 80) color = '#00D4AA'; // green
  else if (percentage >= 50) color = '#FFB800'; // yellow

  return (
    <div className="flex flex-col items-center">
      <h3 className="text-sm font-medium text-[#8B8B9E] mb-3">
        Aderenza al piano
      </h3>
      <div className="relative w-32 h-32">
        <svg className="w-full h-full -rotate-90" viewBox="0 0 100 100">
          <circle
            cx="50"
            cy="50"
            r="45"
            fill="none"
            stroke="#1A1A2E"
            strokeWidth="8"
          />
          <circle
            cx="50"
            cy="50"
            r="45"
            fill="none"
            stroke={color}
            strokeWidth="8"
            strokeDasharray={circumference}
            strokeDashoffset={strokeDashoffset}
            strokeLinecap="round"
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-2xl font-bold" style={{ color }}>
            {percentage}%
          </span>
        </div>
      </div>
      <p className="text-xs text-[#8B8B9E] mt-2">
        {completed}/{planned} sessioni completate
      </p>
    </div>
  );
}
