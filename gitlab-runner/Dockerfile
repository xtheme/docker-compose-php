# 使用 GitLab Runner 基础镜像
FROM gitlab/gitlab-runner:latest

# 安裝 docker
RUN apt-get update && apt-get install -y docker.io

# 添加初始化脚本
RUN echo '#!/bin/sh\n\
    \n\
    chmod 666 /var/run/docker.sock\n\
    exit 0' > /etc/init.d/docker-sock-permissions

# 赋予脚本执行权限
RUN chmod +x /etc/init.d/docker-sock-permissions

# 将脚本添加到系统启动项
RUN ln -s /etc/init.d/docker-sock-permissions /etc/rc2.d/S99docker-sock-permissions
RUN ln -s /etc/init.d/docker-sock-permissions /etc/rc3.d/S99docker-sock-permissions
RUN ln -s /etc/init.d/docker-sock-permissions /etc/rc4.d/S99docker-sock-permissions
RUN ln -s /etc/init.d/docker-sock-permissions /etc/rc5.d/S99docker-sock-permissions

# 下面這行沒作用
# RUN update-rc.d docker-sock-permissions defaults
