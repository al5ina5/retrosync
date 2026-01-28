'use client'

import { useEffect, useState } from 'react'

interface AnimatedLogoProps {
  className?: string
  delay?: number
  duration?: number
}

export default function AnimatedLogo({ className = '', delay = 0, duration = 1.2 }: AnimatedLogoProps) {
  const [mounted, setMounted] = useState(false)
  const [animationProgress, setAnimationProgress] = useState(0)
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false)

  useEffect(() => {
    setMounted(true)

    // Check for reduced motion preference
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)')
    setPrefersReducedMotion(mediaQuery.matches)

    const handleChange = (e: MediaQueryListEvent) => {
      setPrefersReducedMotion(e.matches)
    }

    mediaQuery.addEventListener('change', handleChange)
    return () => mediaQuery.removeEventListener('change', handleChange)
  }, [])

  useEffect(() => {
    if (!mounted) return

    // Skip animation if user prefers reduced motion
    if (prefersReducedMotion) {
      setAnimationProgress(1)
      return
    }

    const startTime = Date.now() + delay * 1000
    let animationFrame: number

    const animate = () => {
      const elapsed = (Date.now() - startTime) / 1000
      const progress = Math.max(0, Math.min(1, elapsed / duration))
      setAnimationProgress(progress)

      if (progress < 1) {
        animationFrame = requestAnimationFrame(animate)
      }
    }

    animationFrame = requestAnimationFrame(animate)

    return () => {
      if (animationFrame) {
        cancelAnimationFrame(animationFrame)
      }
    }
  }, [mounted, delay, duration, prefersReducedMotion])

  const title = 'RETROSYNC'
  const letterCount = title.length
  const fallDuration = 0.35 // portion of total used for fall + slam
  const stagger = (duration - fallDuration) / Math.max(letterCount - 1, 1)

  return (
    <div className={`flex items-center justify-center ${className}`}>
      <div className="relative inline-flex font-bold tracking-tight">
        {title.split('').map((char, i) => {
          const charStart = i * stagger
          const charT = Math.max(0, Math.min(1, (animationProgress * duration - charStart) / fallDuration))

          let yOffset = 0
          let opacity = 0

          if (charT > 0) {
            // Ease + overshoot for slam, then slight sway
            const eased = charT * charT * (3 - 2 * charT)
            const overshoot = Math.sin(eased * Math.pi) * 8
            yOffset = -(1 - eased) * 80 + overshoot
            opacity = 1
          }

          // Small horizontal sway based on index (only during animation)
          const swayAmount = charT < 1 ? Math.sin((animationProgress * duration * 10) + i * 0.7) * (1 - charT) * 2 : 0

          return (
            <span
              key={i}
              className="inline-block text-vercel-white"
              style={{
                transform: `translate(${swayAmount}px, ${yOffset}px)`,
                opacity,
                willChange: 'transform, opacity',
              }}
            >
              {char}
            </span>
          )
        })}
      </div>
    </div>
  )
}
