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
            하드웨어 + AI + 교육
            <br />
            <span className="text-[#FF6B00]">올인원.</span>
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
            <SectionHeading subtitle="미개봉 신품. 소유권 100% 이전.">Apple Mac Mini M4</SectionHeading>
            <p className="text-gray-400 leading-relaxed mb-8">
              고객님 눈앞에서 씰을 뜯습니다.
              하드웨어 소유권은 완전히 고객님께. 애플 1년 무상보증 적용.
            </p>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <tbody className="divide-y divide-white/10">
                  {[
                    ['프로세서', 'Apple M4 (10코어 CPU, 10코어 GPU)'],
                    ['메모리', '16GB 통합 메모리'],
                    ['저장공간', '256GB SSD'],
                    ['Neural Engine', '16코어 (AI 전용)'],
                    ['포트', 'Thunderbolt 4 ×3, HDMI, USB-C ×2'],
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

      {/* Agents Detail — No images, terminal + chat UI */}
      <section className="py-24 px-6">
        <div className="max-w-4xl mx-auto">
          <SectionHeading subtitle="사전 설치. 전원 켜면 바로 작동.">크립토 AI 에이전트 3종</SectionHeading>

          {/* Agent 1: Alpha Watcher */}
          <div className="mb-20">
            <div className="flex items-center gap-4 mb-6">
              <div className="w-12 h-12 rounded-xl bg-[#FF6B00]/10 border border-[#FF6B00]/20 flex items-center justify-center text-2xl">🕵️</div>
              <div>
                <h3 className="text-2xl font-bold">Alpha Watcher</h3>
                <p className="text-[#FF6B00] text-sm">온체인 감시관</p>
              </div>
            </div>
            
            <p className="text-gray-400 leading-relaxed mb-6">
              등록한 고래 지갑의 온체인 활동을 24시간 감시합니다.
              대량 이체, DEX 스왑, 신규 포지션 오픈을 감지하면 텔레그램으로 즉시 알림.
              남들이 트위터에서 소문을 볼 때, 당신은 이미 온체인에서 확인한 상태입니다.
            </p>

            {/* Telegram-style notification */}
            <div className="bg-[#0E1621] rounded-2xl rounded-tl-md p-5 max-w-lg border border-white/5">
              <div className="flex items-center gap-2 mb-3">
                <div className="w-6 h-6 rounded-full bg-[#FF6B00]/20 flex items-center justify-center text-xs">🕵️</div>
                <span className="text-xs font-bold text-[#FF6B00]">Alpha Watcher</span>
                <span className="text-xs text-gray-600">03:42</span>
              </div>
              <p className="text-sm text-gray-300 leading-relaxed">
                <span className="font-bold text-yellow-400">⚠️ 고래 이동 감지</span>
                <br />
                <span className="font-mono text-xs text-gray-500">0x7a3b...f2e1</span> → Binance
                <br />
                <span className="text-white font-bold">1,200 ETH ($4.2M)</span>
                <br />
                <span className="text-gray-500 text-xs mt-2 block">72시간 내 3번째 대량 이체 · 매도 압력 주의</span>
              </p>
            </div>
          </div>

          {/* Agent 2: News Breaker */}
          <div className="mb-20">
            <div className="flex items-center gap-4 mb-6">
              <div className="w-12 h-12 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-2xl">📰</div>
              <div>
                <h3 className="text-2xl font-bold">News Breaker</h3>
                <p className="text-blue-400 text-sm">24시간 뉴스룸</p>
              </div>
            </div>
            
            <p className="text-gray-400 leading-relaxed mb-6">
              크립토 트위터 주요 계정, 디스코드 알파 채널, 뉴스 사이트를 실시간 모니터링.
              노이즈를 걷어내고 핵심만 추려서 매일 아침/저녁 브리핑을 보내드립니다.
              텔레그램 채널 100개 구독할 필요 없습니다.
            </p>

            <div className="bg-[#0E1621] rounded-2xl rounded-tl-md p-5 max-w-lg border border-white/5">
              <div className="flex items-center gap-2 mb-3">
                <div className="w-6 h-6 rounded-full bg-blue-500/20 flex items-center justify-center text-xs">📰</div>
                <span className="text-xs font-bold text-blue-400">News Breaker</span>
                <span className="text-xs text-gray-600">08:00</span>
              </div>
              <p className="text-sm text-gray-300 leading-relaxed">
                <span className="font-bold text-blue-400">📋 모닝 브리핑</span>
                <br /><br />
                1. SEC, 이더리움 현물 ETF 옵션 거래 승인
                <br />
                2. Solana TVL $15B — 사상 최고치
                <br />
                3. 업비트 신규 상장 후보 3종 공시
                <br />
                <span className="text-gray-500 text-xs mt-2 block">42개 소스 분석 · 상세 분석 필요하면 질문하세요</span>
              </p>
            </div>
          </div>

          {/* Agent 3: Portfolio Tracker */}
          <div className="mb-8">
            <div className="flex items-center gap-4 mb-6">
              <div className="w-12 h-12 rounded-xl bg-green-500/10 border border-green-500/20 flex items-center justify-center text-2xl">📊</div>
              <div>
                <h3 className="text-2xl font-bold">Portfolio Tracker</h3>
                <p className="text-green-400 text-sm">개인 자산 관리자</p>
              </div>
            </div>
            
            <p className="text-gray-400 leading-relaxed mb-6">
              업비트, 바이낸스, 메타마스크, Phantom — 거래소와 지갑을 통합 연결합니다.
              실시간 P&L 계산, 자산 비중 분석, 리밸런싱 시점 알림까지.
              엑셀 포트폴리오 관리 지옥에서 해방됩니다.
            </p>

            <div className="bg-[#0E1621] rounded-2xl rounded-tl-md p-5 max-w-lg border border-white/5">
              <div className="flex items-center gap-2 mb-3">
                <div className="w-6 h-6 rounded-full bg-green-500/20 flex items-center justify-center text-xs">📊</div>
                <span className="text-xs font-bold text-green-400">Portfolio Tracker</span>
                <span className="text-xs text-gray-600">09:00</span>
              </div>
              <p className="text-sm text-gray-300 leading-relaxed">
                <span className="font-bold text-green-400">📈 일일 리포트</span>
                <br /><br />
                총 자산: <span className="text-white font-bold">₩142,350,000</span> <span className="text-green-400">(+2.3%)</span>
                <br />
                <span className="text-green-400">▲ BTC +4.1%</span> · <span className="text-green-400">▲ ETH +1.8%</span> · <span className="text-red-400">▼ SOL -2.5%</span>
                <br />
                <span className="text-yellow-400 text-xs mt-2 block">⚡ SOL 비중 22% (목표 15%) — 리밸런싱 검토</span>
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* How It's Different */}
      <section className="py-24 px-6 bg-white/[0.02]">
        <div className="max-w-4xl mx-auto">
          <SectionHeading subtitle="에이전트는 많습니다. 차이는 이겁니다.">ClawNode가 다른 점</SectionHeading>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {[
              { icon: '🏠', title: '100% 로컬', desc: 'API 키가 클라우드에 올라가지 않습니다. 당신의 맥미니 안에서만 동작합니다.' },
              { icon: '💬', title: '대화형 AI', desc: '"ETH 뉴스 요약해줘", "포트폴리오 현황 알려줘" — 텔레그램에서 대화하듯 명령하면 됩니다.' },
              { icon: '🔧', title: '커스터마이징', desc: '관심 코인, 추적할 지갑 주소, 뉴스 소스를 자유롭게 추가/수정할 수 있습니다.' },
              { icon: '♾️', title: '월 구독료 0원', desc: '한 번 사면 평생. 소프트웨어 업데이트도 무료입니다. LLM API 비용만 실비 발생.' },
            ].map(item => (
              <div key={item.title} className="p-6 border border-white/10 rounded-xl">
                <span className="text-2xl">{item.icon}</span>
                <h4 className="font-bold mt-3 mb-2">{item.title}</h4>
                <p className="text-sm text-gray-400">{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-16 px-6 text-center border-t border-white/5">
        <h2 className="text-2xl md:text-3xl font-bold mb-4">관심 있으신가요?</h2>
        <p className="text-gray-400 mb-6">선착순 5대 한정.</p>
        <CTAButton href="https://t.me/buidlermason">내 자리 확보하기</CTAButton>
      </section>
    </main>
  )
}
