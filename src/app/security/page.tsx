import SectionHeading from '@/components/SectionHeading'
import CTAButton from '@/components/CTAButton'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: '보안 아키텍처',
  description: '회계 장부, 고객 DB, API 키 — 남의 서버에 맡기고 계시나요? ClawNode는 100% 로컬. Tailscale 암호화 터널 + 로컬 서비스 최소 노출 + macOS Keychain.',
  openGraph: {
    title: 'ClawNode 보안 — Zero Trust Architecture',
    description: '100% 로컬 실행. Tailscale + 로컬 서비스 최소 노출 + Keychain 다층 방어. 데이터가 절대 외부로 나가지 않습니다.',
    images: [{ url: '/images/og-image.png' }],
  },
}

export default function SecurityPage() {
  return (
    <main>
      {/* Hero */}
      <section className="py-24 px-4 md:px-6 text-center">
        <div className="max-w-3xl mx-auto">
          <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-4">Zero Trust Architecture</p>
          <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-6">
            당신의 데이터는
            <br />
            <span className="text-red-500">안전하지 않습니다.</span>
          </h1>
          <p className="text-xl text-gray-400 leading-relaxed">
            회계 장부, 고객 DB, 거래소 API 키, 매매 전략 —
            <br />
            클라우드 AI에 올린 그 데이터, 지금 어디에 저장되어 있는지 알고 계신가요?
          </p>
        </div>
      </section>

      {/* The Argument: 3-way comparison */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-6xl mx-auto">
          <SectionHeading subtitle="세 가지 선택지를 비교해 보세요.">왜 로컬이어야 하는가</SectionHeading>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Cloud */}
            <div className="border border-red-500/30 bg-red-500/5 rounded-2xl p-8">
              <div className="text-red-500 font-bold text-sm mb-4">Cloud SaaS</div>
              <h3 className="text-xl font-bold mb-4">남의 서버에 내 데이터</h3>
              <ul className="space-y-3 text-sm text-gray-400">
                <li>❌ API 키가 제3자 서버에 저장</li>
                <li>❌ 해킹 시 전체 고객 데이터 유출</li>
                <li>❌ 매월 $20~50 구독료 영구 지출</li>
                <li>❌ 서비스 종료 시 데이터 접근 불가</li>
                <li>❌ 서버 위치도 모르는 경우가 대부분</li>
              </ul>
            </div>

            {/* DIY */}
            <div className="border border-yellow-500/30 bg-yellow-500/5 rounded-2xl p-8">
              <div className="text-yellow-500 font-bold text-sm mb-4">DIY (직접 설치)</div>
              <h3 className="text-xl font-bold mb-4">안전하지만 지옥</h3>
              <ul className="space-y-3 text-sm text-gray-400">
                <li>✅ 데이터 주권 확보</li>
                <li>❌ Tailscale, SSH, Ollama, DB 설정... 삽질 무한</li>
                <li>❌ 에러 발생 시 스택오버플로우 순례</li>
                <li>❌ 보안 설정 누락 시 오히려 더 위험</li>
                <li>❌ 주말 이틀 날리고도 미완성</li>
              </ul>
            </div>

            {/* ClawNode */}
            <div className="border border-[#FF6B00]/50 bg-[#FF6B00]/5 rounded-2xl p-8 ring-2 ring-[#FF6B00]/20">
              <div className="text-[#FF6B00] font-bold text-sm mb-4">ClawNode</div>
              <h3 className="text-xl font-bold mb-4">안전하고 쉽다</h3>
              <ul className="space-y-3 text-sm text-gray-400">
                <li>✅ 100% 로컬 — 데이터가 밖으로 안 나감</li>
                <li>✅ Tailscale 암호화 터널 (군사급)</li>
                <li>✅ 로컬 서비스만 열고 외부 포트 최소화</li>
                <li>✅ 눈앞에서 언박싱 (백도어 원천 차단)</li>
                <li>✅ 전문가가 2시간 만에 설치 완료</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Security Architecture Visual */}
      <section className="py-24 px-4 md:px-6 bg-white/[0.02]">
        <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-16 items-center">
          <div>
            <SectionHeading subtitle="ClawNode의 보안 아키텍처">다층 방어 구조</SectionHeading>
            <div className="space-y-6">
              {[
                { icon: '', title: 'Tailscale Mesh VPN', desc: 'WireGuard 기반 암호화 터널. 외부 접근은 Tailscale 경로로만 열고, 공인 포트 노출을 피합니다.' },
                { icon: '', title: '로컬 서비스 최소 노출', desc: 'OpenClaw와 메모리 보조 서비스는 고객 기기에서만 돌리고, 내부 서비스는 가능하면 loopback으로만 바인딩합니다.' },
                { icon: '', title: '인바운드 포트 최소화', desc: '외부에서 들어오는 연결은 꼭 필요한 경우만 허용합니다. 기본값은 닫힘에 가깝게 유지합니다.' },
                { icon: '', title: 'macOS Keychain', desc: 'API 키와 비밀번호는 애플의 하드웨어 암호화 키체인에 저장됩니다.' },
              ].map(item => (
                <div key={item.title} className="flex gap-4">
                  
                  <div>
                    <h4 className="font-bold mb-1">{item.title}</h4>
                    <p className="text-sm text-gray-400">{item.desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
          {/* Security Layers Diagram */}
          <div className="flex items-center justify-center">
            <div className="relative w-80 h-80">
              {/* Outer ring */}
              <div className="absolute inset-0 rounded-full border-2 border-[#FF6B00]/20 flex items-center justify-center">
                <span className="absolute top-2 text-xs text-[#FF6B00]/50 font-mono">TAILSCALE MESH</span>
              </div>
              {/* Middle ring */}
              <div className="absolute inset-8 rounded-full border-2 border-[#FF6B00]/30 flex items-center justify-center">
                <span className="absolute top-2 text-xs text-[#FF6B00]/60 font-mono">FIREWALL</span>
              </div>
              {/* Inner ring */}
              <div className="absolute inset-16 rounded-full border-2 border-[#FF6B00]/40 flex items-center justify-center">
                <span className="absolute top-2 text-xs text-[#FF6B00]/70 font-mono">LOCAL ONLY</span>
              </div>
              {/* Core */}
              <div className="absolute inset-24 rounded-full bg-[#FF6B00]/10 border-2 border-[#FF6B00] flex items-center justify-center">
                <div className="text-center">
                  <span className="text-3xl">🔐</span>
                  <p className="text-xs text-[#FF6B00] font-bold mt-1">KEYCHAIN</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Terminal Demo */}
      <section className="py-24 px-4 md:px-6">
        <div className="max-w-3xl mx-auto">
          <SectionHeading subtitle="실제 보안 로그 예시">실시간 방어 모니터</SectionHeading>
          <div className="bg-[#0A0A0A] border border-white/10 rounded-xl p-6 font-mono text-sm">
            <div className="flex items-center gap-2 mb-4 border-b border-white/10 pb-3">
              <div className="w-3 h-3 rounded-full bg-red-500" />
              <div className="w-3 h-3 rounded-full bg-yellow-500" />
              <div className="w-3 h-3 rounded-full bg-green-500" />
              <span className="ml-2 text-gray-500 text-xs">clawnode-security.log</span>
            </div>
            <div className="space-y-2 text-gray-300">
              <p><span className="text-green-400">[OK]</span> Tailscale tunnel: <span className="text-green-400">CONNECTED</span> (encrypted)</p>
              <p><span className="text-green-400">[OK]</span> Firewall: All inbound ports <span className="text-green-400">BLOCKED</span></p>
              <p><span className="text-green-400">[OK]</span> Memory/API services: <span className="text-green-400">LOOPBACK ONLY</span></p>
              <p><span className="text-yellow-400">[WARN]</span> External SSH attempt from 45.33.xx.xx → <span className="text-red-400">REJECTED</span></p>
              <p><span className="text-green-400">[OK]</span> API keys: Stored in <span className="text-green-400">macOS Keychain</span> (hardware encrypted)</p>
              <p><span className="text-blue-400">[INFO]</span> OpenClaw runtime: <span className="text-green-400">LOCAL MACOS PROCESS</span></p>
              <p><span className="text-green-400">[OK]</span> Allowed remote path: <span className="text-green-400">TAILSCALE ONLY</span></p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-16 px-4 md:px-6 text-center border-t border-white/5">
        <h2 className="text-2xl md:text-3xl font-bold mb-4">보안은 타협할 수 없습니다.</h2>
        <p className="text-gray-400 mb-6">당신의 데이터를 당신 손에 두세요. 원격 설치부터 올인원까지.</p>
        <CTAButton href="/reserve">지금 예약하기</CTAButton>
      </section>
    </main>
  )
}
