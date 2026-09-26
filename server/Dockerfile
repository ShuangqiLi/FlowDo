# FlowDo API 镜像。
#
# 目标：构建快（依赖层可缓存、build 和 prod 依赖并行）、镜像小（只带运行时依赖）、
# 启动快（Prisma CLI 直接用 node 跑，不走 npx，也不联网查版本）。
#
# 国内构建默认走 npmmirror；CI 或海外机器可覆盖：
#   docker build --build-arg NPM_REGISTRY=https://registry.npmjs.org \
#                --build-arg PRISMA_ENGINES_MIRROR=https://binaries.prisma.sh -t flowdo-server ./server

ARG NODE_IMAGE=node:22-alpine

FROM ${NODE_IMAGE} AS base
WORKDIR /app
ARG NPM_REGISTRY=https://registry.npmmirror.com
ARG PRISMA_ENGINES_MIRROR=https://registry.npmmirror.com/-/binary/prisma
ENV npm_config_registry=${NPM_REGISTRY} \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    npm_config_audit=false \
    PRISMA_ENGINES_MIRROR=${PRISMA_ENGINES_MIRROR} \
    CHECKPOINT_DISABLE=1 \
    PRISMA_HIDE_UPDATE_MESSAGE=1
COPY package.json package-lock.json ./
COPY prisma ./prisma

# 编译阶段：完整依赖 + nest build。npm 缓存挂载在构建机上复用，lockfile 不变时这层直接命中。
FROM base AS build
RUN --mount=type=cache,target=/root/.npm npm ci
COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src
RUN node node_modules/prisma/build/index.js generate && npm run build

# 运行时依赖：只装 dependencies，再生成 Prisma Client。和 build 阶段无依赖关系，BuildKit 会并行跑。
#
# 之后把运行时用不上的东西删掉（node_modules 从 ~250MB 减到 ~140MB）：
#   - 类型声明、source map、文档；
#   - Prisma 把 17MB 的查询引擎复制了三份，只有 .prisma/client 里那份会被加载；
#   - Prisma 给 MySQL / SQLite / SQL Server / CockroachDB 准备的 wasm 引擎；
#   - typescript：Prisma CLI 只在读 prisma.config.ts 时才需要它，这里没有这个文件。
# 删完后 db push、启动 API、user:create 都验证过能跑。
FROM base AS prod-deps
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev \
  && node node_modules/prisma/build/index.js generate \
  && find node_modules -type f \( -name '*.d.ts' -o -name '*.d.mts' -o -name '*.d.cts' \
       -o -name '*.map' -o -name '*.md' -o -name '*.markdown' \) -delete \
  && rm -rf node_modules/typescript \
       node_modules/prisma/libquery_engine-* \
       node_modules/@prisma/engines/libquery_engine-* \
  && find node_modules/@prisma/client node_modules/prisma/build -type f \
       \( -name '*.mysql.*' -o -name '*.sqlite.*' -o -name '*.sqlserver.*' -o -name '*.cockroachdb.*' \) -delete

FROM ${NODE_IMAGE} AS runtime
# 一键更新要在容器里解开 GitHub 上下来的发版包。
RUN apk add --no-cache unzip
WORKDIR /app
ENV NODE_ENV=production \
    CHECKPOINT_DISABLE=1 \
    PRISMA_HIDE_UPDATE_MESSAGE=1 \
    npm_config_update_notifier=false
# 变化最少的层放前面：依赖 → schema → 编译产物。
COPY --from=prod-deps /app/node_modules ./node_modules
COPY package.json ./
COPY prisma ./prisma
COPY --from=build /app/dist ./dist
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
# Windows 上 checkout 出来可能是 CRLF，sh 会把 \r 当命令的一部分。
RUN sed -i 's/\r$//' /app/docker-entrypoint.sh
EXPOSE 3000
HEALTHCHECK --interval=3s --timeout=3s --start-period=5s --retries=40 \
  CMD wget -qO- http://127.0.0.1:3000/health >/dev/null || exit 1
ENTRYPOINT ["sh", "/app/docker-entrypoint.sh"]
