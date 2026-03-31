import type { Metadata } from 'next'

export const siteConfig = {
  name: 'ClawNode',
  title: 'ClawNode(클로노드) — 프리미엄 오픈클로 | V3 장기기억 AI 에이전트 설치 서비스',
  description:
    '클로노드(ClawNode)는 프리미엄 오픈클로 설치 서비스입니다. V3 장기기억 시스템, 맞춤형 AI 에이전트 구축, 전문 온보딩까지 — 오픈클로의 모든 잠재력을 끌어내 드립니다.',
  url: 'https://claw-node.com',
  locale: 'ko_KR',
  ogImagePath: '/images/og-image-new.png',
  logoPath: '/images/clawnode-logo.png',
  email: 'help@claw-node.com',
  supportUrl: 'http://pf.kakao.com/_kBxdZX/chat',
  defaultKeywords: [
    'ClawNode',
    '클로노드',
    '클로노드 설치',
    '클로노드 가격',
    '클로노드 상담',
    '로컬 AI',
    'AI 자동화',
    'AI 에이전트',
    '업무 자동화',
    '방문 AI 설치',
    'OpenClaw',
    '오픈클로',
    '장기기억 AI',
    '텔레그램 자동화',
    'AI 설치 서비스',
    '오픈클로 설치',
    'AI 비서',
    '현장 AI 세팅',
    'AI 자동화 서비스',
    '오픈클로 사용법',
    '프리미엄 오픈클로',
    '오픈클로 프리미엄',
    '오픈클로 설치 대행',
  ],
} as const

interface PageMetadataInput {
  title: string
  description: string
  path: string
  keywords?: string[]
  imagePath?: string
  noIndex?: boolean
}

interface BreadcrumbItem {
  name: string
  path: string
}

interface ServiceOffer {
  name: string
  description?: string
  price?: string
  priceCurrency?: string
  url?: string
}

interface ServiceJsonLdInput {
  name: string
  description: string
  path: string
  serviceType: string
  offers?: ServiceOffer[]
}

interface WebPageJsonLdInput {
  title: string
  description: string
  path: string
  type?: string
}

export function absoluteUrl(path: string = '/') {
  return new URL(path, siteConfig.url).toString()
}

function buildSeoTitle(title: string) {
  return title === siteConfig.title ? title : `${title} | ${siteConfig.name}`
}

export function createPageMetadata({
  title,
  description,
  path,
  keywords = [],
  imagePath = siteConfig.ogImagePath,
  noIndex = false,
}: PageMetadataInput): Metadata {
  const canonical = absoluteUrl(path)
  const imageUrl = absoluteUrl(imagePath)
  const seoTitle = buildSeoTitle(title)

  return {
    title,
    description,
    keywords: [...siteConfig.defaultKeywords, ...keywords],
    alternates: {
      canonical,
    },
    openGraph: {
      type: 'website',
      locale: siteConfig.locale,
      url: canonical,
      siteName: siteConfig.name,
      title: seoTitle,
      description,
      images: [
        {
          url: imageUrl,
          width: 1200,
          height: 630,
          alt: seoTitle,
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title: seoTitle,
      description,
      images: [imageUrl],
    },
    robots: noIndex
      ? {
          index: false,
          follow: false,
        }
      : {
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
  }
}

export function organizationJsonLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    '@id': absoluteUrl('/#organization'),
    name: siteConfig.name,
    alternateName: ['클로노드', 'ClawNode(클로노드)'],
    url: siteConfig.url,
    logo: absoluteUrl(siteConfig.logoPath),
    image: absoluteUrl(siteConfig.ogImagePath),
    description: siteConfig.description,
    email: siteConfig.email,
    sameAs: [siteConfig.supportUrl],
    contactPoint: [
      {
        '@type': 'ContactPoint',
        contactType: 'customer support',
        url: siteConfig.supportUrl,
        email: siteConfig.email,
        availableLanguage: ['Korean'],
      },
    ],
  }
}

export function websiteJsonLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    '@id': absoluteUrl('/#website'),
    url: siteConfig.url,
    name: siteConfig.name,
    alternateName: ['클로노드', 'ClawNode(클로노드)'],
    inLanguage: 'ko-KR',
    publisher: {
      '@id': absoluteUrl('/#organization'),
    },
  }
}

export function webPageJsonLd({
  title,
  description,
  path,
  type = 'WebPage',
}: WebPageJsonLdInput) {
  const url = absoluteUrl(path)

  return {
    '@context': 'https://schema.org',
    '@type': type,
    '@id': `${url}#webpage`,
    url,
    name: title,
    headline: title,
    description,
    inLanguage: 'ko-KR',
    isPartOf: {
      '@id': absoluteUrl('/#website'),
    },
    about: {
      '@id': absoluteUrl('/#organization'),
    },
  }
}

export function breadcrumbJsonLd(items: BreadcrumbItem[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: absoluteUrl(item.path),
    })),
  }
}

export function serviceJsonLd({
  name,
  description,
  path,
  serviceType,
  offers = [],
}: ServiceJsonLdInput) {
  const url = absoluteUrl(path)

  return {
    '@context': 'https://schema.org',
    '@type': 'Service',
    '@id': `${url}#service`,
    url,
    name,
    description,
    serviceType,
    provider: {
      '@id': absoluteUrl('/#organization'),
    },
    areaServed: 'KR',
    availableLanguage: ['ko-KR'],
    offers: offers.map((offer) => ({
      '@type': 'Offer',
      name: offer.name,
      description: offer.description,
      url: offer.url ?? url,
      price: offer.price,
      priceCurrency: offer.priceCurrency ?? 'KRW',
      availability: 'https://schema.org/InStock',
    })),
  }
}

export function faqJsonLd(items: Array<{ q: string; a: string }>) {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map((item) => ({
      '@type': 'Question',
      name: item.q,
      acceptedAnswer: {
        '@type': 'Answer',
        text: item.a,
      },
    })),
  }
}
