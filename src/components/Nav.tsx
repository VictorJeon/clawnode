'use client'

import Link from 'next/link'
import { useState } from 'react'

const NAV_LINKS = [
  { href: '/', label: '홈' },
  { href: '/product', label: '제품' },
  { href: '/security', label: '보안' },
  { href: '/process', label: '설치' },
  { href: '/pricing', label: '가격' },
]

export default function Nav() {
  const [open, setOpen] = useState(false)

  return (
    <nav className="sticky top-0 z-50 backdrop-blur-xl bg-[#050505]/80 border-b border-white/5">
      <div className="max-w-6xl mx-auto flex items-center justify-between px-6 py-4">
        <Link href="/" className="flex items-center gap-2 text-[#FF6B00] font-bold text-xl tracking-tight">
          <img src="/images/clawnode-logo.png" alt="ClawNode 로고" className="w-7 h-7" />
          ClawNode
        </Link>

        {/* Desktop */}
        <ul className="hidden md:flex items-center gap-8">
          {NAV_LINKS.map((link) => (
            <li key={link.href}>
              <Link
                href={link.href}
                className="text-sm text-gray-400 hover:text-white transition-colors"
              >
                {link.label}
              </Link>
            </li>
          ))}
          <li>
            <Link
              href="/reserve"
              className="bg-[#FF6B00] text-black text-sm font-bold px-5 py-2 rounded-md hover:opacity-90 transition-opacity"
            >
              예약하기
            </Link>
          </li>
        </ul>

        {/* Mobile hamburger */}
        <button
          onClick={() => setOpen(!open)}
          className="md:hidden text-white p-2"
          aria-label="메뉴"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            {open ? (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            ) : (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            )}
          </svg>
        </button>
      </div>

      {/* Mobile Menu */}
      {open && (
        <div className="md:hidden border-t border-white/5 bg-[#050505]/95 backdrop-blur-xl">
          <ul className="flex flex-col px-6 py-4 gap-4">
            {NAV_LINKS.map((link) => (
              <li key={link.href}>
                <Link
                  href={link.href}
                  onClick={() => setOpen(false)}
                  className="text-gray-300 hover:text-white transition-colors block py-1"
                >
                  {link.label}
                </Link>
              </li>
            ))}
            <li className="pt-2 border-t border-white/10">
              <Link
                href="/reserve"
                className="bg-[#FF6B00] text-black text-sm font-bold px-5 py-3 rounded-md block text-center"
              >
                예약하기
              </Link>
            </li>
          </ul>
        </div>
      )}
    </nav>
  )
}
