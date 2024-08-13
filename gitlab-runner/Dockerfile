FROM gitlab/gitlab-runner

# 安裝docker
RUN curl -fsSL https://get.docker.com | sh

# 設置 Docker Socket 權限
RUN chmod 666 /var/run/docker.sock