import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = {
  title: "Rounds Operations",
  description: "UrbanFlowers delivery operations workspace.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
