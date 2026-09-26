# 网页端镜像：nginx 托管 Flutter web 产物。
#
# 构建前先出产物（在仓库根目录执行）：
#   cd app && flutter build web --release --no-web-resources-cdn && cd ..
#   docker build -f web/Dockerfile -t flowdo-web:latest .
#
# --no-web-resources-cdn 让 CanvasKit 跟着镜像走，不再去 gstatic 取，
# 内网和访问不了谷歌的网络都能正常渲染。
ARG NGINX_IMAGE=nginx:1.27-alpine

# 先在独立阶段整理产物，删文件和压缩才真的能让镜像变小（同一层里删是删不掉的）。
FROM ${NGINX_IMAGE} AS prep
WORKDIR /site
COPY app/build/web/ ./

# 少一个目录就会变成满屏方块，构建时先确认关键产物都在。
RUN test -f index.html \
  && test -f main.dart.js \
  && test -f flutter_bootstrap.js \
  && test -f assets/FontManifest.json \
  && test -f canvaskit/canvaskit.wasm

# Flutter 会把整个 canvaskit 目录都拷出来，但 dart2js + canvaskit 的构建只会加载
# canvaskit.wasm 和 chromium/ 变体；skwasm / wimp / webparagraph 是 wasm 渲染器用的，
# *.js.symbols 是调试符号。只有构建配置里没出现 skwasm 渲染器时才删，免得以后改了构建方式还在删。
RUN if ! grep -q '"renderer":"skwasm"' flutter_bootstrap.js; then \
      rm -rf canvaskit/skwasm* canvaskit/wimp* canvaskit/webparagraph; \
    fi \
  && find . -name '*.js.symbols' -delete

# assets/ 和 canvaskit/ 只留 .gz：nginx 用 gzip_static always 直接发，
# 极少数不支持 gzip 的客户端由 gunzip 模块现场解开。中文字体能小一半多。
# 根目录的 index.html / main.dart.js 等走 try_files，要保留原文件，只额外压一份。
RUN find assets canvaskit -type f -size +1k \
      \( -name '*.wasm' -o -name '*.ttf' -o -name '*.otf' -o -name '*.json' -o -name '*.js' \
         -o -name '*.svg' -o -name '*.bin' -o -name 'NOTICES' \) \
      -exec gzip -9 {} + \
  && find . -maxdepth 1 -type f -size +1k \
      \( -name '*.js' -o -name '*.json' -o -name '*.html' -o -name '*.css' \) \
      -exec gzip -9 -k {} +

FROM ${NGINX_IMAGE}
COPY web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=prep /site/ /usr/share/nginx/html/
EXPOSE 80
HEALTHCHECK --interval=5s --timeout=3s --start-period=3s --retries=10 \
  CMD wget -qO- http://127.0.0.1/index.html >/dev/null || exit 1
