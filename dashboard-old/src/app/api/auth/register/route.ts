import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { hashPassword, generateToken } from '@/lib/auth'
import { successResponse, errorResponse, validateRequiredFields } from '@/lib/utils'
import { z } from 'zod'

const registerSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z
    .string()
    .min(10, 'Password must be at least 10 characters')
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/,
      'Password must include upper, lower case letters and a digit'
    ),
  name: z.string().optional(),
})

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()

    // Validate input
    const validation = registerSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message)
    }

    const { email, password, name } = validation.data

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email },
    })

    if (existingUser) {
      return errorResponse('User with this email already exists')
    }

    // Hash password
    const passwordHash = await hashPassword(password)

    // Create user
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        name: name || null,
      },
      select: {
        id: true,
        email: true,
        name: true,
        subscriptionTier: true,
        createdAt: true,
      },
    })

    // Generate JWT token
    const token = generateToken({
      userId: user.id,
      email: user.email,
      type: 'user',
    })

    return successResponse({
      user,
      token,
    }, 'User registered successfully')
  } catch (error) {
    console.error('Registration error:', error)
    return errorResponse('Failed to register user', 500)
  }
}
