'use client'

import { useState } from 'react'
import FadeIn from '@/components/FadeIn'

export default function ReservePage() {
  const [form, setForm] = useState({
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
      <main className="min-h-screen flex items-center justify-center px-6">
        <FadeIn>
          <div className="text-center max-w-lg">
            <div className="text-6xl mb-6">🎉</div>
            <h1 className="text-3xl md:text-4xl font-bold mb-4">예약 신청 완료!</h1>
            <p className="text-gray-400 leading-relaxed mb-8">
              확인 후 24시간 이내에 연락드리겠습니다.
              <br />
              텔레그램 또는 전화로 설치 일정을 조율할 예정입니다.
            </p>
            <a href="/" className="text-[#FF6B00] font-medium hover:underline">← 홈으로 돌아가기</a>
          </div>
        </FadeIn>
      </main>
    )
  }

  return (
    <main className="py-24 px-6">
      <div className="max-w-2xl mx-auto">
        <FadeIn>
          <div className="text-center mb-12">
            <p className="text-[#FF6B00] font-bold tracking-wider uppercase text-sm mb-2">Reserve</p>
            <h1 className="text-3xl md:text-5xl font-bold mb-4">ClawNode 예약 신청</h1>
            <p className="text-gray-400">선착순 5대 한정. 아래 폼을 작성해 주세요.</p>
          </div>
        </FadeIn>

        <FadeIn delay={0.1}>
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Name */}
            <div>
              <label htmlFor="name" className="block text-sm font-medium mb-2">이름 / 닉네임 <span className="text-red-400">*</span></label>
              <input
                id="name"
                type="text"
                required
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="홍길동"
                className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-[#FF6B00]/50 transition-colors"
              />
            </div>

            {/* Phone */}
            <div>
              <label htmlFor="phone" className="block text-sm font-medium mb-2">연락처 <span className="text-red-400">*</span></label>
              <input
                id="phone"
                type="tel"
                required
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
                placeholder="010-1234-5678"
                className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-[#FF6B00]/50 transition-colors"
              />
            </div>

            {/* Telegram */}
            <div>
              <label htmlFor="telegram" className="block text-sm font-medium mb-2">텔레그램 ID</label>
              <input
                id="telegram"
                type="text"
                value={form.telegram}
                onChange={(e) => setForm({ ...form, telegram: e.target.value })}
                placeholder="@your_telegram_id"
                className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-[#FF6B00]/50 transition-colors"
              />
            </div>

            {/* Region */}
            <div>
              <label htmlFor="region" className="block text-sm font-medium mb-2">지역 <span className="text-red-400">*</span></label>
              <select
                id="region"
                required
                value={form.region}
                onChange={(e) => setForm({ ...form, region: e.target.value })}
                className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-[#FF6B00]/50 transition-colors"
              >
                <option value="" className="text-gray-600">선택해 주세요</option>
                <option value="서울">서울</option>
                <option value="경기">경기</option>
                <option value="인천">인천</option>
                <option value="그 외 수도권">그 외 수도권</option>
                <option value="지방 (출장비 별도)">지방 (출장비 별도)</option>
                <option value="원격 설치 희망">원격 설치 희망</option>
              </select>
            </div>

            {/* Crypto Experience */}
            <div>
              <label htmlFor="experience" className="block text-sm font-medium mb-2">크립토 경험</label>
              <select
                id="experience"
                value={form.experience}
                onChange={(e) => setForm({ ...form, experience: e.target.value })}
                className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-[#FF6B00]/50 transition-colors"
              >
                <option value="">선택해 주세요</option>
                <option value="1년 미만">1년 미만</option>
                <option value="1~3년">1~3년</option>
                <option value="3년 이상">3년 이상</option>
                <option value="전업 트레이더">전업 트레이더</option>
              </select>
            </div>

            {/* Message */}
            <div>
              <label htmlFor="message" className="block text-sm font-medium mb-2">추가 요청사항</label>
              <textarea
                id="message"
                rows={4}
                value={form.message}
                onChange={(e) => setForm({ ...form, message: e.target.value })}
                placeholder="특별히 관심 있는 기능, M4 Pro 업그레이드 희망 여부 등"
                className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-[#FF6B00]/50 transition-colors resize-none"
              />
            </div>

            {/* Submit */}
            <button
              type="submit"
              disabled={status === 'sending'}
              className="w-full bg-[#FF6B00] text-black font-bold py-4 rounded-xl hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed text-lg"
            >
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
