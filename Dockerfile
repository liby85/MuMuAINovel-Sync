# 在官方镜像基础上打补丁，生成单用户版本
ARG BASE_IMAGE=mumujie/mumuainovel:latest
FROM ${BASE_IMAGE}

# 设置环境变量（使用官方变量名，与官方保持一致）
ENV APP_PORT=7860
ENV APP_HOST=0.0.0.0
ENV DATABASE_URL=sqlite+aiosqlite:////data/mumuai.db
ENV LOCAL_AUTH_ENABLED=false

# 复制补丁脚本
COPY entrypoint-patch.sh /entrypoint-patch.sh
RUN chmod +x /entrypoint-patch.sh

# 复制预生成的 SQLite 数据库（官方路径：/data/）
COPY data/mumuai.db /data/mumuai.db
RUN chmod 666 /data/mumuai.db

# 复制官方代码版本记录
COPY data/official_commit /data/official_commit

# 设置入口点，启动时应用补丁
ENTRYPOINT ["/entrypoint-patch.sh"]