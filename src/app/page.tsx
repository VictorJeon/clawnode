import type { Metadata } from 'next'
import StructuredData from '@/components/StructuredData'
import HomePageClient from '@/components/pages/HomePageClient'
import {
  createPageMetadata,
  serviceJsonLd,
  webPageJsonLd,
} from '@/lib/seo'

const homeTitle = 'ClawNode(클로노드) — 프리미엄 오픈클로 | V3 장기기억 AI 에이전트 설치 서비스'
const homeDescription =
  '클로노드(ClawNode)는 프리미엄 오픈클로(OpenClaw) 설치 서비스입니다. V3 장기기억 AI 에이전트를 맥미니에 구축해 드립니다. 업무 자동화, 텔레그램 연동, 전문 온보딩까지 한 번에.'

export const metadata: Metadata = createPageMetadata({
  title: homeTitle,
  description: homeDescription,
  path: '/',
  keywords: [
    '클로노드',
    '클로노드 설치',
    '클로노드 가격',
    '로컬 AI 직원',
    'AI 비서 설치',
    'AI 자동화 도입',
    '사내 AI 에이전트',
    '오픈클로 설치 서비스',
    '맥미니 AI 에이전트',
  ],
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
        description: '기존 PC에 OpenClaw + V3 장기기억 시스템을 원격 설치하는 서비스',
        price: '300000',
      },
      {
        name: 'All-in-One Premium',
        description: 'Mac Mini M4, V3 장기기억, 방문 설치와 교육이 포함된 올인원 패키지',
        price: '2500000',
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
