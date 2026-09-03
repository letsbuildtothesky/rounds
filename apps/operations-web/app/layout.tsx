import type { Metadata } from "next";
import "mapbox-gl/dist/mapbox-gl.css";
import "./styles.css";
import "./operations-v45.css";
import "./capacity-v45.css";

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
