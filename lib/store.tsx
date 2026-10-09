"use client";
import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import type { Event } from "./program";

export type Me = { id: string; name: string; role: "participant" | "admin"; inPortugal: boolean };
export type Challenge = { id: string; text: string; points: number };
export type Person = { id: string; name: string; code: string; role: string; inPortugal: boolean; moments: number };

type State = { me: Me | null; events: Event[]; myRsvp: string[]; challenges: Challenge[]; people: Person[] };
const EMPTY: State = { me: null, events: [], myRsvp: [], challenges: [], people: [] };

type Api = State & {
  ready: boolean;
  error: string;
  login: (name: string, code: string) => Promise<boolean>;
  logout: () => Promise<void>;
  toggleRsvp: (eventId: string) => Promise<void>;
  setInPortugal: (v: boolean) => Promise<void>;
  saveEvent: (e: Partial<Event> & { title: string; day: string }) => Promise<boolean>;
  deleteEvent: (id: string) => Promise<void>;
  saveChallenge: (c: { id?: string; text: string; points: number }) => Promise<boolean>;
  deleteChallenge: (id: string) => Promise<void>;
  addPerson: (name: string) => Promise<void>;
  removePerson: (id: string) => Promise<void>;
};

const Ctx = createContext<Api | null>(null);

export function StoreProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<State>(EMPTY);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState("");

  /** Chama a API. Em caso de sucesso substitui o estado pelo que o servidor devolve. */
  const call = useCallback(async (path: string, method = "GET", body?: unknown): Promise<boolean> => {
    try {
      const res = await fetch(path, {
        method,
        headers: body ? { "Content-Type": "application/json" } : undefined,
        body: body ? JSON.stringify(body) : undefined,
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(data.error ?? "Algo correu mal.");
        return false;
      }
      setError("");
      if ("events" in data) setState(data);
      return true;
    } catch {
      setError("Sem ligação ao servidor.");
      return false;
    }
  }, []);

  useEffect(() => {
    call("/api/state").finally(() => setReady(true));
  }, [call]);

  const api: Api = {
    ...state,
    ready,
    error,
    login: (name, code) => call("/api/login", "POST", { name, code }),
    logout: async () => {
      await fetch("/api/logout", { method: "POST" });
      await call("/api/state");
    },
    toggleRsvp: async (eventId) => { await call("/api/rsvp", "POST", { eventId }); },
    setInPortugal: async (inPortugal) => { await call("/api/me", "POST", { inPortugal }); },
    saveEvent: (e) => call("/api/admin/events", "POST", e),
    deleteEvent: async (id) => { await call(`/api/admin/events?id=${encodeURIComponent(id)}`, "DELETE"); },
    saveChallenge: (c) => call("/api/admin/challenges", "POST", c),
    deleteChallenge: async (id) => { await call(`/api/admin/challenges?id=${encodeURIComponent(id)}`, "DELETE"); },
    addPerson: async (name) => { await call("/api/admin/people", "POST", { name }); },
    removePerson: async (id) => { await call(`/api/admin/people?id=${encodeURIComponent(id)}`, "DELETE"); },
  };

  return <Ctx.Provider value={api}>{children}</Ctx.Provider>;
}

export function useStore(): Api {
  const v = useContext(Ctx);
  if (!v) throw new Error("useStore fora do StoreProvider");
  return v;
}
