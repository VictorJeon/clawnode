import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import Nav from '@/components/Nav'
import Footer from '@/components/Footer'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

export const metadata: Metadata = {
  title: {
    default: 'ClawNode — 당신의 24시간 무급 직원',
    template: '%s | ClawNode',
  },
  description: '까먹지 않는 AI 직원. V3 장기기억 시스템 + 맞춤형 AI 두뇌. 경리, 리서치, 트레이딩 자동화. 한 번 말하면 영원히 기억합니다.',
  metadataBase: new URL('https://claw-node.com'),
  openGraph: {
    type: 'website',
    locale: 'ko_KR',
    url: 'https://claw-node.com',
    siteName: 'ClawNode',
    title: 'ClawNode — 까먹지 않는 AI 직원',
    description: 'V3 장기기억 시스템으로 3개월 전 대화도 기억하는 AI. 맞춤형 두뇌 이식 + 원격/방문 설치.',
    images: [
      {
        url: 'https://claw-node.com/images/og-image-new.png',
        width: 1200,
        height: 630,
        alt: 'ClawNode — 까먹지 않는 AI 직원',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'ClawNode — 까먹지 않는 AI 직원',
    description: 'V3 장기기억 시스템으로 3개월 전 대화도 기억하는 AI. 한 번 말하면 영원히 기억합니다.',
    images: ['https://claw-node.com/images/og-image-new.png'],
  },
  robots: {
    index: true,
    follow: true,
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko" className={inter.variable}>
      <head>
        {/* Pretendard — Korean + Latin web font via CDN */}
        <link
          rel="stylesheet"
          href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css"
          crossOrigin="anonymous"
        />
      </head>
      <body className="bg-bg text-foreground min-h-screen flex flex-col">
        <Nav />
        <div className="flex-1">{children}</div>
        <Footer />
      </body>
    </html>
  )
}
