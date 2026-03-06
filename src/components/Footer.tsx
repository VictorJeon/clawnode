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
              당신의 24시간 무급 직원.
              Mac Mini M4 + AI 두뇌 + 현장 설치 교육 올인원.
            </p>
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
                <a href="http://pf.kakao.com/_kBxdZX/chat" target="_blank" rel="noopener noreferrer" className="text-sm text-gray-500 hover:text-gray-300 transition-colors flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-yellow-400"></span>
                  카카오톡 채널 상담
                </a>
              </li>
              <li>
                <a href="mailto:help@claw-node.com" className="text-sm text-gray-500 hover:text-gray-300 transition-colors">
                  help@claw-node.com
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
