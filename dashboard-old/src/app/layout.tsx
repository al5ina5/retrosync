import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'RetroSync - Cloud Sync for Retro Gaming Saves',
  description: 'Sync your retro gaming save files across Anbernic, Miyoo handhelds, and PC',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className="dark">
      <body className="antialiased">{children}</body>
    </html>
  )
}
