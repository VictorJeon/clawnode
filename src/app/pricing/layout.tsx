import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: '가격 및 FAQ',
  description: 'ClawNode 가격 안내. 원격 설치(Basic Remote)부터 올인원 프리미엄까지. V3 장기기억 시스템 포함. 숨겨진 비용 없음.',
  openGraph: {
    title: 'ClawNode 가격 — 원격부터 올인원까지',
    description: '까먹지 않는 AI 직원. V3 장기기억 시스템 포함. 나에게 맞는 플랜을 골라보세요.',
    images: [{ url: 'https://claw-node.com/images/og-image-new.png' }],
  },
}

export default function PricingLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>
}
