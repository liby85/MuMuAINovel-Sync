# 在官方镜像基础上打补丁，生成单用户版本
ARG BASE_IMAGE=mumujie/mumuainovel:latest
FROM ${BASE_IMAGE}

# 复制补丁脚本
COPY entrypoint-patch.sh /entrypoint-patch.sh
RUN chmod +x /entrypoint-patch.sh

# 复制预生成的 SQLite 数据库
COPY data/mumuai.db /app/data/mumuai.db
RUN chmod 666 /app/data/mumuai.db

# 设置入口点，启动时应用补丁
ENTRYPOINT ["/entrypoint-patch.sh"]
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]