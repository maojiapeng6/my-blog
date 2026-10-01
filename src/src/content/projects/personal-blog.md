---
title: "个人博客"
slug: personal-blog
published: 2026-09-30
draft: false
order: 90
description: "基于 Astro 的静态博客，Docker Compose 部署在自建 NAS 上，源码变更后自动检测并增量重建发布，含全站动效、动态背景与站内搜索。"
image: "/images/server-cover.png"
status: "completed"
tags:
  - Astro
  - Docker
  - Nginx
  - 前端
lang: "zh_CN"
link:
  - label: "GitHub"
    icon: "fa7-brands:github"
    value: "https://github.com/maojiapeng6"
---

## 项目概述

本站。一个自建、自部署、自动发布的静态博客，运行在自家的家庭数据中心上。

## 技术选型

| 层面 | 选择 | 理由 |
| --- | --- | --- |
| 框架 | Astro | 静态输出，没有数据库与后台，安全且快 |
| 主题 | Firefly | 组件丰富，支持动效、搜索、系列与项目页 |
| 部署 | Docker Compose | 配置即文件，可备份可迁移 |
| 托管 | Nginx | 静态资源缓存、gzip、正确 404 |
| 构建 | 容器内 Node 22 + pnpm | 与宿主机环境解耦 |

## 架构

```
源码（NAS 本地目录）
   ↓ 每 2 分钟检测文件指纹
builder 容器：git 同步 → pnpm install → astro build
   ↓ 构建产物原子替换
Nginx 容器（对外端口）
   ↓
反向代理 → 域名访问
```

关键点：**构建失败时保留上一版产物**，站点不会因为一次失败而挂掉。

## 我做了什么

- **自动化构建**：容器内轮询检测源码变化，变更后自动重建并原子替换产物，无需人工介入
- **双模式设计**：支持"本地编辑"与"远端仓库同步"两种模式，远端模式下先提交本地改动再合并远端，避免覆盖
- **性能优化**：视频 105 MB 压至 7.9 MB 并开启 faststart 边下边播；截图 PNG 转 JPG，体积降至约 1/10
- **视觉定制**：全站飘落动效、全屏动态壁纸、自定义动态背景视频、响应式布局
- **静态资源治理**：明确区分源码目录与 public 静态目录，避免资源 404

## 收获

把一个"能用"的站点做到"别人访问也顺畅"，中间要解决的是工程问题而不只是页面问题：体积、缓存、404 语义、构建容错、目录约定。这些都写进了博客文章里。
