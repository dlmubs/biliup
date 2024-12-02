# Build biliup's web-ui
FROM node:lts as webui
ARG repo_url=https://github.com/biliup/biliup
ARG branch_name=master
RUN set -eux; \
	git clone --depth 1 --branch "$branch_name" "$repo_url"; \
	cd biliup; \
	npm install; \
	npm run build

# Deploy Biliup
FROM python:3.12-slim as biliup
ARG repo_url=https://github.com/biliup/biliup
ARG branch_name=master
ENV TZ=Asia/Shanghai
EXPOSE 19159/tcp
VOLUME /opt

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	useApt=false; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		wget \
		xz-utils \
	; \
	apt-mark auto '.*' > /dev/null; \
	\
	arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
	url='https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2023-10-31-14-21/'; \
	case "$arch" in \
		'amd64') \
			url="${url}ffmpeg-N-112565-g55f28eb627-linux64-gpl.tar.xz"; \
		;; \
		'arm64') \
			url="${url}ffmpeg-N-112565-g55f28eb627-linuxarm64-gpl.tar.xz"; \
		;; \
		*) \
			useApt=true; \
		;; \
	esac; \
	\
	if [ "$useApt" = true ] ; then \
		apt-get install -y --no-install-recommends \
			ffmpeg \
		; \
	else \
		wget -O ffmpeg.tar.xz "$url" --progress=dot:giga; \
		tar -xJf ffmpeg.tar.xz -C /usr/local --strip-components=1; \
		rm -rf \
			/usr/local/doc \
			/usr/local/man; \
		rm -rf \
			/usr/local/bin/ffplay; \
		rm -rf \
			ffmpeg*; \
		chmod a+x /usr/local/* ; \
	fi; \
	\
	# Clean up \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf \
		/tmp/* \
		/usr/share/doc/* \
		/var/cache/* \
		/var/lib/apt/lists/* \
		/var/tmp/* \
		/var/log/*

RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends git g++; \
	git clone --depth 1 --branch "$branch_name" "$repo_url"; \
	cd biliup && \
	pip3 install --no-cache-dir quickjs && \
	pip3 install -e . && \
	\
	# Clean up \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf \
		/tmp/* \
		/usr/share/doc/* \
		/var/cache/* \
		/var/lib/apt/lists/* \
		/var/tmp/* \
		/var/log/*

COPY --from=webui /biliup/biliup/web/public/ /biliup/biliup/web/public/

# Copy config.yaml from public folder to /opt
COPY --from=webui /biliup/public/config.yaml /opt/config.yaml

# Copy cookies.json if it exists in the repo
COPY --from=webui /biliup/cookies.json /opt/cookies.json

# Set working directory
WORKDIR /opt

# Add entrypoint script to handle config and cookies
RUN echo '#!/bin/sh\n\
if [ ! -f /opt/config.yaml ]; then\n\
    cp /opt/config.yaml.default /opt/config.yaml\n\
fi\n\
if [ -f /opt/cookies.json ]; then\n\
    exec biliup --config /opt/config.yaml "$@"\n\
else\n\
    echo "Warning: cookies.json not found. Some upload features may be limited."\n\
    exec biliup --config /opt/config.yaml "$@"\n\
fi' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]


