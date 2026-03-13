#!/bin/bash
# 单用户模式补丁脚本
# 在官方镜像启动时自动应用修改

set -e

echo "🔧 应用单用户模式补丁..."

# ===== 0. 配置环境变量（使用官方变量名）=====
export APP_PORT=${APP_PORT:-7860}
export APP_HOST=${APP_HOST:-0.0.0.0}
export DATABASE_URL=${DATABASE_URL:-sqlite+aiosqlite:////data/mumuai.db}
export LOCAL_AUTH_ENABLED=${LOCAL_AUTH_ENABLED:-false}

echo "📌 配置: APP_PORT=$APP_PORT, APP_HOST=$APP_HOST"
echo "📌 数据库: $DATABASE_URL"

# ===== 1. 检查并配置数据库 =====
DATABASE_FILE="/data/mumuai.db"
if [ -f "$DATABASE_FILE" ]; then
    chmod 666 "$DATABASE_FILE"
    echo "✅ 数据库文件已就绪: $DATABASE_FILE"
    mkdir -p /data
else
    echo "❌ 错误: 数据库文件不存在 - $DATABASE_FILE"
    exit 1
fi

# ===== 2. 修改认证中间件 =====  
# 路径: /app/app/middleware/auth_middleware.py
AUTH_MIDDLEWARE="/app/app/middleware/auth_middleware.py"
if [ -f "$AUTH_MIDDLEWARE" ]; then
    cat > "$AUTH_MIDDLEWARE" << 'EOF'
"""
认证中间件 - 单用户模式
"""
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from app.logger import get_logger

logger = get_logger(__name__)

# 单用户模式的虚拟 User 类
class FakeUser:
    def __init__(self):
        self.user_id = "single_user"
        self.username = "single_user"
        self.email = "single@local"
        self.is_admin = True
        self.trust_level = 1
        self.created_at = None
    def dict(self):
        return {
            "user_id": self.user_id,
            "username": self.username,
            "email": self.email,
            "is_admin": self.is_admin
        }

class AuthMiddleware(BaseHTTPMiddleware):
    """认证中间件（单用户模式）"""
    
    async def dispatch(self, request: Request, call_next):
        request.state.is_proxy_request = False
        request.state.proxy_instance_id = None
        request.state.user_id = "single_user"
        request.state.user = FakeUser()  # 假的 User 对象
        request.state.is_admin = True
        
        response = await call_next(request)
        return response
EOF
    # 验证语法
    python3 -m py_compile "$AUTH_MIDDLEWARE" && echo "✅ 认证中间件语法正确" || echo "❌ 认证中间件语法错误"
    echo "✅ 认证中间件已修改"
else
    echo "⚠️ 认证中间件不存在: $AUTH_MIDDLEWARE"
fi

# ===== 3. 添加 get_single_user_id 函数 =====
DATABASE_PY="/app/app/database.py"
if [ -f "$DATABASE_PY" ]; then
    if ! grep -q "def get_single_user_id" "$DATABASE_PY"; then
        cat >> "$DATABASE_PY" << 'EOF'

def get_single_user_id() -> str:
    """返回单用户模式下的固定用户ID"""
    return "single_user"
EOF
        echo "✅ 数据库模块已更新"
    fi
else
    echo "⚠️ 数据库模块不存在"
fi

# ===== 4. 简化认证 API =====  
AUTH_API="/app/app/api/auth.py"
if [ -f "$AUTH_API" ]; then
    cat > "$AUTH_API" << 'EOFAUTH'
"""
认证 API - 单用户模式简化版
"""
from fastapi import APIRouter

router = APIRouter(prefix="/auth", tags=["认证"])

@router.get("/health")
async def health_check():
    return {"status": "healthy", "message": "单用户模式运行中"}

@router.get("/user")
async def get_current_user():
    return {
        "user_id": "single_user",
        "username": "single_user", 
        "email": "single@local",
        "is_admin": True
    }
EOFAUTH
    echo "✅ 认证 API 已简化"
else
    echo "⚠️ 认证 API 不存在"
fi

# ===== 5. 修改配置文件 =====
CONFIG_PY="/app/app/config.py"
if [ -f "$CONFIG_PY" ]; then
    sed -i 's/LOCAL_AUTH_ENABLED = True/LOCAL_AUTH_ENABLED = False/g' "$CONFIG_PY" 2>/dev/null || true
    sed -i 's/LOCAL_AUTH_ENABLED = true/LOCAL_AUTH_ENABLED = False/g' "$CONFIG_PY" 2>/dev/null || true
    sed -i 's/SESSION_EXPIRE_MINUTES = [0-9]*/SESSION_EXPIRE_MINUTES = 999999/g' "$CONFIG_PY" 2>/dev/null || true
    echo "✅ 配置文件已更新"
fi

echo "✅ 所有补丁已应用完成！"
echo "🚀 启动应用 (端口: $APP_PORT)..."

# 启动应用
cd /app
exec uvicorn app.main:app \
    --host "${APP_HOST:-0.0.0.0}" \
    --port "${APP_PORT:-7860}" \
    --log-level info \
    --access-log \
    --use-colors