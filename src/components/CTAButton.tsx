import type { ReactNode } from 'react'

interface CTAButtonProps {
  children: ReactNode
  href?: string
}

export default function CTAButton({ children, href = '#' }: CTAButtonProps) {
  return (
    <a
      href={href}
      className="inline-block bg-accent text-white font-semibold text-sm px-6 py-3 rounded-md hover:opacity-90 transition-opacity"
    >
      {children}
    </a>
  )
}
