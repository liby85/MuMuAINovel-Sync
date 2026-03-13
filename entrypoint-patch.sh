#!/bin/bash
# 单用户模式补丁脚本
# 在官方镜像启动时自动应用修改

set -e

echo "🔧 应用单用户模式补丁..."

# ===== 0. 配置环境变量 =====
export APP_PORT=${APP_PORT:-7860}
export APP_HOST=${APP_HOST:-0.0.0.0}
export DATABASE_URL=${DATABASE_URL:-sqlite+aiosqlite:////data/mumuai.db}
export LOCAL_AUTH_ENABLED=${LOCAL_AUTH_ENABLED:-false}

echo "📌 配置: APP_PORT=$APP_PORT, APP_HOST=$APP_HOST"
echo "📌 数据库: $DATABASE_URL"

# ===== 1. 初始化数据库 =====
DB_FILE="/data/mumuai.db"
mkdir -p /data

if [ -f "$DB_FILE" ]; then
    echo "✅ 数据库文件已存在: $DB_FILE"
else
    echo "📦 初始化数据库..."
    cd /app/backend
    alembic -c alembic-sqlite.ini upgrade head
    chmod 666 "$DB_FILE"
    echo "✅ 数据库初始化完成"
fi

# ===== 2. 确保 admin 用户存在 =====
python3 << 'PYEOF'
import sqlite3
import hashlib
import os

db_path = "/data/mumuai.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='users'")
if not cursor.fetchone():
    print("⚠️ users 表不存在")
    conn.close()
    exit(0)

cursor.execute("SELECT user_id FROM users WHERE username = 'admin'")
if cursor.fetchone():
    print("ℹ️ admin 用户已存在")
else:
    password = "admin123"
    salt = os.urandom(16).hex()
    hashed = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 100000).hex()
    pwd_hash = f"pbkdf2:sha256:100000${salt}${hashed}"
    
    cursor.execute("""
        INSERT INTO users (user_id, username, email, password, is_admin, trust_level)
        VALUES (?, ?, ?, ?, ?, ?)
    """, ("admin", "admin", "admin@local", pwd_hash, 1, 1))
    conn.commit()
    print("✅ admin 用户已创建（密码: admin123）")

conn.close()
PYEOF

# ===== 3. 修改认证中间件 =====
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
    async def dispatch(self, request: Request, call_next):
        request.state.is_proxy_request = False
        request.state.proxy_instance_id = None
        request.state.user_id = "single_user"
        request.state.user = FakeUser()
        request.state.is_admin = True
        
        response = await call_next(request)
        return response
EOF
    python3 -m py_compile "$AUTH_MIDDLEWARE" && echo "✅ 认证中间件语法正确" || echo "❌ 认证中间件语法错误"
    echo "✅ 认证中间件已修改"
else
    echo "⚠️ 认证中间件不存在"
fi

# ===== 4. 添加认证 API =====
AUTH_API="/app/app/api/auth.py"
if [ -f "$AUTH_API" ]; then
    cat > "$AUTH_API" << 'EOFAUTH'
"""
认证 API - 单用户模式（支持登录验证）
"""
import hashlib
import sqlite3
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

router = APIRouter(prefix="/auth", tags=["认证"])

DB_PATH = "/data/mumuai.db"

class LoginRequest(BaseModel):
    username: str
    password: str

class PasswordSetRequest(BaseModel):
    new_password: str

def verify_password_DB(username: str, password: str) -> bool:
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT password FROM users WHERE username = ?", (username,))
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            return False
            
        pwd_hash = row[0]
        if pwd_hash.startswith("pbkdf2:sha256:"):
            parts = pwd_hash.split("$")
            if len(parts) == 3:
                salt = parts[1]
                stored_hash = parts[2]
                new_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 100000).hex()
                return new_hash == stored_hash
        return False
    except Exception as e:
        print(f"验证密码错误: {e}")
        return False

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

@router.post("/login")
async def login(request: LoginRequest):
    if verify_password_DB(request.username, request.password):
        return {"success": True, "message": "登录成功", "user": {"username": request.username}}
    raise HTTPException(status_code=401, detail="用户名或密码错误")

@router.post("/password/set")
async def set_password(req: PasswordSetRequest, request: Request):
    try:
        import os
        salt = os.urandom(16).hex()
        hashed = hashlib.pbkdf2_hmac('sha256', req.new_password.encode(), bytes.fromhex(salt), 100000).hex()
        pwd_hash = f"pbkdf2:sha256:100000${salt}${hashed}"
        
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("UPDATE users SET password = ? WHERE username = 'admin'", (pwd_hash,))
        conn.commit()
        conn.close()
        
        return {"success": True, "message": "密码修改成功"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"修改密码失败: {str(e)}")
EOFAUTH
    echo "✅ 认证 API 已更新"
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