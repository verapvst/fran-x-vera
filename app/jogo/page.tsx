"use client";
import { useStore } from "@/lib/store";

export default function Jogo() {
  const { challenges, me } = useStore();
  return (
    <div className="sec">
      <h2 className="h2">O jogo</h2>
      <div className="empty">
        <p style={{ margin: 0 }}>As equipas são criadas na quinta, no Grand Opening.</p>
        <p className="formula" style={{ marginTop: 8 }}>Pontuação da equipa = pontos totais ÷ pessoas com check in. Assim ninguém ganha só por ter mais gente.</p>
      </div>
      {me?.role === "admin" && (
        <>
          <h2 className="h2" style={{ marginTop: 38 }}>Challenges</h2>
          <p className="note">Só tu e a outra admin veem esta lista. Os participantes recebem os challenges atribuídos na Fase 2.</p>
          {challenges.map((c) => (
            <div className="chal" key={c.id}><p>{c.text}</p><span className="pts">{c.points}</span></div>
          ))}
        </>
      )}
      <h2 className="h2" style={{ marginTop: 38 }}>Feed</h2>
      <div className="empty">O feed de provas abre na Fase 2.</div>
    </div>
  );
}
