FROM node:22-alpine AS builder

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY functions/package.json ./functions/package.json

RUN pnpm install --frozen-lockfile

COPY functions ./functions

RUN pnpm --filter functions run build


FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY functions/package.json ./functions/package.json

RUN pnpm install --frozen-lockfile --prod

COPY --from=builder /app/functions/dist ./functions/dist

EXPOSE 3000

CMD ["pnpm", "--filter", "functions", "run", "start"]