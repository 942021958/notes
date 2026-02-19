# Base image
FROM ghcr.io/942021958/notes:main

# 安装 rclone（用于自动备份）
RUN apt-get update && apt-get install -y curl && \
    curl https://rclone.org/install.sh | bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch to root user to install tools and prepare the filesystem
USER root

# 1. Install 'gettext' and 'git'.
RUN apk add --no-cache gettext git

# 2. Create the data directory.
RUN mkdir -p /home/node/app/data

# 3. Copy the configuration template and the entrypoint script.
COPY config.template.yaml /home/node/app/config.template.yaml
COPY entrypoint.sh /home/node/app/entrypoint.sh

# --- Install the cloud-saves plugin EXACTLY as per the tutorial ---
# a. Define the target plugins directory specified by the tutorial.
ARG PLUGINS_DIR=/home/node/app/plugins

# b. Create the plugins directory.
RUN mkdir -p ${PLUGINS_DIR}

# c. Switch the working directory to the plugins folder.
WORKDIR ${PLUGINS_DIR}

# d. Run 'git clone' from within the plugins directory.
# This will create the 'cloud-saves' sub-directory automatically.
RUN git clone https://github.com/fuwei99/cloud-saves

# e. Switch the working directory into the newly created plugin folder.
WORKDIR ${PLUGINS_DIR}/cloud-saves

# f. Run 'npm install' to install dependencies.
RUN npm install

# g. Reset the working directory back to the application root.
WORKDIR /home/node/app
# --- End of plugin installation ---

# 4. Set ownership for the ENTIRE application directory to the 'node' user.
RUN chown -R node:node /home/node/app

# 5. Make the entrypoint script executable.
RUN chmod +x /home/node/app/entrypoint.sh

# 6. Switch to the final, non-privileged user.
USER node

# 7. Set the entrypoint to our script.
ENTRYPOINT ["/home/node/app/entrypoint.sh"]
