import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = {
  title: "Rounds Phase 0 Telemetry",
  description: "Honest live, stale, and unknown fleet position validation.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
