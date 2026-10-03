#!/usr/bin/env bash
# ============================================================
#  Firefly 自动构建脚本（在 node:22 容器里运行）
#
#  三种模式，由环境变量 AUTO_SYNC 决定：
#    AUTO_SYNC=0（本地模式，默认）
#        不从远端拉取，只监控 /blog 里的文件变化，变了就重建
#    AUTO_SYNC=1（GitHub 模式，远端为准）
#        每 SYNC_INTERVAL 秒 git fetch，有新提交就 pull 后重建
#        注意：本地改动会被 reset --hard 覆盖
#    AUTO_SYNC=2（双向模式，推荐长期用）
#        本地改了 -> 自动 commit + push 到 GitHub
#        网页改了 -> 自动 fetch + rebase 拉取到本地
#        两边都改了同一文件 -> 以远端为准（避免卡死）
#        需要先用 github_setup.sh 推送一次并配好凭证
#
#  容错：构建失败保留上一次能用的网站，不会把站点搞挂
# ============================================================
set -uo pipefail

REPO_URL="${REPO_URL:-}"
BRANCH="${BRANCH:-master}"
INTERVAL="${SYNC_INTERVAL:-120}"
REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
AUTO_SYNC="${AUTO_SYNC:-0}"
SRC="${SRC:-/blog}"
OUT="${OUT:-/dist}"

log() { echo "[builder $(date '+%F %T')] $*"; }

# ---------- 1. 准备环境 ----------
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
corepack enable >/dev/null 2>&1 || true
export PNPM_HOME=/root/.local/share/pnpm
export PATH="$PNPM_HOME:$PATH"
printf 'registry=%s\n' "$REGISTRY" > /root/.npmrc

mkdir -p "$OUT"

# ---------- 2. 源码准备 ----------
if [ "$AUTO_SYNC" != "0" ]; then
  if ! command -v git >/dev/null 2>&1; then
    log "安装 git ..."
    apt-get update -qq && apt-get install -y -qq --no-install-recommends git ca-certificates
  fi
  git config --global --add safe.directory "$SRC"
  git config --global --add safe.directory "$(dirname "$SRC")" 2>/dev/null || true
  git config --global user.name "maojiapeng6" 2>/dev/null || true
  git config --global user.email "maojiapeng6@gmail.com" 2>/dev/null || true

  if [ -z "$REPO_URL" ]; then
    log "错误：AUTO_SYNC=1 但没有设置 REPO_URL"
    exit 1
  fi

  if [ ! -d "$SRC/.git" ] && [ ! -d "$SRC/../.git" ]; then
    log "首次运行，克隆仓库：$REPO_URL ($BRANCH)"
    for i in 1 2 3 4 5; do
      if git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$SRC"; then break; fi
      log "克隆失败，30 秒后重试 ($i/5)"
      sleep 30
    done
    if [ ! -d "$SRC/.git" ] && [ ! -d "$SRC/../.git" ]; then
      log "克隆彻底失败，容器退出。请检查网络/代理/仓库地址。"
      exit 1
    fi
  fi
else
  if [ ! -f "$SRC/package.json" ]; then
    log "错误：本地模式下 $SRC 里没有源码（缺 package.json）"
    exit 1
  fi
  log "本地模式：不使用远端仓库，只监控 $SRC 的文件变化"
fi

cd "$SRC" || exit 1

# ---------- 3. 构建函数 ----------
build() {
  log "===== 开始构建 ====="
  cd "$SRC" || return 1

  if [ ! -d node_modules ]; then
    log "安装依赖（首次 3~10 分钟）..."
    pnpm install --frozen-lockfile || pnpm install || return 1
  else
    pnpm install --frozen-lockfile >/dev/null 2>&1 || pnpm install || return 1
  fi

  log "编译静态站点（Astro build）..."
  if ! pnpm build; then
    log "!!!!! 构建失败，保留上一版网站不动。看容器日志里的具体报错 !!!!!"
    return 1
  fi

  if [ ! -f "$SRC/dist/index.html" ]; then
    log "!!!!! dist 里没有 index.html，构建异常，保留上一版 !!!!!"
    return 1
  fi

  find "$OUT" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
  cp -a "$SRC/dist/." "$OUT/"
  # 构建产物目录权限有时是 0700，nginx 用户读不到会整站 403/404
  chmod -R a+rX "$OUT"
  log "===== 构建完成，网站已更新 ====="
  return 0
}

# ---------- 4. 文件指纹（排除无关目录） ----------
snapshot() {
  find "$SRC" \
    -path '*/node_modules/*' -prune -o \
    -path '*/.git/*' -prune -o \
    -path '*/.astro/*' -prune -o \
    -path '*/dist/*' -prune -o \
    -type f -printf '%p %T@\n' 2>/dev/null | sort | md5sum | awk '{print $1}'
}

# ---------- 5. 双向同步（AUTO_SYNC=2） ----------
# 本地改动 -> commit + push；远端改动 -> fetch + rebase
sync_two_way() {
  cd "$SRC" || return 1
  git config --global --add safe.directory "$SRC" 2>/dev/null

  # 本地有改动就提交（node_modules 等已被 .gitignore 排除，不会产生噪音）
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    log "发现本地改动，提交"
    git add -A
    git commit -m "本地改动 $(date '+%F %T')" >/dev/null 2>&1 || true
  fi

  # 拉取远端
  if git fetch origin "$BRANCH" >/dev/null 2>&1; then
    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "none")
    REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "none")
    if [ "$REMOTE" != "none" ] && [ "$LOCAL" != "$REMOTE" ]; then
      log "远端有新内容，合并到本地"
      if ! git rebase "origin/$BRANCH" >/dev/null 2>&1; then
        log "自动合并有冲突，以远端为准"
        git rebase --abort >/dev/null 2>&1 || true
        git reset --hard "origin/$BRANCH" >/dev/null 2>&1
      fi
    fi
  else
    log "连接 GitHub 失败（网络问题？），本轮跳过远端同步"
  fi

  # 推送本地提交
  git push origin "HEAD:$BRANCH" >/dev/null 2>&1 || true
}

# ---------- 6. 主循环 ----------
if [ "$AUTO_SYNC" = "2" ]; then
  log "双向模式：启动时先同步一次"
  B0=$(snapshot)
  sync_two_way
  B1=$(snapshot)
  if [ ! -f "$OUT/index.html" ] || [ "$B0" != "$B1" ]; then build; fi
elif [ ! -f "$OUT/index.html" ]; then
  log "产物目录为空，立即执行首次构建"
  build
elif [ "$AUTO_SYNC" = "0" ]; then
  # 本地模式：源码比产物新就立即重建，不用傻等第一个轮询周期
  NEWEST=$(find "$SRC" \
    -path '*/node_modules/*' -prune -o \
    -path '*/.git/*' -prune -o \
    -path '*/.astro/*' -prune -o \
    -path '*/dist/*' -prune -o \
    -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1)
  OUTTIME=$(stat -c %Y "$OUT/index.html" 2>/dev/null || echo 0)
  if [ "${NEWEST:-0}" -gt "${OUTTIME:-0}" ]; then
    log "源码比现有产物新，立即重建"
    build
  fi
fi

LAST=$(snapshot)

while true; do
  sleep "$INTERVAL"

  if [ "$AUTO_SYNC" = "2" ]; then
    B0=$(snapshot)
    sync_two_way
    B1=$(snapshot)
    if [ "$B0" != "$B1" ] || [ ! -f "$OUT/index.html" ]; then
      if build; then LAST=$(snapshot); else log "构建失败，保留上一版"; fi
    fi
    continue
  fi

  if [ "$AUTO_SYNC" = "1" ]; then
    if ! git fetch --depth 1 origin "$BRANCH" >/dev/null 2>&1; then
      log "git fetch 失败（网络问题？），本轮跳过"
      continue
    fi
    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "none")
    REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "none")
    if [ "$LOCAL" = "$REMOTE" ]; then
      continue
    fi
    log "检测到新提交：$LOCAL -> $REMOTE"
    git reset --hard "origin/$BRANCH" >/dev/null 2>&1
    git clean -fdx -e node_modules -e .astro >/dev/null 2>&1
    build
    LAST=$(snapshot)
    continue
  fi

  # 本地模式：比较文件指纹，变了才重建
  NOW=$(snapshot)
  if [ "$NOW" != "$LAST" ]; then
    log "检测到本地文件变化，触发重建"
    if build; then
      LAST=$(snapshot)
    else
      log "本次构建失败，稍后重试（网站仍是上一版）"
    fi
  fi
done
