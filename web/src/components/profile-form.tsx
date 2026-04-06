'use client';

import { useState } from 'react';
import type { UserProfile } from '@/lib/api';

interface ProfileFormProps {
  user: UserProfile;
  token: string;
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost';

export function ProfileForm({ user, token }: ProfileFormProps) {
  const [name, setName] = useState(user.name || '');
  const [age, setAge] = useState(user.age?.toString() || '');
  const [language, setLanguage] = useState(user.language || 'it');
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{
    type: 'success' | 'error';
    text: string;
  } | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setMessage(null);

    try {
      const body: Record<string, unknown> = {};
      if (name !== (user.name || '')) body.name = name;
      if (age !== (user.age?.toString() || '')) body.age = age ? parseInt(age, 10) : null;
      if (language !== user.language) body.language = language;

      if (Object.keys(body).length === 0) {
        setMessage({ type: 'success', text: 'Nessuna modifica da salvare' });
        setSaving(false);
        return;
      }

      const response = await fetch(`${API_BASE_URL}/auth/me`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.detail || `Errore ${response.status}`);
      }

      setMessage({ type: 'success', text: 'Profilo aggiornato con successo' });
    } catch (err) {
      setMessage({
        type: 'error',
        text: err instanceof Error ? err.message : 'Errore nel salvataggio',
      });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="bg-[#1A1A2E] rounded-xl border border-[#4F8CFF]/10 p-6">
      <h2 className="text-lg font-semibold mb-4">Modifica profilo</h2>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="name" className="block text-sm text-[#8B8B9E] mb-1">
            Nome
          </label>
          <input
            id="name"
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full px-3 py-2 bg-[#16213E] border border-[#4F8CFF]/10 rounded-lg text-white focus:outline-none focus:border-[#4F8CFF]/30"
            placeholder="Il tuo nome"
          />
        </div>

        <div>
          <label htmlFor="age" className="block text-sm text-[#8B8B9E] mb-1">
            Eta
          </label>
          <input
            id="age"
            type="number"
            min="13"
            max="120"
            value={age}
            onChange={(e) => setAge(e.target.value)}
            className="w-full px-3 py-2 bg-[#16213E] border border-[#4F8CFF]/10 rounded-lg text-white focus:outline-none focus:border-[#4F8CFF]/30"
            placeholder="La tua eta"
          />
        </div>

        <div>
          <label
            htmlFor="language"
            className="block text-sm text-[#8B8B9E] mb-1"
          >
            Lingua
          </label>
          <select
            id="language"
            value={language}
            onChange={(e) => setLanguage(e.target.value)}
            className="w-full px-3 py-2 bg-[#16213E] border border-[#4F8CFF]/10 rounded-lg text-white focus:outline-none focus:border-[#4F8CFF]/30"
          >
            <option value="it">Italiano</option>
            <option value="en">English</option>
          </select>
        </div>

        {message && (
          <div
            className={`p-3 rounded-lg text-sm ${
              message.type === 'success'
                ? 'bg-[#00D4AA]/10 text-[#00D4AA]'
                : 'bg-red-500/10 text-red-400'
            }`}
          >
            {message.text}
          </div>
        )}

        <button
          type="submit"
          disabled={saving}
          className="w-full py-2.5 bg-[#4F8CFF] hover:bg-[#4F8CFF]/80 disabled:opacity-50 rounded-lg font-medium transition-colors"
        >
          {saving ? 'Salvataggio...' : 'Salva modifiche'}
        </button>
      </form>
    </div>
  );
}
