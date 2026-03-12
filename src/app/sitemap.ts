import type { MetadataRoute } from 'next'
import { siteConfig } from '@/lib/seo'

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date()

  return [
    { url: siteConfig.url, lastModified: now, changeFrequency: 'weekly', priority: 1 },
    { url: `${siteConfig.url}/product`, lastModified: now, changeFrequency: 'weekly', priority: 0.9 },
    { url: `${siteConfig.url}/pricing`, lastModified: now, changeFrequency: 'weekly', priority: 0.9 },
    { url: `${siteConfig.url}/security`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${siteConfig.url}/process`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${siteConfig.url}/reserve`, lastModified: now, changeFrequency: 'weekly', priority: 0.7 },
  ]
}
