# Use a base image with required development tools
FROM ubuntu:20.04

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
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
    patch && \
    apt-get clean

# Install for liboqs
RUN  apt install -y astyle cmake gcc ninja-build libssl-dev python3-pytest python3-pytest-xdist unzip xsltproc doxygen graphviz python3-yaml valgrind

# Define working directory
WORKDIR /usr/src

# Liboqs 0.12.0
RUN git clone https://github.com/open-quantum-safe/liboqs.git && \
    cd liboqs && \
    git checkout 6f30d7ef49ca590979d7a085cd662f00bb6855fe && \
    mkdir build && cd build && \
    cmake -DOQS_USE_OPENSSL=0 .. && \
    make all && make install

# Download and build wolfSSL 5.7.4
RUN git clone https://github.com/wolfSSL/wolfssl.git
RUN cd wolfssl && git checkout bdd62314f00fca0e216bf8c963c8eeff6327e0cb && ./autogen.sh && \
    ./configure --prefix=/usr/local --enable-nginx  --enable-experimental --with-liboqs && \
    make && make all && make install

COPY nginx-1.21.4-wolfssl.patch nginx-1.21.4-wolfssl.patch
# Download and prepare Nginx source code
RUN wget http://nginx.org/download/nginx-1.21.4.tar.gz && \
    tar -xvzf nginx-1.21.4.tar.gz

RUN cd nginx-1.21.4 && patch -p1 < /usr/src/nginx-1.21.4-wolfssl.patch

# Build and install Nginx with wolfSSL support
RUN cd nginx-1.21.4 && \
    ./configure --with-wolfssl=/usr/local --with-http_ssl_module && \
    make && make install

# Expose port 443 for HTTPS
EXPOSE 443

# Copy a default nginx.conf (adjust as needed)
COPY conf/nginx.conf /usr/local/nginx/conf/nginx.conf

# Start Nginx server
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
