FROM debian:stable as builder

ARG NGINX_VER=1.25.2
ARG OPENSSL_VER=3.1.2
ARG HEADERMOD_VER=0.34
ARG LIBMAXMINDDB_VER=1.7.1
ARG GEOIP2_VER=3.4

WORKDIR /tmp

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
    --with-http_v3_module \
    --with-http_mp4_module \
    --with-http_auth_request_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_sub_module \
    --with-http_xslt_module \
    --with-http_image_filter_module \
    --with-http_dav_module \
    --with-http_realip_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_gzip_static_module \
    --with-http_gunzip_module \
    --with-pcre-jit \
    --with-pcre \
    --with-ld-opt='-Wl,-rpath,/usr/local/lib/' \
    --add-module=/usr/local/src/nginx/modules/ngx_brotli \
    --add-module=/usr/local/src/nginx/modules/headers-more-nginx-module-${HEADERMOD_VER} \
    --add-module=/usr/local/src/nginx/modules/ngx_http_geoip2_module-${GEOIP2_VER} \
    --with-openssl=/usr/local/src/nginx/modules/openssl-${OPENSSL_VER} \
    --add-module=/usr/local/src/nginx/modules/ngx_cache_purge \
    --add-module=/usr/local/src/nginx/modules/fancyindex \
    --add-module=/usr/local/src/nginx/modules/nginx-rtmp-module \
    --add-module=/usr/local/src/nginx/modules/nginx-dav-ext-module \
    --add-module=/usr/local/src/nginx/modules/nginx-module-vts"

# Download and extract of Nginx source code

RUN mkdir -p /usr/local/src/nginx/modules && \
    apt-get update && \
    export devpkg="libpcre3-dev autoconf unzip automake libtool git libssl-dev zlib1g-dev libxml2-dev uuid-dev libxslt1-dev lsb-release libgd-dev cmake pkg-config build-essential" && \
    apt-get install -y --no-install-recommends cron ca-certificates wget curl libpcre3  libxml2	libxslt1.1 libgd3 watchman $devpkg && \
    cd /usr/local/src/nginx/modules || exit 1 && \
    git clone https://github.com/google/ngx_brotli && \
    cd ngx_brotli || exit 1 && \
    git submodule update --init && \
    cd /usr/local/src/nginx/modules || exit 1 && \
    wget https://github.com/openresty/headers-more-nginx-module/archive/v${HEADERMOD_VER}.tar.gz && \
    tar zxf v${HEADERMOD_VER}.tar.gz && \
    cd /usr/local/src/nginx/modules || exit 1 && \
    git clone https://github.com/FRiCKLE/ngx_cache_purge && \
    cd /usr/local/src/nginx/modules || exit 1 && \
    wget https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz && \
    tar zxf openssl-${OPENSSL_VER}.tar.gz && \
    cd openssl-${OPENSSL_VER} && \
    ./config && \
    cd /usr/local/src/nginx/modules || exit 1 && \
    wget https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VER}/libmaxminddb-${LIBMAXMINDDB_VER}.tar.gz && \
    tar xaf libmaxminddb-${LIBMAXMINDDB_VER}.tar.gz && \
    cd libmaxminddb-${LIBMAXMINDDB_VER}/ && \
    ./configure && \
    make -j "$(nproc)" && \
    make install && \
    ldconfig && \
    cd ../ && \
    wget https://github.com/leev/ngx_http_geoip2_module/archive/${GEOIP2_VER}.tar.gz && \
    tar zxf ${GEOIP2_VER}.tar.gz && \
    git clone --quiet https://github.com/aperezdc/ngx-fancyindex.git /usr/local/src/nginx/modules/fancyindex && \
    git clone --quiet https://github.com/vozlt/nginx-module-vts.git /usr/local/src/nginx/modules/nginx-module-vts && \
    git clone --quiet https://github.com/sergey-dryabzhinsky/nginx-rtmp-module.git /usr/local/src/nginx/modules/nginx-rtmp-module && \
    git clone --quiet https://github.com/arut/nginx-dav-ext-module.git /usr/local/src/nginx/modules/nginx-dav-ext-module && \
    cd /usr/local/src/nginx/ || exit 1 && \
    wget -qO- http://nginx.org/download/nginx-${NGINX_VER}.tar.gz | tar zxf - && \
    cd nginx-${NGINX_VER} && \
    ./configure $NGINX_OPTIONS $NGINX_MODULES && \
    make -j "$(nproc)" && \
    make install && \
    strip -s /usr/sbin/nginx && \
    cd /tmp && rm -rf /usr/local/src/nginx && \
    wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O /usr/local/sbin/install-ngxblocker && \
    chmod +x /usr/local/sbin/install-ngxblocker && \
    cd /usr/local/sbin || exit 1 && \
    ./install-ngxblocker && \
    ./install-ngxblocker -x && \
    chmod +x /usr/local/sbin/setup-ngxblocker && \
    chmod +x /usr/local/sbin/update-ngxblocker && \
    ./setup-ngxblocker -e conf && \
    ./setup-ngxblocker -x -e conf && \
    apt-get purge -y $devpkg && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./nginx.conf /etc/nginx/nginx.conf

STOPSIGNAL SIGTERM

RUN mkdir -p /var/cache/nginx && \
    mkdir -p /etc/nginx/sites-available && \
    mkdir -p /etc/nginx/sites-enabled && \
    mkdir -p /etc/nginx/conf.d && \
    mkdir -p /var/log/nginx && \
    mkdir -p /opt/geoip && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

WORKDIR /etc/nginx

RUN echo "00 22 * * * /usr/local/sbin/update-ngxblocker -c /etc/nginx/botconf.d -n" | crontab -
RUN echo "00 22 */4 * * /usr/local/sbin/download_geo" | crontab -

RUN groupadd -r nginx -g 1000 &&\
    useradd -u 1000 -r -g nginx -d /home/app -s /sbin/nologin -c "NGINX user" nginx

COPY --chown=nginx:nginx ./default.conf ./sites-enabled/default.conf
COPY --chown=nginx:nginx ./mime.types .
COPY --chown=nginx:nginx ./notify.sh /notify.sh
COPY --chown=nginx:nginx ./run.sh /run.sh
COPY --chown=nginx:nginx ./download_geo /usr/local/sbin/download_geo

CMD /run.sh


RUN chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx && \
    chown -R nginx:nginx /opt/geoip && \
    touch /run/nginx.pid && \
    chown -R nginx:nginx /run/nginx.pid && \
    chmod +x /run.sh && \
    chmod +x /notify.sh && \
    chmod +x /usr/local/sbin/download_geo && \
    chown -R nginx:nginx /var/log/nginx

USER nginx

VOLUME /opt/geoip
VOLUME /var/cache/nginx
