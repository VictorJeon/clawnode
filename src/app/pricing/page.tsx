import type { Metadata } from 'next'
import StructuredData from '@/components/StructuredData'
import PricingPageClient from '@/components/pages/PricingPageClient'
import { PRICING_FAQ_ITEMS } from '@/content/pricingFaq'
import {
  breadcrumbJsonLd,
  createPageMetadata,
  faqJsonLd,
  serviceJsonLd,
  webPageJsonLd,
} from '@/lib/seo'

const pricingTitle = '가격 및 FAQ'
const pricingDescription =
  'ClawNode 가격 안내. 원격 설치부터 올인원 프리미엄까지, 로컬 AI 자동화 환경과 V3 장기기억 시스템을 맞춤 세팅합니다.'

export const metadata: Metadata = createPageMetadata({
  title: pricingTitle,
  description: pricingDescription,
  path: '/pricing',
  keywords: ['AI 설치 가격', '로컬 AI 구축 비용', 'AI 자동화 컨설팅 가격'],
})

const structuredData = [
  webPageJsonLd({
    title: `ClawNode | ${pricingTitle}`,
    description: pricingDescription,
    path: '/pricing',
  }),
  breadcrumbJsonLd([
    { name: '홈', path: '/' },
    { name: pricingTitle, path: '/pricing' },
  ]),
  serviceJsonLd({
    name: 'ClawNode 설치 플랜 및 가격',
    description: pricingDescription,
    path: '/pricing',
    serviceType: 'AI 자동화 설치 서비스',
    offers: [
      {
        name: 'Basic Remote',
        description: '기존 PC를 활용한 원격 설치 플랜',
        price: '300000',
      },
      {
        name: 'All-in-One Premium',
        description: 'Mac Mini M4, 방문 설치, 교육이 포함된 프리미엄 플랜',
        price: '2200000',
      },
    ],
  }),
  faqJsonLd(PRICING_FAQ_ITEMS),
]

export default function PricingPage() {
  return (
    <>
      <StructuredData data={structuredData} />
      <PricingPageClient />
    </>
  )
}
