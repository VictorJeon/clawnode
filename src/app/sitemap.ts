import type { MetadataRoute } from 'next'
import { siteConfig } from '@/lib/seo'
import { getAllPosts } from '@/lib/blog'

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date()

  const staticRoutes: MetadataRoute.Sitemap = [
    { url: siteConfig.url, lastModified: now, changeFrequency: 'weekly', priority: 1 },
    { url: `${siteConfig.url}/product`, lastModified: now, changeFrequency: 'weekly', priority: 0.9 },
    { url: `${siteConfig.url}/pricing`, lastModified: now, changeFrequency: 'weekly', priority: 0.9 },
    { url: `${siteConfig.url}/security`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${siteConfig.url}/process`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${siteConfig.url}/reserve`, lastModified: now, changeFrequency: 'weekly', priority: 0.7 },
    { url: `${siteConfig.url}/blog`, lastModified: now, changeFrequency: 'weekly', priority: 0.8 },
  ]

  const posts = getAllPosts()
  const blogRoutes: MetadataRoute.Sitemap = posts.map((post) => ({
    url: `${siteConfig.url}/blog/${post.slug}`,
    lastModified: new Date(post.date),
    changeFrequency: 'monthly',
    priority: 0.7,
  }))

  return [...staticRoutes, ...blogRoutes]
}
