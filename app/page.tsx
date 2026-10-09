import Link from "next/link";
import { OFFICIAL_TOTAL_MINUTES, formatHours } from "@/lib/program";

export default function Home() {
  return (
    <>
      <header className="hero">
        <span className="side l">Choose your nights. Check in.</span>
        <span className="side r">Complete challenges. Earn points. Pick a side.</span>
        <span className="pill">Team Vera × Team Fran</span>
        <h1 className="names">FRAN ×<br />VERA</h1>
        <p className="big">{formatHours(OFFICIAL_TOTAL_MINUTES)} DE FESTA</p>
        <p className="when">15 — 18 OUTUBRO · LISBOA</p>
        <p className="sub">Duas amigas, dois aniversários, quatro dias. Escolhe as noites em que queres estar e entra no jogo.</p>
        <div className="cta">
          <Link className="btn red" href="/programa">Ver programa</Link>
          <Link className="btn ghost" href="/entrar">Entrar</Link>
        </div>
        <p className="tagline">Choose your nights.<br />Check in. Complete challenges.<br />Earn points. Pick a side.</p>
        <div className="collage">
          <div className="pol a"><img src="/foto.webp" alt="" /></div>
          <div className="bigphoto"><img src="/foto.webp" alt="Fran e Vera" /></div>
          <div className="pol b"><img src="/foto.webp" alt="" /></div>
        </div>
        <p className="cap">Foto provisória. O flyer e a ilustração do brinde entram na versão final.</p>
        <p className="when" style={{ opacity: 0.7, fontSize: "1rem", marginTop: 14 }}>23 + 24</p>
      </header>

      <section className="sec">
        <h2 className="h2">Como <em>funciona</em></h2>
        <ol className="steps">
          <li className="step"><h3>Escolhe as tuas noites</h3><p>Diz em que momentos vais estar. Não precisas de aparecer em todos.</p></li>
          <li className="step"><h3>Faz check in</h3><p>Nos eventos em que estás, regista a tua presença.</p></li>
          <li className="step"><h3>Cumpre challenges</h3><p>Desafios sociais, ligeiramente caóticos e fáceis de provar com foto ou vídeo.</p></li>
          <li className="step"><h3>Ganha pontos</h3><p>Os teus pontos somam para a tua equipa. Há ranking individual e de equipas.</p></li>
          <li className="step"><h3>Pick a side</h3><p>Team Vera ou Team Fran. As equipas são criadas na quinta, com base em quem vai estar em cada momento.</p></li>
        </ol>
        <div className="band">
          <p>A Fran e a Vera não jogam. São as referees: cada uma valida os challenges da equipa da outra.</p>
        </div>
        <div className="band light">
          <p>Estás fora do país? Também vais poder participar e entrar nesta dinâmica. Detalhes em breve.</p>
          <span className="chip">Coming soon</span>
        </div>
      </section>
    </>
  );
}
