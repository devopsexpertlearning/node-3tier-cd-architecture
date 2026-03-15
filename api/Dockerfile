# Stage 1: Install production dependencies
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Minimal production image
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production

# Copy app source first, then overlay with clean builder node_modules
COPY . .
COPY --from=builder /app/node_modules ./node_modules

# Run as non-root user
USER node

EXPOSE 3001
CMD ["npm", "start"]
