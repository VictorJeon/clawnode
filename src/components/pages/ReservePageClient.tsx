'use client'

import Link from 'next/link'
import { useState } from 'react'
import FadeIn from '@/components/FadeIn'
import { trackKakaoChat, trackReserveSubmit } from '@/lib/analytics'

export default function ReservePageClient() {
  const [form, setForm] = useState({
    package: '',
    name: '',
    phone: '',
    telegram: '',
    region: '',
    experience: '',
    message: '',
  })
  const [status, setStatus] = useState<'idle' | 'sending' | 'success' | 'error'>('idle')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setStatus('sending')

    try {
      const res = await fetch('/api/reserve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      })

      if (res.ok) {
        trackReserveSubmit(form.package)
        setStatus('success')
      } else {
        setStatus('error')
      }
    } catch {
      setStatus('error')
    }
  }

  if (status === 'success') {
    return (
      <main className="min-h-screen flex items-center justify-center px-4 md:px-6">
        <FadeIn>
          <div className="text-center max-w-lg">
            <div className="text-6xl mb-6">🎉</div>
            <h1 className="text-3xl md:text-4xl font-bold mb-4">예약 신청 완료!</h1>
            <p className="text-gray-400 leading-relaxed mb-8">
              확인 후 24시간 이내에 연락드리겠습니다.
              <br />
              텔레그램 또는 전화로 설치 일정을 조율할 예정입니다.
            </p>
            <Link href="/" className="text-[#FF6B00] font-medium hover:underline">← 홈으로 돌아가기</Link>
          </div>
        </FadeIn>
      </main>
    )
  }

  return (
    <main className="py-24 px-4 md:px-6">
      <div className="max-w-2xl mx-auto">
        <FadeIn>
          <div className="text-center mb-12">
            <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-2">Reserve</p>
            <h1 className="text-3xl md:text-5xl font-bold mb-4">프리미엄 오픈클로 예약 신청</h1>
            <p className="text-gray-400">아래 폼을 작성해 주세요.</p>
          </div>
        </FadeIn>

        <FadeIn delay={0.1}>
          {/* 카카오톡 상담 배너 */}
          <div className="mb-8 p-5 rounded-2xl border border-yellow-400/30 bg-yellow-400/5 flex flex-col sm:flex-row items-center gap-4">
            <div className="flex-1 text-center sm:text-left">
              <p className="text-sm font-bold text-white mb-1">아직 고민 중이신가요?</p>
              <p className="text-xs text-gray-400">카카오톡으로 편하게 질문하시면 바로 답변 드립니다.</p>
            </div>
            <a
              href="http://pf.kakao.com/_kBxdZX/chat"
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => trackKakaoChat('reserve_banner')}
              className="shrink-0 flex items-center gap-2 bg-yellow-400 text-black font-bold px-5 py-3 rounded-xl hover:bg-yellow-300 transition-colors text-sm whitespace-nowrap"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 3C6.477 3 2 6.477 2 10.5c0 2.524 1.41 4.75 3.563 6.13L4.5 21l4.688-2.406A11.2 11.2 0 0 0 12 18.984c5.523 0 10-3.477 10-7.484C22 6.477 17.523 3 12 3z"/>
              </svg>
              카카오톡 상담하기
            </a>
          </div>
        </FadeIn>

        <FadeIn delay={0.15}>
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Package Selection */}
            <div>
              <label className="block text-sm font-medium mb-3">패키지 선택 <span className="text-red-400">*</span></label>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <label className={`flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-colors ${form.package === 'basic' ? 'border-[#FF6B00] bg-[#FF6B00]/5' : 'border-white/10 bg-[#0A0A0A] hover:border-white/20'}`}>
                  <input
                    type="radio"
                    name="package"
                    value="basic"
                    required
                    checked={form.package === 'basic'}
                    onChange={(e) => setForm({ ...form, package: e.target.value })}
                    className="mt-1 accent-[#FF6B00]"
                  />
                  <div>
                    <div className="font-bold text-sm">Basic Remote — 30만 원</div>
                    <div className="text-xs text-gray-500 mt-1">기존 PC에 원격 설치</div>
                  </div>
                </label>
                <label className={`flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-colors ${form.package === 'premium' ? 'border-[#FF6B00] bg-[#FF6B00]/5' : 'border-white/10 bg-[#0A0A0A] hover:border-white/20'}`}>
                  <input
                    type="radio"
                    name="package"
                    value="premium"
                    checked={form.package === 'premium'}
                    onChange={(e) => setForm({ ...form, package: e.target.value })}
                    className="mt-1 accent-[#FF6B00]"
                  />
                  <div>
                    <div className="font-bold text-sm">All-in-One — <span className="text-[#FF6B00]">160만 원</span></div>
                    <div className="text-xs text-gray-500 mt-1">장비 가격 별도 · 방문 설치 · 2시간 1:1 교육</div>
                  </div>
                </label>
              </div>
            </div>

            {/* Name */}
            <div>
              <label htmlFor="name" className="block text-sm font-medium mb-2">이름 / 닉네임 <span className="text-red-400">*</span></label>
              <input id="name" type="text" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="홍길동" className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-[#FF6B00]/50 transition-colors" />
            </div>

            {/* Phone */}
            <div>
              <label htmlFor="phone" className="block text-sm font-medium mb-2">연락처 <span className="text-red-400">*</span></label>
              <input id="phone" type="tel" required value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="010-1234-5678" className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-[#FF6B00]/50 transition-colors" />
            </div>

            {/* Telegram */}
            <div>
              <label htmlFor="telegram" className="block text-sm font-medium mb-2">텔레그램 ID</label>
              <input id="telegram" type="text" value={form.telegram} onChange={(e) => setForm({ ...form, telegram: e.target.value })} placeholder="@your_telegram_id" className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-[#FF6B00]/50 transition-colors" />
            </div>

            {/* Region (only show for premium) */}
            {form.package === 'premium' && (
              <div>
                <label htmlFor="region" className="block text-sm font-medium mb-2">지역 <span className="text-red-400">*</span></label>
                <select id="region" required value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-[#FF6B00]/50 transition-colors">
                  <option value="" className="text-gray-600">선택해 주세요</option>
                  <option value="서울">서울</option>
                  <option value="경기">경기</option>
                  <option value="인천">인천</option>
                  <option value="그 외 수도권">그 외 수도권</option>
                  <option value="지방 (출장비 별도)">지방 (출장비 별도)</option>
                </select>
              </div>
            )}

            {/* Message */}
            <div>
              <label htmlFor="message" className="block text-sm font-medium mb-2">추가 요청사항</label>
              <textarea id="message" rows={4} value={form.message} onChange={(e) => setForm({ ...form, message: e.target.value })} placeholder="특별히 관심 있는 자동화 기능, 현재 사용 중인 장비, 원하는 워크플로우 등" className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-[#FF6B00]/50 transition-colors resize-none" />
            </div>

            {/* Submit */}
            <button type="submit" disabled={status === 'sending'} className="w-full bg-[#FF6B00] text-black font-bold py-4 rounded-xl hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed text-lg">
              {status === 'sending' ? '전송 중...' : '예약 신청하기'}
            </button>

            {status === 'error' && (
              <p className="text-red-400 text-sm text-center">전송에 실패했습니다. 텔레그램 @buidlermason으로 직접 연락해 주세요.</p>
            )}

            <p className="text-xs text-gray-600 text-center">
              * 예약 신청 후 24시간 이내 확인 연락을 드립니다.
              <br />
              * 결제는 설치 일정 확정 후 진행됩니다.
            </p>
          </form>
        </FadeIn>
      </div>
    </main>
  )
}
