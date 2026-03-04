import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: '가격 및 FAQ',
  description: 'ClawNode Standard 300만원. Mac Mini M4 + AI 에이전트 3종 + 현장 설치 교육 + 30일 지원. 하루 2,740원. 숨겨진 비용 없음.',
  openGraph: {
    title: 'ClawNode 가격 — 300만원 올인원 턴키',
    description: '하루 2,740원. Mac Mini M4 포함. 월 구독료 없음. 평생 소유.',
    images: [{ url: 'https://website-v2-eight-beta.vercel.app/images/og-image.png' }],
  },
}

export default function PricingLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>
}
