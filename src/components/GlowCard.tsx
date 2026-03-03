'use client'

import { motion } from 'framer-motion'
import type { ReactNode } from 'react'

interface GlowCardProps {
  children: ReactNode
  className?: string
  glowColor?: string
}

export default function GlowCard({ children, className = '', glowColor = '#FF6B00' }: GlowCardProps) {
  return (
    <motion.div
      whileHover={{ 
        y: -4,
        boxShadow: `0 0 30px ${glowColor}15, 0 0 60px ${glowColor}08`,
        borderColor: `${glowColor}40`,
      }}
      transition={{ duration: 0.3 }}
      className={`bg-[#0A0A0A] border border-white/10 rounded-2xl p-6 ${className}`}
    >
      {children}
    </motion.div>
  )
}
