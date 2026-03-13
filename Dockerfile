# 在官方镜像基础上打补丁，生成单用户版本
ARG BASE_IMAGE=mumujie/mumuainovel:latest
FROM ${BASE_IMAGE}

# 设置环境变量
ENV APP_PORT=7860
ENV APP_HOST=0.0.0.0
ENV DATABASE_URL=sqlite+aiosqlite:////data/mumuai.db
ENV LOCAL_AUTH_ENABLED=false

# 复制补丁脚本
COPY entrypoint-patch.sh /entrypoint-patch.sh
RUN chmod +x /entrypoint-patch.sh

# 复制 alembic 配置和迁移脚本（用于生成数据库）
COPY backend/alembic-sqlite.ini /app/backend/alembic-sqlite.ini
COPY backend/alembic/sqlite /app/backend/alembic/sqlite

# 运行 alembic 生成数据库
RUN cd /app/backend && \
    python -c "import os; os.makedirs('/data', exist_ok=True)" && \
    alembic -c alembic-sqlite.ini upgrade head || true

# 确保数据库文件存在
RUN if [ -f /data/mumuai.db ]; then \
        echo "✅ 数据库已生成" && \
        chmod 666 /data/mumuai.db; \
    else \
        echo "⚠️ 数据库未生成，创建空文件" && \
        touch /data/mumuai.db; \
    fi

# 设置入口点
ENTRYPOINT ["/entrypoint-patch.sh"]