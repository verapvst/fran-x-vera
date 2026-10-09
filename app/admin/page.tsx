"use client";
import Link from "next/link";
import { useState } from "react";
import { DAYS, type Event } from "@/lib/program";
import { useStore, type Challenge } from "@/lib/store";

type Tab = "eventos" | "challenges" | "pessoas";

function EventRow({ e }: { e: Event }) {
  const { saveEvent, deleteEvent } = useStore();
  const [d, setD] = useState(e);
  const dirty = JSON.stringify(d) !== JSON.stringify(e);
  const set = (p: Partial<Event>) => setD({ ...d, ...p });
  return (
    <div className="edrow">
      <select className="in" value={d.day} onChange={(ev) => set({ day: ev.target.value as Event["day"] })}>
        {DAYS.map((x) => <option key={x.id} value={x.id}>{x.label}</option>)}
      </select>
      <input className="in" value={d.start ?? ""} placeholder="19:00" aria-label="Início" onChange={(ev) => set({ start: ev.target.value })} />
      <input className="in" value={d.end ?? ""} placeholder="23:30" aria-label="Fim" onChange={(ev) => set({ end: ev.target.value })} />
      <input className="in wide" value={d.title} aria-label="Título" onChange={(ev) => set({ title: ev.target.value })} />
      <input className="in wide" value={d.place ?? ""} placeholder="Local" aria-label="Local" onChange={(ev) => set({ place: ev.target.value })} />
      <label className="chip"><input type="checkbox" checked={d.official} onChange={(ev) => set({ official: ev.target.checked })} /> oficial</label>
      <div className="row">
        <button className="btn small" disabled={!dirty} onClick={() => saveEvent(d)}>Guardar</button>
        <button className="btn small ghost" onClick={() => confirm(`Apagar ${e.title}?`) && deleteEvent(e.id)}>Apagar</button>
      </div>
    </div>
  );
}

function ChallengeRow({ c }: { c: Challenge }) {
  const { saveChallenge, deleteChallenge } = useStore();
  const [d, setD] = useState(c);
  const dirty = d.text !== c.text || d.points !== c.points;
  return (
    <div className="edrow c">
      <input className="in wide" value={d.text} aria-label="Texto" onChange={(ev) => setD({ ...d, text: ev.target.value })} />
      <input className="in" type="number" min={0} value={d.points} aria-label="Pontos" onChange={(ev) => setD({ ...d, points: Number(ev.target.value) || 0 })} />
      <div className="row">
        <button className="btn small" disabled={!dirty} onClick={() => saveChallenge(d)}>Guardar</button>
        <button className="btn small ghost" onClick={() => confirm("Apagar challenge?") && deleteChallenge(c.id)}>Apagar</button>
      </div>
    </div>
  );
}

export default function Admin() {
  const s = useStore();
  const [tab, setTab] = useState<Tab>("eventos");
  const [name, setName] = useState("");

  if (!s.ready) return null;
  if (s.me?.role !== "admin") {
    return (
      <div className="sec">
        <h2 className="h2">Painel <em>admin</em></h2>
        <p className="note">Só a Fran e a Vera têm acesso. <Link href="/entrar"><u>Entrar</u></Link></p>
      </div>
    );
  }

  return (
    <div className="sec">
      <h2 className="h2">Painel <em>admin</em></h2>
      {s.error && <p className="note" role="alert">{s.error}</p>}
      <div className="tabs">
        {(["eventos", "challenges", "pessoas"] as Tab[]).map((t) => (
          <button key={t} className="lk" aria-current={tab === t ? "page" : undefined} onClick={() => setTab(t)}>{t}</button>
        ))}
      </div>

      {tab === "eventos" && (
        <>
          {s.events.map((e) => <EventRow key={e.id + JSON.stringify(e)} e={e} />)}
          <button className="btn small" onClick={() => s.saveEvent({ day: "qui", title: "NOVO MOMENTO", official: true, start: "20:00", end: "21:00" })}>Novo momento</button>
        </>
      )}

      {tab === "challenges" && (
        <>
          {s.challenges.map((c) => <ChallengeRow key={c.id + c.text + c.points} c={c} />)}
          <button className="btn small" onClick={() => s.saveChallenge({ text: "Novo challenge", points: 10 })}>Novo challenge</button>
        </>
      )}

      {tab === "pessoas" && (
        <>
          <p className="note">Cria um convidado e envia-lhe o código pessoal. Sem código não há acesso.</p>
          <form className="row" style={{ marginBottom: 16 }} onSubmit={(e) => { e.preventDefault(); if (name.trim()) { s.addPerson(name); setName(""); } }}>
            <input className="in" style={{ maxWidth: 260 }} value={name} onChange={(e) => setName(e.target.value)} placeholder="Nome" aria-label="Nome do convidado" />
            <button className="btn small" type="submit">Adicionar</button>
          </form>
          <div className="scroll">
            <table className="tbl">
              <thead><tr><th>Nome</th><th>Código</th><th>Momentos</th><th></th></tr></thead>
              <tbody>
                {s.people.map((p) => (
                  <tr key={p.id}>
                    <td>{p.name}{p.role === "admin" ? " (admin)" : ""}</td>
                    <td>{p.role === "admin" ? "—" : p.code}</td>
                    <td>{p.moments}</td>
                    <td>{p.role !== "admin" && <button className="btn small ghost" onClick={() => s.removePerson(p.id)}>Remover</button>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}
