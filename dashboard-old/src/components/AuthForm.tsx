'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

interface AuthFormProps {
  type: 'login' | 'register'
}

export default function AuthForm({ type }: AuthFormProps) {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [name, setName] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const endpoint = type === 'login' ? '/api/auth/login' : '/api/auth/register'
      const body = type === 'login'
        ? { email, password }
        : { email, password, name }

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })

      const data = await response.json()

      if (!data.success) {
        setError(data.error || 'An error occurred')
        setLoading(false)
        return
      }

      // Store token
      localStorage.setItem('token', data.data.token)
      localStorage.setItem('user', JSON.stringify(data.data.user))

      // Redirect to dashboard
      router.push('/dashboard')
    } catch (err) {
      setError('An error occurred. Please try again.')
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-vercel-black text-vercel-white flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        {/* Logo/Title */}
        <div className="mb-8 text-center">
          <Link href="/" className="text-2xl font-semibold inline-block mb-2 hover:text-vercel-gray-300 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded">
            RetroSync
          </Link>
          <h1 className="text-3xl font-bold mt-4">
            {type === 'login' ? 'Welcome Back' : 'Create Account'}
          </h1>
          <p className="text-vercel-gray-400 mt-2">
            {type === 'login' 
              ? 'Sign in to your account to continue' 
              : 'Get started with RetroSync today'}
          </p>
        </div>

        {/* Form Card */}
        <div className="border border-vercel-gray-800 rounded-lg p-8 bg-vercel-gray-950">
          {error && (
            <div 
              className="bg-red-500/10 border border-red-500/50 text-red-400 px-4 py-3 rounded-lg mb-6"
              role="alert"
              aria-live="polite"
            >
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6" noValidate>
            {type === 'register' && (
              <div>
                <label 
                  htmlFor="name" 
                  className="block text-sm font-medium text-vercel-gray-300 mb-2"
                >
                  Name <span className="text-vercel-gray-500">(optional)</span>
                </label>
                <input
                  type="text"
                  id="name"
                  name="name"
                  autoComplete="name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-4 py-2.5 bg-vercel-black border border-vercel-gray-800 rounded-lg text-vercel-white placeholder-vercel-gray-500 focus:outline-none focus:ring-2 focus:ring-vercel-blue-500 focus:border-transparent transition-colors"
                  placeholder="John Doe"
                  spellCheck={false}
                />
              </div>
            )}

            <div>
              <label 
                htmlFor="email" 
                className="block text-sm font-medium text-vercel-gray-300 mb-2"
              >
                Email
              </label>
              <input
                type="email"
                id="email"
                name="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="w-full px-4 py-2.5 bg-vercel-black border border-vercel-gray-800 rounded-lg text-vercel-white placeholder-vercel-gray-500 focus:outline-none focus:ring-2 focus:ring-vercel-blue-500 focus:border-transparent transition-colors"
                placeholder="you@example.com"
                spellCheck={false}
              />
            </div>

            <div>
              <label 
                htmlFor="password" 
                className="block text-sm font-medium text-vercel-gray-300 mb-2"
              >
                Password
              </label>
              <input
                type="password"
                id="password"
                name="password"
                autoComplete={type === 'login' ? 'current-password' : 'new-password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={8}
                className="w-full px-4 py-2.5 bg-vercel-black border border-vercel-gray-800 rounded-lg text-vercel-white placeholder-vercel-gray-500 focus:outline-none focus:ring-2 focus:ring-vercel-blue-500 focus:border-transparent transition-colors"
                placeholder="••••••••"
              />
              {type === 'register' && (
                <p className="text-sm text-vercel-gray-500 mt-2">At least 8 characters</p>
              )}
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full px-4 py-2.5 bg-vercel-white text-vercel-black hover:bg-vercel-gray-200 disabled:bg-vercel-gray-800 disabled:text-vercel-gray-500 disabled:cursor-not-allowed font-semibold rounded-lg transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-gray-950"
            >
              {loading ? 'Please wait…' : (type === 'login' ? 'Sign In' : 'Create Account')}
            </button>
          </form>

          <div className="mt-6 text-center text-vercel-gray-400">
            {type === 'login' ? (
              <p>
                Don&apos;t have an account?{' '}
                <Link 
                  href="/auth/register" 
                  className="text-vercel-white hover:text-vercel-gray-300 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-gray-950 rounded"
                >
                  Sign up
                </Link>
              </p>
            ) : (
              <p>
                Already have an account?{' '}
                <Link 
                  href="/auth/login" 
                  className="text-vercel-white hover:text-vercel-gray-300 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-gray-950 rounded"
                >
                  Sign in
                </Link>
              </p>
            )}
          </div>
        </div>

        <div className="mt-6 text-center">
          <Link 
            href="/" 
            className="text-vercel-gray-400 hover:text-vercel-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded"
          >
            ← Back to home
          </Link>
        </div>
      </div>
    </div>
  )
}
