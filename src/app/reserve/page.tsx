import type { Metadata } from 'next'
import StructuredData from '@/components/StructuredData'
import ReservePageClient from '@/components/pages/ReservePageClient'
import {
  breadcrumbJsonLd,
  createPageMetadata,
  serviceJsonLd,
  webPageJsonLd,
} from '@/lib/seo'

const reserveTitle = '예약 신청'
const reserveDescription =
  'ClawNode 설치 예약 페이지입니다. 원격 설치와 올인원 프리미엄 중 원하는 플랜을 선택하고 상담 및 설치 일정을 접수할 수 있습니다.'

export const metadata: Metadata = createPageMetadata({
  title: reserveTitle,
  description: reserveDescription,
  path: '/reserve',
  keywords: ['AI 설치 예약', 'ClawNode 상담 신청', 'AI 자동화 도입 문의'],
})

const structuredData = [
  webPageJsonLd({
    title: `ClawNode | ${reserveTitle}`,
    description: reserveDescription,
    path: '/reserve',
    type: 'ContactPage',
  }),
  breadcrumbJsonLd([
    { name: '홈', path: '/' },
    { name: reserveTitle, path: '/reserve' },
  ]),
  serviceJsonLd({
    name: 'ClawNode 설치 예약 및 상담',
    description: reserveDescription,
    path: '/reserve',
    serviceType: 'AI 자동화 설치 상담',
  }),
]

export default function ReservePage() {
  return (
    <>
      <StructuredData data={structuredData} />
      <ReservePageClient />
    </>
  )
}
