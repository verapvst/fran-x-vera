"use client";
import Link from "next/link";
import { useState } from "react";
import { DAYS, type DayId, type Event } from "@/lib/program";
import { useStore } from "@/lib/store";

type Tab = "eventos" | "challenges" | "pessoas";

export default function Admin() {
  const s = useStore();
  const [tab, setTab] = useState<Tab>("eventos");
  const [name, setName] = useState("");

  if (!s.ready) return null;
  if (s.user?.role !== "admin") {
    return (
      <div className="sec">
        <h2 className="h2">Painel <em>admin</em></h2>
        <p className="note">Só a Fran e a Vera têm acesso. <Link href="/entrar"><u>Entrar</u></Link></p>
      </div>
    );
  }

  const patchEvent = (e: Event, p: Partial<Event>) => s.saveEvent({ ...e, ...p });

  return (
    <div className="sec">
      <h2 className="h2">Painel <em>admin</em></h2>
      <div className="tabs">
        {(["eventos", "challenges", "pessoas"] as Tab[]).map((t) => (
          <button key={t} className="lk" aria-current={tab === t ? "page" : undefined} onClick={() => setTab(t)}>{t}</button>
        ))}
      </div>

      {tab === "eventos" && (
        <>
          {s.events.map((e) => (
            <div className="edrow" key={e.id}>
              <select className="in" value={e.day} onChange={(ev) => patchEvent(e, { day: ev.target.value as DayId })}>
                {DAYS.map((d) => <option key={d.id} value={d.id}>{d.label}</option>)}
              </select>
              <input className="in" value={e.start ?? ""} placeholder="19:00" aria-label="Início" onChange={(ev) => patchEvent(e, { start: ev.target.value })} />
              <input className="in" value={e.end ?? ""} placeholder="23:30" aria-label="Fim" onChange={(ev) => patchEvent(e, { end: ev.target.value })} />
              <input className="in wide" value={e.title} aria-label="Título" onChange={(ev) => patchEvent(e, { title: ev.target.value })} />
              <input className="in wide" value={e.place ?? ""} placeholder="Local" aria-label="Local" onChange={(ev) => patchEvent(e, { place: ev.target.value })} />
              <label className="chip"><input type="checkbox" checked={e.official} onChange={(ev) => patchEvent(e, { official: ev.target.checked })} /> oficial</label>
              <button className="btn small ghost" onClick={() => confirm(`Apagar ${e.title}?`) && s.deleteEvent(e.id)}>Apagar</button>
            </div>
          ))}
          <button className="btn small" onClick={() => s.saveEvent({ id: s.newId(), day: "qui", title: "NOVO MOMENTO", official: true, start: "20:00", end: "21:00" })}>Novo momento</button>
        </>
      )}

      {tab === "challenges" && (
        <>
          {s.challenges.map((c) => (
            <div className="edrow c" key={c.id}>
              <input className="in wide" value={c.text} aria-label="Texto" onChange={(ev) => s.saveChallenge({ ...c, text: ev.target.value })} />
              <input className="in" type="number" min={0} value={c.points} aria-label="Pontos" onChange={(ev) => s.saveChallenge({ ...c, points: Number(ev.target.value) || 0 })} />
              <button className="btn small ghost" onClick={() => confirm("Apagar challenge?") && s.deleteChallenge(c.id)}>Apagar</button>
            </div>
          ))}
          <button className="btn small" onClick={() => s.saveChallenge({ id: s.newId(), text: "Novo challenge", points: 10 })}>Novo challenge</button>
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
                    <td>{p.code}</td>
                    <td>{(s.rsvp[p.id] ?? []).length}</td>
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
