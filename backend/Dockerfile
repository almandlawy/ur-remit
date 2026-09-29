FROM node:24-alpine AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY backend/package.json backend/package.json
COPY admin/package.json admin/package.json
RUN corepack enable && pnpm install --frozen-lockfile --filter @ur/backend...
COPY backend backend
RUN pnpm --filter @ur/backend build
# pnpm workspace installs hoist real files into a root node_modules/.pnpm store and
# leave backend/node_modules as symlinks pointing there. Copying backend/node_modules
# alone into the runtime stage leaves dangling symlinks (e.g. "Cannot find package
# 'fastify'"). `pnpm deploy` materializes a self-contained, symlink-free package.
RUN pnpm --filter @ur/backend deploy --prod --legacy /deploy

FROM node:24-alpine
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=8080
USER node
WORKDIR /app
COPY --from=build --chown=node:node /deploy/dist ./dist
COPY --from=build --chown=node:node /deploy/node_modules ./node_modules
COPY --from=build --chown=node:node /deploy/package.json ./package.json
# postgres-ssl.ts resolves the bundled Supabase root CA relative to its own
# compiled location (dist/../certs/...). Without copying certs/ into the
# runtime image, that lookup silently fails and TLS falls back to
# rejectUnauthorized:true without a CA, defeating the certificate bundling
# fix entirely.
COPY --from=build --chown=node:node /deploy/certs ./certs
CMD ["node", "dist/server.js"]
