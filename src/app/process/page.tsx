import Image from 'next/image'
import SectionHeading from '@/components/SectionHeading'
import CTAButton from '@/components/CTAButton'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: '설치 과정',
  description: '예약부터 가동까지 단 2시간. 미개봉 언박싱 → 원클릭 설치 → 현장 교육 → 핸드오버. 복잡한 건 저희가 다 합니다.',
  openGraph: {
    title: 'ClawNode 설치 — 예약부터 가동까지 2시간',
    description: '고객님 눈앞에서 미개봉 씰을 뜯고, 2시간 만에 AI 노드를 완성합니다.',
    images: [{ url: 'https://website-v2-eight-beta.vercel.app/images/og-image.png' }],
  },
}

export default function ProcessPage() {
  return (
    <main>
      {/* Hero */}
      <section className="py-24 px-4 md:px-6 text-center">
        <div className="max-w-3xl mx-auto">
          <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-4">Installation Protocol</p>
          <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-6">
            예약부터 가동까지
            <br />
            <span className="text-[#FF6B00]">단 2시간.</span>
          </h1>
          <p className="text-xl text-gray-400">
            복잡한 건 저희가 다 합니다. 고객님은 커피만 준비해 주세요.
          </p>
        </div>
      </section>

      {/* Unboxing Image */}
      <section className="py-12 px-4 md:px-6">
        <div className="max-w-4xl mx-auto relative aspect-[21/9] rounded-2xl overflow-hidden">
          <Image src="/images/unboxing-v2.png" alt="Unboxing" fill className="object-cover" />
          <div className="absolute inset-0 bg-gradient-to-t from-[#050505] via-transparent to-transparent" />
          <div className="absolute bottom-8 left-8">
            <p className="text-[#FF6B00] font-bold text-sm">STEP 1</p>
            <p className="text-2xl font-bold">고객님 눈앞에서 미개봉 씰을 뜯습니다.</p>
          </div>
        </div>
      </section>

      {/* Timeline */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-3xl mx-auto">
          <SectionHeading subtitle="2시간 현장 설치 프로토콜">타임라인</SectionHeading>

          <div className="relative">
            {/* Vertical Line */}
            <div className="absolute left-6 top-0 bottom-0 w-0.5 bg-gradient-to-b from-[#FF6B00] to-white/10" />

            {[
              {
                time: '00:00',
                title: '언박싱 (Unboxing)',
                desc: '미개봉 Mac Mini를 고객님 앞에서 씰을 뜯습니다. 백도어 의심을 원천 차단합니다.',
                highlight: true,
              },
              {
                time: '00:05',
                title: 'OS 초기 설정',
                desc: '언어, Wi-Fi, Apple ID(고객님 계정)를 설정합니다. M4는 빠르기 때문에 5분이면 충분합니다.',
              },
              {
                time: '00:15',
                title: '뇌 이식 (Installation)',
                desc: 'USB 스크립트 한 줄로 OpenClaw, Tailscale, Docker, 에이전트를 한 번에 설치합니다. 자동으로 진행되므로 기다리기만 하면 됩니다.',
              },
              {
                time: '00:20',
                title: '현장 교육 시작',
                desc: '설치가 백그라운드에서 돌아가는 동안, AI에게 명령 내리는 법을 가르쳐 드립니다. 텔레그램에서 대화하듯 명령하면 됩니다.',
                highlight: true,
              },
              {
                time: '01:00',
                title: '에이전트 라이브 시연',
                desc: 'Alpha Watcher가 실제로 지갑을 감시하는 모습을 보여드립니다. 텔레그램에 알림이 오는 것을 직접 확인합니다.',
              },
              {
                time: '01:20',
                title: '커스터마이징',
                desc: '고객님이 관심 있는 코인, 추적할 지갑 주소, 뉴스 소스를 에이전트에 직접 입력해 봅니다.',
              },
              {
                time: '01:40',
                title: 'Tailscale 보안 마무리',
                desc: '고객님 계정으로 Tailscale을 설정합니다. 이후 A/S가 필요할 때 Node Sharing으로 잠시 문을 열어주시면 됩니다.',
              },
              {
                time: '02:00',
                title: '핸드오버 (Handover)',
                desc: '"이제 이 노드는 고객님 겁니다." 30일간의 전용 기술 지원 채널이 시작됩니다.',
                highlight: true,
              },
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

      {/* After-Service */}
      <section className="py-24 px-4 md:px-6 bg-white/[0.02]">
        <div className="max-w-3xl mx-auto">
          <SectionHeading subtitle="설치 후에도 혼자가 아닙니다.">A/S & 지원</SectionHeading>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="p-6 bg-[#0A0A0A] border border-white/10 rounded-xl">
              <h4 className="font-bold mb-2">📱 30일 전용 채널</h4>
              <p className="text-sm text-gray-400">전용 텔레그램 채널에서 1:1로 기술 지원을 받으실 수 있습니다. 에이전트 커스텀, 에러 해결, 사용법 질문 모두 가능합니다.</p>
            </div>
            <div className="p-6 bg-[#0A0A0A] border border-white/10 rounded-xl">
              <h4 className="font-bold mb-2">🔧 원격 A/S</h4>
              <p className="text-sm text-gray-400">문제 발생 시 Tailscale Node Sharing으로 일시적 접근 권한을 주시면, 원격으로 신속하게 해결해 드립니다. 모니터/키보드 연결 불필요.</p>
            </div>
            <div className="p-6 bg-[#0A0A0A] border border-white/10 rounded-xl">
              <h4 className="font-bold mb-2">🍎 하드웨어 보증</h4>
              <p className="text-sm text-gray-400">애플 정품이므로 1년 무상보증이 적용됩니다. 하드웨어 고장 시 가까운 애플 서비스센터를 이용하시면 됩니다.</p>
            </div>
            <div className="p-6 bg-[#0A0A0A] border border-white/10 rounded-xl">
              <h4 className="font-bold mb-2">🔄 유료 유지보수 (선택)</h4>
              <p className="text-sm text-gray-400">30일 이후에도 지속적인 업데이트와 우선 지원이 필요하시면 월 유지보수 플랜을 선택하실 수 있습니다.</p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-16 px-4 md:px-6 text-center border-t border-white/5">
        <h2 className="text-2xl md:text-3xl font-bold mb-4">2시간 후, 당신의 AI 노드가 깨어납니다.</h2>
        <p className="text-gray-400 mb-6">선착순 5대 한정.</p>
        <CTAButton href="/reserve">지금 예약하기</CTAButton>
      </section>
    </main>
  )
}
