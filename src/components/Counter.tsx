'use client'

import { useEffect, useRef, useState } from 'react'
import { useInView } from 'framer-motion'

interface CounterProps {
  value: string
  label: string
}

export default function Counter({ value, label }: CounterProps) {
  const ref = useRef<HTMLDivElement>(null)
  const isInView = useInView(ref, { once: true })
  const [display, setDisplay] = useState(value)

  useEffect(() => {
    if (!isInView) return

    // Extract number from value (e.g., "5대" → 5, "30일" → 30)
    // Only animate if value starts with a number (e.g., "5대", "30일", "2시간")
    const match = value.match(/^(\d+)(.*)$/)
    if (!match) {
      // Non-numeric prefix like "M4" — just show as-is
      setDisplay(value)
      return
    }

    const target = parseInt(match[1])
    const suffix = match[2]
    const duration = 1500
    const steps = 30
    const stepTime = duration / steps

    let current = 0
    const timer = setInterval(() => {
      current += Math.ceil(target / steps)
      if (current >= target) {
        current = target
        clearInterval(timer)
      }
      setDisplay(`${current}${suffix}`)
    }, stepTime)

    return () => clearInterval(timer)
  }, [isInView, value])

  return (
    <div ref={ref}>
      <div className="text-3xl md:text-4xl font-bold text-[#FF6B00]">{display}</div>
      <div className="text-sm text-gray-500 mt-1">{label}</div>
    </div>
  )
}
