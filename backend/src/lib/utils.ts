import { NextResponse } from 'next/server'

/**
 * Standard API response format
 */
export interface ApiResponse<T = any> {
  success: boolean
  data?: T
  error?: string
  message?: string
}

/**
 * Create a success response
 */
export function successResponse<T>(data: T, message?: string) {
  return NextResponse.json({
    success: true,
    data,
    message,
  } as ApiResponse<T>)
}

/**
 * Create an error response
 */
export function errorResponse(error: string, status: number = 400) {
  return NextResponse.json({
    success: false,
    error,
  } as ApiResponse, { status })
}

/**
 * Create an unauthorized response
 */
export function unauthorizedResponse(message: string = 'Unauthorized') {
  return errorResponse(message, 401)
}

/**
 * Create a not found response
 */
export function notFoundResponse(message: string = 'Not found') {
  return errorResponse(message, 404)
}

/**
 * Create a server error response
 */
export function serverErrorResponse(message: string = 'Internal server error') {
  return errorResponse(message, 500)
}

/**
 * Validate required fields in request body
 */
export function validateRequiredFields(body: any, fields: string[]): string | null {
  for (const field of fields) {
    if (!body[field]) {
      return `Missing required field: ${field}`
    }
  }
  return null
}
