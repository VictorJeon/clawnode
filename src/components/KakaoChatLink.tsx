'use client'

import { trackKakaoChat } from '@/lib/analytics'

interface KakaoChatLinkProps {
  location: string
  className?: string
  children: React.ReactNode
}

export default function KakaoChatLink({ location, className, children }: KakaoChatLinkProps) {
  return (
    <a
      href="http://pf.kakao.com/_kBxdZX/chat"
      target="_blank"
      rel="noopener noreferrer"
      onClick={() => trackKakaoChat(location)}
      className={className}
    >
      {children}
    </a>
  )
}
