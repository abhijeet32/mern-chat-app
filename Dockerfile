
# FROM node:24-alpine
# WORKDIR /app
# COPY package*.json ./ 
# RUN npm install 
# COPY . .
# RUN npm run build
# EXPOSE 8000
# CMD [ "npm", "start" ]

### MULTISTAGE BUILD ###

FROM node:24-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM node:24-alpine AS runner
WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/backend ./backend
COPY --from=builder /app/frontend/dist ./frontend/dist
# COPY --from=builder /app/.env ./

EXPOSE 8000
CMD [ "node", "backend/server.js" ]