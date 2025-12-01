FROM debian:jessie

# Proxy support (optional)
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ENV http_proxy=${HTTP_PROXY} https_proxy=${HTTPS_PROXY} no_proxy=${NO_PROXY}

# Archived Jessie repos; trust EOL mirrors and disable Valid-Until checks.
RUN printf 'deb [trusted=yes] http://archive.debian.org/debian/ jessie main contrib non-free\n' > /etc/apt/sources.list \
 && printf 'deb [trusted=yes] http://archive.debian.org/debian-security/ jessie/updates main non-free contrib\n' >> /etc/apt/sources.list \
 && printf 'deb [trusted=yes] http://archive.debian.org/debian jessie-backports main\n' >> /etc/apt/sources.list \
 && printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99no-check-valid \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    ca-certificates \
    curl \
    wget \
    xz-utils \
    perl \
    libffi-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    patchelf \
 && rm -rf /var/lib/apt/lists/*

# Build OpenSSL 1.0.2u into /usr/local/ssl (shared libs) to fix broken SSL in Jessie.
ENV OPENSSL_VER=1.0.2u
WORKDIR /tmp
RUN wget -q https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz -O /tmp/openssl.tgz \
 && tar -xf /tmp/openssl.tgz \
 && cd openssl-${OPENSSL_VER} \
 && ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl shared zlib \
 && make -j"$(nproc)" \
 && make install \
 && echo "/usr/local/ssl/lib" > /etc/ld.so.conf.d/openssl-${OPENSSL_VER}.conf \
 && ldconfig \
 && cd / && rm -rf /tmp/openssl-${OPENSSL_VER} /tmp/openssl.tgz

# Build Python 3.8.x with shared lib and rpath to custom OpenSSL.
ENV PY_VER=3.8.18
ENV PY_PREFIX=/usr/local/python-${PY_VER}
ENV CPPFLAGS=-I/usr/local/ssl/include
ENV LDFLAGS=-Wl,-rpath,/usr/local/ssl/lib\ -L/usr/local/ssl/lib
ENV LD_LIBRARY_PATH=/usr/local/ssl/lib
RUN wget -q https://www.python.org/ftp/python/${PY_VER}/Python-${PY_VER}.tgz \
 && tar -xf Python-${PY_VER}.tgz \
 && cd Python-${PY_VER} \
 && LDFLAGS="$LDFLAGS -Wl,-rpath,${PY_PREFIX}/lib" \
    ./configure --prefix=${PY_PREFIX} --enable-shared --with-ensurepip=install \
 && make -j"$(nproc)" \
 && make install \
 && ln -sf ${PY_PREFIX}/bin/python3 /usr/local/bin/python3 \
 && ln -sf ${PY_PREFIX}/bin/pip3 /usr/local/bin/pip3 \
 && echo "${PY_PREFIX}/lib" > /etc/ld.so.conf.d/python-${PY_VER}.conf \
 && ldconfig \
 && cd / && rm -rf /tmp/Python-${PY_VER} /tmp/Python-${PY_VER}.tgz

# Verify SSL
ENV PATH=${PY_PREFIX}/bin:$PATH
RUN python3 -c "import ssl,sys; print(sys.version); print(ssl.OPENSSL_VERSION)"

# Install PyInstaller and common build/runtime deps.
RUN python3 -m ensurepip --upgrade \
 && python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel \
 && python3 -m pip install --no-cache-dir \
      pyinstaller==5.13.2

WORKDIR /work
ENV PYTHONDONTWRITEBYTECODE=1 HOME=/tmp
CMD ["bash"]
