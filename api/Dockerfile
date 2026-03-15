# Stage 1: Build & Install dependencies
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
# Clean install production only dependencies
RUN npm ci --only=production

# Stage 2: Minimal production image
FROM node:22-alpine
WORKDIR /app
# Set environment to production
ENV NODE_ENV=production
# Copy only necessary files from builder
COPY --from=builder /app/node_modules ./node_modules
COPY . .

# Run as non-root user for security best practice
USER node

EXPOSE 3001
CMD ["npm", "start"]
