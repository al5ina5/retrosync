import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

// Create Prisma client with minimal logging (we'll use middleware for better logs)
export const prisma = globalForPrisma.prisma ?? new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['error', 'warn'] : ['error'],
})

// Add middleware for meaningful query logging
if (process.env.NODE_ENV === 'development') {
  prisma.$use(async (params, next) => {
    const before = Date.now()
    const result = await next(params)
    const after = Date.now()
    const duration = after - before

    // Format the operation name
    const model = params.model || 'Unknown'
    const action = params.action
    const operation = `${model}.${action}`

    // Extract meaningful context from params
    let context = ''
    if (params.action === 'findUnique' || params.action === 'findFirst') {
      const where = params.args?.where
      if (where) {
        const keys = Object.keys(where)
        if (keys.length > 0) {
          context = `where ${keys[0]}=${JSON.stringify(where[keys[0]])}`
        }
      }
    } else if (params.action === 'findMany') {
      const count = params.args?.take || 'all'
      context = `fetching ${count} records`
      if (params.args?.where) {
        const whereKeys = Object.keys(params.args.where)
        if (whereKeys.length > 0) {
          context += ` filtered by ${whereKeys.join(', ')}`
        }
      }
    } else if (params.action === 'create') {
      const data = params.args?.data
      if (data) {
        const dataKeys = Object.keys(data).filter(k => k !== 'userId' && k !== 'apiKey')
        if (dataKeys.length > 0) {
          context = `creating with ${dataKeys.join(', ')}`
        }
      }
    } else if (params.action === 'update') {
      const where = params.args?.where
      const data = params.args?.data
      if (where) {
        const whereKeys = Object.keys(where)
        context = `updating where ${whereKeys[0]}=${JSON.stringify(where[whereKeys[0]])}`
      }
      if (data) {
        const dataKeys = Object.keys(data)
        context += ` setting ${dataKeys.join(', ')}`
      }
    } else if (params.action === 'delete' || params.action === 'deleteMany') {
      const where = params.args?.where
      if (where) {
        const whereKeys = Object.keys(where)
        context = `deleting where ${whereKeys[0]}=${JSON.stringify(where[whereKeys[0]])}`
      }
    } else if (params.action === 'updateMany') {
      const where = params.args?.where
      const data = params.args?.data
      if (where) {
        const whereKeys = Object.keys(where)
        context = `updating many where ${whereKeys[0]}=${JSON.stringify(where[whereKeys[0]])}`
      }
      if (data) {
        const dataKeys = Object.keys(data)
        context += ` setting ${dataKeys.join(', ')}`
      }
    }

    // Log with meaningful format
    const logMessage = `[Prisma] ${operation}${context ? ` - ${context}` : ''} (${duration}ms)`
    console.log(logMessage)

    return result
  })
}

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
