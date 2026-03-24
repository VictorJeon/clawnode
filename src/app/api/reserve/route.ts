import { NextResponse } from 'next/server'

export async function POST(request: Request) {
  try {
    const body = await request.json()
    const { name, phone, telegram, region, experience, message, package: pkg } = body

    if (!name || !phone) {
      return NextResponse.json({ error: '필수 항목을 입력해 주세요.' }, { status: 400 })
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
전송 시각: ${new Date().toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' })}`

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
