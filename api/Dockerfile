# Stage 1: Install production dependencies
FROM node:24-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Minimal production image
FROM node:24-alpine
RUN apk upgrade --no-cache
WORKDIR /app
ENV NODE_ENV=production

# Copy app source first, then overlay with clean builder node_modules.
COPY . .
COPY --from=builder /app/node_modules ./node_modules

# Run as non-root user
USER node

EXPOSE 3001
CMD ["npm", "start"]
