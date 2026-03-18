'use client'

import { useState, useRef, useEffect } from 'react'

interface Message {
  role: 'user' | 'assistant'
  content: string
}

const INITIAL_MESSAGE: Message = {
  role: 'assistant',
  content:
    '안녕하세요, ClawNode 컨설턴트입니다.\n\n하시는 일이나 가장 귀찮은 반복 업무를 알려주시면, **AI로 어떻게 자동화할 수 있는지** 바로 진단해 드릴게요.',
}

export default function ChatBot() {
  const [messages, setMessages] = useState<Message[]>([INITIAL_MESSAGE])
  const [input, setInput] = useState('')
  const [isStreaming, setIsStreaming] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const chatContainerRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const hasInteracted = useRef(false)

  useEffect(() => {
    if (!hasInteracted.current) return
    chatContainerRef.current?.scrollTo({
      top: chatContainerRef.current.scrollHeight,
      behavior: 'smooth',
    })
  }, [messages])

  const sendMessage = async () => {
    const trimmed = input.trim()
    if (!trimmed || isStreaming) return

    hasInteracted.current = true
    const userMessage: Message = { role: 'user', content: trimmed }
    const newMessages = [...messages, userMessage]
    setMessages(newMessages)
    setInput('')
    setIsStreaming(true)

    // API에 보낼 메시지 (초기 인사 제외한 실제 대화만)
    const apiMessages = newMessages.map(m => ({ role: m.role, content: m.content }))
    // 첫 assistant 메시지는 프론트엔드 UI용이므로 제외
    const filteredMessages = apiMessages.slice(1)

    try {
      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: filteredMessages }),
      })

      if (!res.ok) {
        throw new Error('API request failed')
      }

      const reader = res.body?.getReader()
      if (!reader) throw new Error('No reader')

      const decoder = new TextDecoder()
      let assistantContent = ''

      setMessages(prev => [...prev, { role: 'assistant', content: '' }])

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const chunk = decoder.decode(value)
        const lines = chunk.split('\n')

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6)
            if (data === '[DONE]') break
            try {
              const parsed = JSON.parse(data) as { text: string }
              assistantContent += parsed.text
              setMessages(prev => {
                const updated = [...prev]
                updated[updated.length - 1] = {
                  role: 'assistant',
                  content: assistantContent,
                }
                return updated
              })
            } catch {
              // skip malformed chunks
            }
          }
        }
      }
    } catch {
      setMessages(prev => [
        ...prev,
        {
          role: 'assistant',
          content: '죄송합니다, 일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        },
      ])
    } finally {
      setIsStreaming(false)
      inputRef.current?.focus()
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendMessage()
    }
  }

  const formatContent = (content: string) => {
    // Regex to find markdown links: [text](url)
    const linkRegex = /\[([^\]]+)\]\(([^)]+)\)/g
    const parts = []
    let lastIndex = 0
    let match

    while ((match = linkRegex.exec(content)) !== null) {
      // Add text before the link
      if (match.index > lastIndex) {
        parts.push(content.substring(lastIndex, match.index))
      }

      // Add the parsed link element
      parts.push(
        <a
          key={`link-${match.index}`}
          href={match[2]}
          className="inline-block mt-2 px-4 py-2 bg-[#FF6B00] text-black font-bold rounded-lg hover:bg-[#FF6B00]/90 transition-colors"
        >
          {match[1]}
        </a>
      )

      lastIndex = linkRegex.lastIndex
    }

    // Add remaining text
    if (lastIndex < content.length) {
      parts.push(content.substring(lastIndex))
    }

    // Map over parts to handle bold and newlines on string parts
    return parts.map((part, index) => {
      if (typeof part !== 'string') return part

      const boldParts = part.split(/(\*\*[^*]+\*\*)/g)
      return boldParts.map((subPart, i) => {
        if (subPart.startsWith('**') && subPart.endsWith('**')) {
          return (
            <strong key={`${index}-bold-${i}`} className="text-[#FF6B00] font-bold">
              {subPart.slice(2, -2)}
            </strong>
          )
        }
        return subPart.split('\n').map((line, j) => (
          <span key={`${index}-text-${i}-${j}`}>
            {j > 0 && <br />}
            {line}
          </span>
        ))
      })
    })
  }

  return (
    <div className="bg-[#050505] border border-white/10 rounded-2xl shadow-2xl overflow-hidden w-full text-left">
      {/* Title bar */}
      <div className="px-6 py-4 border-b border-white/10 flex items-center gap-3 bg-white/5">
        <div className="flex gap-2">
          <div className="w-3 h-3 rounded-full bg-red-500" />
          <div className="w-3 h-3 rounded-full bg-yellow-500" />
          <div className="w-3 h-3 rounded-full bg-green-500" />
        </div>
        <span className="ml-2 text-xs text-gray-500 font-mono">Premium OpenClaw Consultant</span>
        {isStreaming && (
          <span className="ml-auto text-xs text-[#FF6B00] animate-pulse">typing...</span>
        )}
      </div>

      {/* Messages */}
      <div ref={chatContainerRef} className="p-6 space-y-6 min-h-[300px] max-h-[500px] overflow-y-auto">
        {messages.map((msg, i) => (
          <div
            key={i}
            className={`flex gap-4 ${msg.role === 'user' ? 'flex-row-reverse' : ''}`}
          >
            <div
              className={`w-10 h-10 rounded-full flex items-center justify-center font-bold shrink-0 text-sm ${
                msg.role === 'assistant'
                  ? 'bg-[#FF6B00] text-black'
                  : 'bg-gray-700 text-white'
              }`}
            >
              {msg.role === 'assistant' ? 'AI' : 'Me'}
            </div>
            <div
              className={`p-4 rounded-2xl text-sm leading-relaxed max-w-[85%] ${
                msg.role === 'assistant'
                  ? 'bg-[#1a1a1a] rounded-tl-sm text-gray-300'
                  : 'bg-[#FF6B00]/20 rounded-tr-sm text-white border border-[#FF6B00]/30'
              }`}
            >
              {formatContent(msg.content)}
              {isStreaming && i === messages.length - 1 && msg.role === 'assistant' && msg.content === '' && (
                <span className="inline-block w-2 h-4 bg-[#FF6B00] animate-pulse" />
              )}
            </div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="p-4 border-t border-white/10 bg-white/5">
        <div className="relative">
          <input
            ref={inputRef}
            type="text"
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="예: 쇼핑몰 운영 중인데 매일 CS 답변하는 게 너무 많아요."
            className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl py-4 pl-4 pr-14 text-white placeholder-gray-600 focus:outline-none focus:border-[#FF6B00]/50 transition-colors"
            disabled={isStreaming}
          />
          <button
            onClick={sendMessage}
            disabled={isStreaming || !input.trim()}
            className="absolute right-2 top-2 bottom-2 bg-[#FF6B00] text-black font-bold px-4 rounded-lg hover:bg-[#FF6B00]/90 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {isStreaming ? '...' : '\u2192'}
          </button>
        </div>
        <p className="text-center text-xs text-gray-600 mt-3">
          AI 컨설턴트가 실시간으로 답변합니다. 무료 상담이니 편하게 물어보세요!
        </p>
      </div>
    </div>
  )
}
