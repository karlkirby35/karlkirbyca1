FROM node:22-slim AS base

WORKDIR /app

COPY backend/package.json backend/package-lock.json ./

ENV PORT=8000
EXPOSE 8000

FROM base AS dev

RUN npm ci
COPY backend/ ./

CMD ["npm", "run", "dev"]

FROM node:22-slim AS frontend

WORKDIR /frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM base AS production

ENV NODE_ENV=production

RUN npm ci --omit=dev
COPY backend/ ./

COPY --from=frontend /frontend/dist ./dist

RUN mkdir -p uploads && chown node:node uploads

USER node

CMD ["node", "src/server.js"]