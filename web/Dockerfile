# 网页端镜像：nginx 托管 Flutter web 产物。
#
# 构建前先出产物（在仓库根目录执行）：
#   cd app && flutter build web --release --no-web-resources-cdn && cd ..
#   docker build -f web/Dockerfile -t flowdo-web:latest .
#
# --no-web-resources-cdn 让 CanvasKit 跟着镜像走，不再去 gstatic 取，
# 内网和访问不了谷歌的网络都能正常渲染。
FROM nginx:1.27-alpine

COPY web/nginx.conf /etc/nginx/conf.d/default.conf
COPY app/build/web/ /usr/share/nginx/html/

# 少一个目录就会变成满屏方块，构建时先确认关键产物都在。
RUN test -f /usr/share/nginx/html/index.html \
  && test -f /usr/share/nginx/html/main.dart.js \
  && test -f /usr/share/nginx/html/assets/FontManifest.json \
  && test -f /usr/share/nginx/html/canvaskit/canvaskit.wasm

# 预压一份 .gz 给 gzip_static，首屏那个中文字体能小一半多。
RUN find /usr/share/nginx/html -type f \
  \( -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.html' \
  -o -name '*.wasm' -o -name '*.ttf' -o -name '*.otf' -o -name '*.svg' \) \
  -size +1k -exec gzip -9 -k {} +

EXPOSE 80
