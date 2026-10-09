export type DayId = "qui" | "sex" | "sab" | "dom";

export type Event = {
  id: string;
  day: DayId;
  start?: string; // "HH:MM"
  end?: string;
  allDay?: boolean;
  title: string;
  place?: string;
  note?: string;
  rule?: string;
  official: boolean;
};

export const DAYS: { id: DayId; label: string; date: string }[] = [
  { id: "qui", label: "QUINTA", date: "15 OUTUBRO" },
  { id: "sex", label: "SEXTA", date: "16 OUTUBRO" },
  { id: "sab", label: "SÁBADO", date: "17 OUTUBRO" },
  { id: "dom", label: "DOMINGO", date: "18 OUTUBRO" },
];

// Programa oficial. Não alterar horários.
export const INITIAL_EVENTS: Event[] = [
  { id: "e1", day: "qui", start: "19:00", end: "23:30", title: "THE GRAND OPENING", place: "Corner", note: "Início oficial da festa, apresentação do conceito, equipas e jogo.", official: true },
  { id: "e2", day: "sex", start: "00:00", end: "00:30", title: "23.", note: "Momento de aniversário da Fran.", official: true },
  { id: "e3", day: "sex", start: "00:30", end: "02:00", title: "PRAIA NO PARQUE", official: true },
  { id: "e4", day: "sex", start: "02:00", end: "18:00", title: "WORK DAY", note: "Dia normal de trabalho. Não é programação oficial da festa.", official: false },
  { id: "e5", day: "sex", start: "19:00", end: "23:00", title: "RALLY TASCAS & CROQUETTE", place: "Belém → Bairro Alto", note: "Um rally pelas tascas, com diferentes challenges e pontos ao longo do percurso.", official: true },
  { id: "e6", day: "sex", start: "23:00", end: "02:00", title: "ZÉ DOS BOIS", official: true },
  { id: "e7", day: "sab", allDay: true, title: "RECOVERY DAY", official: true },
  { id: "e8", day: "sab", start: "20:00", end: "22:00", title: "BINGO", note: "Evento especial com sistema de pontuação próprio.", rule: "Linha: X pontos · Bingo: 100 pontos", official: true },
  { id: "e9", day: "sab", start: "22:00", end: "00:00", title: "PRE-DRINKS", official: true },
  { id: "e10", day: "dom", start: "00:00", end: "00:30", title: "24.", note: "Momento de aniversário da Vera.", official: true },
  { id: "e11", day: "dom", start: "00:30", end: "06:00", title: "THE FINALE", official: true },
];

export const OFFICIAL_TOTAL_MINUTES = 23 * 60 + 30;

export function toMinutes(t: string): number {
  const [h, m] = t.split(":");
  return (parseInt(h, 10) || 0) * 60 + (parseInt(m, 10) || 0);
}

/** Duração em minutos. Eventos não oficiais ou sem hora contam 0. Passa a meia-noite. */
export function duration(e: Event): number {
  if (!e.official || e.allDay || !e.start || !e.end) return 0;
  return (toMinutes(e.end) - toMinutes(e.start) + 1440) % 1440;
}

export function totalOfficialMinutes(events: Event[]): number {
  return events.reduce((sum, e) => sum + duration(e), 0);
}

export function formatHours(minutes: number): string {
  return `${Math.floor(minutes / 60)}H${String(minutes % 60).padStart(2, "0")}`;
}
