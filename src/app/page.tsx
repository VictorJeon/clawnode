import Image from 'next/image'
import CTAButton from '@/components/CTAButton'

export default function HomePage() {
  return (
    <main>
      {/* Hero */}
      <section className="relative min-h-screen flex flex-col items-center justify-center text-center px-6 overflow-hidden">
        {/* Background Image */}
        <div className="absolute inset-0 z-0 opacity-30">
          <Image src="/images/hero-bg.png" alt="" fill className="object-cover" priority />
        </div>

        <div className="relative z-10 max-w-4xl mx-auto">
          {/* Fire Ant Badge */}
          <div className="inline-flex items-center gap-3 px-4 py-2 rounded-full border border-white/10 bg-white/5 text-sm font-medium mb-8 backdrop-blur-sm">
            <Image src="/images/fire-ant-logo.jpg" alt="Fire Ant Crypto" width={28} height={28} className="rounded-full" />
            <span className="text-gray-300">Trusted by <span className="text-white font-bold">Fire Ant Crypto</span> (40K+)</span>
          </div>

          <h1 className="text-5xl md:text-7xl font-bold tracking-tight mb-6 leading-tight">
            잠자는 동안에도 시장을 감시하는
            <br />
            <span className="bg-gradient-to-r from-orange-400 to-red-500 bg-clip-text text-transparent">
              내 책상 위의 AI 노드.
            </span>
          </h1>

          <p className="text-xl text-gray-400 max-w-2xl mx-auto mb-10 leading-relaxed">
            월 구독료 0원. 클라우드 의존 0%. 데이터 유출 0건.
            <br />
            애플 M4 실리콘의 강력한 보안으로 당신만의 금융 인텔리전스를 구축하세요.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <CTAButton href="https://t.me/buidlermason">지금 예약하기 (300만원) →</CTAButton>
            <a href="/security" className="px-8 py-3 rounded-md border border-white/10 hover:bg-white/5 text-white font-medium transition-all">
              왜 로컬인가?
            </a>
          </div>
        </div>
      </section>

      {/* Stats Counter */}
      <section className="border-y border-white/5 py-12">
        <div className="max-w-5xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-8 text-center">
          {[
            { value: '5대', label: '선착순 한정' },
            { value: 'M4', label: 'Apple Silicon' },
            { value: '2시간', label: '설치 완료' },
            { value: '30일', label: '기술 지원' },
          ].map(s => (
            <div key={s.label}>
              <div className="text-3xl font-bold text-[#FF6B00]">{s.value}</div>
              <div className="text-sm text-gray-500 mt-1">{s.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Mac Mini Product Shot */}
      <section className="py-24 px-6">
        <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-16 items-center">
          <div className="relative aspect-[4/3] rounded-2xl overflow-hidden">
            <Image src="/images/mac-mini-hero.png" alt="Mac Mini M4" fill className="object-cover" />
          </div>
          <div>
            <h2 className="text-3xl md:text-4xl font-bold mb-6">
              당신의 책상 위에 놓이는
              <br />
              <span className="text-[#FF6B00]">개인 AI 서버.</span>
            </h2>
            <p className="text-gray-400 leading-relaxed mb-6">
              Apple Mac Mini M4는 세계에서 가장 조용하고, 가장 효율적인 AI 연산 장치입니다. 
              전기세는 전구 하나 수준이면서, 24시간 내내 당신만의 AI 에이전트를 돌릴 수 있습니다.
            </p>
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-white/5 p-4 rounded-xl border border-white/10">
                <div className="text-[#FF6B00] font-bold text-xl">10코어</div>
                <div className="text-xs text-gray-500">CPU + Neural Engine</div>
              </div>
              <div className="bg-white/5 p-4 rounded-xl border border-white/10">
                <div className="text-[#FF6B00] font-bold text-xl">16GB</div>
                <div className="text-xs text-gray-500">Unified Memory</div>
              </div>
              <div className="bg-white/5 p-4 rounded-xl border border-white/10">
                <div className="text-[#FF6B00] font-bold text-xl">~7W</div>
                <div className="text-xs text-gray-500">유휴 시 소비전력</div>
              </div>
              <div className="bg-white/5 p-4 rounded-xl border border-white/10">
                <div className="text-[#FF6B00] font-bold text-xl">0dB</div>
                <div className="text-xs text-gray-500">팬리스 무소음</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Agents Preview */}
      <section className="py-24 px-6 bg-white/[0.02]">
        <div className="max-w-6xl mx-auto text-center mb-16">
          <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-2">Pre-installed Agents</p>
          <h2 className="text-3xl md:text-4xl font-bold">전원을 켜면, 3명의 직원이 일을 시작합니다.</h2>
        </div>

        <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-8">
          {[
            {
              img: '/images/agent-alpha-final.png',
              name: 'Alpha Watcher',
              role: '온체인 감시관',
              desc: '특정 지갑의 움직임을 24시간 감시하고, 이상 거래 발생 시 텔레그램으로 즉시 알림을 보냅니다.',
            },
            {
              img: '/images/agent-news-final.png',
              name: 'News Breaker',
              role: '24시간 뉴스룸',
              desc: '수백 개의 크립토 트위터, 뉴스, 디스코드를 모니터링하고 매일 아침/저녁 핵심 요약을 보내드립니다.',
            },
            {
              img: '/images/agent-portfolio-final.png',
              name: 'Portfolio Tracker',
              role: '개인 자산 관리자',
              desc: '거래소와 지갑을 통합 연결하여 실시간 P&L을 계산하고 리밸런싱 시점을 알려드립니다.',
            },
          ].map(agent => (
            <div key={agent.name} className="bg-[#0A0A0A] border border-white/10 rounded-2xl p-6 hover:border-[#FF6B00]/50 transition-colors group">
              <div className="relative w-full aspect-[16/9] mb-4 rounded-xl overflow-hidden bg-black">
                <Image src={agent.img} alt={agent.name} fill className="object-contain group-hover:scale-105 transition-transform" />
              </div>
              <h3 className="text-xl font-bold">{agent.name}</h3>
              <p className="text-sm text-[#FF6B00] mb-3">{agent.role}</p>
              <p className="text-sm text-gray-400 leading-relaxed">{agent.desc}</p>
            </div>
          ))}
        </div>

        <div className="text-center mt-12">
          <a href="/product" className="text-[#FF6B00] font-medium hover:underline">에이전트 상세 보기 →</a>
        </div>
      </section>

      {/* Mid CTA */}
      <section className="py-16 px-6 text-center border-y border-white/5">
        <h2 className="text-2xl md:text-3xl font-bold mb-4">준비되셨나요?</h2>
        <p className="text-gray-400 mb-6">선착순 5대 한정. 지금 예약하세요.</p>
        <CTAButton href="https://t.me/buidlermason">텔레그램으로 예약하기</CTAButton>
      </section>

      {/* Final CTA */}
      <section className="py-24 px-6 text-center relative overflow-hidden">
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
          <CTAButton href="https://t.me/buidlermason">지금 예약하기 (300만원) →</CTAButton>
        </div>
      </section>
    </main>
  )
}
