import type { Metadata, Viewport } from "next";
import { Archivo, Londrina_Solid } from "next/font/google";
import "./globals.css";
import { StoreProvider } from "@/lib/store";
import Nav from "@/components/Nav";

const londrina = Londrina_Solid({ weight: ["400", "900"], subsets: ["latin"], variable: "--font-londrina" });
const archivo = Archivo({ subsets: ["latin"], variable: "--font-archivo" });

export const metadata: Metadata = {
  title: "FRAN × VERA · 23H30 DE FESTA",
  description: "Birthday weekend, 15 — 18 outubro, Lisboa.",
};
export const viewport: Viewport = { width: "device-width", initialScale: 1, viewportFit: "cover" };

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="pt-PT" className={`${londrina.variable} ${archivo.variable}`}>
      <body>
        <StoreProvider>
          <Nav />
          <main className="wrap">{children}</main>
          <footer className="wrap foot">
            <span>FRAN × VERA · 15 — 18 OUTUBRO · LISBOA</span>
          </footer>
        </StoreProvider>
      </body>
    </html>
  );
}
