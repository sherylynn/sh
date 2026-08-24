#!/usr/bin/env bash
set -Eeuo pipefail

# 将旧版 Codex/自编译版的会话缓存迁移到官方 DEB 使用的 Chromium Default profile。
# 运行前必须手动退出官方 ChatGPT/Codex；脚本不会替用户强制结束程序。

readonly CODEX_ROOT="${HOME}/.config/Codex"
readonly LEGACY_STORAGE="${CODEX_ROOT}/Local Storage"
readonly OFFICIAL_PROFILE="${CODEX_ROOT}/Default"
readonly OFFICIAL_STORAGE="${OFFICIAL_PROFILE}/Local Storage"
readonly BACKUP_ROOT="${CODEX_ROOT}/migration-backups"

say() { printf '%s\n' "$*"; }
die() { printf '错误：%s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
用法：
  codex-migrate-official.sh --dry-run
  codex-migrate-official.sh --apply
  codex-migrate-official.sh --rollback <备份目录>

说明：
  --dry-run   只检查路径、进程和预计迁移内容，不修改文件。
  --apply     备份官方数据后，将旧版 Local Storage 导入官方 Default profile。
  --rollback  从指定备份恢复官方 Default/Local Storage。
EOF
}

active_processes() {
    ps -eo pid=,args= | rg '/usr/lib/chatgpt/ChatGPT|/usr/bin/chatgpt|/usr/local/bin/chatgpt' || true
}

require_closed() {
    local running
    running=$(active_processes)
    if [ -n "$running" ]; then
        say "检测到官方 ChatGPT/Codex 仍在运行："
        say "$running"
        die "请先手动完全退出官方程序，再重新运行本脚本。"
    fi
}

check_sources() {
    [ -d "$LEGACY_STORAGE/leveldb" ] || die "未找到旧版会话存储：$LEGACY_STORAGE/leveldb"
    [ -d "$OFFICIAL_PROFILE" ] || die "未找到官方 Default profile：$OFFICIAL_PROFILE"
}

show_plan() {
    say "旧版来源：      $LEGACY_STORAGE"
    say "官方目标：      $OFFICIAL_STORAGE"
    say "预计旧版大小：  $(du -sh "$LEGACY_STORAGE" | awk '{print $1}')"
    if [ -d "$OFFICIAL_STORAGE" ]; then
        say "官方现有大小：  $(du -sh "$OFFICIAL_STORAGE" | awk '{print $1}')"
    else
        say "官方现有大小：  不存在"
    fi
    say "迁移范围：      仅 Local Storage/leveldb；不覆盖官方 Cookies、登录状态和设置。"
}

apply_migration() {
    require_closed
    check_sources
    show_plan
    say ""
    read -r -p "确认备份官方数据并导入旧版会话？[y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { say "已取消。"; exit 0; }

    local stamp backup_dir
    stamp=$(date +%Y%m%d-%H%M%S)
    backup_dir="$BACKUP_ROOT/$stamp"
    mkdir -p "$backup_dir"

    say "正在备份旧版和官方数据到：$backup_dir"
    cp -a "$LEGACY_STORAGE" "$backup_dir/legacy-Local Storage"
    if [ -d "$OFFICIAL_STORAGE" ]; then
        cp -a "$OFFICIAL_STORAGE" "$backup_dir/official-Local Storage"
    fi

    if [ -e "$OFFICIAL_STORAGE" ]; then
        mv "$OFFICIAL_STORAGE" "$backup_dir/official-Local Storage-before-import"
    fi
    cp -a "$LEGACY_STORAGE" "$OFFICIAL_STORAGE"

    cat > "$backup_dir/README.txt" <<EOF
迁移时间：$stamp
旧版来源：$LEGACY_STORAGE
官方目标：$OFFICIAL_STORAGE
回滚命令：$0 --rollback "$backup_dir"
EOF
    say "迁移完成。官方程序下次启动将使用旧版会话缓存。"
    say "备份目录：$backup_dir"
}

rollback() {
    local backup_dir=${1:-}
    [ -n "$backup_dir" ] || die "请提供备份目录。"
    [ -d "$backup_dir" ] || die "备份目录不存在：$backup_dir"
    require_closed
    [ -d "$backup_dir/official-Local Storage-before-import" ] || die "备份中没有可恢复的官方 Local Storage。"

    local stamp
    stamp=$(date +%Y%m%d-%H%M%S)
    mkdir -p "$BACKUP_ROOT/rollback-$stamp"
    if [ -e "$OFFICIAL_STORAGE" ]; then
        mv "$OFFICIAL_STORAGE" "$BACKUP_ROOT/rollback-$stamp/official-Local Storage-current"
    fi
    cp -a "$backup_dir/official-Local Storage-before-import" "$OFFICIAL_STORAGE"
    say "已回滚官方 Local Storage。当前迁移后的数据另存于：$BACKUP_ROOT/rollback-$stamp"
}

case "${1:-}" in
    --dry-run)
        check_sources
        show_plan
        say "dry-run：未修改任何文件。"
        ;;
    --apply)
        apply_migration
        ;;
    --rollback)
        rollback "${2:-}"
        ;;
    -h|--help|"")
        usage
        [ -n "${1:-}" ] || exit 0
        ;;
    *)
        usage
        exit 2
        ;;
esac
