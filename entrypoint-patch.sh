#!/bin/bash
# 单用户模式补丁脚本
# 在官方镜像启动时自动应用修改

set -e

echo "🔧 应用单用户模式补丁..."

# ===== 0. 检查并修复数据库文件 =====
DATABASE_FILE="/app/data/mumuai.db"
if [ -f "$DATABASE_FILE" ]; then
    chmod 666 "$DATABASE_FILE"
    echo "✅ 数据库文件已就绪: $DATABASE_FILE"
else
    echo "❌ 错误: 数据库文件不存在 - $DATABASE_FILE"
    exit 1
fi

# ===== 1. 修改认证中间件 =====
AUTH_MIDDLEWARE="/app/backend/app/middleware/auth_middleware.py"
if [ -f "$AUTH_MIDDLEWARE" ]; then
    cat > "$AUTH_MIDDLEWARE" << 'EOF'
"""
认证中间件 - 单用户模式
"""
from fastapi import Request
from app.logger import get_logger

logger = get_logger(__name__)

async def auth_middleware(request: Request, call_next):
    """单用户模式中间件，始终注入固定用户身份"""
    request.state.user_id = "single_user"
    request.state.is_admin = True
    logger.debug(f"单用户模式: user_id={request.state.user_id}, is_admin={request.state.is_admin}")
    response = await call_next(request)
    return response
EOF
    echo "✅ 认证中间件已修改"
fi

# ===== 2. 添加 get_single_user_id 函数 =====
DATABASE_PY="/app/backend/app/database.py"
if [ -f "$DATABASE_PY" ] && ! grep -q "def get_single_user_id" "$DATABASE_PY"; then
    cat >> "$DATABASE_PY" << 'EOF'

def get_single_user_id() -> str:
    """返回单用户模式下的固定用户ID"""
    return "single_user"
EOF
    echo "✅ 数据库模块已更新"
fi

# ===== 3. 简化认证 API =====
AUTH_API="/app/backend/app/api/auth.py"
if [ -f "$AUTH_API" ]; then
    cat > "$AUTH_API" << 'EOF'
"""
认证 API - 单用户模式简化版
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db

router = APIRouter(tags=["认证"])

@router.get("/health")
async def health_check(db: AsyncSession = Depends(get_db)):
    """健康检查端点"""
    return {"status": "healthy", "message": "单用户模式运行中"}
EOF
    echo "✅ 认证 API 已简化"
fi

# ===== 4. 修改配置文件 =====
CONFIG_PY="/app/backend/app/config.py"
if [ -f "$CONFIG_PY" ]; then
    sed -i 's/LOCAL_AUTH_ENABLED = True/LOCAL_AUTH_ENABLED = False/g' "$CONFIG_PY" 2>/dev/null || true
    sed -i 's/LOCAL_AUTH_ENABLED = true/LOCAL_AUTH_ENABLED = False/g' "$CONFIG_PY" 2>/dev/null || true
    sed -i 's/SESSION_EXPIRE_MINUTES = [0-9]*/SESSION_EXPIRE_MINUTES = 999999/g' "$CONFIG_PY" 2>/dev/null || true
    echo "✅ 配置文件已更新"
fi

# ===== 5. 修改启动脚本 =====
ENTRYPOINT="/app/backend/scripts/entrypoint.sh"
if [ -f "$ENTRYPOINT" ]; then
    # 移除数据库迁移相关命令
    sed -i '/等待数据库/d' "$ENTRYPOINT" 2>/dev/null || true
    sed -i '/alembic upgrade/d' "$ENTRYPOINT" 2>/dev/null || true
    sed -i '/数据库迁移/d' "$ENTRYPOINT" 2>/dev/null || true
    echo "✅ 启动脚本已更新"
fi

# ===== 6. 前端修改（移除登录相关）=====
FRONTEND_DIR="/app/frontend/dist"
if [ -d "$FRONTEND_DIR" ]; then
    rm -rf "$FRONTEND_DIR/login" 2>/dev/null || true
    rm -f "$FRONTEND_DIR/login.html" 2>/dev/null || true
    if [ -f "$FRONTEND_DIR/index.html" ]; then
        sed -i 's|"/login"|"/"|g' "$FRONTEND_DIR/index.html" 2>/dev/null || true
    fi
    echo "✅ 前端已更新"
fi

echo "✅ 所有补丁已应用完成！"
echo "🚀 启动应用..."

exec "$@"