"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useStore } from "@/lib/store";

const ITEMS = [
  { href: "/", label: "Início" },
  { href: "/programa", label: "Programa" },
  { href: "/jogo", label: "Jogo" },
];

export default function Nav() {
  const path = usePathname();
  const { user, logout } = useStore();
  const items = user?.role === "admin" ? [...ITEMS, { href: "/admin", label: "Admin" }] : ITEMS;
  return (
    <nav className="nav" aria-label="Principal">
      <div className="wrap navin">
        <Link className="logo" href="/">FRAN × VERA</Link>
        <div className="links">
          {items.map((i) => (
            <Link key={i.href} href={i.href} className="lk" aria-current={path === i.href ? "page" : undefined}>
              {i.label}
            </Link>
          ))}
          {user ? (
            <>
              <span className="who">{user.name}</span>
              <button className="lk" onClick={logout}>Sair</button>
            </>
          ) : (
            <Link href="/entrar" className="lk solid">Entrar</Link>
          )}
        </div>
      </div>
    </nav>
  );
}
