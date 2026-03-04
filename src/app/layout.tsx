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
    default: 'ClawNode — 내 책상 위의 크립토 AI 노드',
    template: '%s | ClawNode',
  },
  description: '새벽 3시 펌핑, 또 놓치실 건가요? Mac Mini M4 + AI 에이전트 3종 사전탑재. 월 구독료 없음. 현장 설치 교육 포함. 선착순 5대.',
  metadataBase: new URL('https://website-v2-eight-beta.vercel.app'),
  openGraph: {
    type: 'website',
    locale: 'ko_KR',
    url: 'https://website-v2-eight-beta.vercel.app',
    siteName: 'ClawNode',
    title: 'ClawNode — 내 책상 위의 크립토 AI 노드',
    description: '새벽 3시 펌핑, 또 놓치실 건가요? Mac Mini M4 + AI 에이전트 3종. 월 구독료 0원. 선착순 5대 한정.',
    images: [
      {
        url: 'https://website-v2-eight-beta.vercel.app/images/og-image.png',
        width: 1536,
        height: 1024,
        alt: 'ClawNode — Mac Mini M4 AI 크립토 노드',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'ClawNode — 내 책상 위의 크립토 AI 노드',
    description: '새벽 3시 펌핑, 또 놓치실 건가요? Mac Mini M4 + AI 에이전트 3종. 월 구독료 0원.',
    images: ['https://website-v2-eight-beta.vercel.app/images/og-image.png'],
  },
  icons: {
    icon: '/images/fire-ant-logo.jpg',
    apple: '/images/fire-ant-logo.jpg',
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
