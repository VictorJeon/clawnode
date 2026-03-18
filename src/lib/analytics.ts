/**
 * GA4 custom event helpers.
 *
 * Usage:
 *   import { trackEvent } from '@/lib/analytics'
 *   trackEvent('reserve_submit', { package: 'premium' })
 */

type GtagEvent = {
  action: string
  category?: string
  label?: string
  value?: number
  [key: string]: string | number | undefined
}

/**
 * Send a custom event to GA4 via the global gtag function.
 * Safely no-ops when gtag is not loaded (e.g. missing GA_ID).
 */
export function trackEvent(
  action: string,
  params?: Omit<GtagEvent, 'action'>,
) {
  if (typeof window === 'undefined') return
  const gtag = (window as unknown as { gtag?: (...args: unknown[]) => void }).gtag
  if (!gtag) return
  gtag('event', action, params)
}

/* ── Conversion events ──────────────────────────────────── */

/** /reserve 폼 제출 완료 */
export function trackReserveSubmit(pkg: string) {
  trackEvent('reserve_submit', {
    event_category: 'conversion',
    event_label: pkg,
  })
}

/** 카카오톡 상담하기 클릭 */
export function trackKakaoChat(location: string) {
  trackEvent('kakao_chat_click', {
    event_category: 'conversion',
    event_label: location,
  })
}
