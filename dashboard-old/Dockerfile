FROM node:18-slim

WORKDIR /app

# Install OpenSSL for Prisma
RUN apt-get update -y && apt-get install -y openssl

# Copy package files
COPY package*.json ./
COPY prisma ./prisma/

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Generate Prisma client
RUN npx prisma generate

# Build Next.js app
RUN npm run build

# Expose port
EXPOSE 3000

# Start command
CMD ["sh", "-c", "npx prisma db push --accept-data-loss && npm start"]
