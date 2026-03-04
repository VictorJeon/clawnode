'use client'

import Image from 'next/image'
import SectionHeading from '@/components/SectionHeading'
import CTAButton from '@/components/CTAButton'
import FadeIn from '@/components/FadeIn'
import Accordion from '@/components/Accordion'

// Note: metadata export is in a separate file below (pricing/layout.tsx)
// because this page uses 'use client'

const FAQ_ITEMS = [
  { q: '해킹당하면 책임지나요?', a: '하드웨어와 소프트웨어 세팅을 제공하는 서비스입니다. 기기는 100% 고객님 소유이며, 보안 관리 책임도 고객님께 있습니다. 다만 업계 표준 보안(Tailscale, Docker 격리, 포트 폐쇄)을 적용하여 위험을 최소화합니다.' },
  { q: '지방도 설치 가능한가요?', a: '현재 서울/경기권만 직접 방문 설치가 가능합니다. 그 외 지역은 출장비 별도 청구 또는 화상(Zoom) 원격 설치 가이드로 진행할 수 있습니다.' },
  { q: '코인 지갑(Private Key) 연결해도 되나요?', a: '"읽기 전용(View-Only)" 권한만 연결하는 것을 강력히 권장합니다. Private Key나 출금 권한이 있는 API Key는 절대 입력하지 마세요.' },
  { q: 'M4 Pro로 업그레이드 가능한가요?', a: '가능합니다. 주문 시 미리 말씀해 주시면 하드웨어 차액만큼 추가 결제 후 M4 Pro 모델로 준비해 드립니다.' },
  { q: 'A/S는 어떻게 되나요?', a: '하드웨어 → 애플 공식 서비스센터. 소프트웨어 → 30일 전용 채널 무상 지원. 이후 유료 유지보수 플랜 선택 가능.' },
  { q: '사용하다가 중고로 팔아도 되나요?', a: '네, 하드웨어 소유권 100% 고객님께 있으므로 자유 처분 가능합니다. 판매 전 기기 초기화를 권장하며, 기술 지원은 최초 구매자에게만 제공됩니다.' },
  { q: 'API 비용은 별도인가요?', a: '네, LLM API(Claude, GPT 등) 사용료는 고객님이 직접 부담합니다. 다만 온보딩 시 spending limit 설정을 도와드려서 예상치 못한 과금을 방지합니다.' },
  { q: '모니터/키보드 없이 쓸 수 있나요?', a: '네, 설치 완료 후에는 텔레그램으로만 대화하면 됩니다. 맥미니에 모니터 연결할 필요 없이 전원만 꽂아두시면 됩니다.' },
]

export default function PricingPage() {
  return (
    <main>
      {/* Hero */}
      <section className="py-24 px-4 md:px-6 text-center">
        <div className="max-w-3xl mx-auto">
          <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-4">Pricing</p>
          <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-6">
            단 한 번의 투자.
            <br />
            <span className="text-[#FF6B00]">평생 무료 운영.</span>
          </h1>
          <p className="text-xl text-gray-400">숨겨진 비용도, 월 구독료도 없습니다.</p>
        </div>
      </section>

      {/* Pricing Card */}
      <section className="py-12 px-4 md:px-6">
        <div className="max-w-2xl mx-auto">
          <div className="bg-[#0A0A0A] border border-[#FF6B00]/30 rounded-3xl p-8 md:p-12">
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-10 gap-6">
              <div>
                <h3 className="text-3xl font-bold mb-2">ClawNode Standard</h3>
                <p className="text-gray-400">All-in-One Turnkey Solution</p>
              </div>
              <div className="text-right">
                <div className="text-5xl font-bold text-[#FF6B00]">300만원</div>
                <div className="text-sm text-gray-500 mt-1">VAT 별도 / 평생 소유</div>
              </div>
            </div>

            {/* ROI */}
            <div className="bg-[#FF6B00]/10 border border-[#FF6B00]/20 rounded-xl p-4 mb-10">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-0 text-center sm:divide-x divide-[#FF6B00]/20">
                <div className="py-2 sm:py-0">
                  <div className="text-2xl font-bold text-white">2,740원</div>
                  <div className="text-xs text-gray-400">하루 비용 (3년 기준)</div>
                </div>
                <div className="py-2 sm:py-0 border-t sm:border-t-0 border-[#FF6B00]/20">
                  <div className="text-2xl font-bold text-white">25만원</div>
                  <div className="text-xs text-gray-400">월 비용 (12개월 기준)</div>
                </div>
                <div className="py-2 sm:py-0 border-t sm:border-t-0 border-[#FF6B00]/20">
                  <div className="text-2xl font-bold text-white">∞</div>
                  <div className="text-xs text-gray-400">3년 이후 비용</div>
                </div>
              </div>
            </div>

            {/* What's Included */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-10">
              <div>
                <h4 className="font-bold border-b border-white/10 pb-2 mb-4">📦 하드웨어</h4>
                <ul className="space-y-3">
                  {[
                    'Apple Mac Mini M4 (16GB/256GB) 신품',
                    'Apple 정품 악세사리 일체',
                    'Thunderbolt 4 ×3, HDMI 2.1',
                    '애플 1년 무상보증',
                  ].map(item => (
                    <li key={item} className="flex items-start gap-2 text-sm text-gray-300">
                      <span className="text-[#FF6B00] mt-0.5">✓</span> {item}
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <h4 className="font-bold border-b border-white/10 pb-2 mb-4">🛠️ 소프트웨어 & 서비스</h4>
                <ul className="space-y-3">
                  {[
                    'OpenClaw + Crypto Agents 3종 설치',
                    'Tailscale 보안 터널 구성',
                    '서울/경기 방문 설치 및 교육 (2시간)',
                    '30일 1:1 기술 지원 (전용 텔레그램)',
                  ].map(item => (
                    <li key={item} className="flex items-start gap-2 text-sm text-gray-300">
                      <span className="text-[#FF6B00] mt-0.5">✓</span> {item}
                    </li>
                  ))}
                </ul>
              </div>
            </div>

            <div className="text-center">
              <CTAButton href="/reserve">지금 예약하기 (선착순 5대)</CTAButton>
              <p className="text-xs text-gray-500 mt-4">* 주문 제작 상품으로 설치 후 환불이 불가능합니다.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Comparison Table */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-5xl mx-auto">
          <SectionHeading subtitle="같은 돈으로 뭘 할 수 있을까요?">가치 비교</SectionHeading>
          {/* Desktop: Table */}
          <div className="hidden md:block overflow-x-auto">
            <table className="w-full text-left border-collapse text-sm">
              <thead>
                <tr className="border-b border-white/10 text-gray-400">
                  <th className="py-4 px-4" />
                  <th className="py-4 px-4">DIY</th>
                  <th className="py-4 px-4">VPS 월 구독</th>
                  <th className="py-4 px-4">크몽 설치대행</th>
                  <th className="py-4 px-4 text-[#FF6B00] bg-[#FF6B00]/10 rounded-t-lg font-bold">ClawNode</th>
                </tr>
              </thead>
              <tbody>
                {[
                  ['비용', '시간 무제한', '매달 $20~50', '10만원 + HW별도', '일시불 (평생)'],
                  ['하드웨어', '본인 조달', '없음 (공용)', '본인 조달', 'M4 Mac Mini 포함'],
                  ['보안', '본인 책임', '클라우드 리스크', '원격 백도어 우려', 'Zero Trust'],
                  ['교육', '유튜브 독학', '없음', '텍스트 가이드', '2시간 1:1 과외'],
                  ['지원', '없음', '느린 티켓', '설치 후 끝', '30일 전용 채널'],
                ].map(([feature, ...values]) => (
                  <tr key={feature} className="border-b border-white/5">
                    <td className="py-4 px-4 font-bold text-white">{feature}</td>
                    {values.map((v, i) => (
                      <td key={i} className={`py-4 px-4 ${i === 3 ? 'bg-[#FF6B00]/5 text-white font-medium' : 'text-gray-400'}`}>
                        {v}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile: Cards */}
          <div className="md:hidden space-y-4">
            {[
              { feature: '비용', others: 'DIY: 시간 무제한 · VPS: 매달 $20~50 · 크몽: 10만원+HW별도', claw: '일시불 (평생)' },
              { feature: '하드웨어', others: 'DIY: 본인 조달 · VPS: 없음 · 크몽: 본인 조달', claw: 'M4 Mac Mini 포함' },
              { feature: '보안', others: 'DIY: 본인 책임 · VPS: 클라우드 리스크 · 크몽: 백도어 우려', claw: 'Zero Trust' },
              { feature: '교육', others: 'DIY: 유튜브 독학 · VPS: 없음 · 크몽: 텍스트 가이드', claw: '2시간 1:1 과외' },
              { feature: '지원', others: 'DIY: 없음 · VPS: 느린 티켓 · 크몽: 설치 후 끝', claw: '30일 전용 채널' },
            ].map(item => (
              <div key={item.feature} className="bg-[#0A0A0A] border border-white/10 rounded-xl p-4">
                <div className="text-white font-bold mb-2">{item.feature}</div>
                <div className="text-xs text-gray-500 mb-3 leading-relaxed">{item.others}</div>
                <div className="text-sm text-[#FF6B00] font-medium flex items-center gap-2">
                  <span>🔶</span> ClawNode: {item.claw}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Not For You */}
      <section className="py-24 px-4 md:px-6 bg-white/[0.02]">
        <div className="max-w-3xl mx-auto">
          <SectionHeading subtitle="솔직하게 말씀드립니다.">이런 분에게는 안 맞습니다</SectionHeading>
          <div className="space-y-4">
            {[
              '이미 OpenClaw을 직접 설치해서 잘 쓰고 계신 분 (DIY 능력자)',
              '맥미니 없이 클라우드 VPS로 충분하다고 생각하시는 분',
              'AI 에이전트가 뭔지 전혀 관심 없으신 분',
              '300만원이 부담되시는 분 (무리하지 마세요)',
            ].map(item => (
              <div key={item} className="flex items-start gap-3 p-4 bg-[#0A0A0A] border border-white/10 rounded-xl">
                <span className="text-red-400 text-lg">✕</span>
                <p className="text-sm text-gray-400">{item}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-3xl mx-auto">
          <FadeIn>
            <SectionHeading>자주 묻는 질문</SectionHeading>
          </FadeIn>
          <FadeIn delay={0.1}>
            <Accordion items={FAQ_ITEMS} />
          </FadeIn>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-24 px-4 md:px-6 text-center relative overflow-hidden">
        <div className="absolute inset-0 z-0 opacity-20">
          <Image src="/images/hero-bg.png" alt="" fill className="object-cover" />
        </div>
        <div className="relative z-10 max-w-2xl mx-auto">
          <div className="inline-flex items-center gap-2 mb-6">
            <Image src="/images/fire-ant-logo.jpg" alt="Fire Ant" width={24} height={24} className="rounded-full" />
            <span className="text-sm text-gray-400">Fire Ant Crypto 추천</span>
          </div>
          <h2 className="text-3xl md:text-5xl font-bold mb-4">
            당신의 노드를
            <br />
            <span className="text-[#FF6B00]">시작하세요.</span>
          </h2>
          <p className="text-gray-400 mb-8">하루 2,740원. 커피 한 잔 값으로 평생 일하는 AI 직원.</p>
          <CTAButton href="/reserve">지금 예약하기 (300만원) →</CTAButton>
        </div>
      </section>
    </main>
  )
}
