# Peng 的个人技术博客

基于 [Astro](https://astro.build) 静态站点生成器搭建的个人博客，部署在家庭飞牛 NAS 上，
通过 Docker 双容器实现「源码变更 → 自动构建 → Nginx 发布」的无人值守流水线。

> 线上地址：https://blog.kfc666.ccwu.cc:45678

## 站点特性

- **Astro 深度定制**：导航栏、打赏（支付宝/微信收款码）、友链、Giscus 评论、
  动态壁纸与视频背景等模块均按个人需求改写
- **原创内容**：家用数据中心、Docker Compose 编排、Cloudflare Tunnel、
  Emby 影音库、Pygame 小游戏开发等 5 篇长文，全部为本人实操记录
- **双容器部署**：`node:22` 构建容器负责依赖安装与静态产物生成，
  `nginx:1.27-alpine` 容器只读对外提供服务，两者通过共享卷解耦
- **构建容错**：构建失败自动保留上一次可用产物，不会把线上站点搞挂

## 架构

```
                ┌────────────────── 飞牛 NAS (Docker) ──────────────────┐
写作/修改源码 ──▶│  firefly-builder (node:22)      firefly-web (nginx)  │
 (本地模式)     │  监控 /blog 变化 → pnpm build ──▶ /dist 共享卷(只读)   │──▶ :18080
                └───────────────────────────────────────────────────────┘
                                        │
                     Cloudflare Tunnel + 反向代理 ──▶ 公网 HTTPS 访问
```

## 快速开始

```bash
# 1. 克隆仓库到 NAS（或任意 Linux 主机）
git clone https://github.com/maojiapeng6/my-blog.git
cd my-blog

# 2. 启动（首次会自动 pnpm install + build，约 2-5 分钟）
docker compose up -d

# 3. 查看构建进度
docker logs -f firefly-builder

# 4. 访问
#    内网: http://<NAS IP>:18080
#    公网: 按你的域名/隧道配置
```

### 本地开发（不用 Docker）

```bash
cd src
pnpm install
pnpm dev      # http://localhost:4321
pnpm build    # 产物在 src/dist/
```

## 目录结构

```
my-blog/
├── docker-compose.yml      # 双容器编排（构建器 + Nginx）
├── nginx/
│   └── default.conf        # 静态站 rewrite 与缓存策略
├── scripts/
│   └── entrypoint.sh       # 自动构建脚本（支持本地/拉取/双向三种模式）
└── src/                    # Astro 源码
    ├── src/
    │   ├── config/         # 站点、导航、友链、打赏等配置
    │   ├── content/
    │   │   ├── posts/      # 博客文章（Markdown）
    │   │   └── projects/   # 项目展示卡
    │   └── pages/          # 页面路由
    └── public/
        └── assets/         # 图片 / 视频 / 音频等静态资源
```

## 自动构建脚本的三种模式

| AUTO_SYNC | 模式     | 行为                                         |
| --------- | -------- | -------------------------------------------- |
| `0`       | 本地模式 | 监控本地源码变化后重建（默认，当前使用）     |
| `1`       | 远端为准 | 定时拉取远端仓库并重建，本地改动会被覆盖     |
| `2`       | 双向模式 | 本地改动自动推送、远端更新自动拉取（推荐）   |

## 踩坑记录（都已固化在配置里）

- Nginx `try_files $uri $uri/ $uri/index.html =404;` 中 `$uri/` 不能删，
  删了带尾斜杠的文章地址会全部 404
- 构建产物由 root 写入，需 `chmod -R a+rX` 否则 Nginx 读不到（403）
- bind mount 的目录本身被 `rm -rf` 后，容器仍指向已删除的旧 inode，
  表现为容器内看到空目录——清理产物应删目录内容而非目录本身
- 需要频繁更换的图片（如收款码）要单独设短缓存例外，
  否则浏览器 `immutable` 缓存会让更新永不生效

## 相关仓库

- 站点主题基于开源项目 Firefly（MIT License，见 `src/LICENSE`）

## License

源码部分遵循原项目 License；文章内容与个人素材版权归我所有，转载请注明出处。
