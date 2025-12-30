# Frontend Dockerfile - Development mode
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code (including .env if present)
COPY . .

# Build-time environment variables for TURN server
ARG VITE_TURN_USERNAME
ARG VITE_TURN_CREDENTIAL
ENV VITE_TURN_USERNAME=$VITE_TURN_USERNAME
ENV VITE_TURN_CREDENTIAL=$VITE_TURN_CREDENTIAL

# Expose port
EXPOSE 5173

# Run dev server with host binding for external access
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
