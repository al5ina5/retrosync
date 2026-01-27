'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

interface SyncLog {
  id: string
  action: string
  filePath: string
  fileSize: number | null
  status: string
  errorMsg: string | null
  createdAt: string
  device: {
    id: string
    name: string
    deviceType: string
  }
}

export default function DevicesPage() {
  const router = useRouter()
  const [logs, setLogs] = useState<SyncLog[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const token = localStorage.getItem('token')
    if (!token) {
      router.push('/auth/login')
      return
    }

    fetchLogs()
  }, [router])

  const fetchLogs = async () => {
    try {
      const token = localStorage.getItem('token')
      const response = await fetch('/api/sync/log?limit=50', {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      })

      const data = await response.json()

      if (data.success) {
        setLogs(data.data.logs)
      } else {
        setError(data.error || 'Failed to fetch sync logs')
      }
    } catch (err) {
      setError('Failed to fetch sync logs')
    } finally {
      setLoading(false)
    }
  }

  const getActionColor = (action: string) => {
    switch (action) {
      case 'upload':
        return 'text-blue-500'
      case 'download':
        return 'text-green-500'
      case 'delete':
        return 'text-red-500'
      case 'conflict':
        return 'text-yellow-500'
      default:
        return 'text-gray-500'
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'success':
        return 'text-green-500'
      case 'failed':
        return 'text-red-500'
      case 'pending':
        return 'text-yellow-500'
      default:
        return 'text-gray-500'
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-gray-900 to-gray-800 flex items-center justify-center">
        <div className="text-white text-xl">Loading...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-900 to-gray-800 text-white">
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <Link href="/dashboard" className="text-blue-500 hover:text-blue-400 mb-4 inline-block">
            ← Back to Dashboard
          </Link>
          <h1 className="text-4xl font-bold">Sync Activity</h1>
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500 text-red-500 px-4 py-3 rounded mb-6">
            {error}
          </div>
        )}

        <div className="bg-gray-800 rounded-lg p-6">
          <h2 className="text-2xl font-bold mb-6">Recent Sync Events</h2>

          {logs.length === 0 ? (
            <p className="text-gray-400">No sync activity yet.</p>
          ) : (
            <div className="space-y-4">
              {logs.map((log) => (
                <div key={log.id} className="bg-gray-700 rounded-lg p-4">
                  <div className="flex justify-between items-start mb-2">
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <span className={`font-bold ${getActionColor(log.action)}`}>
                          {log.action.toUpperCase()}
                        </span>
                        <span className={getStatusColor(log.status)}>
                          [{log.status}]
                        </span>
                      </div>
                      <p className="text-sm text-gray-300">{log.filePath}</p>
                    </div>
                    <div className="text-right text-sm text-gray-400">
                      <p>{log.device.name}</p>
                      <p>{new Date(log.createdAt).toLocaleString()}</p>
                    </div>
                  </div>

                  {log.fileSize && (
                    <p className="text-xs text-gray-400">
                      Size: {(log.fileSize / 1024).toFixed(2)} KB
                    </p>
                  )}

                  {log.errorMsg && (
                    <p className="text-xs text-red-500 mt-2">
                      Error: {log.errorMsg}
                    </p>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
