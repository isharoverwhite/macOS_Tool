#!/bin/bash

# macOS Tool Collection — Installer
# Mỗi tool nằm trong một hàm riêng biệt để có thể cài độc lập hoặc cùng nhau.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
ZSHRC="$HOME/.zshrc"

info()    { echo -e "${CYAN}  →${NC} $*"; }
success() { echo -e "${GREEN}  ✔${NC} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $*"; }
error()   { echo -e "${RED}  ✘${NC} $*"; }

# Đảm bảo ~/.local/bin tồn tại và có trong PATH
ensure_install_dir() {
    mkdir -p "$INSTALL_DIR"
    if ! grep -q 'local/bin' "$ZSHRC" 2>/dev/null; then
        echo '' >> "$ZSHRC"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
        info "Đã thêm ~/.local/bin vào PATH trong $ZSHRC"
    fi
}

# ─── TOOL: SANDBOX SHELL MANAGER ──────────────────────────────────────────────

install_sandbox() {
    echo -e "\n${BOLD}[sandbox] Sandbox Shell Manager${NC}"

    local src="$SCRIPT_DIR/sandbox-shell.sh"
    local dst="$INSTALL_DIR/sbox"

    if [ ! -f "$src" ]; then
        error "Không tìm thấy sandbox-shell.sh trong $SCRIPT_DIR"
        return 1
    fi

    ensure_install_dir

    # Nếu đang dùng alias cũ từ ~/scripts, xóa để tránh conflict
    if grep -q "alias sbox=" "$ZSHRC" 2>/dev/null; then
        # Dùng temp file để xóa dòng alias cũ an toàn
        local tmp; tmp=$(mktemp)
        grep -v "alias sbox=" "$ZSHRC" | grep -v "# Sandbox Shell Manager" > "$tmp"
        mv "$tmp" "$ZSHRC"
        warn "Đã xóa alias 'sbox' cũ trong $ZSHRC (không cần thiết nữa)"
    fi

    cp "$src" "$dst"
    chmod +x "$dst"
    success "Đã cài: $dst"

    # Tạo thư mục sandbox và log
    mkdir -p "$HOME/.sandbox"
    touch "$HOME/.sandbox/.sandbox_log"
    success "Khởi tạo: ~/.sandbox/"

    echo -e "\n${GREEN}  Hoàn tất! Chạy lệnh sau để áp dụng ngay:${NC}"
    echo -e "  ${CYAN}source ~/.zshrc && sbox${NC}"
}

# ─── TOOL: ETOOL (UPDATER) ────────────────────────────────────────────────────

install_etool() {
    echo -e "\n${BOLD}[etool] macOS Tool Updater${NC}"

    local src="$SCRIPT_DIR/update.sh"
    local dst="$INSTALL_DIR/etool"

    if [ ! -f "$src" ]; then
        error "Không tìm thấy update.sh trong $SCRIPT_DIR"
        return 1
    fi

    ensure_install_dir
    cp "$src" "$dst"
    chmod +x "$dst"
    success "Đã cài: $dst"
    info "Dùng: etool check | etool update"
}

# ─── TEMPLATE CHO TOOL MỚI ────────────────────────────────────────────────────
# Khi thêm tool mới, tạo một hàm install_<toolname>() theo mẫu dưới đây
# rồi thêm nó vào install_all() và vào argument parsing bên dưới.
#
# install_<toolname>() {
#     echo -e "\n${BOLD}[toolname] Tên công cụ${NC}"
#     local src="$SCRIPT_DIR/<source-file>"
#     local dst="$INSTALL_DIR/<binary-name>"
#     ensure_install_dir
#     cp "$src" "$dst" && chmod +x "$dst"
#     success "Đã cài: $dst"
# }

# ─── CÀI TẤT CẢ TOOLS ────────────────────────────────────────────────────────

install_all() {
    install_sandbox
    install_etool
    # Thêm install_<toolname> ở đây khi có tool mới
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "┌───────────────────────────────────────────────────────┐"
    echo "│           macOS Tool Collection — Installer           │"
    echo "│           Install dir: ~/.local/bin/                  │"
    echo "└───────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_usage() {
    echo -e "Cách dùng:"
    echo -e "  ${CYAN}./install.sh${NC}                  — Cài tất cả tools"
    echo -e "  ${CYAN}./install.sh --only sandbox${NC}   — Chỉ cài Sandbox Manager"
    echo -e "  ${CYAN}./install.sh --only etool${NC}     — Chỉ cài etool updater"
    echo -e "  ${CYAN}./install.sh --help${NC}           — Hiển thị trợ giúp này"
}

print_header

case "${1:-}" in
    --only)
        tool="${2:-}"
        case "$tool" in
            sandbox) install_sandbox ;;
            etool)   install_etool ;;
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
