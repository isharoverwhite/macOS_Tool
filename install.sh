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
        local tmp; tmp=$(mktemp)
        grep -v "alias sbox=" "$ZSHRC" | grep -v "# Sandbox Shell Manager" > "$tmp"
        mv "$tmp" "$ZSHRC"
        warn "Đã xóa alias 'sbox' cũ trong $ZSHRC (không cần thiết nữa)"
    fi

    cp "$src" "$dst"
    chmod +x "$dst"
    success "Đã cài: $dst"

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

# ─── TOOL: NPM PACKAGE MANAGER ───────────────────────────────────────────────

install_npkg() {
    echo -e "\n${BOLD}[npkg] NPM Package Manager${NC}"

    local src="$SCRIPT_DIR/npkg.sh"
    local dst="$INSTALL_DIR/npkg"

    if [ ! -f "$src" ]; then
        error "Không tìm thấy npkg.sh trong $SCRIPT_DIR"
        return 1
    fi

    ensure_install_dir
    cp "$src" "$dst"
    chmod +x "$dst"
    success "Đã cài: $dst"
    info "Dùng: npkg (trong thư mục project) hoặc npkg --global"
}

# ─── ZSH ENVIRONMENT (zsh + oh-my-zsh + plugins + NVM + .zshrc) ──────────────

install_zsh_env() {
    echo -e "\n${BOLD}[zsh-env] Zsh + Oh My Zsh + Plugins + NVM${NC}"

    # ── 1. Homebrew ───────────────────────────────────────────────────────────
    if ! command -v brew &>/dev/null; then
        info "Cài đặt Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Apple Silicon: thêm brew vào PATH cho phiên hiện tại
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        success "Đã cài Homebrew"
    else
        info "Homebrew đã có ($(brew --version | head -1))"
    fi

    # ── 2. Zsh ────────────────────────────────────────────────────────────────
    if ! brew list zsh &>/dev/null 2>&1; then
        info "Cài đặt zsh..."
        brew install zsh
        success "Đã cài zsh"
    else
        info "zsh đã có ($(zsh --version))"
    fi

    # Đặt zsh làm shell mặc định nếu chưa phải
    local zsh_path
    zsh_path="$(brew --prefix)/bin/zsh"
    if [[ "$SHELL" != "$zsh_path" ]]; then
        if ! grep -qF "$zsh_path" /etc/shells; then
            echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
            info "Đã thêm $zsh_path vào /etc/shells"
        fi
        chsh -s "$zsh_path"
        success "Shell mặc định đã đổi → $zsh_path"
    else
        info "Shell mặc định đã là zsh"
    fi

    # ── 3. Oh My Zsh ──────────────────────────────────────────────────────────
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        info "Cài đặt Oh My Zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        success "Đã cài Oh My Zsh"
    else
        info "Oh My Zsh đã có"
    fi

    # ── 4. Powerlevel10k theme ────────────────────────────────────────────────
    local p10k_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    if [[ ! -d "$p10k_dir" ]]; then
        info "Cài đặt Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
        success "Đã cài Powerlevel10k → $p10k_dir"
    else
        info "Powerlevel10k đã có"
    fi

    # ── 5. zsh-autosuggestions ────────────────────────────────────────────────
    local autosug_dir="$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    if [[ ! -d "$autosug_dir" ]]; then
        info "Cài đặt zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$autosug_dir"
        success "Đã cài zsh-autosuggestions"
    else
        info "zsh-autosuggestions đã có"
    fi

    # ── 6. zsh-syntax-highlighting ────────────────────────────────────────────
    local synhi_dir="$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    if [[ ! -d "$synhi_dir" ]]; then
        info "Cài đặt zsh-syntax-highlighting..."
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$synhi_dir"
        success "Đã cài zsh-syntax-highlighting"
    else
        info "zsh-syntax-highlighting đã có"
    fi

    # ── 7. NVM ────────────────────────────────────────────────────────────────
    if [[ ! -d "$HOME/.nvm" ]]; then
        info "Cài đặt NVM v0.40.4..."
        # PROFILE=/dev/null để NVM installer không tự động sửa .zshrc
        # (template của chúng ta đã có sẵn khối NVM)
        PROFILE=/dev/null \
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh)"
        success "Đã cài NVM → ~/.nvm/"
    else
        info "NVM đã có"
    fi

    # ── 8. Ghi .zshrc từ template ─────────────────────────────────────────────
    local template="$SCRIPT_DIR/zshrc.template"
    if [[ ! -f "$template" ]]; then
        error "Không tìm thấy zshrc.template trong $SCRIPT_DIR"
        return 1
    fi

    if [[ -f "$ZSHRC" ]]; then
        local backup="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ZSHRC" "$backup"
        warn "Đã backup .zshrc cũ → $backup"
    fi

    cp "$template" "$ZSHRC"
    success "Đã ghi ~/.zshrc từ template"

    # ── 9. Copy cấu hình Powerlevel10k ────────────────────────────────────────
    local p10k_cfg="$SCRIPT_DIR/p10k.zsh"
    if [[ -f "$p10k_cfg" ]]; then
        cp "$p10k_cfg" "$HOME/.p10k.zsh"
        success "Đã copy cấu hình p10k → ~/.p10k.zsh"
    else
        warn "Không tìm thấy p10k.zsh — chạy 'p10k configure' sau khi cài xong"
    fi

    echo -e "\n${GREEN}${BOLD}  Zsh environment hoàn tất!${NC}"
    echo -e "  ${CYAN}Mở terminal mới hoặc chạy:  exec zsh${NC}"
    echo -e "  ${CYAN}Nếu font bị lỗi, cài Nerd Font:  brew install --cask font-meslo-lg-nerd-font${NC}"
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

# ─── CÀI TẤT CẢ ──────────────────────────────────────────────────────────────

install_all() {
    install_zsh_env
    install_sandbox
    install_etool
    install_npkg
    # Thêm install_<toolname> ở đây khi có tool mới

    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║  Cài đặt hoàn tất! Mở terminal mới để bắt đầu.  ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}\n"
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
    echo -e "  ${CYAN}./install.sh${NC}                  — Cài tất cả (zsh env + tools)"
    echo -e "  ${CYAN}./install.sh --only zsh${NC}       — Chỉ cài zsh + oh-my-zsh + plugins + NVM + .zshrc"
    echo -e "  ${CYAN}./install.sh --only sandbox${NC}   — Chỉ cài Sandbox Manager"
    echo -e "  ${CYAN}./install.sh --only etool${NC}     — Chỉ cài etool updater"
    echo -e "  ${CYAN}./install.sh --only npkg${NC}      — Chỉ cài NPM Package Manager"
    echo -e "  ${CYAN}./install.sh --help${NC}           — Hiển thị trợ giúp này"
}

print_header

case "${1:-}" in
    --only)
        tool="${2:-}"
        case "$tool" in
            zsh)     install_zsh_env ;;
            sandbox) install_sandbox ;;
            etool)   install_etool ;;
            npkg)    install_npkg ;;
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
