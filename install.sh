#!/bin/bash

# macOS Tool Collection — Installer
# Mỗi tool nằm trong một hàm riêng biệt để có thể cài độc lập hoặc cùng nhau.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/scripts"
ZSHRC="$HOME/.zshrc"

info()    { echo -e "${CYAN}  →${NC} $*"; }
success() { echo -e "${GREEN}  ✔${NC} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $*"; }
error()   { echo -e "${RED}  ✘${NC} $*"; }

# ─── TOOL: SANDBOX SHELL MANAGER ──────────────────────────────────────────────

install_sandbox() {
    echo -e "\n${BOLD}[1/1] Sandbox Shell Manager (sbox)${NC}"

    # Đảm bảo thư mục cài đặt tồn tại
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        info "Tạo thư mục: $INSTALL_DIR"
    fi

    # Copy script và cấp quyền thực thi
    local src="$SCRIPT_DIR/sandbox-shell.sh"
    local dst="$INSTALL_DIR/sandbox-shell.sh"

    if [ ! -f "$src" ]; then
        error "Không tìm thấy sandbox-shell.sh trong $SCRIPT_DIR"
        return 1
    fi

    cp "$src" "$dst"
    chmod +x "$dst"
    success "Đã copy: $dst"

    # Thêm alias vào ~/.zshrc nếu chưa có
    if grep -q "alias sbox=" "$ZSHRC" 2>/dev/null; then
        warn "Alias 'sbox' đã tồn tại trong $ZSHRC — bỏ qua."
    else
        echo "" >> "$ZSHRC"
        echo "# Sandbox Shell Manager" >> "$ZSHRC"
        echo "alias sbox='$dst'" >> "$ZSHRC"
        success "Đã thêm alias 'sbox' vào $ZSHRC"
    fi

    # Tạo thư mục sandbox và log
    mkdir -p "$HOME/.sandbox"
    touch "$HOME/.sandbox/.sandbox_log"
    success "Khởi tạo: ~/.sandbox/"

    echo -e "\n${GREEN}  Hoàn tất! Chạy lệnh sau để áp dụng ngay:${NC}"
    echo -e "  ${CYAN}source ~/.zshrc${NC}"
    echo -e "  ${CYAN}sbox${NC}"
}

# ─── TEMPLATE CHO TOOL MỚI ────────────────────────────────────────────────────
# Khi thêm tool mới, tạo một hàm install_<toolname>() theo mẫu dưới đây
# rồi thêm nó vào install_all() và vào argument parsing bên dưới.
#
# install_<toolname>() {
#     echo -e "\n${BOLD}[N/M] Tên công cụ${NC}"
#     # ... logic cài đặt ...
#     success "Hoàn tất cài đặt <toolname>"
# }

# ─── CÀI TẤT CẢ TOOLS ────────────────────────────────────────────────────────

install_all() {
    install_sandbox
    # Thêm install_<toolname> ở đây khi có tool mới
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "┌───────────────────────────────────────────────────────┐"
    echo "│           macOS Tool Collection — Installer           │"
    echo "└───────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_usage() {
    echo -e "Cách dùng:"
    echo -e "  ${CYAN}./install.sh${NC}                  — Cài tất cả tools"
    echo -e "  ${CYAN}./install.sh --only sandbox${NC}   — Chỉ cài Sandbox Manager"
    echo -e "  ${CYAN}./install.sh --help${NC}           — Hiển thị trợ giúp này"
}

print_header

case "${1:-}" in
    --only)
        tool="${2:-}"
        case "$tool" in
            sandbox) install_sandbox ;;
            *)
                error "Tool không hợp lệ: '$tool'"
                echo ""
                print_usage
                exit 1
                ;;
        esac
        ;;
    --help|-h)
        print_usage
        ;;
    "")
        install_all
        ;;
    *)
        error "Tham số không hợp lệ: '$1'"
        echo ""
        print_usage
        exit 1
        ;;
esac
