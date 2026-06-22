import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Toaster } from "@/components/ui/toaster";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Tower Defense — Sentry vs Dispenser (MK1/MK2/MK3)",
  description: "Compare o poder do MK2 e a diferença entre MK1, MK2 e MK3 do Dispenser, e jogue em tempo real. Veja por que a Sentry custa mais (recarga).",
  keywords: ["tower defense", "sentry", "dispenser", "MK1", "MK2", "MK3", "game", "Next.js"],
  authors: [{ name: "Z.ai Team" }],
  icons: {
    icon: "https://z-cdn.chatglm.cn/z-ai/static/logo.svg",
  },
  openGraph: {
    title: "Tower Defense — Sentry vs Dispenser",
    description: "Compare MK1, MK2 e MK3 do Dispenser e jogue em tempo real.",
    url: "https://chat.z.ai",
    siteName: "Z.ai",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Tower Defense — Sentry vs Dispenser",
    description: "Compare MK1, MK2 e MK3 do Dispenser e jogue em tempo real.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-background text-foreground`}
      >
        {children}
        <Toaster />
      </body>
    </html>
  );
}
