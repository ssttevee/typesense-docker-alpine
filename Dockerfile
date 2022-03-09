FROM alpine:3.15

RUN apk add --update --no-cache \
        build-base \
        cmake \
        bash \
        perl \
        libelf-static \
        elfutils-dev \
        curl \
        git \
        openssl-libs-static \
        openssl-dev \
        linux-headers \
        snappy-static \
        snappy-dev \
        libuv-static \
        libuv-dev \
        brotli-static \
        brotli-dev \
        libcap-static \
        libcap-dev \
        curl-static \
        curl-dev \
        icu-static \
        icu-dev \
        libunwind-static \
        libunwind-dev \
        nghttp2-static \
        nghttp2-dev \
        libexecinfo-static \
        libexecinfo-dev \
        zlib-static \
        zlib-dev

WORKDIR /build

RUN curl -sL https://github.com/gflags/gflags/archive/refs/tags/v2.2.2.tar.gz | tar zx && \
    cmake -Hgflags-2.2.2 -Bgflags-2.2.2/build \
        -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) -C gflags-2.2.2/build && \
    make -C gflags-2.2.2/build install && \
    rm -rf gflags-2.2.2

RUN curl -sL https://github.com/google/glog/archive/refs/tags/v0.5.0.tar.gz | tar zx && \
    cmake -Hglog-0.5.0 -Bglog-0.5.0/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        -DWITH_GFLAGS=ON \
        -DWITH_TLS=OFF \
        -DWITH_UNWIND=OFF \
        -DBUILD_SHARED_LIBS=OFF && \
    make -j$(nproc) -C glog-0.5.0/build && \
    make -C glog-0.5.0/build install && \
    rm -rf glog-0.5.0

RUN git clone --recurse-submodules --single-branch --branch 1.23 --depth 1 https://github.com/google/leveldb.git && \
    cmake -Hleveldb -Bleveldb/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DLEVELDB_BUILD_BENCHMARKS=OFF \
        -DLEVELDB_BUILD_TESTS=OFF && \
    make -j$(nproc) -C leveldb/build && \
    make -C leveldb/build install && \
    rm -rf leveldb

RUN curl -sL https://github.com/protocolbuffers/protobuf/releases/download/v3.12.4/protobuf-cpp-3.12.4.tar.gz | tar zx && \
    cmake -Hprotobuf-3.12.4/cmake -Bprotobuf-3.12.4/build \
        -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) -C protobuf-3.12.4/build && \
    make -C protobuf-3.12.4/build install && \
    rm -rf protobuf-3.12.4

COPY patches/brpc-0.9.7-rc03.patch /patches/brpc-0.9.7-rc03.patch

RUN curl -sL https://github.com/apache/incubator-brpc/archive/0.9.7-rc03.tar.gz | tar zx && \
    curl -sL -o incubator-brpc-0.9.7-rc03/src/CMakeLists.txt https://raw.githubusercontent.com/typesense/typesense/v0.22.1/docker/patches/brpc_cmakelists.txt && \
    ( \
        cd incubator-brpc-0.9.7-rc03 && \
        sed -i 's/__BEGIN_DECLS/#ifdef __cplusplus\nextern "C" {\n#endif\n/g;s/__END_DECLS/#ifdef __cplusplus\n}\n#endif\n/g' src/butil/compat.h src/bthread/errno.h src/bthread/condition_variable.h src/bthread/mutex.h src/bthread/unstable.h src/bthread/id.h src/butil/endpoint.cpp src/bthread/bthread.h && \
        patch -p1 < /patches/brpc-0.9.7-rc03.patch \
    ) && \
    cmake -Hincubator-brpc-0.9.7-rc03 -Bincubator-brpc-0.9.7-rc03/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DWITH_DEBUG_SYMBOLS=OFF \
        -DWITH_GLOG=ON && \
    sed -i 's|-lrt $|-lrt /usr/lib/libexecinfo.a /usr/lib/libcrypto.a /usr/lib/libsnappy.a|' incubator-brpc-0.9.7-rc03/build/tools/parallel_http/CMakeFiles/parallel_http.dir/link.txt incubator-brpc-0.9.7-rc03/build/tools/rpc_press/CMakeFiles/rpc_press.dir/link.txt incubator-brpc-0.9.7-rc03/build/tools/rpc_replay/CMakeFiles/rpc_replay.dir/link.txt incubator-brpc-0.9.7-rc03/build/tools/rpc_view/CMakeFiles/rpc_view.dir/link.txt incubator-brpc-0.9.7-rc03/build/tools/trackme_server/CMakeFiles/trackme_server.dir/link.txt && \
    make -j$(nproc) CXX_DEFINES=-D_POSIX_SOURCE -C incubator-brpc-0.9.7-rc03/build && \
    make -C incubator-brpc-0.9.7-rc03/build install && \
    rm -rf incubator-brpc-0.9.7-rc03 /patches

COPY patches/braft-c649789.patch /patches/braft-c649789.patch

RUN curl -sL https://github.com/typesense/braft/archive/c649789.tar.gz | tar zx && \
    curl -sL -o braft-c649789133566dc06e39ebd0c69a824f8e98993a/src/CMakeLists.txt https://raw.githubusercontent.com/typesense/typesense/v0.22.1/docker/patches/braft_cmakelists.txt && \
    ( \
        cd braft-c649789133566dc06e39ebd0c69a824f8e98993a && \
        patch -p1 < /patches/braft-c649789.patch \
    ) && \
    cmake -Hbraft-c649789133566dc06e39ebd0c69a824f8e98993a -Bbraft-c649789133566dc06e39ebd0c69a824f8e98993a/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DWITH_DEBUG_SYMBOLS=OFF \
        -DBRPC_WITH_GLOG=ON && \
    sed -i 's|-lrt -Xlinker|-lrt /usr/lib/libexecinfo.a /usr/lib/libsnappy.a -Xlinker|' braft-c649789133566dc06e39ebd0c69a824f8e98993a/build/tools/CMakeFiles/braft_cli.dir/link.txt && \
    make -j$(nproc) -C braft-c649789133566dc06e39ebd0c69a824f8e98993a/build && \
    make -C braft-c649789133566dc06e39ebd0c69a824f8e98993a/build install && \
    rm -rf braft-c649789133566dc06e39ebd0c69a824f8e98993a /patches

RUN curl -sL https://github.com/typesense/typesense/archive/refs/tags/v0.22.2.tar.gz | tar zx && \
    sed -i "s|make \"static_lib|make -j$(nproc) \"static_lib|" typesense-0.22.2/cmake/RocksDB.cmake && \
    sed -i "s|make \"build_lib_static|make -j$(nproc) \"build_lib_static|" typesense-0.22.2/cmake/Jemalloc.cmake && \
    sed -i "s|--target s2|--target s2 --parallel $(nproc)|" typesense-0.22.2/cmake/s2.cmake && \
    cmake -Htypesense-0.22.2 -Btypesense-0.22.2/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DTYPESENSE_VERSION=0.22.1 && \
    sed -i 's|-lrt -lpthread|-lrt /usr/lib/libexecinfo.a /usr/lib/libnghttp2.a /usr/lib/libbrotlidec.a /usr/lib/libbrotlicommon.a -lpthread|' typesense-0.22.2/build/CMakeFiles/typesense-server.dir/link.txt

COPY patches/typesense-0.22.2.patch /patches/typesense-0.22.2.patch

RUN ( \
        cd typesense-0.22.2 && \
        patch -p1 < /patches/typesense-0.22.2.patch \
    ) && \
    make -j$(nproc) -C typesense-0.22.2/build typesense-server && \
    strip typesense-0.22.2/build/typesense-server

FROM alpine:3.15

COPY --from=0 /build/typesense-0.22.2/build/typesense-server /opt/typesense-server

EXPOSE 8108

ENTRYPOINT ["/opt/typesense-server"]
