'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function SavesPage() {
  const router = useRouter()

  useEffect(() => {
    router.replace('/saves')
  }, [router])

  return null
}
