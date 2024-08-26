# 使用 GitLab Runner 基础镜像
FROM gitlab/gitlab-runner:latest

# 安裝 docker
RUN apt-get update && apt-get install -y docker.io

# 添加初始化脚本
RUN echo '#!/bin/sh\n\
    ### BEGIN INIT INFO\n\
    # Provides:          docker-sock-permissions\n\
    # Required-Start:    $remote_fs $syslog\n\
    # Required-Stop:     $remote_fs $syslog\n\
    # Default-Start:     2 3 4 5\n\
    # Default-Stop:      0 1 6\n\
    # Short-Description: Set permissions for Docker socket\n\
    # Description:       This script sets the permissions for the Docker socket\n\
    ### END INIT INFO\n\
    \n\
    chmod 666 /var/run/docker.sock\n\
    exit 0' > /etc/init.d/docker-sock-permissions

# 赋予脚本执行权限
RUN chmod +x /etc/init.d/docker-sock-permissions

# 将脚本添加到系统启动项
RUN update-rc.d docker-sock-permissions defaults
