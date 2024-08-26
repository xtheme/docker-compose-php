# 使用 GitLab Runner 基础镜像
FROM gitlab/gitlab-runner:latest

# 安裝 docker
RUN apt-get update && apt-get install -y docker.io

# 將gitlab-runner添加到root group
RUN usermod -aG root gitlab-runner