#!/bin/sh
set -e

# 1. 生成 config.yaml（原有）
envsubst < /home/node/app/config.template.yaml > /home/node/app/config.yaml

# 2. 强制修改配置（原有）
sed -i 's/^ *whitelistMode:.*$/whitelistMode: false/' /home/node/app/config.yaml
sed -i 's/^ *enableServerPlugins:.*$/enableServerPlugins: true/' /home/node/app/config.yaml
sed -i 's/^ *enableServerPluginsAutoUpdate:.*$/enableServerPluginsAutoUpdate: false/' /home/node/app/config.yaml
sed -i 's/^ *extensions\.enabled:.*$/extensions.enabled: true/' /home/node/app/config.yaml

# ========== 新增：WebDAV 自动备份/恢复（仅当变量存在时执行）==========
if [ -n "$WEBDAV_URL" ] && [ -n "$WEBDAV_USER" ] && [ -n "$WEBDAV_PASS" ]; then
    echo "配置 rclone 用于 WebDAV 同步..."

    # 使用临时配置文件，避免权限问题
    export RCLONE_CONFIG="/tmp/rclone.conf"
    
    # 创建 webdav remote（注意：这里用 rclone config create 比手动写配置更可靠）
    rclone config create webdav webdav vendor other url "$WEBDAV_URL" user "$WEBDAV_USER" pass "$(rclone obscure "$WEBDAV_PASS")" --config "$RCLONE_CONFIG" >/dev/null 2>&1

    # 尝试从 WebDAV 拉取数据（如果远程路径存在）
    if rclone ls webdav:/SillyTavernData --config "$RCLONE_CONFIG" >/dev/null 2>&1; then
        echo "从 WebDAV 恢复数据..."
        rclone sync webdav:/SillyTavernData /home/node/app/data --config "$RCLONE_CONFIG"
    else
        echo "WebDAV 中无数据，跳过恢复。"
    fi

    # 启动后台定时同步（每5分钟一次）
    echo "启动后台同步任务（每5分钟）..."
    (
        while true; do
            sleep 300
            echo "正在同步数据到 WebDAV..."
            rclone sync /home/node/app/data webdav:/SillyTavernData --update --verbose --config "$RCLONE_CONFIG"
        done
    ) &
else
    echo "未设置 WebDAV 环境变量，跳过自动备份。"
fi
# ========== 新增结束 ==========

# 3. 启动主应用（原有）
exec node server.js