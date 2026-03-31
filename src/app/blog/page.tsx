import type { Metadata } from 'next'
import Link from 'next/link'
import { getAllPosts } from '@/lib/blog'
import { createPageMetadata, breadcrumbJsonLd, webPageJsonLd } from '@/lib/seo'
import StructuredData from '@/components/StructuredData'

export const metadata: Metadata = createPageMetadata({
  title: '블로그 — 프리미엄 오픈클로 가이드',
  description:
    'AI 에이전트, 오픈클로 사용법, 업무 자동화 노하우를 담은 ClawNode 블로그입니다. 프리미엄 오픈클로 활용법부터 로컬 AI 운영, 실전 자동화 사례까지 다룹니다.',
  path: '/blog',
  keywords: [
    '오픈클로 사용법',
    'AI 자동화 블로그',
    '로컬 AI 가이드',
    '오픈클로 설치',
    'AI 에이전트 활용',
  ],
})

const structuredData = [
  webPageJsonLd({
    title: 'ClawNode 블로그 — 프리미엄 오픈클로 가이드',
    description:
      'AI 에이전트, 오픈클로 사용법, 업무 자동화 노하우를 담은 ClawNode 블로그',
    path: '/blog',
  }),
  breadcrumbJsonLd([
    { name: '홈', path: '/' },
    { name: '블로그', path: '/blog' },
  ]),
]

export default function BlogListPage() {
  const posts = getAllPosts()

  return (
    <>
      <StructuredData data={structuredData} />
      <main className="min-h-screen bg-[#050505] text-white">
        <div className="max-w-4xl mx-auto px-6 py-20">
          {/* Header */}
          <div className="mb-14">
            <h1 className="text-4xl md:text-5xl font-bold mb-4 tracking-tight">
              블로그
            </h1>
            <p className="text-gray-400 text-lg leading-relaxed">
              AI 에이전트, 오픈클로, 업무 자동화에 관한 실전 가이드
            </p>
          </div>

          {/* Post List */}
          {posts.length === 0 ? (
            <p className="text-gray-500">아직 게시글이 없습니다.</p>
          ) : (
            <ul className="flex flex-col gap-8">
              {posts.map((post) => (
                <li key={post.slug}>
                  <Link
                    href={`/blog/${post.slug}`}
                    className="group block border border-white/8 rounded-xl p-7 hover:border-[#FF6B00]/40 transition-colors bg-white/2 hover:bg-white/4"
                  >
                    <div className="flex items-center gap-3 mb-3 flex-wrap">
                      <time
                        dateTime={post.date}
                        className="text-xs text-gray-500"
                      >
                        {new Date(post.date).toLocaleDateString('ko-KR', {
                          year: 'numeric',
                          month: 'long',
                          day: 'numeric',
                        })}
                      </time>
                      {post.tags.slice(0, 2).map((tag) => (
                        <span
                          key={tag}
                          className="text-xs bg-[#FF6B00]/10 text-[#FF6B00] px-2 py-0.5 rounded-full"
                        >
                          {tag}
                        </span>
                      ))}
                    </div>
                    <h2 className="text-xl font-semibold mb-2 group-hover:text-[#FF6B00] transition-colors">
                      {post.title}
                    </h2>
                    <p className="text-gray-400 text-sm leading-relaxed line-clamp-2">
                      {post.description}
                    </p>
                    <span className="mt-4 inline-block text-xs text-[#FF6B00] font-medium">
                      읽기 →
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </div>
      </main>
    </>
  )
}
