# MuMuAINovel-Sync

> 🤖 基于官方镜像打补丁，自动生成单用户版本 + SQLite 数据库

---

## 📋 项目说明

本项目通过在官方镜像 `mumujie/mumuainovel:latest` 基础上打补丁的方式，生成可用的单用户版本。

### 主要功能

- 🔐 **单用户模式** - 自动注入固定用户身份，无需登录
- 🗄️ **SQLite 数据库** - 预生成数据库，开箱即用
- ⚙️ **环境变量配置** - 使用官方变量名 APP_PORT / APP_HOST

---

## 🔄 工作流程

```
官方代码更新 → GitHub Actions 自动检测
      ↓
1. 克隆官方代码 xiamuceer-j/MuMuAINovel
      ↓
2. 生成 SQLite 数据库（表结构）
      ↓
3. 保存到 data/mumuai.db
      ↓
用户构建镜像 → 基于官方镜像 + 补丁 + 数据库
```

---

## 📁 项目结构

```
.
├── Dockerfile                 # 基于官方镜像打补丁
├── entrypoint-patch.sh       # 启动时应用补丁脚本
├── .github/
│   └── workflows/
│       └── patch.yml         # 自动生成数据库的工作流
├── data/
│   ├── mumuai.db            # 预生成的 SQLite 数据库
│   └── official_commit      # 官方代码版本记录
└── README.md
```

---

## 🐳 构建镜像

```bash
# 构建镜像
docker build -t mumuainovel-singleuser .

# 运行（默认端口 7860）
docker run -d \
  --name mumuainovel \
  -p 7860:7860 \
  -e OPENAI_API_KEY=your_api_key_here \
  mumuainovel-singleuser

# 自定义端口（使用官方变量名）
docker run -d -p 8080:7860 -e APP_PORT=8080 -e OPENAI_API_KEY=xxx image
```

---

## ⚙️ 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `APP_PORT` | 7860 | 服务端口 |
| `APP_HOST` | 0.0.0.0 | 服务地址 |
| `DATABASE_URL` | sqlite+aiosqlite:///data/mumuai.db | 数据库路径 |
| `LOCAL_AUTH_ENABLED` | false | 禁用本地认证 |
| `OPENAI_API_KEY` | - | OpenAI API 密钥（必需） |

---

## 🤖 GitHub Actions

### 触发方式

- **自动**：每周日凌晨 2 点（UTC）检查官方代码更新
- **手动**：在 Actions 页面点击 "Run workflow"

### 所需 Secrets

| Secret | 用途 |
|--------|------|
| `DOCKER_USERNAME` | Docker Hub 用户名（用于拉取官方镜像） |
| `DOCKER_TOKEN` | Docker Hub 访问令牌 |

---

## 🔐 单用户化修改内容

entrypoint-patch.sh 自动应用以下修改：

- 认证中间件 → 始终注入 `user_id="single_user"`
- 认证 API → 简化为仅保留健康检查
- 配置文件 → `LOCAL_AUTH_ENABLED=false`
- 启动脚本 → 移除数据库迁移
- 前端 → 移除登录页面

---

## 📝 许可证

GPL-3.0 - 与原项目一致

---

> 🤖 此项目由 AI 协作开发维护