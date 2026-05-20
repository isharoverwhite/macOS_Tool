#!/bin/bash

# macOS Tool Collection — Updater
# So sánh từng tool đã cài với code mới trong repo, cập nhật nếu có thay đổi.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo -e "${CYAN}  →${NC} $*"; }
success() { echo -e "${GREEN}  ✔${NC} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $*"; }
error()   { echo -e "${RED}  ✘${NC} $*"; }

# Tìm binary đã cài của một tool.
# Thứ tự tìm: ~/.local/bin/<bin_name> → ~/.local/bin/<script_name> → ~/scripts/<script_name>
find_installed() {
    local bin_name="$1"
    local script_name="$2"
    if   [ -f "$HOME/.local/bin/$bin_name" ];    then echo "$HOME/.local/bin/$bin_name"
    elif [ -f "$HOME/.local/bin/$script_name" ];  then echo "$HOME/.local/bin/$script_name"
    elif [ -f "$HOME/scripts/$script_name" ];     then echo "$HOME/scripts/$script_name"
    fi
}

# Hiển thị diff có màu giữa file đã cài (old) và file mới trong repo (new),
# rồi hỏi user có muốn cập nhật không.
show_diff_and_update() {
    local label="$1"
    local installed="$2"
    local repo_file="$3"

    if diff -q "$installed" "$repo_file" > /dev/null 2>&1; then
        success "$label: đã là phiên bản mới nhất"
        return
    fi

    # Thống kê thay đổi
    local added removed changed
    added=$(diff "$installed" "$repo_file"   | grep -c "^>" 2>/dev/null || true)
    removed=$(diff "$installed" "$repo_file" | grep -c "^<" 2>/dev/null || true)

    echo -e "\n  ${BOLD}$label${NC} — ${GREEN}+$added dòng mới${NC}, ${RED}-$removed dòng xóa${NC}"
    echo -e "  ${DIM}Cài tại: $installed${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────${NC}"

    # Preview diff (30 dòng đầu), có màu nếu terminal hỗ trợ
    if diff --color=always "$installed" "$repo_file" > /dev/null 2>&1; then
        diff --color=always "$installed" "$repo_file" 2>/dev/null \
            | grep -v "^---\|^+++" \
            | head -30 \
            | sed 's/^/    /'
    else
        diff "$installed" "$repo_file" \
            | head -30 \
            | sed "s/^>/$(printf '\033[0;32m')>$(printf '\033[0m')/;s/^</$(printf '\033[0;31m')<$(printf '\033[0m')/" \
            | sed 's/^/    /'
    fi

    local total_lines; total_lines=$(diff "$installed" "$repo_file" | wc -l | tr -d ' ')
    [ "$total_lines" -gt 30 ] && echo -e "    ${DIM}... và $(( total_lines - 30 )) dòng nữa${NC}"

    echo ""
    echo -ne "  Cập nhật ${BOLD}$label${NC}? [y/N] "
    read -r confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        # Backup trước khi ghi đè
        cp "$installed" "${installed}.bak"
        cp "$repo_file" "$installed"
        chmod +x "$installed"
        success "Đã cập nhật: $installed  ${DIM}(backup: ${installed}.bak)${NC}"
    else
        info "Bỏ qua $label"
    fi
}

# ─── TOOL: SANDBOX SHELL MANAGER ──────────────────────────────────────────────

update_sandbox() {
    echo -e "\n${BOLD}[sandbox] Sandbox Shell Manager${NC}"

    local repo_file="$SCRIPT_DIR/sandbox-shell.sh"
    if [ ! -f "$repo_file" ]; then
        error "Không tìm thấy sandbox-shell.sh trong repo"
        return 1
    fi

    local installed; installed=$(find_installed "sbox" "sandbox-shell.sh")
    if [ -z "$installed" ]; then
        warn "Sandbox Manager chưa được cài. Chạy ./install.sh --only sandbox"
        return
    fi

    show_diff_and_update "Sandbox Shell Manager" "$installed" "$repo_file"
}

# ─── TEMPLATE CHO TOOL MỚI ────────────────────────────────────────────────────
# update_<toolname>() {
#     echo -e "\n${BOLD}[toolname] Tên công cụ${NC}"
#     local repo_file="$SCRIPT_DIR/<source-file>"
#     local installed; installed=$(find_installed "<bin-name>" "<source-file>")
#     [ -z "$installed" ] && warn "<toolname> chưa được cài" && return
#     show_diff_and_update "Tên công cụ" "$installed" "$repo_file"
# }

# ─── CẬP NHẬT TẤT CẢ ─────────────────────────────────────────────────────────

update_all() {
    update_sandbox
    # Thêm update_<toolname> ở đây khi có tool mới
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "┌───────────────────────────────────────────────────────┐"
    echo "│           macOS Tool Collection — Updater             │"
    echo "└───────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_usage() {
    echo -e "Cách dùng:"
    echo -e "  ${CYAN}./update.sh${NC}                  — Kiểm tra và cập nhật tất cả tools"
    echo -e "  ${CYAN}./update.sh --only sandbox${NC}   — Chỉ cập nhật Sandbox Manager"
    echo -e "  ${CYAN}./update.sh --check${NC}          — Chỉ kiểm tra, không cập nhật"
    echo -e "  ${CYAN}./update.sh --help${NC}           — Hiển thị trợ giúp này"
}

print_header

# Pull phiên bản mới nhất từ remote trước khi so sánh
info "Đồng bộ từ remote..."
if git -C "$SCRIPT_DIR" pull --ff-only 2>/dev/null; then
    success "Repo đã được cập nhật"
else
    warn "Không thể pull (có thể offline hoặc không có remote). Dùng code local."
fi

case "${1:-}" in
    --only)
        tool="${2:-}"
        case "$tool" in
            sandbox) update_sandbox ;;
            *)
                error "Tool không hợp lệ: '$tool'"
                echo ""
                print_usage
                exit 1
                ;;
        esac
        ;;
    --check)
        # Chỉ in diff, không hỏi update
        # Override hàm confirm để luôn từ chối
        read() { REPLY="n"; }
        update_all
        ;;
    --help|-h)
        print_usage
        ;;
    "")
        update_all
        ;;
    *)
        error "Tham số không hợp lệ: '$1'"
        echo ""
        print_usage
        exit 1
        ;;
esac

echo ""
