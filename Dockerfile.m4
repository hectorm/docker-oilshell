m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:20.04]], [[FROM docker.io/ubuntu:20.04]]) AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

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
ARG OILSHELL_VERSION=0.9.9
ARG OILSHELL_TARBALL_URL=https://www.oilshell.org/download/oil-${OILSHELL_VERSION}.tar.gz
ARG OILSHELL_TARBALL_CHECKSUM=e10b6de6da4bda27a012e0b5750a9bee8c7576bd0d75ec13385e1fcf01febafa
RUN curl -Lo /tmp/oilshell.tgz "${OILSHELL_TARBALL_URL:?}"
RUN printf '%s' "${OILSHELL_TARBALL_CHECKSUM:?}  /tmp/oilshell.tgz" | sha256sum -c
RUN mkdir /tmp/oilshell/ && tar -xzf /tmp/oilshell.tgz --strip-components=1 -C /tmp/oilshell/
WORKDIR /tmp/oilshell/
RUN ./configure --prefix=/usr --with-readline
RUN make -j"$(nproc)"
RUN ./install
RUN file /usr/bin/oil.ovm
RUN oil.ovm --version

##################################################
## "base" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:20.04]], [[FROM docker.io/ubuntu:20.04]]) AS base
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		libreadline8 \
		libtinfo6 \
	&& rm -rf /var/lib/apt/lists/*

# Copy Oil shell build
COPY --from=build --chown=root:root /usr/bin/oil.ovm /usr/bin/
RUN ln -rs /usr/bin/oil.ovm /usr/bin/oil
RUN ln -rs /usr/bin/oil.ovm /usr/bin/osh

# Set OSH as default shell
SHELL ["/usr/bin/osh", "-c"]
ENV SHELL=/usr/bin/osh
RUN chsh -s /usr/bin/osh

ENTRYPOINT ["/usr/bin/oil"]

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
