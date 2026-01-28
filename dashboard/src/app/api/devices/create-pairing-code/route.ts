import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest, generatePairingCode } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import QRCode from 'qrcode'

export async function POST(request: NextRequest) {
  try {
    // Authenticate user
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    // Generate 6-digit pairing code
    let code = generatePairingCode()
    let attempts = 0
    const maxAttempts = 10

    // Ensure code is unique
    while (attempts < maxAttempts) {
      const existing = await prisma.pairingCode.findUnique({
        where: { code },
      })

      if (!existing) {
        break
      }

      code = generatePairingCode()
      attempts++
    }

    if (attempts >= maxAttempts) {
      return errorResponse('Failed to generate unique pairing code', 500)
    }

    // Create pairing code (expires in 15 minutes)
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000)
    const pairingCode = await prisma.pairingCode.create({
      data: {
        code,
        userId: user.userId,
        expiresAt,
      },
    })

    // Generate QR code
    const qrCodeData = JSON.stringify({
      code,
      apiUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000',
    })

    const qrCode = await QRCode.toDataURL(qrCodeData)

    return successResponse({
      code: pairingCode.code,
      expiresAt: pairingCode.expiresAt,
      qrCode,
    }, 'Pairing code generated successfully')
  } catch (error) {
    console.error('Create pairing code error:', error)
    return errorResponse('Failed to create pairing code', 500)
  }
}
