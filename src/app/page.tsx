import type { Metadata } from 'next'
import StructuredData from '@/components/StructuredData'
import HomePageClient from '@/components/pages/HomePageClient'
import {
  createPageMetadata,
  serviceJsonLd,
  webPageJsonLd,
} from '@/lib/seo'

const homeTitle = '로컬 AI 직원 설치 서비스'
const homeDescription =
  'ClawNode는 로컬 AI 자동화 환경, V3 장기기억 시스템, 맞춤형 AI 에이전트 설치와 온보딩을 제공해 반복 업무를 자동화합니다.'

export const metadata: Metadata = createPageMetadata({
  title: homeTitle,
  description: homeDescription,
  path: '/',
  keywords: ['로컬 AI 직원', 'AI 비서 설치', 'AI 자동화 도입', '사내 AI 에이전트'],
})

const structuredData = [
  webPageJsonLd({
    title: `ClawNode | ${homeTitle}`,
    description: homeDescription,
    path: '/',
  }),
  serviceJsonLd({
    name: 'ClawNode 로컬 AI 자동화 설치 서비스',
    description: homeDescription,
    path: '/',
    serviceType: 'AI 자동화 설치 및 온보딩',
    offers: [
      {
        name: 'Basic Remote',
        description: '기존 PC에 OpenClaw와 AI 자동화 환경을 원격 설치하는 서비스',
        price: '300000',
      },
      {
        name: 'All-in-One Premium',
        description: 'Mac Mini M4, V3 장기기억, 방문 설치와 교육이 포함된 올인원 패키지',
        price: '2200000',
      },
    ],
  }),
]

export default function HomePage() {
  return (
    <>
      <StructuredData data={structuredData} />
      <HomePageClient />
    </>
  )
}
