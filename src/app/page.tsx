'use client'

import Image from 'next/image'
import CTAButton from '@/components/CTAButton'
import FadeIn from '@/components/FadeIn'
import Counter from '@/components/Counter'
import GlowCard from '@/components/GlowCard'
import SectionHeading from '@/components/SectionHeading'
import ChatBot from '@/components/ChatBot'

export default function HomePage() {
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
                나만의 전용 AI 서버, <span className="text-white font-bold">ClawNode</span>.
              </p>
              <p className="text-base text-gray-500 mb-10 leading-relaxed">
                코딩을 아무것도 몰라도 괜찮습니다. 다 셋팅해 드립니다.<br />
                AI가 경리, 리서치, 데이터 수집을 대신합니다.
              </p>
            </FadeIn>

            <FadeIn delay={0.6}>
              <div className="flex flex-col sm:flex-row items-center lg:items-start justify-center lg:justify-start gap-4">
                <CTAButton href="/reserve">선착순 5대 — 내 자리 확보하기</CTAButton>
                <a href="/product" className="px-8 py-3 rounded-md border border-white/10 hover:bg-white/5 text-white font-medium transition-all">
                  제품 상세 보기
                </a>
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

      {/* Stats Counter */}
      <section className="border-y border-white/5 py-12 bg-white/[0.02]">
        <div className="max-w-6xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-8 text-center">
          <Counter value="220만" label="평생 고용 비용" />
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
            <SectionHeading subtitle="ClawNode 하나로 대체할 수 있는 직무들">당신의 AI 직원이 할 수 있는 일</SectionHeading>
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

      {/* Cost Savings */}
      <section className="py-24 px-4 md:px-6 overflow-hidden relative">
        <div className="absolute inset-0 bg-[#FF6B00]/5 skew-y-3 transform scale-110" />
        <div className="max-w-5xl mx-auto relative z-10">
           <FadeIn>
             <div className="text-center mb-16">
               <h2 className="text-3xl md:text-5xl font-bold mb-6">1년이면 <span className="text-[#FF6B00]">2,780만 원</span>이 절약됩니다.</h2>
               <p className="text-gray-400">초기 도입비 한 번으로 평생 무료. 월급도, 퇴직금도, 4대 보험도 없습니다.</p>
             </div>
           </FadeIn>

           <div className="grid grid-cols-1 md:grid-cols-3 gap-8 text-center">
             <FadeIn delay={0}>
               <div className="p-8 rounded-2xl bg-white/5 border border-white/10 opacity-50">
                 <p className="text-sm text-gray-400 mb-2">신입 인턴 고용 (연봉)</p>
                 <p className="text-3xl font-bold text-gray-500 line-through decoration-red-500/50">30,000,000원</p>
               </div>
             </FadeIn>
             <FadeIn delay={0.1}>
               <div className="p-8 rounded-2xl bg-white/5 border border-white/10 opacity-50">
                 <p className="text-sm text-gray-400 mb-2">단순 경리 직원 (연봉)</p>
                 <p className="text-3xl font-bold text-gray-500 line-through decoration-red-500/50">25,000,000원</p>
               </div>
             </FadeIn>
             <FadeIn delay={0.2}>
               <div className="p-8 rounded-2xl bg-[#FF6B00]/10 border border-[#FF6B00] shadow-[0_0_50px_rgba(255,107,0,0.1)] transform md:-translate-y-4">
                 <p className="text-sm text-[#FF6B00] font-bold mb-2">ClawNode 올인원 (평생)</p>
                 <div className="text-xl text-gray-500 line-through mb-1">3,000,000원</div>
                 <div className="text-4xl md:text-5xl font-bold text-white flex justify-center items-center gap-1">
                   <Counter value="2,200,000" label="" />원
                 </div>
                 <p className="text-xs text-[#FF6B00] mt-2">런칭 특가 · 기기값 포함 · 추가 비용 0원</p>
               </div>
             </FadeIn>
           </div>
        </div>
      </section>

      {/* Why ClawNode (Differentiation) */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-6xl mx-auto">
          <SectionHeading subtitle="왜 15만 원짜리 설치 대행보다 10배 비쌀까요?">단순 설치가 아닙니다. '두뇌 이식'입니다.</SectionHeading>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mt-12">
            {[ 
              { num: '01', title: '경력직 뇌구조 탑재', desc: '깡통 오픈클로가 아닙니다. 수천 시간 검증된 업무 루틴(AGENTS)과 페르소나(SOUL)를 심어드립니다. 처음부터 일 잘하는 경력직처럼 행동합니다.' },
              { num: '02', title: '완벽한 V3 기억장치', desc: '일반 설치는 대화를 금방 까먹습니다. ClawNode는 엔터프라이즈급 벡터 DB를 구축해, 3개월 전 지나가듯 말한 지시사항도 완벽하게 기억합니다.' },
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
               <div className="p-8 rounded-3xl border border-white/10 bg-[#0A0A0A] hover:border-white/20 transition-colors relative flex flex-col h-full">
                 <div className="mb-6">
                   <h3 className="text-xl font-bold text-gray-300">Basic Remote</h3>
                   <div className="text-4xl font-bold mt-4 mb-2">30만 원</div>
                   <p className="text-sm text-gray-500">VAT 별도 · 기존 PC 보유자용</p>
                 </div>
                 <ul className="space-y-4 mb-8 flex-1">
                   <li className="flex gap-3 text-sm text-gray-300"><span className="text-[#FF6B00]">✓</span> 원격 오픈클로 설치 지원</li>
                   <li className="flex gap-3 text-sm text-gray-300"><span className="text-[#FF6B00]">✓</span> AI 연산 최적화 세팅</li>
                   <li className="flex gap-3 text-sm text-gray-300"><span className="text-[#FF6B00]">✓</span> 기본 기능 활용 원격 가이드</li>
                   <li className="flex gap-3 text-sm text-gray-300"><span className="text-[#FF6B00]">✓</span> 텔레그램 지원 채널</li>
                 </ul>
                 <a href="/reserve" className="block w-full text-center py-4 rounded-xl border border-white/20 hover:bg-white/5 text-white font-bold transition-colors">원격 설치 예약하기</a>
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
                   <p className="text-sm text-gray-400">VAT 포함 · 기기값 포함 · <span className="text-[#FF6B00] font-bold">런칭 할인가</span></p>
                 </div>
                 <ul className="space-y-4 mb-8 flex-1">
                   <li className="flex gap-3 text-sm text-white font-bold"><span className="text-[#FF6B00]">✓</span> Apple Mac Mini M4 (신품) 포함</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 서울/경기 방문 설치 (투명한 언박싱)</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 1:1 현장 활용 강의 (2시간)</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> 맞춤형 자동화 봇 1개 즉석 제작</li>
                   <li className="flex gap-3 text-sm text-white"><span className="text-[#FF6B00]">✓</span> V3 장기기억 시스템(DB) 구축</li>
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
             <a href="/product" className="text-[#FF6B00] hover:underline font-medium">하드웨어 스펙 자세히 보기 →</a>
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
            <p className="text-gray-400 mb-8">선착순 5대 한정. <span className="text-gray-300">정가 300만 원 →</span> <span className="text-[#FF6B00] font-bold">런칭 특가 220만 원</span></p>
            <CTAButton href="/reserve">지금 예약하기 (220만 원) →</CTAButton>
          </FadeIn>
        </div>
      </section>
    </main>
  )
}
