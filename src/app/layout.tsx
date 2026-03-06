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
  description: '220만 원으로 평생 쓰는 AI 직원. Mac Mini M4 + OpenClaw AI 두뇌 + 방문 설치 교육. 경리, 리서치, 트레이딩 자동화. 월 구독료 0원. 선착순 5대.',
  metadataBase: new URL('https://website-v2-eight-beta.vercel.app'),
  openGraph: {
    type: 'website',
    locale: 'ko_KR',
    url: 'https://website-v2-eight-beta.vercel.app',
    siteName: 'ClawNode',
    title: 'ClawNode — 당신의 24시간 무급 직원',
    description: '220만 원으로 평생 쓰는 AI 직원. Mac Mini M4 + AI 두뇌 + 방문 설치. 월 구독료 0원. 선착순 5대 한정.',
    images: [
      {
        url: 'https://website-v2-eight-beta.vercel.app/images/og-image.png',
        width: 1200,
        height: 630,
        alt: 'ClawNode — 당신의 24시간 무급 직원',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'ClawNode — 당신의 24시간 무급 직원',
    description: '220만 원으로 평생 쓰는 AI 직원. Mac Mini M4 + AI 두뇌 + 방문 설치. 월 구독료 0원.',
    images: ['https://website-v2-eight-beta.vercel.app/images/og-image.png'],
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
