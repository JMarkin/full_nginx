FROM debian:stable as builder

ARG NGINX_VER=1.20.1
ARG OPENSSL_VER=3.0.0
ARG HEADERMOD_VER=0.33
ARG LUA_JIT_VER=2.1-20181029
ARG LUA_NGINX_VER=0.10.14rc2
ARG NGINX_DEV_KIT=0.3.1
ARG NGINX_DYNTLS_VER=0.5
ARG NGINX_DYNTLS_PATCH=nginx__dynamic_tls_records_1.17.7+.patch
ARG LIBMAXMINDDB_VER=1.4.3
ARG GEOIP2_VER=3.3
ARG NGX_BROTLI_VER=v1.0.0rc

RUN mkdir -p /usr/local/src/nginx/modules && \
    apt-get update && \
    apt-get install -y --no-install-recommends build-essential ca-certificates wget curl libpcre3 libpcre3-dev autoconf unzip automake libtool tar git libssl-dev zlib1g-dev uuid-dev lsb-release libxml2-dev libxslt1-dev cmake pkg-config libgd-dev

# BROTLI
RUN cd /usr/local/src/nginx/modules || exit 1 && \
    git clone https://github.com/google/ngx_brotli && \
    cd ngx_brotli || exit 1 && \
    git checkout ${NGX_BROTLI_VER}  && \
    git submodule update --init

# MORE HEADERS
RUN cd /usr/local/src/nginx/modules || exit 1 && \
    wget https://github.com/openresty/headers-more-nginx-module/archive/v${HEADERMOD_VER}.tar.gz && \
    tar zxf v${HEADERMOD_VER}.tar.gz

# Cache purge
RUN cd /usr/local/src/nginx/modules || exit 1 && \
    git clone https://github.com/FRiCKLE/ngx_cache_purge

#LUA
RUN cd /usr/local/src/nginx/modules && \
    wget https://github.com/openresty/luajit2/archive/v${LUA_JIT_VER}.tar.gz && \
    tar zxf v${LUA_JIT_VER}.tar.gz && \
    cd luajit2-${LUA_JIT_VER} && \
    make -j "$(nproc)" && \
    make install && \
    # ngx_devel_kit download
    cd /usr/local/src/nginx/modules && \
    wget https://github.com/simplresty/ngx_devel_kit/archive/v${NGINX_DEV_KIT}.tar.gz && \
    tar zxf v${NGINX_DEV_KIT}.tar.gz && \
    #lua-nginx-module download
    cd /usr/local/src/nginx/modules && \
    wget https://github.com/openresty/lua-nginx-module/archive/v${LUA_NGINX_VER}.tar.gz && \
    tar zxf v${LUA_NGINX_VER}.tar.gz

# OpenSSL
RUN cd /usr/local/src/nginx/modules || exit 1 && \
    wget https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz && \
    tar zxf openssl-${OPENSSL_VER}.tar.gz && \
    cd openssl-${OPENSSL_VER} && \
    ./config

# GEOIP
RUN cd /usr/local/src/nginx/modules || exit 1 && \
    # install libmaxminddb
    wget https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VER}/libmaxminddb-${LIBMAXMINDDB_VER}.tar.gz && \
    tar xaf libmaxminddb-${LIBMAXMINDDB_VER}.tar.gz && \
    cd libmaxminddb-${LIBMAXMINDDB_VER}/ && \
    ./configure && \
    make -j "$(nproc)" && \
    make install && \
    ldconfig && \
    cd ../ && \
    wget https://github.com/leev/ngx_http_geoip2_module/archive/${GEOIP2_VER}.tar.gz && \
    tar zxf ${GEOIP2_VER}.tar.gz

#FANCYIDNEX
RUN git clone --quiet https://github.com/aperezdc/ngx-fancyindex.git /usr/local/src/nginx/modules/fancyindex

# VTS
RUN git clone --quiet https://github.com/vozlt/nginx-module-vts.git /usr/local/src/nginx/modules/nginx-module-vts

# RTMP
RUN git clone --quiet https://github.com/sergey-dryabzhinsky/nginx-rtmp-module.git /usr/local/src/nginx/modules/nginx-rtmp-module

RUN mkdir -p /etc/nginx

ENV NGINX_OPTIONS="--prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --user=nginx \
    --group=nginx \
    --with-cc-opt=-Wno-deprecated-declarations \
    --with-cc-opt=-Wno-ignored-qualifiers"

ENV NGINX_MODULES="--with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_mp4_module \
    --with-http_auth_request_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_sub_module \
    --with-http_xslt_module \
    --with-http_image_filter_module \
    --with-http_dav_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-ld-opt='-Wl,-rpath,/usr/local/lib/' \
    --add-module=/usr/local/src/nginx/modules/ngx_brotli \
    --add-module=/usr/local/src/nginx/modules/headers-more-nginx-module-${HEADERMOD_VER} \
    --add-module=/usr/local/src/nginx/modules/ngx_http_geoip2_module-${GEOIP2_VER} \
    --with-openssl=/usr/local/src/nginx/modules/openssl-${OPENSSL_VER} \
    --add-module=/usr/local/src/nginx/modules/ngx_cache_purge \
    --add-module=/usr/local/src/nginx/modules/ngx_devel_kit-${NGINX_DEV_KIT} \
    --add-module=/usr/local/src/nginx/modules/lua-nginx-module-${LUA_NGINX_VER} \
    --add-module=/usr/local/src/nginx/modules/fancyindex \
    --add-module=/usr/local/src/nginx/modules/nginx-rtmp-module \
    --add-module=/usr/local/src/nginx/modules/nginx-module-vts"

ENV LUAJIT_LIB=/usr/local/lib/
ENV LUAJIT_INC=/usr/local/include/luajit-2.1/
# Download and extract of Nginx source code

RUN cd /usr/local/src/nginx/ || exit 1 && \
    wget -qO- http://nginx.org/download/nginx-${NGINX_VER}.tar.gz | tar zxf - && \
    cd nginx-${NGINX_VER} && \
    ./configure $NGINX_OPTIONS $NGINX_MODULES && \
    make -j "$(nproc)" && \
    make install && \
    strip -s /usr/sbin/nginx

# Install Bad Bot Blocker
RUN wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O /usr/local/sbin/install-ngxblocker && \
    chmod +x /usr/local/sbin/install-ngxblocker && \
    cd /usr/local/sbin || exit 1 && \
    ./install-ngxblocker && \
    ./install-ngxblocker -x && \
    chmod +x /usr/local/sbin/setup-ngxblocker && \
    chmod +x /usr/local/sbin/update-ngxblocker && \
    ./setup-ngxblocker -e conf && \
    ./setup-ngxblocker -x -e conf

COPY ./nginx.conf /etc/nginx/nginx.conf

ARG WATCHMAN=v4.9.0

RUN git clone --quiet https://github.com/facebook/watchman.git -b ${WATCHMAN} --depth 1 && \
    cd watchman && \
    ./autogen.sh && \
    ./configure --enable-statedir=/tmp --without-python  --without-pcre --enable-lenient && \
    make -j "$(nproc)" && make install

RUN mkdir -p /libs && \
    cp /usr/local/lib/libmaxminddb* /libs && \
    cp /usr/local/lib/libluajit* /libs && \
    cp /usr/lib/x86_64-linux-gnu/libperl* /libs && \
    cp /usr/lib/x86_64-linux-gnu/libxml* /libs && \
    cp /usr/lib/x86_64-linux-gnu/libexslt* /libs && \
    cp /usr/lib/x86_64-linux-gnu/libgd* /libs && \
    cp /usr/lib/x86_64-linux-gnu/libxslt* /libs
# cp /tmp/watchman-${WATCHMAN}-linux/lib/* /libs

RUN mkdir -p /bins && \
    cp watchman/watchman /bins/

FROM debian:stable-slim as app
STOPSIGNAL SIGTERM

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    git vim cron ca-certificates curl libtiff5 libjpeg62-turbo libxpm4 libfontconfig1 libpng16-16 libicu67 && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /etc/nginx/sites-available && \
    mkdir -p /etc/nginx/sites-enabled && \
    mkdir -p /etc/nginx/conf.d && \
    mkdir -p /var/log/nginx && \
    touch /var/log/nginx/access.log && \
    touch /var/log/nginx/error.log

COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/local/sbin/setup-ngxblocker /usr/local/sbin/setup-ngxblocker
COPY --from=builder /usr/local/sbin/update-ngxblocker /usr/local/sbin/update-ngxblocker
COPY --from=builder /usr/local/sbin/install-ngxblocker /usr/local/sbin/install-ngxblocker
COPY --from=builder /libs /usr/local/lib/
COPY --from=builder /bins /usr/local/bin/

RUN chmod 755 /usr/local/bin/watchman


WORKDIR /etc/nginx

RUN echo "00 22 * * * /usr/local/sbin/update-ngxblocker -c /etc/nginx/botconf.d -n" | crontab - && \
    mkdir -p /etc/nginx/botconf.d/ && \
    mv /etc/nginx/conf.d/botblocker-nginx-settings.conf /etc/nginx/botconf.d/botblocker-nginx-settings.conf &&\
    mv /etc/nginx/conf.d/globalblacklist.conf /etc/nginx/botconf.d/globalblacklist.conf && \
    echo "\
    # YANDEX             \n\
    77.88.0.0/18      0; \n\
    87.250.224.0/19   0; \n\
    93.158.128.0/18   0; \n\
    95.108.128.0/17   0; \n\
    213.180.192.0/19  0; \n\
    87.250.255.243    0; \n " > /etc/nginx/bots.d/whitelist-ips.conf

COPY /default.conf /etc/nginx/sites-enabled/default.conf

COPY /notify.sh /notify.sh
COPY /run.sh /run.sh
RUN chmod +x /run.sh && chmod +x /notify.sh
CMD /run.sh
