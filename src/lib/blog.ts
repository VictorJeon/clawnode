import fs from 'fs'
import path from 'path'
import matter from 'gray-matter'

export interface BlogPost {
  slug: string
  title: string
  description: string
  date: string
  author: string
  tags: string[]
  keywords: string[]
  content: string
}

export interface BlogPostMeta {
  slug: string
  title: string
  description: string
  date: string
  author: string
  tags: string[]
  keywords: string[]
}

const CONTENT_DIR = path.join(process.cwd(), 'src/content/blog')

export function getAllPostSlugs(): string[] {
  if (!fs.existsSync(CONTENT_DIR)) return []
  return fs
    .readdirSync(CONTENT_DIR)
    .filter((f) => f.endsWith('.mdx'))
    .map((f) => f.replace(/\.mdx$/, ''))
}

export function getAllPosts(): BlogPostMeta[] {
  const slugs = getAllPostSlugs()
  const posts = slugs.map((slug) => {
    const filePath = path.join(CONTENT_DIR, `${slug}.mdx`)
    const raw = fs.readFileSync(filePath, 'utf-8')
    const { data } = matter(raw)
    return {
      slug,
      title: data.title ?? '',
      description: data.description ?? '',
      date: data.date ?? '',
      author: data.author ?? 'ClawNode',
      tags: data.tags ?? [],
      keywords: data.keywords ?? [],
    } as BlogPostMeta
  })

  // 최신 글 순 정렬
  return posts.sort(
    (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
  )
}

export function getPostBySlug(slug: string): BlogPost | null {
  const filePath = path.join(CONTENT_DIR, `${slug}.mdx`)
  if (!fs.existsSync(filePath)) return null
  const raw = fs.readFileSync(filePath, 'utf-8')
  const { data, content } = matter(raw)
  return {
    slug,
    title: data.title ?? '',
    description: data.description ?? '',
    date: data.date ?? '',
    author: data.author ?? 'ClawNode',
    tags: data.tags ?? [],
    keywords: data.keywords ?? [],
    content,
  }
}
