#!/usr/bin/env bash
set -euo pipefail

# 从 upstream（fork 的原始仓库）拉取更新，合并后推送到自己的 fork（origin）。
#
# 流程：fetch upstream → merge upstream/<分支> → push origin/<分支>
#
# 用法：
#   ./scripts/sync-upstream.sh                # 默认 main 分支，合并并推送
#   ./scripts/sync-upstream.sh master         # 指定分支
#   ./scripts/sync-upstream.sh main --no-push # 只合并，不推送
#
# 前提：已添加 upstream remote，例如：
#   git remote add upstream https://github.com/mattpocock/skills.git

BRANCH="main"
PUSH=true

while [ $# -gt 0 ]; do
  case "$1" in
    --no-push) PUSH=false; shift;;
    -h|--help)
      echo "用法: $0 [分支名] [--no-push]"
      echo "  分支名     upstream 的分支名，默认 main"
      echo "  --no-push  只合并到本地，不推送到 origin"
      exit 0
      ;;
    -*) echo "未知参数: $1" >&2; exit 1;;
    *) BRANCH="$1"; shift;;
  esac
done

# 必须在 git 仓库内
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "错误：当前目录不在 git 仓库内。" >&2
  exit 1
fi

# 检查 upstream / origin 是否已配置
if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "错误：未配置 upstream remote。" >&2
  echo "请先添加：git remote add upstream <原始仓库地址>" >&2
  exit 1
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "错误：未配置 origin remote。" >&2
  exit 1
fi

# 显示两个 remote 地址，便于核对推拉方向是否正确
echo "upstream: $(git remote get-url upstream)"
echo "origin:   $(git remote get-url origin)"

# 工作区必须干净，否则合并/切换分支可能丢失改动或产生冲突
if [ -n "$(git status --porcelain)" ]; then
  echo "错误：工作区有未提交的改动，请先处理：" >&2
  git status --short >&2
  exit 1
fi

echo "==> 拉取 upstream 更新..."
git fetch upstream

# 确认本地分支存在
if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "错误：本地分支 '$BRANCH' 不存在。" >&2
  echo "可用分支：" >&2
  git branch >&2
  exit 1
fi

echo "==> 切换到 $BRANCH 分支..."
git checkout "$BRANCH"

echo "==> 合并 upstream/$BRANCH..."
if ! git merge "upstream/$BRANCH"; then
  echo "" >&2
  echo "错误：合并出现冲突，请手动解决后继续：" >&2
  echo "  git add <冲突文件>" >&2
  echo "  git commit" >&2
  echo "  git push origin $BRANCH" >&2
  exit 1
fi

if [ "$PUSH" = true ]; then
  echo "==> 推送到 origin/$BRANCH..."
  git push origin "$BRANCH"
  echo "完成：upstream/$BRANCH → 本地 $BRANCH → origin/$BRANCH 已同步。"
else
  echo "完成：已合并 upstream/$BRANCH 到本地（已跳过推送）。"
fi
