'use client'

import Image from 'next/image'
import CTAButton from '@/components/CTAButton'
import FadeIn from '@/components/FadeIn'
import Counter from '@/components/Counter'
import GlowCard from '@/components/GlowCard'

export default function HomePage() {
  return (
    <main>
      {/* Hero */}
      <section className="relative min-h-screen flex flex-col items-center justify-center text-center px-6 overflow-hidden">
        <div className="absolute inset-0 z-0 opacity-30">
          <Image src="/images/hero-bg.png" alt="" fill className="object-cover" priority />
        </div>

        <div className="relative z-10 max-w-4xl mx-auto">
          <FadeIn delay={0.1}>
            <div className="inline-flex items-center gap-3 px-4 py-2 rounded-full border border-white/10 bg-white/5 text-sm font-medium mb-8 backdrop-blur-sm">
              <Image src="/images/fire-ant-logo.jpg" alt="Fire Ant Crypto" width={28} height={28} className="rounded-full" />
              <span className="text-gray-300"><span className="text-white font-bold">불개미</span> 4만 커뮤니티 추천</span>
            </div>
          </FadeIn>

          <FadeIn delay={0.2}>
            <h1 className="text-4xl md:text-6xl lg:text-7xl font-bold tracking-tight mb-6 leading-tight">
              새벽 3시 펌핑,
              <br />
              <span className="bg-gradient-to-r from-orange-400 to-red-500 bg-clip-text text-transparent">
                또 놓치실 건가요?
              </span>
            </h1>
          </FadeIn>

          <FadeIn delay={0.4}>
            <p className="text-lg md:text-xl text-gray-400 max-w-2xl mx-auto mb-10 leading-relaxed">
              텔레그램 알파 채널 100개를 눈으로 다 볼 수 없습니다.
              <br />
              당신 책상 위의 Mac Mini가 대신 감시하고, 대신 알려줍니다.
              <br />
              <span className="text-gray-500">월 구독료 없음 · 클라우드 없음 · API 키 유출 0건</span>
            </p>
          </FadeIn>

          <FadeIn delay={0.6}>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <CTAButton href="/reserve">선착순 5대 — 내 자리 확보하기</CTAButton>
              <a href="/security" className="px-8 py-3 rounded-md border border-white/10 hover:bg-white/5 text-white font-medium transition-all">
                왜 로컬인가?
              </a>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Stats Counter */}
      <section className="border-y border-white/5 py-12">
        <div className="max-w-5xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-8 text-center">
          <Counter value="5대" label="선착순 한정" />
          <Counter value="M4" label="Apple Silicon" />
          <Counter value="2시간" label="현장 설치" />
          <Counter value="30일" label="1:1 기술지원" />
        </div>
      </section>

      {/* Pain Point → Solution */}
      <section className="py-24 px-6">
        <div className="max-w-4xl mx-auto">
          <FadeIn>
            <div className="text-center mb-16">
              <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-2">The Problem</p>
              <h2 className="text-3xl md:text-4xl font-bold">이거 다 해본 적 있죠?</h2>
            </div>
          </FadeIn>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-16">
            {[
              { emoji: '😴', pain: '새벽 3시 27분, 고래가 ETH 2,400개를 바이낸스로 옮겼어요. 당신은 7시에 일어나서 -8% 차트를 봤고요.' },
              { emoji: '📱', pain: '텔레그램 알파 채널 127개 구독 중. 오늘 실제로 읽은 건 3개. 그 사이에 묻힌 알파가 몇 개일까요.' },
              { emoji: '📊', pain: '업비트, 바이낸스, 메타마스크, 팬텀 — 4개 앱 돌려가며 총 자산 계산하다가 세 번째 구글 시트도 포기했어요.' },
              { emoji: '🔐', pain: '클라우드 봇에 거래소 API 키를 넣었는데, 그 서버를 누가 관리하는지 물어본 적 있나요?' },
            ].map((item, i) => (
              <FadeIn key={item.pain} delay={i * 0.1}>
                <GlowCard>
                  <div className="flex items-start gap-4">
                    <span className="text-2xl shrink-0">{item.emoji}</span>
                    <p className="text-gray-300 leading-relaxed">{item.pain}</p>
                  </div>
                </GlowCard>
              </FadeIn>
            ))}
          </div>

          <FadeIn>
            <div className="text-center">
              <p className="text-gray-500 mb-4">↓</p>
              <h3 className="text-2xl font-bold mb-2">그래서 만들었습니다.</h3>
              <p className="text-gray-400">당신 옆에서 24시간 일하는, <span className="text-[#FF6B00] font-bold">진짜 내 것인</span> AI.</p>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Mac Mini Product Shot */}
      <section className="py-24 px-6 bg-white/[0.02]">
        <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-16 items-center">
          <FadeIn direction="left">
            <div className="relative aspect-[4/3] rounded-2xl overflow-hidden">
              <Image src="/images/mac-mini-hero.png" alt="Mac Mini M4" fill className="object-cover" />
            </div>
          </FadeIn>
          <FadeIn direction="right">
            <div>
              <h2 className="text-3xl md:text-4xl font-bold mb-6">
                당신의 책상 위에 놓이는
                <br />
                <span className="text-[#FF6B00]">개인 AI 서버.</span>
              </h2>
              <p className="text-gray-400 leading-relaxed mb-6">
                Apple Mac Mini M4. 팬 없이 무소음. 전기세 전구 하나 수준.
                그런데 24시간 내내 AI 에이전트 3개를 동시에 돌립니다.
              </p>
              <div className="grid grid-cols-2 gap-4">
                {[
                  { val: '10코어', sub: 'CPU + Neural Engine' },
                  { val: '16GB', sub: 'Unified Memory' },
                  { val: '~7W', sub: '유휴 시 소비전력' },
                  { val: '0dB', sub: '팬리스 무소음' },
                ].map(s => (
                  <div key={s.val} className="bg-white/5 p-4 rounded-xl border border-white/10 hover:border-[#FF6B00]/30 transition-colors">
                    <div className="text-[#FF6B00] font-bold text-xl">{s.val}</div>
                    <div className="text-xs text-gray-500">{s.sub}</div>
                  </div>
                ))}
              </div>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Agents — Telegram Chat UI Style */}
      <section className="py-24 px-6">
        <div className="max-w-4xl mx-auto">
          <FadeIn>
            <div className="text-center mb-16">
              <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-2">3 AI Agents, Pre-installed</p>
              <h2 className="text-3xl md:text-4xl font-bold">전원 켜면 바로 일합니다.</h2>
              <p className="text-gray-400 mt-3">텔레그램으로 이런 알림이 옵니다.</p>
            </div>
          </FadeIn>

          {/* Agent 1: Alpha Watcher */}
          <FadeIn delay={0}>
            <div className="mb-12">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-full bg-[#FF6B00]/20 flex items-center justify-center text-lg">🕵️</div>
                <div>
                  <h3 className="font-bold">Alpha Watcher</h3>
                  <p className="text-xs text-gray-500">온체인 감시관 · 24시간 고래 추적</p>
                </div>
              </div>
              <div className="bg-[#0E1621] rounded-2xl rounded-tl-md p-5 max-w-lg border border-white/5 hover:border-[#FF6B00]/20 transition-colors">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-6 h-6 rounded-full bg-[#FF6B00]/20 flex items-center justify-center text-xs">🕵️</div>
                  <span className="text-xs font-bold text-[#FF6B00]">Alpha Watcher</span>
                  <span className="text-xs text-gray-600">03:42</span>
                </div>
                <p className="text-sm text-gray-300 leading-relaxed">
                  <span className="font-bold text-yellow-400">🚨 고래 긴급</span>
                  <br />
                  <span className="font-mono text-xs text-gray-500">0x7a3b...f2e1</span> → Binance
                  <br />
                  <span className="text-white font-bold">2,400 ETH ($8.2M)</span> 이체
                  <br />
                  <span className="text-gray-500 text-xs block">72시간 내 3회째 · 누적 매도 $8.2M</span>
                  <span className="text-yellow-400 text-xs block">지난번 이 패턴 후 ETH 12% 하락했어요</span>
                </p>
              </div>
              <p className="text-sm text-gray-500 mt-3">고래 지갑, DEX 유동성, 비정상 거래 패턴을 실시간으로 감시합니다.</p>
            </div>
          </FadeIn>

          {/* Agent 2: News Breaker */}
          <FadeIn delay={0.1}>
            <div className="mb-12">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-full bg-blue-500/20 flex items-center justify-center text-lg">📰</div>
                <div>
                  <h3 className="font-bold">News Breaker</h3>
                  <p className="text-xs text-gray-500">24시간 뉴스룸 · CT/디스코드/뉴스 모니터링</p>
                </div>
              </div>
              <div className="bg-[#0E1621] rounded-2xl rounded-tl-md p-5 max-w-lg border border-white/5 hover:border-blue-500/20 transition-colors">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-6 h-6 rounded-full bg-blue-500/20 flex items-center justify-center text-xs">📰</div>
                  <span className="text-xs font-bold text-blue-400">News Breaker</span>
                  <span className="text-xs text-gray-600">08:00</span>
                </div>
                <p className="text-sm text-gray-300 leading-relaxed">
                  <span className="font-bold text-blue-400">📋 모닝 브리핑</span>
                  <br /><br />
                  1. SEC, 이더리움 현물 ETF 옵션 거래 최종 승인 → ETH +6.2%
                  <br />
                  2. 바이낸스 신규 상장 KMNO 공지 → 업비트 상장 가능성
                  <br />
                  3. Solana TVL $15B 돌파 — DEX 거래량 이더 추월
                  <br />
                  <span className="text-gray-500 text-xs mt-2 block">42개 소스 종합 · 상세 분석 필요하면 물어보세요</span>
                </p>
              </div>
              <p className="text-sm text-gray-500 mt-3">수백 개 소스를 모니터링하고, 노이즈를 제거한 핵심만 매일 2회 브리핑합니다.</p>
            </div>
          </FadeIn>

          {/* Agent 3: Portfolio Tracker */}
          <FadeIn delay={0.2}>
            <div className="mb-8">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-full bg-green-500/20 flex items-center justify-center text-lg">📊</div>
                <div>
                  <h3 className="font-bold">Portfolio Tracker</h3>
                  <p className="text-xs text-gray-500">개인 자산 관리자 · 거래소+지갑 통합</p>
                </div>
              </div>
              <div className="bg-[#0E1621] rounded-2xl rounded-tl-md p-5 max-w-lg border border-white/5 hover:border-green-500/20 transition-colors">
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
                  <span className="text-yellow-400 text-xs block">⚠️ SOL 비중 22% → 목표 15% 초과</span>
                  <span className="text-gray-500 text-xs block">7% 정리 시 약 ₩980만원 리밸런싱 가능</span>
                </p>
              </div>
              <p className="text-sm text-gray-500 mt-3">거래소와 지갑을 연결하면 실시간 P&L, 비중 분석, 리밸런싱 알림까지.</p>
            </div>
          </FadeIn>

          <FadeIn>
            <div className="text-center mt-12">
              <a href="/product" className="text-[#FF6B00] font-medium hover:underline">에이전트 상세 보기 →</a>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Social Proof */}
      <section className="py-24 px-6 bg-white/[0.02]">
        <div className="max-w-5xl mx-auto">
          <FadeIn>
            <div className="text-center mb-12">
              <h2 className="text-3xl font-bold">먼저 써본 사람들</h2>
            </div>
          </FadeIn>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {[
              {
                name: '새벽손절러',
                type: '데이 트레이더',
                quote: '고래 알림 보고 새벽에 숏 잡았는데 아침에 +18%. 예전 같으면 손절 타이밍도 못 잡고 물렸을 거예요.',
              },
              {
                name: '비트묻어둔남자',
                type: '장기 홀더',
                quote: '텔레그램 채널 정리 다 했어요. 아침 브리핑 하나면 충분. 정보 스트레스에서 해방됐어요 진짜로.',
              },
              {
                name: '알파독',
                type: '알파 헌터',
                quote: 'CT에서 소문 돌기 6시간 전에 온체인에서 잡아요. 정보 먹이사슬이 확실히 달라졌어요.',
              },
            ].map((p, i) => (
              <FadeIn key={p.name} delay={i * 0.15}>
                <GlowCard>
                  <p className="text-gray-300 text-sm leading-relaxed mb-6">&ldquo;{p.quote}&rdquo;</p>
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-full bg-[#FF6B00]/20 flex items-center justify-center text-xs font-bold text-[#FF6B00]">
                      {p.name[0]}
                    </div>
                    <div>
                      <p className="text-sm font-bold">{p.name}</p>
                      <p className="text-xs text-gray-500">{p.type}</p>
                    </div>
                  </div>
                </GlowCard>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* Why Local */}
      <section className="py-24 px-6">
        <div className="max-w-4xl mx-auto text-center">
          <FadeIn>
            <h2 className="text-3xl md:text-4xl font-bold mb-12">
              API 키를 <span className="text-red-500">남의 서버</span>에 맡기고 계시나요?
            </h2>
          </FadeIn>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 text-left">
            {[
              { num: '01', title: '클라우드 봇은 공용 서버', desc: '당신의 API 키가 수천 명의 키와 같은 DB에 저장됩니다. 한 명이 뚫리면 전체가 뚫립니다.' },
              { num: '02', title: '서비스가 죽으면 끝', desc: '클라우드 서비스가 종료하면 설정, 데이터, 전략 전부 사라집니다. 내 것이 아닌 건 내 것이 아닙니다.' },
              { num: '03', title: 'ClawNode는 내 책상 위', desc: 'API 키는 Apple Keychain에 암호화 저장. 데이터는 맥미니 안에서만. 외부 통신은 Tailscale 암호화 터널만.' },
            ].map((item, i) => (
              <FadeIn key={item.num} delay={i * 0.15}>
                <div className="p-6 border border-white/10 rounded-xl hover:border-[#FF6B00]/30 transition-colors">
                  <p className="text-[#FF6B00] text-3xl font-bold mb-4">{item.num}</p>
                  <h4 className="font-bold mb-2">{item.title}</h4>
                  <p className="text-sm text-gray-400">{item.desc}</p>
                </div>
              </FadeIn>
            ))}
          </div>
          <FadeIn>
            <div className="mt-10">
              <a href="/security" className="text-[#FF6B00] font-medium hover:underline">보안 아키텍처 상세 보기 →</a>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Mid CTA */}
      <section className="py-16 px-6 text-center border-y border-white/5">
        <FadeIn>
          <h2 className="text-2xl md:text-3xl font-bold mb-4">선착순 5대. 고민하면 없어집니다.</h2>
          <p className="text-gray-400 mb-6">텔레그램에서 바로 예약 가능합니다.</p>
          <CTAButton href="/reserve">내 자리 확보하기</CTAButton>
        </FadeIn>
      </section>

      {/* Final CTA */}
      <section className="py-24 px-6 text-center relative overflow-hidden">
        <div className="absolute inset-0 z-0 opacity-20">
          <Image src="/images/hero-bg.png" alt="" fill className="object-cover" />
        </div>
        <div className="relative z-10 max-w-2xl mx-auto">
          <FadeIn>
            <div className="inline-flex items-center gap-2 mb-6">
              <Image src="/images/fire-ant-logo.jpg" alt="Fire Ant" width={24} height={24} className="rounded-full" />
              <span className="text-sm text-gray-400">불개미 커뮤니티 추천</span>
            </div>
            <h2 className="text-3xl md:text-5xl font-bold mb-4">
              다음 펌핑은
              <br />
              <span className="text-[#FF6B00]">놓치지 마세요.</span>
            </h2>
            <p className="text-gray-400 mb-8">하루 2,740원. 3년 쓰면 커피값. 그런데 평생 씁니다.</p>
            <CTAButton href="/reserve">선착순 5대 — 내 자리 확보하기</CTAButton>
          </FadeIn>
        </div>
      </section>
    </main>
  )
}
