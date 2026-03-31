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

const productTitle = '제품 소개'
const productDescription =
  'ClawNode — 프리미엄 오픈클로(OpenClaw) AI 에이전트를 고객님의 장비에 구축해 드립니다. V3 장기기억 시스템, 업무 자동화 루틴, 텔레그램 AI 비서 세팅까지 전부 포함됩니다.'

export const metadata: Metadata = createPageMetadata({
  title: productTitle,
  description: productDescription,
  path: '/product',
  keywords: [
    'AI 에이전트 구축',
    '오픈클로 설치',
    'AI 비서 세팅',
    'V3 장기기억',
    '로컬 AI 서버',
    '업무 자동화 설치',
  ],
})

const structuredData = [
  webPageJsonLd({
    title: `ClawNode | ${productTitle}`,
    description: productDescription,
    path: '/product',
  }),
  breadcrumbJsonLd([
    { name: '홈', path: '/' },
    { name: productTitle, path: '/product' },
  ]),
  serviceJsonLd({
    name: 'ClawNode 제품 구성',
    description: productDescription,
    path: '/product',
    serviceType: 'AI 자동화 환경 구축',
  }),
]

export default function ProductPage() {
  return (
    <>
      <StructuredData data={structuredData} />
      <main>
        <section className="py-24 px-4 md:px-6 text-center">
          <div className="max-w-3xl mx-auto">
            <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-4">What You Get</p>
            <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-6">
              현장 세팅 + AI 두뇌 + 교육
              <br />
              <span className="text-[#FF6B00]">올인원.</span>
            </h1>
            <p className="text-xl text-gray-400">
              깡통 서버가 아닙니다. ClawNode는 처음부터 일 잘하는 경력직 AI를 심어드립니다.
              <br />
              <span className="text-white font-medium">코딩을 몰라도 바로 실무에 쓸 수 있게 다 세팅해 드립니다.</span>
            </p>
          </div>
        </section>

        <section className="py-12 px-4 md:px-6">
          <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-6">
            {[
              { num: '01', title: '설치 환경', sub: '장비 · 권한 · 보안 점검', desc: '고객 장비 상태와 계정, 원격 접속, 보안 경로를 실제 사용 환경 기준으로 맞춥니다.' },
              { num: '02', title: 'AI 두뇌', sub: 'OpenClaw + V3 Memory', desc: '수천 시간 검증된 업무 루틴(AGENTS)과 장기 기억(V3 DB)을 탑재합니다.' },
              { num: '03', title: '실전 교육', sub: '2시간 1:1 과외', desc: 'AI에게 명령 내리는 법, 운영 루틴, 첫 자동화 워크플로우까지 직접 익히게 해드립니다.' },
            ].map((item) => (
              <div key={item.num} className="relative p-8 border border-white/10 bg-[#0A0A0A] rounded-2xl overflow-hidden group hover:border-[#FF6B00]/30 transition-all">
                <div className="absolute -right-2 -top-2 text-8xl font-bold text-white/[0.03] select-none">{item.num}</div>
                <div className="relative z-10">
                  <h3 className="text-xl font-bold mb-1">{item.title}</h3>
                  <p className="text-[#FF6B00] text-sm font-medium mb-3">{item.sub}</p>
                  <p className="text-sm text-gray-400 leading-relaxed">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="py-24 px-4 md:px-6 bg-white/[0.02]">
          <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-12 items-start">
            <div>
              <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-2">On-Site Setup Scope</p>
              <h2 className="text-3xl font-bold mb-6">올인원에서 실제로 해드리는 것</h2>
              <p className="text-gray-400 leading-relaxed mb-8">
                장비 판매가 아니라, 고객님의 실제 업무 환경에 OpenClaw를 얹는 구축 서비스입니다.
                무엇을 자동화할지부터 운영 루틴까지 현장에서 바로 잡습니다.
              </p>
              <div className="grid grid-cols-1 gap-4">
                {[
                  '고객 장비 상태 점검 및 권장 사양 확인',
                  'OpenClaw + V3 메모리 DB 풀세팅',
                  '텔레그램/알림/원격 접속 경로 연결',
                  '권한·보안·운영 안정화 설정',
                  '2시간 1:1 활용 강의',
                  '맞춤 자동화 봇 1개 즉석 제작',
                ].map((item) => (
                  <div key={item} className="flex items-start gap-3 p-4 border border-white/10 rounded-xl bg-[#0A0A0A]">
                    <span className="text-[#FF6B00] mt-0.5">✓</span>
                    <p className="text-sm text-gray-300">{item}</p>
                  </div>
                ))}
              </div>
            </div>

            <div className="border border-white/10 rounded-2xl overflow-hidden bg-[#0A0A0A]">
              <div className="px-6 py-4 border-b border-white/10 bg-white/[0.03]">
                <p className="text-sm font-bold text-white">현장 세팅 체크리스트</p>
                <p className="text-xs text-gray-500 mt-1">설치 당일 기준으로 같이 맞추는 항목들입니다.</p>
              </div>
              <div className="p-6 overflow-x-auto">
                <table className="w-full text-sm">
                  <tbody className="divide-y divide-white/10">
                    {[
                      ['장비', '고객 보유 장비 또는 별도 준비 장비'],
                      ['운영체제', 'macOS 권장 / Windows / Linux 가능'],
                      ['원격 접속', 'Tailscale 기반 안전한 접근 경로 설정'],
                      ['알림 채널', '텔레그램 기본 연결'],
                      ['메모리', 'V3 장기기억 시스템 구축'],
                      ['보안', '권한·키 저장소·포트 최소화 점검'],
                      ['교육', '2시간 1:1 실전 운영 가이드'],
                      ['산출물', '맞춤 자동화 봇 1개 + 운영 루틴'],
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

        <section className="py-24 px-4 md:px-6">
          <div className="max-w-5xl mx-auto">
            <div className="text-center mb-16">
              <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-2">AI Brain</p>
              <h2 className="text-3xl md:text-4xl font-bold mb-4">OpenClaw — 당신의 AI 운영체제</h2>
              <p className="text-gray-400 max-w-2xl mx-auto">
                OpenClaw는 오픈소스 AI 에이전트 프레임워크입니다. ChatGPT처럼 대화만 하는 게 아니라,
                <span className="text-white font-medium"> 실제로 컴퓨터를 조작하고, 웹을 탐색하고, 파일을 만들고, API를 호출합니다.</span>
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div className="space-y-1">
                <h3 className="font-bold text-lg mb-4 text-white">OpenClaw가 할 수 있는 일</h3>
                {[
                  '웹 브라우저를 직접 조작해서 데이터를 수집합니다',
                  '파일을 읽고, 쓰고, 엑셀/PDF를 자동 생성합니다',
                  '텔레그램/슬랙/디스코드로 보고하고 명령을 받습니다',
                  '외부 API(거래소, 뉴스, 블로그 등)를 자유롭게 호출합니다',
                  '여러 AI 에이전트가 협업해서 복잡한 작업을 수행합니다',
                  '크론 스케줄러로 정해진 시간에 자동 실행합니다',
                ].map((text) => (
                  <div key={text} className="flex items-start gap-3 py-3 border-b border-white/5 last:border-0">
                    <span className="text-[#FF6B00] mt-0.5 text-sm">✓</span>
                    <p className="text-sm text-gray-300">{text}</p>
                  </div>
                ))}
              </div>

              <div className="bg-[#050505] border border-white/10 rounded-2xl overflow-hidden">
                <div className="px-4 py-3 border-b border-white/10 flex items-center gap-2 bg-white/5">
                  <div className="flex gap-1.5">
                    <div className="w-3 h-3 rounded-full bg-red-500/80" />
                    <div className="w-3 h-3 rounded-full bg-yellow-500/80" />
                    <div className="w-3 h-3 rounded-full bg-green-500/80" />
                  </div>
                  <span className="text-xs text-gray-600 font-mono ml-2">openclaw — zsh</span>
                </div>
                <div className="p-5 font-mono text-xs leading-relaxed space-y-3">
                  <div>
                    <span className="text-green-400">❯</span> <span className="text-gray-400">매일 아침 8시에 크립토 뉴스 요약해서 텔레그램으로 보내줘</span>
                  </div>
                  <div className="text-gray-500">
                    ✓ 크론 작업 생성: 매일 08:00 KST<br />
                    ✓ 뉴스 소스 설정: CoinDesk, The Block, CT 주요 계정<br />
                    ✓ 텔레그램 채널 연결 완료<br />
                    <span className="text-[#FF6B00]">→ 내일 아침부터 브리핑이 시작됩니다.</span>
                  </div>
                  <div className="border-t border-white/5 pt-3">
                    <span className="text-green-400">❯</span> <span className="text-gray-400">네이버 부동산에서 강남구 신규 매물 매일 수집해줘</span>
                  </div>
                  <div className="text-gray-500">
                    ✓ 브라우저 자동화 스크립트 생성<br />
                    ✓ 강남구 아파트 신규 매물 필터 설정<br />
                    ✓ 엑셀 자동 저장 + 텔레그램 알림 연결<br />
                    <span className="text-[#FF6B00]">→ 매일 09:00에 수집 결과를 보내드립니다.</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="py-24 px-4 md:px-6 bg-white/[0.02]">
          <div className="max-w-4xl mx-auto">
            <div className="text-center mb-12">
              <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-2">Long-Term Memory</p>
              <h2 className="text-3xl md:text-4xl font-bold mb-4">V3 기억 시스템 — 까먹지 않는 AI</h2>
              <p className="text-gray-400">일반 AI는 대화를 끊으면 모든 걸 까먹습니다. 프리미엄 오픈클로의 V3 메모리 시스템은 다릅니다.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {[
                { title: '영구 기억', desc: '3개월 전에 지나가듯 말한 “나 ETH 평단 350만 원이야”를 기억합니다. 매번 다시 설명할 필요 없습니다.' },
                { title: '벡터 검색', desc: '엔터프라이즈급 pgvector DB. “지난달에 말한 마케팅 전략 뭐였지?” 물으면 즉시 찾아줍니다.' },
                { title: '자동 증류', desc: '매일의 대화를 자동으로 요약하고 핵심 기억으로 압축합니다. 기억 관리를 사람이 할 필요가 없습니다.' },
              ].map((item) => (
                <div key={item.title} className="p-6 border border-white/10 bg-[#0A0A0A] rounded-xl">
                  <h4 className="font-bold mb-3">{item.title}</h4>
                  <p className="text-sm text-gray-400 leading-relaxed">{item.desc}</p>
                </div>
              ))}
            </div>

            <div className="mt-8 p-6 border border-white/10 bg-[#0A0A0A] rounded-xl text-center">
              <p className="text-sm text-gray-400">
                <span className="text-white font-bold">일반 설치 대행 vs 프리미엄 오픈클로</span> — 가장 큰 차이가 바로 이 기억 시스템입니다.
                <br />일반 설치에는 이 기능이 없습니다. ClawNode는 DB 구축부터 데이터 마이그레이션까지 전부 해드립니다.
              </p>
            </div>
          </div>
        </section>

        <section className="py-24 px-4 md:px-6">
          <div className="max-w-5xl mx-auto">
            <SectionHeading subtitle="크립토 트레이더를 위한 활용 사례">크립토 자동화</SectionHeading>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12">
              <div className="border border-white/10 bg-[#0A0A0A] rounded-2xl overflow-hidden hover:border-[#FF6B00]/30 transition-all">
                <div className="p-6 border-b border-white/5">
                  <h3 className="font-bold text-lg mb-1">Alpha Watcher</h3>
                  <p className="text-[#FF6B00] text-xs mb-3">온체인 고래 감시</p>
                  <p className="text-sm text-gray-400 leading-relaxed">고래 지갑의 대량 이체, DEX 스왑, 신규 포지션을 24시간 감시하고 즉시 알림.</p>
                </div>
                <div className="bg-[#0E1621] p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-[10px] font-bold text-[#FF6B00]">Alpha Watcher</span>
                    <span className="text-[10px] text-gray-600 ml-auto">03:42</span>
                  </div>
                  <div className="text-xs text-gray-300 leading-relaxed">
                    <span className="font-bold text-yellow-400">⚠ 고래 이동 감지</span><br />
                    <span className="font-mono text-[10px] text-gray-500">0x7a3b...f2e1</span> → Binance<br />
                    <span className="text-white font-bold">1,200 ETH ($4.2M)</span><br />
                    <span className="text-gray-500 text-[10px] mt-1 block">72시간 내 3번째 대량 이체</span>
                  </div>
                </div>
              </div>

              <div className="border border-white/10 bg-[#0A0A0A] rounded-2xl overflow-hidden hover:border-blue-500/30 transition-all">
                <div className="p-6 border-b border-white/5">
                  <h3 className="font-bold text-lg mb-1">News Breaker</h3>
                  <p className="text-blue-400 text-xs mb-3">24시간 뉴스 브리핑</p>
                  <p className="text-sm text-gray-400 leading-relaxed">CT, 디스코드, 뉴스를 모니터링. 노이즈를 걸러내고 핵심만 매일 보고.</p>
                </div>
                <div className="bg-[#0E1621] p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-[10px] font-bold text-blue-400">News Breaker</span>
                    <span className="text-[10px] text-gray-600 ml-auto">08:00</span>
                  </div>
                  <div className="text-xs text-gray-300 leading-relaxed">
                    <span className="font-bold text-blue-400">모닝 브리핑</span><br />
                    1. SEC, ETH ETF 옵션 승인<br />
                    2. Solana TVL $15B 최고치<br />
                    3. 업비트 상장 후보 3종<br />
                    <span className="text-gray-500 text-[10px] mt-1 block">42개 소스 분석 완료</span>
                  </div>
                </div>
              </div>

              <div className="border border-white/10 bg-[#0A0A0A] rounded-2xl overflow-hidden hover:border-green-500/30 transition-all">
                <div className="p-6 border-b border-white/5">
                  <h3 className="font-bold text-lg mb-1">Portfolio Tracker</h3>
                  <p className="text-green-400 text-xs mb-3">자산 통합 관리</p>
                  <p className="text-sm text-gray-400 leading-relaxed">거래소 + 온체인 지갑 통합. 실시간 P&L, 비중 분석, 리밸런싱 알림.</p>
                </div>
                <div className="bg-[#0E1621] p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-[10px] font-bold text-green-400">Portfolio Tracker</span>
                    <span className="text-[10px] text-gray-600 ml-auto">09:00</span>
                  </div>
                  <div className="text-xs text-gray-300 leading-relaxed">
                    <span className="font-bold text-green-400">일일 리포트</span><br />
                    총 자산: <span className="text-white font-bold">₩142,350,000</span> <span className="text-green-400">(+2.3%)</span><br />
                    <span className="text-green-400">▲ BTC +4.1%</span> · <span className="text-red-400">▼ SOL -2.5%</span><br />
                    <span className="text-yellow-400 text-[10px] mt-1 block">SOL 비중 22% → 리밸런싱 검토</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="py-24 px-4 md:px-6 bg-white/[0.02]">
          <div className="max-w-5xl mx-auto">
            <SectionHeading subtitle="크립토만이 아닙니다">범용 비즈니스 자동화</SectionHeading>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-12">
              {[
                { title: '회계/장부 자동화', desc: '은행/카드사 내역을 긁어와 엑셀 장부를 자동 정리. 경리 직원의 4시간을 3초로.', tag: '경리 대체' },
                { title: '쇼핑몰 운영', desc: '상품 등록, 상세페이지 초안, CS 답변 초안 작성. 혼자서 쇼핑몰 3개를 운영할 수 있습니다.', tag: '운영팀 대체' },
                { title: '뉴스/트렌드 리서치', desc: '매일 아침 업계 뉴스, 경쟁사 동향, SNS 여론을 요약해서 보고합니다.', tag: '리서처 대체' },
                { title: '부동산 매물 수집', desc: '네이버 부동산 신규 매물 자동 수집 → 블로그 홍보글 자동 작성 → 자동 발행.', tag: '중개보조 대체' },
                { title: '이메일/CS 자동화', desc: '고객 문의 자동 분류, 답변 초안 작성, 발송까지. 하루 100건 CS도 혼자 처리.', tag: 'CS팀 대체' },
                { title: '문서/보고서 생성', desc: '데이터를 넣으면 보고서, 제안서, 회의록을 자동으로 만들어 줍니다.', tag: '인턴 대체' },
              ].map((item) => (
                <div key={item.title} className="flex gap-4 p-6 border border-white/10 bg-[#0A0A0A] rounded-xl hover:border-[#FF6B00]/20 transition-colors">
                  <div>
                    <div className="flex items-center gap-3 mb-2">
                      <h4 className="font-bold">{item.title}</h4>
                      <span className="px-2 py-0.5 rounded-full bg-[#FF6B00]/10 text-[#FF6B00] text-xs font-bold">{item.tag}</span>
                    </div>
                    <p className="text-sm text-gray-400 leading-relaxed">{item.desc}</p>
                  </div>
                </div>
              ))}
            </div>

            <div className="text-center mt-10">
              <p className="text-sm text-gray-500">위 사례는 일부입니다. 텔레그램으로 “이거 자동화 돼?” 물어보세요. 대부분 됩니다.</p>
            </div>
          </div>
        </section>

        <section className="py-24 px-4 md:px-6">
          <div className="max-w-4xl mx-auto">
            <SectionHeading subtitle="설치만 하고 떠나는 대행과는 다릅니다">ClawNode가 다른 이유</SectionHeading>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-12">
              {[
                { title: '100% 로컬 실행', desc: 'API 키와 데이터가 클라우드에 올라가지 않습니다. 고객님의 기기 안에서만 동작하도록 구성합니다.' },
                { title: '경력직 두뇌 이식', desc: '깡통 오픈클로가 아닙니다. 수천 시간 검증된 업무 루틴과 페르소나를 심어드립니다.' },
                { title: '무한 커스터마이징', desc: '에이전트 추가, 봇 수정, 새로운 자동화 — 모두 텔레그램 대화로 요청하면 됩니다.' },
                { title: '월 구독료 0원', desc: '한 번 세팅하면 장기적으로 운영비는 API 실비 중심입니다. 별도 SaaS 구독에 덜 묶입니다.' },
              ].map((item) => (
                <div key={item.title} className="p-6 border border-white/10 rounded-xl hover:border-white/20 transition-colors">
                  <h4 className="font-bold mb-2">{item.title}</h4>
                  <p className="text-sm text-gray-400 leading-relaxed">{item.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="py-24 px-4 md:px-6 text-center">
          <div className="max-w-2xl mx-auto">
            <h2 className="text-3xl md:text-4xl font-bold mb-4">직접 확인하고 싶으신가요?</h2>
            <p className="text-gray-400 mb-8">원격 설치부터 올인원 현장 세팅까지. 나에게 맞는 플랜을 골라보세요.</p>
            <CTAButton href="/reserve">내 자리 확보하기</CTAButton>
          </div>
        </section>
      </main>
    </>
  )
}
