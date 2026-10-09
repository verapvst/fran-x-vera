"use client";
import Link from "next/link";
import { DAYS, formatHours, totalOfficialMinutes } from "@/lib/program";
import { useStore } from "@/lib/store";

export default function Programa() {
  const { events, user, rsvp, toggleRsvp } = useStore();
  const mine = user ? rsvp[user.id] ?? [] : [];
  const total = totalOfficialMinutes(events);

  return (
    <div className="sec">
      <h2 className="h2">Programa</h2>
      <div className="sumbar">
        <span><b>{formatHours(total)}</b>de programação oficial</span>
        <span className="note" style={{ margin: 0 }}>O Work Day não conta.</span>
      </div>
      {!user && (
        <p className="note"><Link href="/entrar"><u>Entra</u></Link> para escolher os momentos a que vais.</p>
      )}
      {DAYS.map((d) => {
        const list = events.filter((e) => e.day === d.id);
        if (!list.length) return null;
        return (
          <section className="day" key={d.id}>
            <div className="dayh"><h3>{d.label}</h3><span>{d.date}</span></div>
            {list.map((e) => (
              <article key={e.id} className={`ev${e.official ? "" : " off"}${mine.includes(e.id) ? " sel" : ""}`}>
                <div className="t">{e.allDay ? "Durante o dia" : `${e.start} — ${e.end}`}</div>
                <div>
                  <h4>{e.title}</h4>
                  {e.place && <div className="pl">{e.place}</div>}
                  {e.note && <p>{e.note}</p>}
                  {e.rule && <span className="rule">{e.rule}</span>}
                </div>
                <div className="actions">
                  {!e.official ? (
                    <span className="chip">Não oficial</span>
                  ) : user ? (
                    <button
                      className={`btn small${mine.includes(e.id) ? "" : " ghost"}`}
                      aria-pressed={mine.includes(e.id)}
                      onClick={() => toggleRsvp(e.id)}
                    >
                      {mine.includes(e.id) ? "Vou" : "Vou?"}
                    </button>
                  ) : null}
                </div>
              </article>
            ))}
          </section>
        );
      })}
    </div>
  );
}
