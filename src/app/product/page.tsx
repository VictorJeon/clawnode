import Image from 'next/image'
import SectionHeading from '@/components/SectionHeading'
import CTAButton from '@/components/CTAButton'

export default function ProductPage() {
  return (
    <main>
      {/* Hero */}
      <section className="py-24 px-6 text-center">
        <div className="max-w-3xl mx-auto">
          <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-4">What You Get</p>
          <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-6">
            하드웨어 + 소프트웨어 + 교육
            <br />
            <span className="text-[#FF6B00]">올인원 패키지.</span>
          </h1>
        </div>
      </section>

      {/* Hardware Section */}
      <section className="py-24 px-6 bg-white/[0.02]">
        <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-16 items-center">
          <div className="relative aspect-[4/3] rounded-2xl overflow-hidden">
            <Image src="/images/mac-mini-hero.png" alt="Mac Mini M4" fill className="object-cover" />
          </div>
          <div>
            <SectionHeading subtitle="소유권 100% 이전">Apple Mac Mini M4</SectionHeading>
            <p className="text-gray-400 leading-relaxed mb-8">
              미개봉 신품을 고객님 눈앞에서 뜯어 드립니다.
              하드웨어의 소유권은 완전히 고객님께 이전됩니다.
              애플 공식 1년 보증이 적용됩니다.
            </p>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <tbody className="divide-y divide-white/10">
                  {[
                    ['프로세서', 'Apple M4 (10코어 CPU, 10코어 GPU)'],
                    ['메모리', '16GB 통합 메모리 (120GB/s 대역폭)'],
                    ['저장공간', '256GB SSD'],
                    ['Neural Engine', '16코어 (AI 전용)'],
                    ['포트', 'Thunderbolt 4 ×3, HDMI 2.1, USB-C ×2'],
                    ['네트워크', 'Wi-Fi 6E + Gigabit Ethernet'],
                    ['소비전력', '유휴 ~7W / 풀로드 ~45W'],
                    ['소음', '팬리스 (0dB)'],
                  ].map(([key, val]) => (
                    <tr key={key}>
                      <td className="py-3 pr-4 text-gray-500 font-medium whitespace-nowrap">{key}</td>
                      <td className="py-3 text-gray-300">{val}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </section>

      {/* Agents Detail */}
      <section className="py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <SectionHeading subtitle="사전 설치되어 바로 작동합니다.">크립토 특화 에이전트 3종</SectionHeading>

          {/* Agent 1 */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center mb-24">
            <div className="relative aspect-[16/10] rounded-2xl overflow-hidden bg-black border border-white/10">
              <Image src="/images/agent-alpha-final.png" alt="Alpha Watcher" fill className="object-contain" />
            </div>
            <div>
              <h3 className="text-2xl font-bold mb-2">🕵️ Alpha Watcher</h3>
              <p className="text-[#FF6B00] text-sm mb-4">온체인 감시관</p>
              <p className="text-gray-400 leading-relaxed mb-6">
                고래 지갑, 특정 토큰의 온체인 움직임을 24시간 감시합니다.
                대량 이체, 덱스 유동성 변동, 비정상적 거래 패턴이 감지되면
                텔레그램으로 즉시 알림을 보냅니다.
              </p>
              <div className="bg-[#0A0A0A] border border-white/10 rounded-xl p-4 font-mono text-xs">
                <p className="text-green-400">➜ [Alpha] 고래 지갑 0x7a...f2 감지</p>
                <p className="text-gray-400 ml-4">1,000 ETH → Binance Hot Wallet</p>
                <p className="text-yellow-400 ml-4">⚠ 대량 매도 가능성. 확인 요망.</p>
              </div>
            </div>
          </div>

          {/* Agent 2 */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center mb-24">
            <div className="order-2 md:order-1">
              <h3 className="text-2xl font-bold mb-2">📰 News Breaker</h3>
              <p className="text-[#FF6B00] text-sm mb-4">24시간 뉴스룸</p>
              <p className="text-gray-400 leading-relaxed mb-6">
                수백 개의 크립토 트위터 계정, 뉴스 사이트, 텔레그램 채널을
                실시간으로 모니터링합니다. 노이즈를 제거하고 핵심만 추려서
                매일 아침/저녁 브리핑을 보내드립니다.
              </p>
              <div className="bg-[#0A0A0A] border border-white/10 rounded-xl p-4 font-mono text-xs">
                <p className="text-blue-400">➜ [News] 오늘의 브리핑 (08:00 KST)</p>
                <p className="text-gray-400 ml-4">1. SEC, 이더리움 현물 ETF 최종 승인</p>
                <p className="text-gray-400 ml-4">2. Solana TVL $15B 돌파, 사상 최고치</p>
                <p className="text-gray-400 ml-4">3. Binance, 한국 시장 재진출 검토 중</p>
              </div>
            </div>
            <div className="relative aspect-[16/10] rounded-2xl overflow-hidden bg-black border border-white/10 order-1 md:order-2">
              <Image src="/images/agent-news-final.png" alt="News Breaker" fill className="object-contain" />
            </div>
          </div>

          {/* Agent 3 */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
            <div className="relative aspect-[16/10] rounded-2xl overflow-hidden bg-black border border-white/10">
              <Image src="/images/agent-portfolio-final.png" alt="Portfolio Tracker" fill className="object-contain" />
            </div>
            <div>
              <h3 className="text-2xl font-bold mb-2">📊 Portfolio Tracker</h3>
              <p className="text-[#FF6B00] text-sm mb-4">개인 자산 관리자</p>
              <p className="text-gray-400 leading-relaxed mb-6">
                바이낸스, 업비트, 메타마스크 등 거래소와 지갑을 통합 연결합니다.
                실시간 P&amp;L 계산, 자산 비중 분석, 리밸런싱 시점 알림까지.
                엑셀 지옥에서 해방됩니다.
              </p>
              <div className="bg-[#0A0A0A] border border-white/10 rounded-xl p-4 font-mono text-xs">
                <p className="text-[#FF6B00]">➜ [Portfolio] 일일 리포트</p>
                <p className="text-gray-400 ml-4">총 자산: ₩142,350,000 (+2.3%)</p>
                <p className="text-green-400 ml-4">BTC: +4.1% | ETH: +1.8%</p>
                <p className="text-red-400 ml-4">SOL: -2.5% (리밸런싱 권장)</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-16 px-6 text-center border-t border-white/5">
        <h2 className="text-2xl md:text-3xl font-bold mb-4">마음에 드시나요?</h2>
        <p className="text-gray-400 mb-6">선착순 5대 한정. 지금 예약하세요.</p>
        <CTAButton href="https://t.me/buidlermason">지금 예약하기 (300만원)</CTAButton>
      </section>
    </main>
  )
}
