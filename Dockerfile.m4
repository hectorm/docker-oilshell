m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:24.04]], [[FROM docker.io/ubuntu:24.04]]) AS build

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		curl \
		file \
		libreadline-dev \
	&& rm -rf /var/lib/apt/lists/*

# Build Oil shell
ARG OILSHELL_VERSION=0.24.0
ARG OILSHELL_TARBALL_URL=https://www.oilshell.org/download/oils-for-unix-${OILSHELL_VERSION}.tar.gz
ARG OILSHELL_TARBALL_CHECKSUM=df4afed94d53b303a782ce0380c393d60f6d21921ef2a25922b400828add98f3
RUN curl -Lo /tmp/oilshell.tgz "${OILSHELL_TARBALL_URL:?}"
RUN printf '%s' "${OILSHELL_TARBALL_CHECKSUM:?}  /tmp/oilshell.tgz" | sha256sum -c
RUN mkdir /tmp/oilshell/ && tar -xzf /tmp/oilshell.tgz --strip-components=1 -C /tmp/oilshell/
WORKDIR /tmp/oilshell/
RUN ./configure --prefix=/usr
RUN ./_build/oils.sh
RUN ./install
RUN file /usr/bin/oils-for-unix
RUN osh --version
RUN ysh --version

##################################################
## "base" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:24.04]], [[FROM docker.io/ubuntu:24.04]]) AS base

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		libreadline8t64 \
		libtinfo6 \
	&& rm -rf /var/lib/apt/lists/*

# Copy Oil shell build
COPY --from=build --chown=root:root /usr/bin/oils-for-unix /usr/bin/
RUN ln -rs /usr/bin/oils-for-unix /usr/bin/osh
RUN ln -rs /usr/bin/oils-for-unix /usr/bin/ysh

# Set OSH as default shell
SHELL ["/usr/bin/osh", "-c"]
ENV SHELL=/usr/bin/osh
RUN chsh -s /usr/bin/osh

ENTRYPOINT ["/usr/bin/ysh"]

##################################################
## "test" stage
##################################################

FROM base AS test

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
	&& rm -rf /var/lib/apt/lists/*

# Run some complex scripts
RUN curl -fsSL 'https://raw.githubusercontent.com/dylanaraps/pfetch/0.6.0/pfetch' | osh
RUN curl -fsSL 'https://raw.githubusercontent.com/dylanaraps/neofetch/7.1.0/neofetch' | osh

##################################################
## "main" stage
##################################################

FROM base AS main

# Dummy instruction so BuildKit does not skip the test stage
RUN --mount=type=bind,from=test,source=/mnt/,target=/mnt/
