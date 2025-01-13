# Stage 1: Build Environment
FROM arm64v8/ubuntu:latest AS build

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for building
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    git \
    libtool \
    autoconf \
    automake \
    zlib1g-dev \
    libpcre3-dev \
    libssl-dev \
    patch \
    astyle \
    cmake \
    gcc \
    ninja-build \
    python3-pytest \
    python3-pytest-xdist \
    unzip \
    xsltproc \
    doxygen \
    graphviz \
    python3-yaml \
    valgrind && \
    # gcc-aarch64-linux-gnu && \
    apt-get clean

# Define working directory
WORKDIR /usr/src

# Build and install liboqs (version 0.12.0)
RUN git clone https://github.com/open-quantum-safe/liboqs.git && \
    cd liboqs && \
    git checkout 6f30d7ef49ca590979d7a085cd662f00bb6855fe && \
    mkdir build && cd build && \
    cmake -DOQS_USE_OPENSSL=0 .. && \
    make all && make install

# Build and install wolfSSL (version 5.7.4)
RUN git clone https://github.com/wolfSSL/wolfssl.git && \
    cd wolfssl && git checkout bdd62314f00fca0e216bf8c963c8eeff6327e0cb && ./autogen.sh && \
    ./configure --host=aarch64-linux-gnu --prefix=/usr/local --enable-nginx --enable-experimental --with-liboqs && \
    make && make all && make install

# Download and prepare Nginx source code
COPY nginx-1.21.4-wolfssl.patch nginx-1.21.4-wolfssl.patch
RUN wget http://nginx.org/download/nginx-1.21.4.tar.gz && tar -xvzf nginx-1.21.4.tar.gz

# Patch and build Nginx with wolfSSL support
RUN cd nginx-1.21.4 && patch -p1 < /usr/src/nginx-1.21.4-wolfssl.patch && \
    ./configure --with-wolfssl=/usr/local --with-http_ssl_module && make

# Stage 2: Runtime Environment
FROM arm64v8/ubuntu:latest AS runtime

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y libpcre3 zlib1g libssl-dev && apt-get clean

# Copy built components from the build stage
COPY --from=build /usr/local /usr/local
COPY --from=build /usr/src/nginx-1.21.4/objs/nginx /usr/local/nginx/sbin/nginx

# Copy Nginx configuration file (adjust as needed)
COPY conf/ /usr/local/nginx/conf/

# Expose port 443 for HTTPS
EXPOSE 443
COPY --from=build /usr/local/lib/libwolfssl.so* /usr/lib/
RUN mkdir /usr/local/nginx/logs
# Start Nginx server
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
