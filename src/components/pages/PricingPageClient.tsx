'use client'

import Image from 'next/image'
import Link from 'next/link'
import SectionHeading from '@/components/SectionHeading'
import CTAButton from '@/components/CTAButton'
import FadeIn from '@/components/FadeIn'
import Accordion from '@/components/Accordion'
import { PRICING_FAQ_ITEMS } from '@/content/pricingFaq'

export default function PricingPageClient() {
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

      {/* Two-Tier Pricing Cards */}
      <section className="py-12 px-4 md:px-6">
        <div className="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-8">
          {/* Basic */}
          <FadeIn delay={0}>
            <div className="bg-[#0A0A0A] border border-white/10 rounded-3xl p-8 md:p-10 flex flex-col h-full hover:border-white/20 transition-colors">
              <div className="mb-8">
                <h3 className="text-2xl font-bold mb-2">Basic Remote</h3>
                <p className="text-sm text-gray-500">기존 PC 보유자를 위한 원격 세팅</p>
              </div>
              <div className="mb-8">
                <div className="text-5xl font-bold">30만원</div>
                <div className="text-sm text-gray-500 mt-1">VAT 별도</div>
              </div>

              {/* ROI */}
              <div className="bg-white/5 border border-white/10 rounded-xl p-4 mb-8 text-center">
                <div className="text-xl font-bold text-white">월 25,000원</div>
                <div className="text-xs text-gray-400">12개월 기준 환산</div>
              </div>

              <ul className="space-y-4 mb-10 flex-1">
                {[
                  '원격 OpenClaw 설치 (Mac/Windows/Linux)',
                  'V3 장기기억 시스템 구축 (pgvector)',
                  'AI 연산 최적화 세팅',
                  '기본 기능 활용 원격 가이드 (1시간)',
                  '기본적인 온보딩 교육 진행',
                ].map(item => (
                  <li key={item} className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="text-[#FF6B00] mt-0.5">✓</span> {item}
                  </li>
                ))}
              </ul>

              <Link href="/reserve" className="block w-full text-center py-4 rounded-xl border border-white/20 hover:bg-white/5 text-white font-bold transition-colors">
                원격 설치 예약하기
              </Link>
            </div>
          </FadeIn>

          {/* Premium */}
          <FadeIn delay={0.15}>
            <div className="bg-[#0A0A0A] border border-[#FF6B00]/30 rounded-3xl p-8 md:p-10 relative flex flex-col h-full shadow-[0_0_40px_rgba(255,107,0,0.08)]">
              <div className="absolute top-0 right-0 bg-[#FF6B00] text-black text-xs font-bold px-4 py-1.5 rounded-bl-xl rounded-tr-2xl">
                BEST CHOICE
              </div>
              <div className="mb-8">
                <h3 className="text-2xl font-bold text-[#FF6B00] mb-2">All-in-One Premium</h3>
                <p className="text-sm text-gray-400">Mac Mini + 방문 설치 + 강의 + 맞춤 봇</p>
              </div>
              <div className="mb-8">
                <div className="flex items-baseline gap-3">
                  <div className="text-5xl font-bold text-white">250만원</div>
                  <div className="text-xl text-gray-500 line-through">300만원</div>
                </div>
                <div className="text-sm text-gray-400 mt-1">VAT 포함 · 기기값 포함</div>
              </div>

              {/* Value Props */}
              <div className="bg-[#FF6B00]/10 border border-[#FF6B00]/20 rounded-xl p-4 mb-8">
                <div className="grid grid-cols-3 gap-4 text-center divide-x divide-[#FF6B00]/20">
                  <div>
                    <div className="text-xl font-bold text-white">V3</div>
                    <div className="text-xs text-gray-400">장기기억 시스템</div>
                  </div>
                  <div>
                    <div className="text-xl font-bold text-white">1:1</div>
                    <div className="text-xs text-gray-400">방문 설치 강의</div>
                  </div>
                  <div>
                    <div className="text-xl font-bold text-white">∞</div>
                    <div className="text-xs text-gray-400">추가 구독료 없음</div>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-10 flex-1">
                <div>
                  <h4 className="font-bold border-b border-white/10 pb-2 mb-4 text-sm">하드웨어</h4>
                  <ul className="space-y-3">
                    {[
                      'Apple Mac Mini M4 신품',
                      '10코어 CPU / 10코어 GPU',
                      '16GB 통합 메모리 / 256GB SSD',
                      '팬리스 무소음 · 유휴 7W',
                      'Thunderbolt 4 ×3 · HDMI · Wi-Fi 6E',
                    ].map(item => (
                      <li key={item} className="flex items-start gap-2 text-sm text-gray-300">
                        <span className="text-[#FF6B00] mt-0.5">✓</span> {item}
                      </li>
                    ))}
                  </ul>
                </div>
                <div>
                  <h4 className="font-bold border-b border-white/10 pb-2 mb-4 text-sm">소프트웨어 & 서비스</h4>
                  <ul className="space-y-3">
                    {[
                      'OpenClaw + V3 메모리 DB 풀세팅',
                      '서울/경기 방문 설치 (투명한 언박싱)',
                      '2시간 1:1 현장 활용 강의',
                      '맞춤 자동화 봇 1개 즉석 제작',
                      '무상 A/S 지원',
                    ].map(item => (
                      <li key={item} className="flex items-start gap-2 text-sm text-gray-300">
                        <span className="text-[#FF6B00] mt-0.5">✓</span> {item}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              <CTAButton href="/reserve">올인원 패키지 예약하기</CTAButton>
              <p className="text-xs text-gray-500 mt-4 text-center">* 주문 제작 상품으로 설치 후 환불이 불가능합니다.</p>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Comparison Table */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-5xl mx-auto">
          <SectionHeading subtitle="같은 돈으로 뭘 할 수 있을까요?">가치 비교</SectionHeading>
          <div className="hidden md:block overflow-x-auto">
            <table className="w-full text-left border-collapse text-sm">
              <thead>
                <tr className="border-b border-white/10 text-gray-400">
                  <th className="py-4 px-4" />
                  <th className="py-4 px-4">DIY (직접 설치)</th>
                  <th className="py-4 px-4 text-[#FF6B00] bg-[#FF6B00]/5">ClawNode Basic</th>
                  <th className="py-4 px-4 text-[#FF6B00] bg-[#FF6B00]/10 rounded-t-lg font-bold">프리미엄 오픈클로 올인원</th>
                </tr>
              </thead>
              <tbody>
                {[
                  ['비용', '시간 무제한', '30만원', '250만원 (평생)'],
                  ['하드웨어', '본인 조달', '본인 보유', 'M4 Mac Mini 포함'],
                  ['보안', '본인 책임', 'Zero Trust', 'Zero Trust + 눈앞 언박싱'],
                  ['기억력 (V3)', '없음', 'V3 DB 구축', 'V3 DB 풀세팅'],
                  ['교육', '유튜브 독학', '원격 가이드', '2시간 1:1 현장 과외'],
                  ['맞춤 봇', '없음', '없음', '1개 즉석 제작'],
                  ['지원', '없음', '기본 온보딩', '전용 채널'],
                ].map(([feature, ...values]) => (
                  <tr key={feature} className="border-b border-white/5">
                    <td className="py-4 px-4 font-bold text-white">{feature}</td>
                    {values.map((v, i) => (
                      <td key={i} className={`py-4 px-4 ${i >= 1 ? 'bg-[#FF6B00]/5 text-white font-medium' : 'text-gray-400'}`}>
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
              { feature: '비용', diy: '시간 무제한', basic: '30만원', premium: '250만원 (평생)' },
              { feature: '하드웨어', diy: '본인 조달', basic: '본인 보유', premium: 'M4 Mac Mini 포함' },
              { feature: '보안', diy: '본인 책임', basic: 'Zero Trust', premium: 'Zero Trust + 눈앞 언박싱' },
              { feature: '기억력', diy: '없음', basic: 'V3 DB 구축', premium: 'V3 DB 풀세팅' },
              { feature: '교육', diy: '유튜브 독학', basic: '원격 가이드', premium: '2시간 1:1 과외' },
            ].map(item => (
              <div key={item.feature} className="bg-[#0A0A0A] border border-white/10 rounded-xl p-4">
                <div className="text-white font-bold mb-2">{item.feature}</div>
                <div className="text-xs text-gray-500 mb-3 leading-relaxed">DIY: {item.diy}</div>
                <div className="text-xs text-gray-400 mb-1">Basic: {item.basic}</div>
                <div className="text-sm text-[#FF6B00] font-medium">
                  올인원: {item.premium}
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
              '이미 OpenClaw를 직접 설치해서 잘 쓰고 계신 분 (DIY 능력자)',

              '단순 챗봇만 필요하신 분 (ChatGPT로 충분합니다)',
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
            <Accordion items={PRICING_FAQ_ITEMS} />
          </FadeIn>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-24 px-4 md:px-6 text-center relative overflow-hidden">
        <div className="absolute inset-0 z-0 opacity-20">
          <Image src="/images/hero-bg.png" alt="" fill className="object-cover" />
        </div>
        <div className="relative z-10 max-w-2xl mx-auto">
          <h2 className="text-3xl md:text-5xl font-bold mb-4">
            당신의 24시간 무급 직원,
            <br />
            <span className="text-[#FF6B00]">지금 고용하세요.</span>
          </h2>
          <p className="text-gray-400 mb-8">베이직 30만 원부터. 올인원 250만 원.</p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
            <CTAButton href="/reserve">지금 예약하기 →</CTAButton>
            <a
              href="tel:010-6662-4995"
              className="inline-flex items-center gap-2 px-8 py-4 rounded-xl border border-white/20 hover:bg-white/5 text-white font-bold transition-colors"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" /></svg>
              전화 상담하기
            </a>
          </div>
          <p className="text-gray-500 text-sm mt-4">궁금한 점이 있으시면 편하게 전화주세요 — 010-6662-4995</p>
        </div>
      </section>
    </main>
  )
}
