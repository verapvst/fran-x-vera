"use client";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useStore } from "@/lib/store";

export default function Entrar() {
  const { login, user, setInPortugal } = useStore();
  const router = useRouter();
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");

  if (user) {
    return (
      <div className="sec">
        <h2 className="h2">Olá, {user.name}</h2>
        <div className="card stack">
          <div>
            <label className="f">Onde vais estar?</label>
            <div className="row">
              <button className={`btn small${user.inPortugal ? "" : " ghost"}`} onClick={() => setInPortugal(true)}>Em Portugal</button>
              <button className={`btn small${user.inPortugal ? " ghost" : ""}`} onClick={() => setInPortugal(false)}>Fora do país</button>
            </div>
            {!user.inPortugal && <p className="note" style={{ marginTop: 10 }}>Os detalhes para quem está fora do país vêm em breve.</p>}
          </div>
          <button className="btn red" onClick={() => router.push("/programa")}>Escolher os meus momentos</button>
        </div>
      </div>
    );
  }

  return (
    <div className="sec">
      <h2 className="h2">Entrar</h2>
      <p className="note">Usa o nome e o código pessoal que a Fran ou a Vera te enviaram.</p>
      <form
        className="card stack"
        onSubmit={(e) => {
          e.preventDefault();
          if (!login(name, code)) setError("Nome ou código errado. Confirma com a Fran ou a Vera.");
        }}
      >
        <div>
          <label className="f" htmlFor="n">O teu nome</label>
          <input className="in" id="n" value={name} onChange={(e) => setName(e.target.value)} autoComplete="off" />
        </div>
        <div>
          <label className="f" htmlFor="c">Código pessoal</label>
          <input className="in" id="c" value={code} onChange={(e) => setCode(e.target.value)} autoComplete="off" autoCapitalize="characters" />
        </div>
        {error && <p className="note" role="alert" style={{ margin: 0 }}>{error}</p>}
        <button className="btn" type="submit">Entrar</button>
      </form>
    </div>
  );
}
