import Link from 'next/link'

const NAV_LINKS = [
  { href: '/', label: 'Home' },
  { href: '/product', label: 'Product' },
  { href: '/security', label: 'Security' },
  { href: '/process', label: 'Process' },
  { href: '/pricing', label: 'Pricing' },
]

export default function Nav() {
  return (
    <nav className="flex items-center justify-between px-6 py-4 border-b border-white/10">
      <span className="text-accent font-bold text-lg tracking-tight">ClawNode</span>
      <ul className="flex gap-6">
        {NAV_LINKS.map((link) => (
          <li key={link.href}>
            <Link
              href={link.href}
              className="text-sm text-foreground/60 hover:text-foreground transition-colors"
            >
              {link.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  )
}
