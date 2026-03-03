import Image from 'next/image'
import Link from 'next/link'

export default function Footer() {
  return (
    <footer className="border-t border-white/5 bg-[#030303]">
      <div className="max-w-6xl mx-auto px-6 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10">
          {/* Brand */}
          <div className="md:col-span-2">
            <span className="text-[#FF6B00] font-bold text-xl">ClawNode</span>
            <p className="text-sm text-gray-500 mt-3 max-w-sm leading-relaxed">
              크립토 트레이더를 위한 턴키 AI 노드.
              Mac Mini M4 + AI 에이전트 3종 + 현장 설치 교육.
            </p>
            <div className="flex items-center gap-2 mt-4">
              <Image src="/images/fire-ant-logo.jpg" alt="Fire Ant" width={20} height={20} className="rounded-full" />
              <span className="text-xs text-gray-500">불개미 커뮤니티 추천 제품</span>
            </div>
          </div>

          {/* Links */}
          <div>
            <h4 className="text-sm font-bold text-gray-400 mb-4">제품</h4>
            <ul className="space-y-2">
              {[
                { href: '/product', label: '에이전트 소개' },
                { href: '/security', label: '보안 아키텍처' },
                { href: '/process', label: '설치 과정' },
                { href: '/pricing', label: '가격 및 FAQ' },
              ].map(link => (
                <li key={link.href}>
                  <Link href={link.href} className="text-sm text-gray-500 hover:text-gray-300 transition-colors">
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Contact */}
          <div>
            <h4 className="text-sm font-bold text-gray-400 mb-4">연락처</h4>
            <ul className="space-y-2">
              <li>
                <a href="https://t.me/buidlermason" target="_blank" rel="noopener noreferrer" className="text-sm text-gray-500 hover:text-gray-300 transition-colors">
                  Telegram
                </a>
              </li>
              <li>
                <a href="https://twitter.com/buidlermason" target="_blank" rel="noopener noreferrer" className="text-sm text-gray-500 hover:text-gray-300 transition-colors">
                  Twitter / X
                </a>
              </li>
              <li>
                <a href="mailto:hello@clawnode.io" className="text-sm text-gray-500 hover:text-gray-300 transition-colors">
                  hello@clawnode.io
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-10 pt-6 border-t border-white/5 text-xs text-gray-600">
          © 2026 ClawNode. All rights reserved.
        </div>
      </div>
    </footer>
  )
}
