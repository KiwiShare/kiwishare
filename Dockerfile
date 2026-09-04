FROM node:22-alpine AS builder

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY server/package.json ./server/package.json

RUN pnpm install --frozen-lockfile

COPY server ./server

RUN pnpm --filter server run build


FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY server/package.json ./server/package.json

RUN pnpm install --frozen-lockfile --prod

COPY --from=builder /app/server/dist ./server/dist

EXPOSE 3000

CMD ["pnpm", "--filter", "server", "run", "start"]