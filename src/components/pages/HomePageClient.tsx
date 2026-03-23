'use client'

import Image from 'next/image'
import Link from 'next/link'
import CTAButton from '@/components/CTAButton'
import FadeIn from '@/components/FadeIn'
import Counter from '@/components/Counter'
import GlowCard from '@/components/GlowCard'
import SectionHeading from '@/components/SectionHeading'
import ChatBot from '@/components/ChatBot'

export default function HomePageClient() {
  return (
    <main>
      {/* Hero */}
      <section className="relative min-h-screen flex flex-col justify-center px-6 py-24 overflow-hidden">
        <div className="absolute inset-0 z-0 opacity-30">
          <Image src="/images/hero-bg.png" alt="" fill className="object-cover" priority />
        </div>

        <div className="relative z-10 max-w-7xl mx-auto w-full grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          {/* Left: Copy */}
          <div className="text-center lg:text-left">
            <FadeIn delay={0.2}>
              <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-6 leading-tight">
                당신을 위한 24시간
                <br />
                <span className="bg-gradient-to-r from-orange-400 to-red-500 bg-clip-text text-transparent">
                  무급 직원을 고용하세요.
                </span>
              </h1>
            </FadeIn>

            <FadeIn delay={0.4}>
              <p className="text-lg text-gray-400 mb-4 leading-relaxed">
                프리미엄 오픈클로, <span className="text-white font-bold">ClawNode(클로노드)</span>.
              </p>
              <p className="text-base text-gray-500 mb-10 leading-relaxed">
                오픈클로는 오픈소스입니다. 하지만 '잘 쓰는 것'과 '그냥 설치하는 것'은 다릅니다.<br />
                코딩 몰라도 됩니다. V3 기억부터 맞춤 봇까지 전부 셋팅해 드립니다.
              </p>
            </FadeIn>

            <FadeIn delay={0.6}>
              <div className="flex flex-col sm:flex-row items-center lg:items-start justify-center lg:justify-start gap-4">
                <CTAButton href="/reserve">선착순 마감 — 내 자리 확보하기</CTAButton>
                <Link href="/product" className="px-8 py-3 rounded-md border border-white/10 hover:bg-white/5 text-white font-medium transition-all">
                  제품 상세 보기
                </Link>
              </div>
            </FadeIn>
          </div>

          {/* Right: Chatbot */}
          <FadeIn delay={0.5}>
            <div className="w-full">
              <div className="text-center lg:text-left mb-4">
                <p className="text-xs text-[#FF6B00] font-bold tracking-wider uppercase">Free AI Consulting</p>
                <p className="text-sm text-gray-500 mt-1">어떤 업무를 자동화하고 싶으신지 알려주세요.</p>
              </div>
              <ChatBot />
            </div>
          </FadeIn>
        </div>
      </section>

      {/* 🔥 Early Adopter Event Banner */}
      <section className="relative overflow-hidden border-y border-[#FF6B00]/20 bg-gradient-to-r from-[#FF6B00]/10 via-[#FF3D00]/5 to-[#FF6B00]/10 py-5">
        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGNpcmNsZSBjeD0iMjAiIGN5PSIyMCIgcj0iMSIgZmlsbD0icmdiYSgyNTUsMTA3LDAsMC4wNSkiLz48L3N2Zz4=')] opacity-50" />
        <div className="relative z-10 mx-auto max-w-5xl px-6 flex flex-col md:flex-row items-center justify-center gap-3 md:gap-6 text-center md:text-left">
          <span className="inline-flex items-center gap-2 rounded-full bg-[#FF6B00] px-3 py-1 text-xs font-bold text-black shrink-0">
            🛡️ 얼리어답터 이벤트
          </span>
          <p className="text-sm md:text-base text-gray-200 leading-relaxed">
            <span className="font-bold text-white">4월 9일까지</span> 신청 고객 대상 —{' '}
            <span className="font-bold text-[#FF6B00]">설치 후 2주 내 해킹 발생 시 최대 500만 원 보전</span>
          </p>
          <Link
            href="/reserve"
            className="shrink-0 rounded-lg bg-[#FF6B00] px-5 py-2 text-sm font-bold text-black hover:bg-[#FF8533] transition-colors"
          >
            이벤트 신청 →
          </Link>
        </div>
      </section>

      {/* Stats Counter */}
      <section className="border-y border-white/5 py-12 bg-white/[0.02]">
        <div className="max-w-6xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-8 text-center">
          <Counter value="V3" label="장기기억 시스템" />
          <Counter value="0원" label="월 구독료" />
          <Counter value="100%" label="데이터 소유권" />
          <Counter value="2시간" label="설치부터 가동까지" />
        </div>
      </section>

      {/* Pain Point */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-4xl mx-auto">
          <FadeIn>
            <div className="text-center mb-16">
              <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-2">The Problem</p>
              <h2 className="text-3xl md:text-4xl font-bold">직원 한 명 뽑기, 너무 힘드시죠?</h2>
            </div>
          </FadeIn>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-16">
            {[
              '단순 반복 업무 시키려고 월 250만 원 주는 건 너무 아까워요.',
              '회계 장부나 고객 DB를 챗GPT에 올리자니 정보 유출이 겁납니다.',
              '외주 개발자에게 자동화 봇 하나 맡기면 500만 원 부르고 3주 걸려요.',
              '좋다는 AI 툴은 많은데, 막상 내 업무에 적용하려면 너무 복잡해요.',
            ].map((pain, i) => (
              <FadeIn key={pain} delay={i * 0.1}>
                <GlowCard>
                  <p className="text-gray-300 leading-relaxed font-medium">{pain}</p>
                </GlowCard>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* Use Cases Grid */}
      <section className="py-24 px-4 md:px-6 bg-white/[0.02]">
        <div className="max-w-6xl mx-auto">
          <FadeIn>
            <SectionHeading subtitle="프리미엄 오픈클로로 대체할 수 있는 직무들">당신의 AI 직원이 할 수 있는 일</SectionHeading>
          </FadeIn>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12">
            {[
              { title: '회계/장부 자동화', desc: '은행/카드사 내역을 자동으로 긁어와 엑셀 장부를 정리합니다. 경리 직원의 4시간을 3초로 단축합니다.', tag: '경리 대체' },
              { title: '쇼핑몰/웹사이트 운영', desc: '상품 등록, 상세페이지 초안 작성, CS 답변 초안 작성까지. 혼자서 쇼핑몰 3개를 운영할 수 있습니다.', tag: '운영팀 대체' },
              { title: '뉴스/트렌드 리서치', desc: '매일 아침 업계 뉴스, 경쟁사 동향, 트위터 여론을 요약해서 텔레그램으로 보고합니다.', tag: '리서처 대체' },
              { title: '크립토/주식 트레이딩', desc: '24시간 시세를 감시하고, 원하는 조건이 오면 즉시 알림을 보내거나 자동 매매합니다.', tag: '트레이더 대체' },
              { title: '온체인 고래 추적', desc: '특정 지갑이 움직이면 1초 만에 알람. 남들보다 한 발 빠르게 움직일 수 있습니다.', tag: '알파 헌터' },
              { title: '반복 업무 무한 자동화', desc: '이메일 발송, 데이터 입력, 문서 변환... 귀찮은 모든 일을 AI에게 가르쳐서 위임하세요.', tag: '인턴 대체' },
            ].map((item, i) => (
              <FadeIn key={item.title} delay={i * 0.1}>
                <div className="h-full p-8 border border-white/10 bg-[#0A0A0A] rounded-2xl hover:border-[#FF6B00]/30 transition-all group">
                  <div className="flex justify-between items-start mb-4">
                    <h3 className="text-xl font-bold">{item.title}</h3>
                    <span className="px-3 py-1 rounded-full bg-[#FF6B00]/10 text-[#FF6B00] text-xs font-bold shrink-0 ml-3">{item.tag}</span>
                  </div>
                  <p className="text-sm text-gray-400 leading-relaxed">{item.desc}</p>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* Memory System — Core Differentiator */}
      <section className="py-32 px-4 md:px-6 overflow-hidden relative">
        {/* Background glow */}
        <div className="absolute inset-0">
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-[#FF6B00]/[0.04] rounded-full blur-[120px]" />
        </div>

        <div className="max-w-6xl mx-auto relative z-10">
          <FadeIn>
            <div className="text-center mb-6">
              <p className="text-[#FF6B00] font-bold tracking-[0.2em] uppercase text-xs mb-4">V3 Memory System</p>
              <h2 className="text-4xl md:text-6xl font-bold leading-tight">
                3개월 전에 지나가듯 한 말도
                <br />
                <span className="bg-gradient-to-r from-[#FF6B00] to-[#FF3D00] bg-clip-text text-transparent">전부 기억합니다.</span>
              </h2>
            </div>
          </FadeIn>

          <FadeIn delay={0.2}>
            <p className="text-center text-gray-500 text-lg max-w-xl mx-auto mb-20">
              일반 설치는 금방 까먹습니다. 프리미엄 오픈클로는 다릅니다.
            </p>
          </FadeIn>

          {/* Chat Comparison — Side by Side */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 lg:gap-8 mb-20">
            {/* Left: Generic AI */}
            <FadeIn delay={0.3}>
              <div className="rounded-2xl border border-white/10 bg-[#0A0A0A] overflow-hidden h-full">
                <div className="px-6 py-4 border-b border-white/5 flex items-center gap-3">
                  <div className="w-3 h-3 rounded-full bg-red-500/60" />
                  <span className="text-sm text-gray-500 font-medium">일반 AI</span>
                </div>
                <div className="p-6 space-y-4">
                  <div className="flex justify-end">
                    <div className="bg-white/10 rounded-2xl rounded-br-md px-4 py-2.5 max-w-[80%]">
                      <p className="text-sm text-gray-300">저번에 말한 거래처 리스트 정리해줘</p>
                    </div>
                  </div>
                  <div className="flex justify-start">
                    <div className="bg-white/5 border border-white/10 rounded-2xl rounded-bl-md px-4 py-2.5 max-w-[80%]">
                      <p className="text-sm text-gray-400">죄송합니다, 이전 대화 내용을 확인할 수 없습니다. 거래처 리스트를 다시 알려주시겠어요?</p>
                    </div>
                  </div>
                  <div className="flex justify-end">
                    <div className="bg-white/10 rounded-2xl rounded-br-md px-4 py-2.5 max-w-[80%]">
                      <p className="text-sm text-gray-300">아니 지난달에 다 말했잖아...</p>
                    </div>
                  </div>
                  <div className="flex justify-start">
                    <div className="bg-white/5 border border-white/10 rounded-2xl rounded-bl-md px-4 py-2.5 max-w-[80%]">
                      <p className="text-sm text-gray-400">이전 세션의 데이터에는 접근할 수 없습니다. 다시 입력해 주시면 정리해 드리겠습니다 🙏</p>
                    </div>
                  </div>
                  <div className="text-center pt-2">
                    <p className="text-xs text-red-400/80 font-medium">❌ 매번 처음부터 다시 설명해야 합니다</p>
                  </div>
                </div>
              </div>
            </FadeIn>

            {/* Right: ClawNode */}
            <FadeIn delay={0.5}>
              <div className="rounded-2xl border border-[#FF6B00]/30 bg-[#0A0A0A] overflow-hidden h-full shadow-[0_0_60px_rgba(255,107,0,0.06)]">
                <div className="px-6 py-4 border-b border-[#FF6B00]/10 flex items-center gap-3">
                  <div className="w-3 h-3 rounded-full bg-[#FF6B00]" />
                  <span className="text-sm text-[#FF6B00] font-medium">프리미엄 오픈클로</span>
                  <span className="ml-auto text-[10px] text-[#FF6B00]/60 font-mono">V3 MEMORY ACTIVE</span>
                </div>
                <div className="p-6 space-y-4">
                  <div className="flex justify-end">
                    <div className="bg-[#FF6B00]/10 rounded-2xl rounded-br-md px-4 py-2.5 max-w-[80%]">
                      <p className="text-sm text-gray-200">저번에 말한 거래처 리스트 정리해줘</p>
                    </div>
                  </div>
                  <div className="flex justify-start">
                    <div className="bg-white/5 border border-[#FF6B00]/20 rounded-2xl rounded-bl-md px-4 py-2.5 max-w-[85%]">
                      <p className="text-[10px] text-[#FF6B00]/50 font-mono mb-1.5">📎 memory/2025-01-15.md 참조</p>
                      <p className="text-sm text-gray-300">2월 15일에 말씀하신 거래처 5곳 정리했어요. 삼성물산은 단가 재협상 중이라고 하셨고, 한진은 3월 계약 갱신 예정이었죠. 엑셀로 보낼까요?</p>
                    </div>
                  </div>
                  <div className="flex justify-end">
                    <div className="bg-[#FF6B00]/10 rounded-2xl rounded-br-md px-4 py-2.5 max-w-[80%]">
                      <p className="text-sm text-gray-200">한진 계약 조건 뭐였지?</p>
                    </div>
                  </div>
                  <div className="flex justify-start">
                    <div className="bg-white/5 border border-[#FF6B00]/20 rounded-2xl rounded-bl-md px-4 py-2.5 max-w-[85%]">
                      <p className="text-[10px] text-[#FF6B00]/50 font-mono mb-1.5">📎 memory/2025-01-22.md + memory/2025-02-03.md</p>
                      <p className="text-sm text-gray-300">월 500만 원, 분기 정산, 김 과장님 담당이에요. 2월 3일에 단가 5% 인상 요청하셨고 아직 회신 안 온 상태예요.</p>
                    </div>
                  </div>
                  <div className="text-center pt-2">
                    <p className="text-xs text-[#FF6B00] font-medium">✦ 한 번 말하면 영원히 기억합니다</p>
                  </div>
                </div>
              </div>
            </FadeIn>
          </div>

          {/* Memory Architecture Strip */}
          <FadeIn delay={0.6}>
            <div className="relative rounded-2xl border border-white/10 bg-[#0A0A0A] p-8 md:p-12 overflow-hidden">
              <div className="absolute top-0 right-0 w-64 h-64 bg-[#FF6B00]/[0.03] rounded-full blur-[80px]" />
              <div className="relative z-10">
                <div className="flex flex-col md:flex-row items-start md:items-center gap-8 md:gap-16">
                  {/* Flow visualization */}
                  <div className="flex-1 w-full">
                    <h3 className="text-xl font-bold mb-8">어떻게 기억하나요?</h3>
                    <div className="flex flex-col md:flex-row items-start md:items-center gap-4 md:gap-0">
                      {[
                        { step: '대화', desc: '텔레그램으로 평소처럼 대화', icon: '💬' },
                        { step: '추출', desc: '중요 정보를 자동 감지', icon: '⚡' },
                        { step: '벡터화', desc: 'pgvector로 의미 단위 저장', icon: '🧬' },
                        { step: '회상', desc: '"그때 그거" 한마디에 즉시 검색', icon: '🎯' },
                      ].map((item, i) => (
                        <div key={item.step} className="flex items-center gap-4 md:gap-0 flex-1 w-full md:w-auto">
                          <div className="flex flex-col items-center text-center min-w-[80px]">
                            <div className="text-2xl mb-2">{item.icon}</div>
                            <div className="text-sm font-bold text-white">{item.step}</div>
                            <div className="text-[11px] text-gray-500 mt-1 max-w-[120px]">{item.desc}</div>
                          </div>
                          {i < 3 && (
                            <div className="hidden md:block flex-1 h-px bg-gradient-to-r from-[#FF6B00]/30 to-[#FF6B00]/10 mx-2" />
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                {/* Bottom stats */}
                <div className="mt-10 pt-8 border-t border-white/5 grid grid-cols-3 gap-8 text-center">
                  <div>
                    <div className="text-2xl md:text-3xl font-bold text-[#FF6B00]">∞</div>
                    <div className="text-xs text-gray-500 mt-1">기억 용량 제한 없음</div>
                  </div>
                  <div>
                    <div className="text-2xl md:text-3xl font-bold text-white">&lt;1s</div>
                    <div className="text-xs text-gray-500 mt-1">기억 검색 속도</div>
                  </div>
                  <div>
                    <div className="text-2xl md:text-3xl font-bold text-white">100%</div>
                    <div className="text-xs text-gray-500 mt-1">로컬 저장 (외부 전송 없음)</div>
                  </div>
                </div>
              </div>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Why ClawNode (Differentiation) */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-6xl mx-auto">
          <SectionHeading subtitle="왜 15만 원짜리 설치 대행보다 10배 비쌀까요?">단순 설치가 아닙니다. '두뇌 이식'입니다.</SectionHeading>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mt-12">
            {[ 
              { num: '01', title: '경력직 뇌구조 탑재', desc: '깡통 오픈클로가 아닙니다. 수천 시간 검증된 업무 루틴(AGENTS)과 페르소나(SOUL)를 심어드립니다. 처음부터 일 잘하는 경력직처럼 행동합니다.' },
              { num: '02', title: '완벽한 V3 기억장치', desc: '일반 설치는 대화를 금방 까먹습니다. 프리미엄 오픈클로는 엔터프라이즈급 벡터 DB를 구축해, 3개월 전 지나가듯 말한 지시사항도 완벽하게 기억합니다.' },
              { num: '03', title: '설치 당일, 맞춤 봇 완성', desc: '설치만 하고 떠나지 않습니다. 고객님이 가장 필요한 자동화 봇 하나를 그 자리에서 뚝딱 만들어 드립니다. 설치 당일부터 본전을 뽑으세요.' },
            ].map((item, i) => (
              <FadeIn key={item.num} delay={i * 0.15}>
                <div className="relative p-8 border border-white/10 bg-[#0A0A0A] rounded-2xl overflow-hidden group hover:border-[#FF6B00]/30 transition-all h-full">
                  <div className="absolute -right-4 -top-4 text-9xl font-bold text-white/[0.03] group-hover:text-[#FF6B00]/10 transition-colors select-none">
                    {item.num}
                  </div>
                  <div className="relative z-10">
                    <div className="text-[#FF6B00] font-bold text-lg mb-4">Point {item.num}</div>
                    <h3 className="text-2xl font-bold mb-4">{item.title}</h3>
                    <p className="text-gray-400 leading-relaxed">{item.desc}</p>
                  </div>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>



      {/* Pricing Two-Tier */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-6xl mx-auto">
           <FadeIn>
             <SectionHeading subtitle="나에게 맞는 패키지 선택">Pricing Plans</SectionHeading>
           </FadeIn>

           <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mt-12 max-w-4xl mx-auto">
             <FadeIn delay={0}>
               <div className="p-8 rounded-3xl border border-white/10 bg-[#0A0A0A] hover:border-[#FF6B00]/20 transition-colors relative flex flex-col h-full group">
                 <div className="absolute top-0 right-0 bg-white/10 text-white text-xs font-bold px-3 py-1 rounded-bl-xl rounded-tr-2xl">
                   QUICK START
                 </div>
                 <div className="mb-6">
                   <h3 className="text-xl font-bold text-white">Basic Remote</h3>
                   <div className="text-4xl font-bold mt-4 mb-2">30만 원</div>
                   <p className="text-sm text-gray-400">VAT 별도 · 기존 PC 보유자용 · Mac/Windows</p>
                 </div>
                 <ul className="space-y-4 mb-8 flex-1">
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 원격 오픈클로 설치 + 세팅</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> SOUL/AGENTS 페르소나 구성</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 텔레그램 봇 연동</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 1주일 사후 지원</li>
                   <li className="flex gap-3 text-sm text-gray-500"><span className="text-gray-600">–</span> 기기 미포함 (기존 PC 사용)</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> V3 장기기억 시스템 구축</li>
                 </ul>
                 <Link href="/reserve" className="block w-full text-center py-4 rounded-xl border border-[#FF6B00]/30 hover:bg-[#FF6B00]/10 text-[#FF6B00] font-bold transition-colors">원격 설치 예약하기</Link>
               </div>
             </FadeIn>

             <FadeIn delay={0.2}>
               <div className="p-8 rounded-3xl border border-[#FF6B00] bg-[#FF6B00]/5 relative flex flex-col h-full shadow-[0_0_30px_rgba(255,107,0,0.1)]">
                 <div className="absolute top-0 right-0 bg-[#FF6B00] text-black text-xs font-bold px-3 py-1 rounded-bl-xl rounded-tr-2xl">
                   BEST CHOICE
                 </div>
                 <div className="mb-6">
                   <h3 className="text-xl font-bold text-[#FF6B00]">All-in-One Premium</h3>
                   <div className="flex items-baseline gap-3 mt-4 mb-2">
                     <div className="text-4xl font-bold text-white">220만 원</div>
                     <div className="text-xl text-gray-500 line-through">300만 원</div>
                   </div>
                   <p className="text-sm text-gray-400">VAT 포함 · 기기값 포함</p>
                 </div>
                 <ul className="space-y-4 mb-8 flex-1">
                   <li className="flex gap-3 text-sm text-white font-bold"><span className="text-[#FF6B00]">✓</span> Apple Mac Mini M4 (신품) 포함</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 서울/경기 방문 설치 (투명한 언박싱)</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 1:1 현장 활용 강의 (2시간)</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 맞춤형 자동화 봇 1개 즉석 제작</li>
                   <li className="flex gap-3 text-sm text-white font-bold"><span className="text-[#FF6B00]">✓</span> V3 장기기억 시스템 구축 (pgvector)</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 무상 A/S 지원</li>
                 </ul>
                 <CTAButton href="/reserve">올인원 패키지 예약하기</CTAButton>
               </div>
             </FadeIn>
           </div>
        </div>
      </section>

      {/* Hardware Teaser */}
      <section className="py-24 px-4 md:px-6 bg-white/[0.02]">
        <div className="max-w-4xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
           <div className="relative aspect-[4/3] rounded-2xl overflow-hidden grayscale hover:grayscale-0 transition-all duration-500">
             <Image src="/images/mac-mini-hero.png" alt="Mac Mini" fill className="object-cover" />
           </div>
           <div>
             <h3 className="text-2xl font-bold mb-4">하드웨어는 거들 뿐.</h3>
             <p className="text-gray-400 leading-relaxed mb-6">
               Apple Mac Mini M4. 작지만 강력합니다.
               팬리스 무소음 설계로 침실에 둬도 모릅니다.
               전기세는 전구 하나 수준입니다.
             </p>
             <Link href="/product" className="text-[#FF6B00] hover:underline font-medium">하드웨어 스펙 자세히 보기 →</Link>
           </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-24 px-4 md:px-6 text-center relative overflow-hidden">
        <div className="absolute inset-0 z-0 opacity-20">
          <Image src="/images/hero-bg.png" alt="" fill className="object-cover" />
        </div>
        <div className="relative z-10 max-w-2xl mx-auto">
          <FadeIn>
            <h2 className="text-3xl md:text-5xl font-bold mb-6">
              당신의 24시간 무급 직원,
              <br />
              <span className="text-[#FF6B00]">오늘 고용하세요.</span>
            </h2>
            <p className="text-gray-400 mb-8">선착순 한정. <span className="text-gray-300">정가 300만 원 →</span> <span className="text-[#FF6B00] font-bold">런칭 특가 220만 원</span></p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
              <CTAButton href="/reserve">지금 예약하기 (220만 원) →</CTAButton>
              <a
                href="tel:010-6662-4995"
                className="inline-flex items-center gap-2 px-8 py-4 rounded-xl border border-white/20 hover:bg-white/5 text-white font-bold transition-colors"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" /></svg>
                전화 상담하기
              </a>
            </div>
            <p className="text-gray-500 text-sm mt-4">궁금한 점이 있으시면 편하게 전화주세요 — 010-6662-4995</p>
          </FadeIn>
        </div>
      </section>

      {/* 플로팅 전화 버튼 */}
      <a
        href="tel:010-6662-4995"
        className="fixed bottom-6 right-6 z-50 flex items-center gap-2 bg-[#FF6B00] hover:bg-[#FF8533] text-white px-5 py-3 rounded-full shadow-lg shadow-[#FF6B00]/30 transition-all hover:scale-105"
        aria-label="전화 상담"
      >
        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" /></svg>
        <span className="hidden sm:inline font-bold">전화 상담</span>
      </a>
    </main>
  )
}
