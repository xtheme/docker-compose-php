FROM gitlab/gitlab-runner:latest

# 安裝docker
RUN apt-get update && apt-get install -y docker.io

# 自定义 ENTRYPOINT 来添加权限调整并保持原有的 ENTRYPOINT 和 CMD
ENTRYPOINT ["/bin/sh", "-c", "chmod 666 /var/run/docker.sock && exec /usr/bin/dumb-init /entrypoint run --user=gitlab-runner --working-directory=/home/gitlab-runner"]