import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: '예약 신청',
  description: 'ClawNode 선착순 5대 예약 신청. 확인 후 24시간 이내 연락드립니다.',
  openGraph: {
    title: 'ClawNode 예약 — 선착순 5대 한정',
    description: '지금 예약하고 당신만의 크립토 AI 노드를 시작하세요.',
    images: [{ url: '/images/og-image.png' }],
  },
}

export default function ReserveLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>
}
