FROM ghcr.io/biliup/caution:latest
# Modify the Dockerfile to use Azure App Service's persistent storage location
WORKDIR /home/site/wwwroot

# Copy config and create directories
RUN mkdir -p /home/site/wwwroot/downloads \
    && mkdir -p /home/site/wwwroot/config

# Update entrypoint to use the new location
ENTRYPOINT ["biliup", "--data-dir", "/home/site/wwwroot/downloads"]
