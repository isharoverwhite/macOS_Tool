#!/bin/bash
# etool — macOS Tool Collection Updater
# Cài tại: ~/.local/bin/etool
# So sánh code đã cài trên máy với bản mới nhất trên GitHub.
# Dùng: etool check | etool update [tool_name]

set -uo pipefail

REPO_RAW="https://raw.githubusercontent.com/isharoverwhite/macOS_Tool/main"
INSTALL_DIR="$HOME/.local/bin"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

info()    { echo -e "${CYAN}  →${NC} $*"; }
success() { echo -e "${GREEN}  ✔${NC} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $*"; }
error()   { echo -e "${RED}  ✘${NC} $*"; }

# Registry: "display_name|repo_filename|installed_binary"
# Thêm tool mới vào đây khi mở rộng collection.
TOOL_REGISTRY=(
    "Sandbox Shell Manager|sandbox-shell.sh|sbox"
    "etool (self)|update.sh|etool"
)

# ─── HELPERS ──────────────────────────────────────────────────────────────────

# Tải file từ GitHub về temp file. In ra đường dẫn temp nếu thành công, rỗng nếu lỗi.
fetch_remote() {
    local repo_file="$1"
    local tmp; tmp=$(mktemp /tmp/etool_XXXXXX)
    if curl -fsSL --max-time 15 "$REPO_RAW/$repo_file" -o "$tmp" 2>/dev/null; then
        echo "$tmp"
    else
        rm -f "$tmp"
        echo ""
    fi
}

files_differ() { ! diff -q "$1" "$2" > /dev/null 2>&1; }

# Hiển thị diff có màu giữa file đã cài và bản mới từ repo.
show_diff() {
    local installed="$1"
    local remote_tmp="$2"

    local added removed
    added=$(diff  "$installed" "$remote_tmp" | grep -c "^>" 2>/dev/null || true)
    removed=$(diff "$installed" "$remote_tmp" | grep -c "^<" 2>/dev/null || true)
    echo -e "  ${GREEN}+${added} dòng mới${NC}   ${RED}-${removed} dòng xóa${NC}"
    echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"

    diff --color=always "$installed" "$remote_tmp" 2>/dev/null \
        | grep -v "^---\|^+++" \
        | head -30 \
        | sed 's/^/    /' \
    || diff "$installed" "$remote_tmp" \
        | head -30 \
        | sed "s/^>/$(printf '\033[0;32m')>$(printf '\033[0m')/;s/^</$(printf '\033[0;31m')<$(printf '\033[0m')/" \
        | sed 's/^/    /'

    local total; total=$(diff "$installed" "$remote_tmp" | wc -l | tr -d ' ')
    [ "$total" -gt 30 ] && echo -e "    ${DIM}... $(( total - 30 )) dòng nữa${NC}"
}

# ─── CHECK ────────────────────────────────────────────────────────────────────

cmd_check() {
    local filter="${1:-}"
    local any_outdated=false

    echo ""
    for entry in "${TOOL_REGISTRY[@]}"; do
        IFS='|' read -r display_name repo_file bin_name <<< "$entry"
        [[ -n "$filter" && "$bin_name" != "$filter" ]] && continue

        local installed="$INSTALL_DIR/$bin_name"

        if [ ! -f "$installed" ]; then
            echo -e "  ${DIM}[--]${NC} ${BOLD}$display_name${NC}  —  chưa cài"
            continue
        fi

        info "Đang kiểm tra $display_name..."
        local remote_tmp; remote_tmp=$(fetch_remote "$repo_file")

        if [ -z "$remote_tmp" ]; then
            echo -e "  ${RED}[??]${NC} ${BOLD}$display_name${NC}  —  không thể kết nối repo"
            continue
        fi

        if files_differ "$installed" "$remote_tmp"; then
            echo -e "  ${YELLOW}[!!]${NC} ${BOLD}$display_name${NC}  —  có bản cập nhật"
            any_outdated=true
        else
            echo -e "  ${GREEN}[OK]${NC} ${BOLD}$display_name${NC}  —  đã là bản mới nhất"
        fi
        rm -f "$remote_tmp"
    done

    echo ""
    $any_outdated && echo -e "  ${YELLOW}Chạy ${BOLD}etool update${NC}${YELLOW} để cập nhật.${NC}" && echo ""
    true
}

# ─── UPDATE ───────────────────────────────────────────────────────────────────

cmd_update() {
    local filter="${1:-}"
    local updated=0

    echo ""
    for entry in "${TOOL_REGISTRY[@]}"; do
        IFS='|' read -r display_name repo_file bin_name <<< "$entry"
        [[ -n "$filter" && "$bin_name" != "$filter" ]] && continue

        local installed="$INSTALL_DIR/$bin_name"

        echo -e "${BOLD}[$bin_name]${NC} $display_name"

        if [ ! -f "$installed" ]; then
            warn "Chưa được cài. Chạy ./install.sh để cài trước."
            echo ""; continue
        fi

        info "Lấy bản mới từ repo..."
        local remote_tmp; remote_tmp=$(fetch_remote "$repo_file")

        if [ -z "$remote_tmp" ]; then
            error "Không thể kết nối. Kiểm tra internet."
            echo ""; continue
        fi

        if ! files_differ "$installed" "$remote_tmp"; then
            success "Đã là bản mới nhất — bỏ qua"
            rm -f "$remote_tmp"; echo ""; continue
        fi

        show_diff "$installed" "$remote_tmp"
        echo ""

        echo -ne "  Cập nhật ${BOLD}$display_name${NC}? [y/N] "
        read -r confirm || true

        if [[ "$confirm" =~ ^[yY]$ ]]; then
            cp "$installed" "${installed}.bak"
            cp "$remote_tmp" "$installed"
            chmod +x "$installed"
            updated=$(( updated + 1 ))
            success "Đã cập nhật  ${DIM}(backup: ${installed}.bak)${NC}"
        else
            info "Bỏ qua"
        fi

        rm -f "$remote_tmp"
        echo ""
    done

    [ "$updated" -gt 0 ] && echo -e "${GREEN}  $updated tool đã được cập nhật.${NC}\n"
    true
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "┌───────────────────────────────────────────────────────┐"
    echo "│              etool — macOS Tool Updater               │"
    echo "│    So sánh code máy ↔ repo GitHub · Cập nhật          │"
    echo "└───────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_usage() {
    echo -e "Cách dùng:"
    echo -e "  ${CYAN}etool check${NC}              — Kiểm tra tất cả có bản mới không"
    echo -e "  ${CYAN}etool check <tool>${NC}       — Kiểm tra một tool (sandbox, etool...)"
    echo -e "  ${CYAN}etool update${NC}             — Xem diff và cập nhật tất cả"
    echo -e "  ${CYAN}etool update <tool>${NC}      — Cập nhật một tool cụ thể"
    echo -e "  ${CYAN}etool update etool${NC}       — Tự cập nhật etool"
    echo -e "  ${CYAN}etool help${NC}               — Hiển thị trợ giúp này"
}

print_header

case "${1:-help}" in
    check)  cmd_check  "${2:-}" ;;
    update) cmd_update "${2:-}" ;;
    help|--help|-h) print_usage; echo "" ;;
    *)
        error "Lệnh không hợp lệ: '${1:-}'"
        echo ""; print_usage; echo ""
        exit 1
        ;;
esac
