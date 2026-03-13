# 在官方镜像基础上打补丁，生成单用户版本
# 使用自定义 entrypoint 启动时应用修改

ARG BASE_IMAGE=xiamuceer-j/mumuainovel:latest
FROM ${BASE_IMAGE}

# 复制补丁脚本
COPY entrypoint-patch.sh /entrypoint-patch.sh
RUN chmod +x /entrypoint-patch.sh

# 设置入口点
ENTRYPOINT ["/entrypoint-patch.sh"]
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]