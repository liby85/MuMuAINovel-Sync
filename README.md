# MuMuAINovel-Sync

> 🤖 基于官方镜像打补丁，自动生成单用户版本 Docker 镜像

---

## 📋 项目说明

本项目通过**在官方 Docker 镜像上打补丁**的方式，自动生成单用户版本的 MuMuAINovel。

### 特点

- 🚀 **轻量级**：只存储补丁脚本，无需完整源代码
- 🔄 **自动化**：每周自动检查官方镜像更新并重建
- 🎯 **无侵入**：不修改官方镜像，基于官方镜像生成新镜像

---

## 🔄 自动化流程

```
官方镜像更新 → GitHub Actions 触发
      ↓
1. 拉取官方镜像 xiamuceer-j/mumuainovel:latest
      ↓
2. 基于镜像创建容器
      ↓
3. 启动时应用补丁脚本（entrypoint-patch.sh）
      ↓
4. 提交为新镜像
      ↓
5. 推送至 Docker Hub
```

---

## 📦 Docker 镜像

自动构建并推送至：

```
liby85/mumuainovel-singleuser:latest
```

### 快速使用

```bash
# 拉取镜像
docker pull liby85/mumuainovel-singleuser:latest

# 运行（需要预先准备好数据目录）
docker run -d \
  --name mumuainovel \
  -p 8000:8000 \
  -v ./data:/app/data \
  -v ./logs:/app/logs \
  -e OPENAI_API_KEY=your_api_key_here \
  liby85/mumuainovel-singleuser:latest
```

---

## 📁 项目结构

```
.
├── Dockerfile                 # 补丁构建配置
├── entrypoint-patch.sh       # 启动时自动应用的补丁脚本
├── .github/
│   └── workflows/
│       └── patch.yml         # GitHub Actions 工作流
└── README.md
```

---

## 🔧 工作原理

1. **继承官方镜像**：基于 `xiamuceer-j/mumuainovel:latest`
2. **自定义入口点**：使用 `entrypoint-patch.sh` 替代默认启动命令
3. **运行时修改**：容器启动时自动修改：
   - 认证中间件 → 单用户模式
   - 认证 API → 简化版（仅健康检查）
   - 配置文件 → 禁用本地认证
   - 前端 → 移除登录页面

---

## ⚙️ GitHub Actions 配置

### 所需 Secrets

在仓库 Settings → Secrets and variables → Actions 中添加：

| Secret | 用途 |
|--------|------|
| `DOCKER_USERNAME` | Docker Hub 用户名 |
| `DOCKER_TOKEN` | Docker Hub 访问令牌 |

### 触发方式

- **自动**：每周日凌晨 2 点（UTC）检查更新
- **手动**：在 Actions 页面点击 "Run workflow"

---

## 📝 许可证

GPL-3.0 - 与原项目一致

---

> 🤖 此项目由 AI 协作开发维护