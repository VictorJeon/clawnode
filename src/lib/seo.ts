import type { Metadata } from 'next'

export const siteConfig = {
  name: 'ClawNode',
  title: 'ClawNode',
  description:
    '까먹지 않는 AI 직원. 로컬 AI 자동화 환경, V3 장기기억 시스템, 맞춤형 AI 에이전트 설치와 온보딩을 제공합니다.',
  url: 'https://claw-node.com',
  locale: 'ko_KR',
  ogImagePath: '/images/og-image-new.png',
  logoPath: '/images/clawnode-logo.png',
  email: 'help@claw-node.com',
  supportUrl: 'http://pf.kakao.com/_kBxdZX/chat',
  defaultKeywords: [
    'ClawNode',
    '로컬 AI',
    'AI 자동화',
    'AI 에이전트',
    '업무 자동화',
    '맥미니 AI 서버',
    'OpenClaw',
    '장기기억 AI',
    '텔레그램 자동화',
    'AI 설치 서비스',
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
