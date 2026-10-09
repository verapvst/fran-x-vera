"use client";
import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { INITIAL_EVENTS, type Event } from "./program";

// Fase 1 sem backend: estado guardado no browser. A interface fica igual quando ligarmos o Supabase.
export type Person = { id: string; name: string; code: string; role: "participant" | "admin"; inPortugal: boolean };
export type Challenge = { id: string; text: string; points: number; eventId?: string };

type State = {
  events: Event[];
  challenges: Challenge[];
  people: Person[];
  userId: string | null;
  rsvp: Record<string, string[]>; // personId -> eventIds
};

const INITIAL: State = {
  events: INITIAL_EVENTS,
  challenges: [
    { id: "c1", text: "[Nome A] tem de convencer [Nome B] a tirar uma foto a fazer X.", points: 30 },
    { id: "c2", text: "Três pessoas da tua equipa numa só foto, a imitar a mesma pose.", points: 20 },
  ],
  people: [
    { id: "p-fran", name: "Fran", code: "FRAN", role: "admin", inPortugal: true },
    { id: "p-vera", name: "Vera", code: "VERA", role: "admin", inPortugal: true },
  ],
  userId: null,
  rsvp: {},
};

const KEY = "fxv-state-v1";
const uid = () => Math.random().toString(36).slice(2, 9);
const newCode = () => Math.random().toString(36).slice(2, 6).toUpperCase();

type Api = State & {
  ready: boolean;
  user: Person | null;
  login: (name: string, code: string) => boolean;
  logout: () => void;
  toggleRsvp: (eventId: string) => void;
  setInPortugal: (v: boolean) => void;
  saveEvent: (e: Event) => void;
  deleteEvent: (id: string) => void;
  saveChallenge: (c: Challenge) => void;
  deleteChallenge: (id: string) => void;
  addPerson: (name: string) => void;
  removePerson: (id: string) => void;
  newId: () => string;
};

const Ctx = createContext<Api | null>(null);

export function StoreProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<State>(INITIAL);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) setState({ ...INITIAL, ...JSON.parse(raw) });
    } catch {}
    setReady(true);
  }, []);

  useEffect(() => {
    if (!ready) return;
    try { localStorage.setItem(KEY, JSON.stringify(state)); } catch {}
  }, [state, ready]);

  const upsert = <T extends { id: string }>(list: T[], item: T) =>
    list.some((x) => x.id === item.id) ? list.map((x) => (x.id === item.id ? item : x)) : [...list, item];

  const login = useCallback((name: string, code: string) => {
    const p = state.people.find(
      (x) => x.name.trim().toLowerCase() === name.trim().toLowerCase() && x.code === code.trim().toUpperCase(),
    );
    if (!p) return false;
    setState((s) => ({ ...s, userId: p.id }));
    return true;
  }, [state.people]);

  const api: Api = {
    ...state,
    ready,
    user: state.people.find((p) => p.id === state.userId) ?? null,
    login,
    logout: () => setState((s) => ({ ...s, userId: null })),
    toggleRsvp: (eventId) =>
      setState((s) => {
        if (!s.userId) return s;
        const cur = s.rsvp[s.userId] ?? [];
        const next = cur.includes(eventId) ? cur.filter((x) => x !== eventId) : [...cur, eventId];
        return { ...s, rsvp: { ...s.rsvp, [s.userId]: next } };
      }),
    setInPortugal: (v) =>
      setState((s) => ({ ...s, people: s.people.map((p) => (p.id === s.userId ? { ...p, inPortugal: v } : p)) })),
    saveEvent: (e) => setState((s) => ({ ...s, events: upsert(s.events, e) })),
    deleteEvent: (id) => setState((s) => ({ ...s, events: s.events.filter((e) => e.id !== id) })),
    saveChallenge: (c) => setState((s) => ({ ...s, challenges: upsert(s.challenges, c) })),
    deleteChallenge: (id) => setState((s) => ({ ...s, challenges: s.challenges.filter((c) => c.id !== id) })),
    addPerson: (name) =>
      setState((s) => ({
        ...s,
        people: [...s.people, { id: uid(), name: name.trim(), code: newCode(), role: "participant", inPortugal: true }],
      })),
    removePerson: (id) => setState((s) => ({ ...s, people: s.people.filter((p) => p.id !== id || p.role === "admin") })),
    newId: uid,
  };

  return <Ctx.Provider value={api}>{children}</Ctx.Provider>;
}

export function useStore(): Api {
  const v = useContext(Ctx);
  if (!v) throw new Error("useStore fora do StoreProvider");
  return v;
}
