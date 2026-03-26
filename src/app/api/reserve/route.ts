import { NextResponse } from 'next/server'

// --- Rate Limiting (IP 기반, 메모리) ---
const rateMap = new Map<string, { count: number; resetAt: number }>()
const RATE_WINDOW_MS = 10 * 60 * 1000 // 10분
const RATE_LIMIT = 3 // 10분에 3건

function isRateLimited(ip: string): boolean {
  const now = Date.now()
  const entry = rateMap.get(ip)
  if (!entry || now > entry.resetAt) {
    rateMap.set(ip, { count: 1, resetAt: now + RATE_WINDOW_MS })
    return false
  }
  entry.count++
  return entry.count > RATE_LIMIT
}

// --- Input Sanitization ---
function sanitize(input: string | undefined): string {
  if (!input) return ''
  return input
    .replace(/[<>'"]/g, '') // XSS 기본 방어
    .replace(/javascript:/gi, '')
    .replace(/on\w+\s*=/gi, '')
    .trim()
    .slice(0, 200) // 최대 200자
}

function isSpamName(name: string): boolean {
  const spamPatterns = [
    /^(spam|test|loadtest|sectest|hack|admin|root|bot)/i,
    /^.{0,1}$/, // 1글자 이하
    /<[^>]*>/,  // HTML 태그
    /script/i,
    /alert\s*\(/i,
    /onerror/i,
  ]
  return spamPatterns.some(p => p.test(name))
}

function isValidPhone(phone: string): boolean {
  // 한국 전화번호: 010-XXXX-XXXX 등
  const cleaned = phone.replace(/[-\s]/g, '')
  return /^01[0-9]{8,9}$/.test(cleaned)
}

export async function POST(request: Request) {
  try {
    // Rate limit by IP
    const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
      || request.headers.get('x-real-ip')
      || 'unknown'
    
    if (isRateLimited(ip)) {
      return NextResponse.json(
        { error: '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.' },
        { status: 429 }
      )
    }

    const body = await request.json()
    const name = sanitize(body.name)
    const phone = sanitize(body.phone)
    const telegram = sanitize(body.telegram)
    const region = sanitize(body.region)
    const experience = sanitize(body.experience)
    const message = sanitize(body.message)?.slice(0, 500)
    const pkg = body.package === 'premium' ? 'premium' : 'basic'

    // Validation
    if (!name || !phone) {
      return NextResponse.json({ error: '필수 항목을 입력해 주세요.' }, { status: 400 })
    }

    if (isSpamName(name)) {
      // 스팸으로 판단되면 성공인 척 → 공격자에게 정보 안 줌
      return NextResponse.json({ ok: true })
    }

    if (!isValidPhone(phone)) {
      return NextResponse.json({ error: '올바른 연락처를 입력해 주세요.' }, { status: 400 })
    }

    const emailBody = `🔶 ClawNode 새 예약 신청

━━━━━━━━━━━━━━━━━━━━
패키지: ${pkg === 'premium' ? 'All-in-One Premium (250만 원)' : 'Basic Remote (30만 원)'}
이름: ${name}
연락처: ${phone}
텔레그램: ${telegram || '미입력'}
지역: ${region || '미입력'}
크립토 경험: ${experience || '미입력'}
━━━━━━━━━━━━━━━━━━━━

추가 요청사항:
${message || '없음'}

━━━━━━━━━━━━━━━━━━━━
전송 시각: ${new Date().toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' })}
IP: ${ip}`

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'ClawNode <onboarding@resend.dev>',
        to: 'dyddnjs0007@gmail.com',
        subject: `[ClawNode 예약] ${name}님 - ${pkg === 'premium' ? '올인원' : '베이직'}${region ? ' - ' + region : ''}`,
        text: emailBody,
      }),
    })

    if (!res.ok) {
      const err = await res.text()
      console.error('Resend error:', err)
      return NextResponse.json({ error: '이메일 전송 실패' }, { status: 500 })
    }

    return NextResponse.json({ ok: true })
  } catch (error) {
    console.error('Email send failed:', error)
    return NextResponse.json({ error: '이메일 전송 실패' }, { status: 500 })
  }
}
