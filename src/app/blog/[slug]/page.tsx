import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import { MDXRemote } from 'next-mdx-remote/rsc'
import { getPostBySlug, getAllPostSlugs } from '@/lib/blog'
import {
  createPageMetadata,
  breadcrumbJsonLd,
  absoluteUrl,
  siteConfig,
} from '@/lib/seo'
import StructuredData from '@/components/StructuredData'

interface Props {
  params: Promise<{ slug: string }>
}

export async function generateStaticParams() {
  const slugs = getAllPostSlugs()
  return slugs.map((slug) => ({ slug }))
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const post = getPostBySlug(slug)
  if (!post) return {}

  return createPageMetadata({
    title: post.title,
    description: post.description,
    path: `/blog/${slug}`,
    keywords: [...post.tags, ...post.keywords],
    imagePath: siteConfig.ogImagePath,
  })
}

function blogPostingJsonLd(post: NonNullable<ReturnType<typeof getPostBySlug>>) {
  const url = absoluteUrl(`/blog/${post.slug}`)
  return {
    '@context': 'https://schema.org',
    '@type': 'BlogPosting',
    '@id': `${url}#blogposting`,
    url,
    headline: post.title,
    description: post.description,
    datePublished: post.date,
    dateModified: post.date,
    author: {
      '@type': 'Organization',
      name: post.author,
      url: siteConfig.url,
    },
    publisher: {
      '@type': 'Organization',
      name: siteConfig.name,
      url: siteConfig.url,
      logo: absoluteUrl(siteConfig.logoPath),
    },
    image: absoluteUrl(siteConfig.ogImagePath),
    inLanguage: 'ko-KR',
    isPartOf: {
      '@id': absoluteUrl('/#website'),
    },
    keywords: [...post.tags, ...post.keywords].join(', '),
  }
}

// MDX 컴포넌트 커스텀 스타일
const mdxComponents = {
  h1: (props: React.HTMLAttributes<HTMLHeadingElement>) => (
    <h1 className="text-3xl md:text-4xl font-bold mt-10 mb-5 leading-tight" {...props} />
  ),
  h2: (props: React.HTMLAttributes<HTMLHeadingElement>) => (
    <h2 className="text-2xl font-bold mt-12 mb-4 text-white border-b border-white/10 pb-2" {...props} />
  ),
  h3: (props: React.HTMLAttributes<HTMLHeadingElement>) => (
    <h3 className="text-xl font-semibold mt-8 mb-3 text-gray-100" {...props} />
  ),
  p: (props: React.HTMLAttributes<HTMLParagraphElement>) => (
    <p className="text-gray-300 leading-relaxed mb-5 text-base" {...props} />
  ),
  ul: (props: React.HTMLAttributes<HTMLUListElement>) => (
    <ul className="list-disc list-inside space-y-2 mb-5 text-gray-300 ml-2" {...props} />
  ),
  ol: (props: React.HTMLAttributes<HTMLOListElement>) => (
    <ol className="list-decimal list-inside space-y-2 mb-5 text-gray-300 ml-2" {...props} />
  ),
  li: (props: React.HTMLAttributes<HTMLLIElement>) => (
    <li className="text-gray-300 leading-relaxed" {...props} />
  ),
  strong: (props: React.HTMLAttributes<HTMLElement>) => (
    <strong className="text-white font-semibold" {...props} />
  ),
  a: (props: React.AnchorHTMLAttributes<HTMLAnchorElement>) => (
    <a className="text-[#FF6B00] underline underline-offset-2 hover:opacity-80 transition-opacity" {...props} />
  ),
  blockquote: (props: React.HTMLAttributes<HTMLQuoteElement>) => (
    <blockquote
      className="border-l-4 border-[#FF6B00]/50 pl-5 py-1 my-6 text-gray-400 italic bg-white/3 rounded-r-lg"
      {...props}
    />
  ),
  code: (props: React.HTMLAttributes<HTMLElement>) => (
    <code
      className="bg-white/8 text-[#FF6B00] px-1.5 py-0.5 rounded text-sm font-mono"
      {...props}
    />
  ),
  pre: (props: React.HTMLAttributes<HTMLPreElement>) => (
    <pre
      className="bg-white/5 border border-white/10 rounded-lg p-5 overflow-x-auto mb-6 text-sm font-mono text-gray-200"
      {...props}
    />
  ),
  hr: () => <hr className="border-white/10 my-10" />,
}

export default async function BlogPostPage({ params }: Props) {
  const { slug } = await params
  const post = getPostBySlug(slug)
  if (!post) notFound()

  const structuredData = [
    blogPostingJsonLd(post),
    breadcrumbJsonLd([
      { name: '홈', path: '/' },
      { name: '블로그', path: '/blog' },
      { name: post.title, path: `/blog/${slug}` },
    ]),
  ]

  return (
    <>
      <StructuredData data={structuredData} />
      <main className="min-h-screen bg-[#050505] text-white">
        <article className="max-w-3xl mx-auto px-6 py-20">
          {/* Breadcrumb */}
          <nav className="mb-8 text-sm text-gray-500 flex items-center gap-2">
            <Link href="/" className="hover:text-white transition-colors">홈</Link>
            <span>/</span>
            <Link href="/blog" className="hover:text-white transition-colors">블로그</Link>
            <span>/</span>
            <span className="text-gray-400 line-clamp-1">{post.title}</span>
          </nav>

          {/* Meta */}
          <div className="mb-6 flex items-center gap-3 flex-wrap">
            <time dateTime={post.date} className="text-xs text-gray-500">
              {new Date(post.date).toLocaleDateString('ko-KR', {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
              })}
            </time>
            <span className="text-gray-700">·</span>
            <span className="text-xs text-gray-500">{post.author}</span>
            {post.tags.map((tag) => (
              <span
                key={tag}
                className="text-xs bg-[#FF6B00]/10 text-[#FF6B00] px-2 py-0.5 rounded-full"
              >
                {tag}
              </span>
            ))}
          </div>

          {/* Content */}
          <div className="prose-custom">
            <MDXRemote source={post.content} components={mdxComponents} />
          </div>

          {/* Back to blog */}
          <div className="mt-16 pt-8 border-t border-white/10">
            <Link
              href="/blog"
              className="text-sm text-gray-400 hover:text-white transition-colors inline-flex items-center gap-2"
            >
              ← 블로그 목록으로
            </Link>
          </div>
        </article>
      </main>
    </>
  )
}
