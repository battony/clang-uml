FROM debian:12.9 AS builder

ARG nproc=4

ENV PATH=/opt/deps/bin:$PATH
ENV CPATH=/opt/deps/include:$CPATH
ENV LD_LIBRARY_PATH=/opt/deps/lib64:/opt/deps/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=/opt/deps/lib64/pkgconfig:/opt/deps/lib/pkgconfig:$PKG_CONFIG_PATH

WORKDIR /opt

RUN apt update && \
    apt install -y --no-install-suggests --no-install-recommends \
        git gnupg ca-certificates curl pkg-config openssh-client \
        g++ gcc cmake make ninja-build python3 \
        unzip && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

ARG yaml_version=0.7.0
RUN git clone https://github.com/jbeder/yaml-cpp.git \
        -b yaml-cpp-$yaml_version --depth 1 --recursive && \
    mkdir yaml-cpp/build && cd yaml-cpp/build && \
    cmake .. \
        -D CMAKE_INSTALL_PREFIX="/opt/deps" \
        -D CMAKE_BUILD_TYPE="release" && \
    cmake --build . -- -j$nproc && \
    cmake --install . && \
    rm -rf /opt/yaml-cpp

ARG clang_version
RUN curl -sfLo sources.zip --create-dirs \
        https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-$clang_version.zip && \
    unzip sources.zip > /dev/null && rm -rf sources.zip && \
    mv -f llvm-project-* llvm-project && \
    cd llvm-project && mkdir build && cd build && \
    cmake -S ../llvm \
        -D CMAKE_C_FLAGS="-latomic" \
        -D CMAKE_CXX_FLAGS="-latomic" \
        -D LLVM_ENABLE_PROJECTS="clang" \
        -D LLVM_ENABLE_RTTI=on \
        -D LLVM_BUILD_LLVM_DYLIB=off \
        -D CLANG_DEFAULT_CXX_STDLIB="libstdc++" \
        -D CMAKE_INSTALL_PREFIX="/opt/deps" \
        -D CMAKE_BUILD_TYPE="release" && \
    cmake --build . -- -j$nproc && \
    cmake --install . && \
    rm -rf /opt/llvm-project

ARG clang_uml_version
RUN git clone https://github.com/bkryza/clang-uml.git && \
    cd clang-uml && git checkout $clang_uml_version && \
    mkdir build && cd build && \
    cmake .. \
        -D BUILD_TESTS=off \
        -D CMAKE_INSTALL_PREFIX="/opt/deps" \
        -D CMAKE_BUILD_TYPE="release" && \
    cmake --build . -- -j$nproc && \
    cmake --install . && \
    rm -rf /opt/clang-uml

FROM debian:12.9-slim
COPY --from=builder /opt/deps/bin/clang-uml /usr/local/bin
