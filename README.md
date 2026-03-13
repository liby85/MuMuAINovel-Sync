# MuMuAINovel-Sync

> 🤖 为魔搭空间（ModelScope）部署而改造的单用户版本

---

## 📋 项目说明

本项目基于 [xiamuceer-j/MuMuAINovel](https://github.com/xiamuceer-j/MuMuAINovel) 原版进行改造，专门适配魔搭空间的部署环境。

### 改造背景

魔搭空间从 Git 仓库构建 Docker 镜像时，**不支持二进制文件**（如 .db 数据库文件）上传。因此本项目采用**运行时生成数据库**的方式：通过 Alembic 迁移脚本在容器启动时自动初始化 SQLite 数据库。

### 主要功能

- 🔐 **单用户模式** - 内置登录验证（默认账号：admin/admin123）
- 🗄️ **SQLite 数据库** - 启动时自动初始化
- ⚙️ **环境变量配置** - 与官方保持一致
- 📱 **魔搭友好** - 无需上传大文件，直接构建部署

---

## 🙏 致谢

感谢原项目作者 [xiamuceer-j](https://github.com/xiamuceer-j) 的无私付出，本项目仅是对原作品的适配改造。

---

## 🔄 工作流程

```
官方代码更新 → GitHub Actions 自动检测
      ↓
1. 克隆官方代码 xiamuceer-j/MuMuAINovel
      ↓
2. 同步 Alembic 迁移文件
      ↓
3. 提交到本项目
      ↓
用户构建镜像 → 基于官方镜像 + 补丁 + 数据库
```

---

## 📁 项目结构

```
.
├── Dockerfile                 # 基于官方镜像打补丁
├── entrypoint-patch.sh       # 启动时应用补丁脚本
├── backend/
│   └── alembic/
│       └── sqlite/           # SQLite 迁移脚本
├── .github/
│   └── workflows/
│       ├── sync-alembic.yml  # 同步 Alembic 文件
│       └── patch.yml         # 构建工作流
└── README.md
```

---

## 🐳 构建与部署

### 本地构建

```bash
# 构建镜像
docker build -t mumuainovel-singleuser .

# 运行（默认端口 7860）
docker run -d \
  --name mumuainovel \
  -p 7860:7860 \
  -e OPENAI_API_KEY=your_api_key_here \
  mumuainovel-singleuser

# 自定义端口
docker run -d -p 8080:7860 -e APP_PORT=8080 -e OPENAI_API_KEY=xxx image
```

### 魔搭空间部署

1. 将本仓库链接到魔搭空间
2. 构建镜像会自动执行以下步骤：
   - 复制 Alembic 迁移文件到镜像
   - 启动时初始化 SQLite 数据库
   - 应用单用户补丁

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

## 🔐 登录说明

### 默认账号

| 用户名 | 密码 |
|--------|------|
| admin | admin123 |

### 修改密码

```bash
curl -X POST http://localhost:7860/api/auth/password/set \
  -H "Content-Type: application/json" \
  -d '{"new_password": "your_new_password"}'
```

---

## 🤖 GitHub Actions

### 工作流说明

| 工作流 | 功能 |
|--------|------|
| `sync-alembic.yml` | 每周自动同步官方 Alembic 迁移文件 |
| `patch.yml` | 构建时生成数据库（已集成到 Dockerfile） |

### 触发方式

- **自动**：每周日凌晨 2 点（UTC）检查官方代码更新
- **手动**：在 Actions 页面点击 "Run workflow"

---

## 📝 许可证

GPL-3.0 - 与原项目一致

---

## ⚠️ 注意事项

1. 首次启动时数据库会自动初始化（约几秒钟）
2. 如需迁移数据，请备份 `/data/mumuai.db` 文件
3. 修改密码后请妥善保管，忘记密码需要重建数据库

---

> 🤖 此项目由 AI 协作开发维护 | 感谢原作者的开源贡献