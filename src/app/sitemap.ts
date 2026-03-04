import type { MetadataRoute } from 'next'

export default function sitemap(): MetadataRoute.Sitemap {
  const base = 'https://clawnode.io'
  const now = new Date()

  return [
    { url: base, lastModified: now, changeFrequency: 'weekly', priority: 1 },
    { url: `${base}/product`, lastModified: now, changeFrequency: 'weekly', priority: 0.9 },
    { url: `${base}/security`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${base}/process`, lastModified: now, changeFrequency: 'monthly', priority: 0.7 },
    { url: `${base}/pricing`, lastModified: now, changeFrequency: 'weekly', priority: 0.9 },
    { url: `${base}/reserve`, lastModified: now, changeFrequency: 'weekly', priority: 0.8 },
  ]
}
