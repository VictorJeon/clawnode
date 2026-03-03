const FOOTER_LINKS = [
  { label: 'Telegram', href: 'https://t.me/clawnode' },
  { label: 'Twitter', href: 'https://twitter.com/clawnode' },
  { label: 'Email', href: 'mailto:hello@clawnode.io' },
]

export default function Footer() {
  return (
    <footer className="px-6 py-8 border-t border-white/10">
      <div className="flex gap-6">
        {FOOTER_LINKS.map((link) => (
          <a
            key={link.label}
            href={link.href}
            target={link.href.startsWith('mailto') ? undefined : '_blank'}
            rel={link.href.startsWith('mailto') ? undefined : 'noopener noreferrer'}
            className="text-sm text-foreground/40 hover:text-foreground transition-colors"
          >
            {link.label}
          </a>
        ))}
      </div>
    </footer>
  )
}
