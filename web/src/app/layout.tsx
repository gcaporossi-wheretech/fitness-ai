import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({
  variable: '--font-inter',
  subsets: ['latin'],
});

export const metadata: Metadata = {
  title: 'FitnessAI Dashboard',
  description: 'AI-powered fitness coaching dashboard',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="it" className={`${inter.variable} h-full dark`}>
      <body className="min-h-full bg-[#0D0D0D] text-white antialiased">
        {children}
      </body>
    </html>
  );
}
