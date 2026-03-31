import Image from 'next/image'
import type { Metadata } from 'next'
import StructuredData from '@/components/StructuredData'
import SectionHeading from '@/components/SectionHeading'
import CTAButton from '@/components/CTAButton'
import {
  breadcrumbJsonLd,
  createPageMetadata,
  serviceJsonLd,
  webPageJsonLd,
} from '@/lib/seo'

const processTitle = '설치 과정'
const processDescription =
  '프리미엄 오픈클로(ClawNode) AI 에이전트 설치 과정을 안내합니다. 예약 → 환경 점검 → 현장 세팅 → 교육까지, 비개발자도 하루 만에 AI 자동화 환경을 갖출 수 있습니다.'

export const metadata: Metadata = createPageMetadata({
  title: processTitle,
  description: processDescription,
  path: '/process',
  keywords: ['AI 설치 과정', '원격 설치', '방문 설치', 'ClawNode 온보딩'],
})

const structuredData = [
  webPageJsonLd({
    title: `ClawNode | ${processTitle}`,
    description: processDescription,
    path: '/process',
  }),
  breadcrumbJsonLd([
    { name: '홈', path: '/' },
    { name: processTitle, path: '/process' },
  ]),
  serviceJsonLd({
    name: 'ClawNode 설치 및 온보딩 절차',
    description: processDescription,
    path: '/process',
    serviceType: 'AI 자동화 설치 온보딩',
  }),
]

export default function ProcessPage() {
  return (
    <>
      <StructuredData data={structuredData} />
      <main>
        <section className="py-24 px-4 md:px-6 text-center">
          <div className="max-w-3xl mx-auto">
            <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-4">Installation Protocol</p>
            <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-6">
              예약부터 가동까지
              <br />
              <span className="text-[#FF6B00]">단 2시간.</span>
            </h1>
            <p className="text-xl text-gray-400">복잡한 건 저희가 다 합니다. 고객님은 장비와 목표만 준비해 주세요.</p>
          </div>
        </section>

        <section className="py-12 px-4 md:px-6">
          <div className="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-8">
            <div className="border border-[#FF6B00]/30 bg-[#FF6B00]/5 rounded-2xl p-8">
              <div className="text-[#FF6B00] font-bold text-sm mb-2">올인원 패키지</div>
              <h3 className="text-xl font-bold mb-4">방문 설치</h3>
              <p className="text-sm text-gray-400 leading-relaxed">
                서울/경기 직접 방문. 고객님이 이미 보유한 장비 기준으로도 가능하고, 장비가 없으면 ClawNode를 통한 구매 연계 후 현장 세팅도 가능합니다. OpenClaw와 V3 메모리, 원격 접속, 보안 설정까지 현장에서 마무리합니다.
              </p>
            </div>
            <div className="border border-white/10 bg-white/[0.02] rounded-2xl p-8">
              <div className="text-gray-400 font-bold text-sm mb-2">베이직 패키지 (30만 원)</div>
              <h3 className="text-xl font-bold mb-4">원격 설치</h3>
              <p className="text-sm text-gray-400 leading-relaxed">
                기존에 보유하신 Mac/Windows/Linux PC에 화상 통화(Zoom)와 원격 접속으로 OpenClaw를 세팅해 드립니다. 30분~1시간이면 완료됩니다.
              </p>
            </div>
          </div>
        </section>

        <section className="py-12 px-4 md:px-6">
          <div className="max-w-4xl mx-auto relative aspect-[21/9] rounded-2xl overflow-hidden border border-white/10">
            <Image src="/images/hero-bg.png" alt="Installation overview" fill className="object-cover" />
            <div className="absolute inset-0 bg-gradient-to-t from-[#050505] via-[#050505]/40 to-transparent" />
            <div className="absolute bottom-8 left-8 right-8">
              <p className="text-[#FF6B00] font-bold text-sm">STEP 1</p>
              <p className="text-2xl font-bold">고객 환경과 목표부터 확인합니다.</p>
              <p className="text-sm text-gray-300 mt-2">장비, 계정, 보안, 원하는 자동화를 먼저 맞추고 그 위에 세팅합니다.</p>
            </div>
          </div>
        </section>

        <section className="py-24 px-4 md:px-6">
          <div className="max-w-3xl mx-auto">
            <SectionHeading subtitle="올인원 패키지 · 2시간 현장 설치 프로토콜">방문 설치 타임라인</SectionHeading>

            <div className="relative">
              <div className="absolute left-6 top-0 bottom-0 w-0.5 bg-gradient-to-b from-[#FF6B00] to-white/10" />

              {[
                { time: '00:00', title: '환경 점검', desc: '현재 장비, 계정, 네트워크, 사용 목적을 빠르게 점검합니다. 설치 범위와 우선순위를 현장에서 바로 정리합니다.', highlight: true },
                { time: '00:10', title: 'OS / 권한 설정', desc: '필수 권한, 계정, 보안 저장소, 원격 접속 경로를 정리합니다.' },
                { time: '00:25', title: '핵심 설치', desc: 'OpenClaw, Tailscale, V3 메모리 DB, 텔레그램 연동을 한 번에 세팅합니다.' },
                { time: '00:40', title: '현장 교육 시작', desc: '설치가 돌아가는 동안 AI에게 명령 내리는 법과 운영 루틴을 가르쳐 드립니다.', highlight: true },
                { time: '01:10', title: '에이전트 라이브 시연', desc: '실제로 AI가 작업하는 모습을 보여드리고 텔레그램 알림까지 확인합니다.' },
                { time: '01:25', title: '맞춤 봇 제작', desc: '고객님이 가장 먼저 필요로 하는 자동화 봇 1개를 바로 만듭니다.' },
                { time: '01:45', title: '보안 / 운영 마무리', desc: '원격 A/S를 위한 안전한 접속 경로와 기본 운영 수칙을 정리합니다.' },
                { time: '02:00', title: '핸드오버', desc: '전용 지원 채널 안내와 다음 액션을 정리하고 운영을 시작합니다.', highlight: true },
              ].map((step, i) => (
                <div key={i} className="relative flex gap-4 md:gap-8 mb-10 md:mb-12 last:mb-0">
                  <div className={`w-10 h-10 md:w-12 md:h-12 rounded-full flex items-center justify-center font-bold text-sm shrink-0 z-10 ${step.highlight ? 'bg-[#FF6B00] text-black' : 'bg-[#1a1a1a] border border-[#FF6B00] text-[#FF6B00]'}`}>
                    {i + 1}
                  </div>
                  <div className="pt-1 min-w-0">
                    <div className="text-xs text-[#FF6B00] font-mono mb-1">{step.time}</div>
                    <h3 className="text-lg font-bold mb-1">{step.title}</h3>
                    <p className="text-sm text-gray-400 leading-relaxed">{step.desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="py-24 px-4 md:px-6 bg-white/[0.02]">
          <div className="max-w-3xl mx-auto">
            <SectionHeading subtitle="베이직 패키지 · 원격 설치 프로토콜">원격 설치 타임라인</SectionHeading>

            <div className="relative">
              <div className="absolute left-6 top-0 bottom-0 w-0.5 bg-gradient-to-b from-gray-500 to-white/10" />

              {[
                { time: '00:00', title: '화상 통화 연결', desc: 'Zoom 또는 Google Meet으로 연결합니다. 고객님의 화면을 공유받아 진행합니다.' },
                { time: '00:05', title: '원격 접속 & 스크립트 실행', desc: 'AnyDesk 또는 Tailscale로 원격 접속 후 설치 스크립트를 실행합니다. Mac/Windows/Linux 모두 지원합니다.' },
                { time: '00:15', title: '기본 활용법 가이드', desc: '설치가 진행되는 동안 OpenClaw 기본 사용법, 텔레그램 연동, 명령 내리는 법을 가르쳐 드립니다.' },
                { time: '00:30~01:00', title: '완료 & 지원 채널 입장', desc: '설치 완료를 확인하고 전용 텔레그램 지원 채널에 초대합니다.' },
              ].map((step, i) => (
                <div key={i} className="relative flex gap-4 md:gap-8 mb-10 md:mb-12 last:mb-0">
                  <div className="w-10 h-10 md:w-12 md:h-12 rounded-full flex items-center justify-center font-bold text-sm shrink-0 z-10 bg-[#1a1a1a] border border-gray-500 text-gray-400">
                    {i + 1}
                  </div>
                  <div className="pt-1 min-w-0">
                    <div className="text-xs text-gray-500 font-mono mb-1">{step.time}</div>
                    <h3 className="text-lg font-bold mb-1">{step.title}</h3>
                    <p className="text-sm text-gray-400 leading-relaxed">{step.desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="py-24 px-4 md:px-6">
          <div className="max-w-3xl mx-auto">
            <SectionHeading subtitle="설치 후에도 혼자가 아닙니다.">A/S & 지원</SectionHeading>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="p-6 bg-[#0A0A0A] border border-white/10 rounded-xl">
                <h4 className="font-bold mb-2">전용 지원 채널</h4>
                <p className="text-sm text-gray-400">전용 텔레그램 채널에서 1:1로 기술 지원을 받으실 수 있습니다. 에이전트 커스텀, 에러 해결, 사용법 질문 모두 가능합니다.</p>
              </div>
              <div className="p-6 bg-[#0A0A0A] border border-white/10 rounded-xl">
                <h4 className="font-bold mb-2">원격 A/S</h4>
                <p className="text-sm text-gray-400">문제 발생 시 Tailscale Node Sharing으로 일시적 접근 권한을 주시면, 원격으로 신속하게 해결해 드립니다.</p>
              </div>
              <div className="p-6 bg-[#0A0A0A] border border-white/10 rounded-xl">
                <h4 className="font-bold mb-2">장비 사전 점검</h4>
                <p className="text-sm text-gray-400">장비가 아직 없거나 사양이 애매하면, 사용 목적에 맞는 권장 사양과 운영 구성을 먼저 잡아드립니다.</p>
              </div>
              <div className="p-6 bg-[#0A0A0A] border border-white/10 rounded-xl">
                <h4 className="font-bold mb-2">유료 유지보수 (선택)</h4>
                <p className="text-sm text-gray-400">무상 지원 이후에도 지속적인 업데이트와 우선 지원이 필요하시면 월 유지보수 플랜을 선택하실 수 있습니다.</p>
              </div>
            </div>
          </div>
        </section>

        <section className="py-16 px-4 md:px-6 text-center border-t border-white/5">
          <h2 className="text-2xl md:text-3xl font-bold mb-4">2시간 후, 당신의 AI 운영 환경이 돌아가기 시작합니다.</h2>
          <p className="text-gray-400 mb-6">방문 설치 또는 원격 설치. 선택은 당신의 몫입니다.</p>
          <CTAButton href="/reserve">지금 예약하기</CTAButton>
        </section>
      </main>
    </>
  )
}
