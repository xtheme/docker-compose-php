# 使用 GitLab Runner 基础镜像
FROM gitlab/gitlab-runner:latest

# 安裝 docker
RUN apt-get update && apt-get install -y docker.io

# 接收主机上的 Docker 群组 ID
ARG DOCKER_GROUP_ID

# 创建与主机 Docker 群组对应的群组，并将 gitlab-runner 用户加入其中
RUN groupadd -g $DOCKER_GROUP_ID docker_group -f \
    && usermod -aG $DOCKER_GROUP_ID gitlab-runner