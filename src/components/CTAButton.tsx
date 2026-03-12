import type { ReactNode } from 'react'
import Link from 'next/link'

interface CTAButtonProps {
  children: ReactNode
  href?: string
}

export default function CTAButton({ children, href = '#' }: CTAButtonProps) {
  const isExternal =
    href.startsWith('http://') ||
    href.startsWith('https://') ||
    href.startsWith('mailto:') ||
    href.startsWith('tel:')

  if (isExternal) {
    return (
      <a
        href={href}
        className="inline-block bg-accent text-white font-semibold text-sm px-6 py-3 rounded-md hover:opacity-90 transition-opacity"
      >
        {children}
      </a>
    )
  }

  return (
    <Link
      href={href}
      className="inline-block bg-accent text-white font-semibold text-sm px-6 py-3 rounded-md hover:opacity-90 transition-opacity"
    >
      {children}
    </Link>
  )
}
