import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { GoogleAnalytics } from '@next/third-parties/google'
import './globals.css'
import Nav from '@/components/Nav'
import Footer from '@/components/Footer'
import StructuredData from '@/components/StructuredData'
import {
  absoluteUrl,
  organizationJsonLd,
  siteConfig,
  websiteJsonLd,
} from '@/lib/seo'

const GA_ID = process.env.NEXT_PUBLIC_GA_ID

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

export const metadata: Metadata = {
  title: {
    default: siteConfig.name,
    template: '%s | ClawNode',
  },
  description: siteConfig.description,
  metadataBase: new URL(siteConfig.url),
  applicationName: siteConfig.name,
  referrer: 'origin-when-cross-origin',
  keywords: [...siteConfig.defaultKeywords],
  authors: [{ name: siteConfig.name }],
  creator: siteConfig.name,
  publisher: siteConfig.name,
  formatDetection: {
    telephone: false,
    address: false,
    email: false,
  },
  alternates: {
    canonical: siteConfig.url,
  },
  openGraph: {
    type: 'website',
    locale: siteConfig.locale,
    url: siteConfig.url,
    siteName: siteConfig.name,
    title: siteConfig.name,
    description: siteConfig.description,
    images: [
      {
        url: absoluteUrl(siteConfig.ogImagePath),
        width: 1200,
        height: 630,
        alt: siteConfig.name,
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: siteConfig.name,
    description: siteConfig.description,
    images: [absoluteUrl(siteConfig.ogImagePath)],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-snippet': -1,
      'max-image-preview': 'large',
      'max-video-preview': -1,
    },
  },
  icons: {
    icon: '/icon.png',
    apple: '/apple-icon.png',
  },
  manifest: '/manifest.webmanifest',
  category: 'technology',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko" className={inter.variable}>
      <head>
        <meta name="naver-site-verification" content="e136bb251326c90073d1fa61bf25a5da9ff0970a" />
        <link rel="preconnect" href="https://cdn.jsdelivr.net" crossOrigin="anonymous" />
        <link rel="dns-prefetch" href="https://cdn.jsdelivr.net" />
        {/* Pretendard — Korean + Latin web font via CDN */}
        <link
          rel="stylesheet"
          href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css"
          crossOrigin="anonymous"
        />
      </head>
      <body className="bg-bg text-foreground min-h-screen flex flex-col">
        <StructuredData data={[organizationJsonLd(), websiteJsonLd()]} />
        <Nav />
        <div className="flex-1">{children}</div>
        <Footer />
      </body>
      {GA_ID && <GoogleAnalytics gaId={GA_ID} />}
      {/* Google Ads conversion tracking */}
      <GoogleAnalytics gaId="AW-17999714736" />
    </html>
  )
}
