# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install git (required by npm for some dependencies)
RUN apk add --no-cache git

# Copy package files
COPY package.json bun.lock* package-lock.json* ./

# Install dependencies
RUN npm install || bun install

# Copy source code
COPY . .

# Build the application using Docker-specific config
RUN npm run build -- --config astro.config.node.mjs

# Runtime stage - use nginx to serve static files
FROM nginx:alpine

# Install curl for healthcheck
RUN apk add --no-cache curl

# Copy built static files from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom nginx server configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 3022
EXPOSE 3022

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
