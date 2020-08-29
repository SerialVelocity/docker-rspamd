FROM debian:stable-slim AS rspamd

ARG RSPAMD_VERSION

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    apt-get clean

RUN wget -qO- "https://github.com/rspamd/rspamd/archive/${RSPAMD_VERSION}.tar.gz" | tar xz

RUN apt-get update && \
    apt-get install -y --no-install-recommends cmake g++ gcc libc6-dev libglib2.0-dev libhyperscan-dev libicu-dev libjemalloc-dev libluajit-5.1-dev libsodium-dev libssl-dev libsqlite3-dev libunwind-dev make pkg-config ragel && \
    apt-get clean

RUN mkdir /rspamd-build && \
    cd /rspamd-build && \
    cmake "/rspamd-${RSPAMD_VERSION}" -DENABLE_HYPERSCAN=ON -DENABLE_LUAJIT=ON -DENABLE_LIBUNWIND=ON -DENABLE_OPTIMIZATION=ON -DENABLE_JEMALLOC=ON -DCMAKE_BUILD_TYPE=RelWithDebuginfo && \
    make -j5

RUN cd /rspamd-build && \
    make DESTDIR=/pkg install



FROM debian:stable-slim AS s6-overlay

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    apt-get clean

RUN mkdir /pkg && \
    wget -qO- https://github.com/just-containers/s6-overlay/releases/download/v1.21.8.0/s6-overlay-amd64.tar.gz | tar xvz -C /pkg && \
    wget -qO- https://github.com/just-containers/socklog-overlay/releases/download/v3.1.0-2/socklog-overlay-amd64.tar.gz | tar xvz -C /pkg



FROM debian:stable-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends libc6 libglib2.0-0 libhyperscan5 libicu63 libluajit-5.1-2 libsodium23 libsqlite3-0 libssl1.1 libunwind8 && \
    apt-get clean

COPY --from=rspamd /pkg/ /
COPY --from=s6-overlay /pkg/ /

RUN groupadd -g 9993 _rspamd && \
    useradd -u 9993 -d /usr/local/lib/rspamd -g _rspamd -s /bin/false _rspamd


COPY rootfs/ /

ENTRYPOINT ["/init"]
CMD ["rspamd", "-f", "-u", "_rspamd", "-g", "_rspamd"]
