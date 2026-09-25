FROM node:24-alpine AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY backend/package.json backend/package.json
RUN corepack enable && pnpm install --frozen-lockfile --filter @ur/backend...
COPY backend backend
RUN pnpm --filter @ur/backend build

FROM node:24-alpine
ENV NODE_ENV=production
USER node
WORKDIR /app
COPY --from=build --chown=node:node /app/backend/dist ./dist
COPY --from=build --chown=node:node /app/backend/node_modules ./node_modules
COPY --from=build --chown=node:node /app/backend/package.json ./package.json
CMD ["node", "dist/server.js"]

