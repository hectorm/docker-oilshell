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

# Build Oils
ARG OILS_VERSION=0.26.0
ARG OILS_TARBALL_URL=https://oils.pub/download/oils-for-unix-${OILS_VERSION}.tar.gz
ARG OILS_TARBALL_CHECKSUM=2b5b295a577a2763814203b4a34880ca03067a29eeb80af4857b6092314d6eed
RUN curl -Lo /tmp/oils.tgz "${OILS_TARBALL_URL:?}"
RUN printf '%s' "${OILS_TARBALL_CHECKSUM:?}  /tmp/oils.tgz" | sha256sum -c
RUN mkdir /tmp/oils/ && tar -xzf /tmp/oils.tgz --strip-components=1 -C /tmp/oils/
WORKDIR /tmp/oils/
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

# Copy Oils build
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
