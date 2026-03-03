'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'

interface AccordionProps {
  items: { q: string; a: string }[]
}

export default function Accordion({ items }: AccordionProps) {
  const [openIdx, setOpenIdx] = useState<number | null>(null)

  return (
    <div className="space-y-4">
      {items.map((faq, i) => (
        <div
          key={i}
          className="border border-white/10 rounded-xl overflow-hidden hover:border-white/20 transition-colors"
        >
          <button
            onClick={() => setOpenIdx(openIdx === i ? null : i)}
            className="w-full flex items-center justify-between p-6 text-left"
          >
            <h3 className="font-bold text-lg pr-4">Q. {faq.q}</h3>
            <motion.span
              animate={{ rotate: openIdx === i ? 45 : 0 }}
              transition={{ duration: 0.2 }}
              className="text-[#FF6B00] text-2xl shrink-0"
            >
              +
            </motion.span>
          </button>
          <AnimatePresence>
            {openIdx === i && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.3, ease: [0.25, 0.4, 0.25, 1] }}
              >
                <p className="px-6 pb-6 text-gray-400 text-sm leading-relaxed">{faq.a}</p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      ))}
    </div>
  )
}
