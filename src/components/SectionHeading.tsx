import type { ReactNode } from 'react'

interface SectionHeadingProps {
  children: ReactNode
  subtitle?: string
}

export default function SectionHeading({ children, subtitle }: SectionHeadingProps) {
  return (
    <div className="mb-12">
      <h2 className="text-4xl font-bold text-foreground tracking-tight">{children}</h2>
      {subtitle && <p className="mt-3 text-foreground/50">{subtitle}</p>}
    </div>
  )
}
