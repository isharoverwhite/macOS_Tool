#!/bin/bash

# macOS Tool Collection — Installer
# Chạy ./install.sh để cài đầy đủ 11 bước bắt buộc theo thứ tự.
# Dùng --only <tool> để cài riêng lẻ (cho máy đã setup sẵn).

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
ZSHRC="$HOME/.zshrc"

TOTAL_STEPS=12
CURRENT_STEP=0

# ─── HELPERS ──────────────────────────────────────────────────────────────────

info()    { echo -e "  ${CYAN}→${NC} $*"; }
success() { echo -e "  ${GREEN}✔${NC} $*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $*"; }
error()   { echo -e "  ${RED}✘${NC} $*"; }
skip()    { echo -e "  ${DIM}–${NC} $* ${DIM}(đã có, bỏ qua)${NC}"; }

step() {
    CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    echo -e "\n${CYAN}${BOLD}┌─ Bước ${CURRENT_STEP}/${TOTAL_STEPS} ─── $*${NC}"
}

ensure_install_dir() {
    mkdir -p "$INSTALL_DIR"
}

# ─── CÁC BƯỚC CÀI ĐẶT ────────────────────────────────────────────────────────

step_homebrew() {
    step "Homebrew"
    if ! command -v brew &>/dev/null; then
        info "Cài đặt Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        success "Homebrew đã cài xong"
    else
        skip "Homebrew $(brew --version | head -1)"
    fi
}

step_zsh() {
    step "Zsh + set default shell"
    if ! brew list zsh &>/dev/null 2>&1; then
        info "Cài đặt zsh qua Homebrew..."
        brew install zsh
        success "Đã cài zsh"
    else
        skip "zsh $(zsh --version)"
    fi

    local zsh_path
    zsh_path="$(brew --prefix)/bin/zsh"
    if [[ "$SHELL" != "$zsh_path" ]]; then
        if ! grep -qF "$zsh_path" /etc/shells; then
            echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
            info "Thêm $zsh_path vào /etc/shells"
        fi
        chsh -s "$zsh_path"
        success "Shell mặc định → $zsh_path"
    else
        skip "Shell mặc định đã là $zsh_path"
    fi
}

step_ohmyzsh() {
    step "Oh My Zsh"
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        info "Cài đặt Oh My Zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        success "Đã cài Oh My Zsh → ~/.oh-my-zsh/"
    else
        skip "Oh My Zsh đã có tại ~/.oh-my-zsh/"
    fi
}

step_p10k() {
    step "Powerlevel10k theme"
    local dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    if [[ ! -d "$dir" ]]; then
        info "Clone Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$dir"
        success "Đã cài Powerlevel10k"
    else
        skip "Powerlevel10k đã có"
    fi
}

step_autosuggestions() {
    step "zsh-autosuggestions"
    local dir="$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    if [[ ! -d "$dir" ]]; then
        info "Clone zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$dir"
        success "Đã cài zsh-autosuggestions"
    else
        skip "zsh-autosuggestions đã có"
    fi
}

step_syntax_highlighting() {
    step "zsh-syntax-highlighting"
    local dir="$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    if [[ ! -d "$dir" ]]; then
        info "Clone zsh-syntax-highlighting..."
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$dir"
        success "Đã cài zsh-syntax-highlighting"
    else
        skip "zsh-syntax-highlighting đã có"
    fi
}

step_nvm() {
    step "NVM (Node Version Manager)"
    if [[ ! -d "$HOME/.nvm" ]]; then
        info "Cài đặt NVM v0.40.4..."
        # PROFILE=/dev/null: không để NVM tự sửa .zshrc — template đã có sẵn khối NVM
        PROFILE=/dev/null \
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh)"
        success "Đã cài NVM → ~/.nvm/"
    else
        skip "NVM đã có tại ~/.nvm/"
    fi
}

step_zshrc() {
    step ".zshrc + Powerlevel10k config"

    local template="$SCRIPT_DIR/zshrc.template"
    if [[ ! -f "$template" ]]; then
        error "Không tìm thấy zshrc.template trong $SCRIPT_DIR"
        exit 1
    fi

    if [[ -f "$ZSHRC" ]]; then
        local backup="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ZSHRC" "$backup"
        warn "Backup .zshrc cũ → $backup"
    fi
    cp "$template" "$ZSHRC"
    success "Đã ghi ~/.zshrc từ template"

    local p10k_cfg="$SCRIPT_DIR/p10k.zsh"
    if [[ -f "$p10k_cfg" ]]; then
        cp "$p10k_cfg" "$HOME/.p10k.zsh"
        success "Đã copy cấu hình Powerlevel10k → ~/.p10k.zsh"
    else
        warn "Không tìm thấy p10k.zsh — chạy 'p10k configure' sau khi mở terminal mới"
    fi
}

step_sandbox() {
    step "Sandbox Shell Manager (sbox)"
    local src="$SCRIPT_DIR/sandbox-shell.sh"
    if [[ ! -f "$src" ]]; then
        error "Không tìm thấy sandbox-shell.sh trong $SCRIPT_DIR"
        exit 1
    fi
    ensure_install_dir
    cp "$src" "$INSTALL_DIR/sbox"
    chmod +x "$INSTALL_DIR/sbox"
    success "Đã cài → $INSTALL_DIR/sbox"
    mkdir -p "$HOME/.sandbox"
    touch "$HOME/.sandbox/.sandbox_log"
    success "Khởi tạo ~/.sandbox/"
}

step_etool() {
    step "etool — macOS Tool Updater"
    local src="$SCRIPT_DIR/update.sh"
    if [[ ! -f "$src" ]]; then
        error "Không tìm thấy update.sh trong $SCRIPT_DIR"
        exit 1
    fi
    ensure_install_dir
    cp "$src" "$INSTALL_DIR/etool"
    chmod +x "$INSTALL_DIR/etool"
    success "Đã cài → $INSTALL_DIR/etool"
}

step_npkg() {
    step "NPM Package Manager (npkg)"
    local src="$SCRIPT_DIR/npkg.sh"
    if [[ ! -f "$src" ]]; then
        error "Không tìm thấy npkg.sh trong $SCRIPT_DIR"
        exit 1
    fi
    ensure_install_dir
    cp "$src" "$INSTALL_DIR/npkg"
    chmod +x "$INSTALL_DIR/npkg"
    success "Đã cài → $INSTALL_DIR/npkg"
}

step_warp() {
    step "Warp terminal config"

    # Nếu Warp chưa cài, gợi ý cài rồi bỏ qua bước này
    if [[ ! -d "/Applications/Warp.app" ]]; then
        warn "Warp chưa được cài. Bỏ qua config."
        info "Cài Warp:  brew install --cask warp"
        return 0
    fi

    local warp_cfg="$SCRIPT_DIR/warp"
    if [[ ! -d "$warp_cfg" ]]; then
        error "Không tìm thấy thư mục warp/ trong $SCRIPT_DIR"
        exit 1
    fi

    mkdir -p "$HOME/.warp/tab_configs"

    # settings.toml — copy thẳng, không có thông tin cá nhân
    cp "$warp_cfg/settings.toml" "$HOME/.warp/settings.toml"
    success "Đã copy settings.toml → ~/.warp/settings.toml"

    # startup_config.toml — thay __HOME__ bằng $HOME thực tế
    sed "s|__HOME__|$HOME|g" \
        "$warp_cfg/tab_configs/startup_config.toml" \
        > "$HOME/.warp/tab_configs/startup_config.toml"
    success "Đã copy startup_config.toml → ~/.warp/tab_configs/startup_config.toml"
}

# ─── CÀI TẤT CẢ: 11 bước bắt buộc theo thứ tự ───────────────────────────────

install_all() {
    step_homebrew           # Bước  1
    step_zsh                # Bước  2
    step_ohmyzsh            # Bước  3
    step_p10k               # Bước  4
    step_autosuggestions    # Bước  5
    step_syntax_highlighting # Bước 6
    step_nvm                # Bước  7
    step_zshrc              # Bước  8
    step_sandbox            # Bước  9
    step_etool              # Bước 10
    step_npkg               # Bước 11
    step_warp               # Bước 12
    # Thêm step_<toolname>() ở đây khi có tool mới (nhớ tăng TOTAL_STEPS)

    echo -e "\n${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  ✔  Hoàn tất tất cả ${TOTAL_STEPS} bước!                           ║"
    echo "║                                                          ║"
    echo "║  Bước tiếp theo:                                         ║"
    echo "║    1. Mở terminal mới  (hoặc: exec zsh)                  ║"
    echo "║    2. Nếu font lỗi:                                      ║"
    echo "║       brew install --cask font-meslo-lg-nerd-font        ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "┌──────────────────────────────────────────────────────────┐"
    echo "│          macOS Tool Collection — Installer               │"
    echo "│          ${TOTAL_STEPS} bước bắt buộc · Install dir: ~/.local/bin/  │"
    echo "└──────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_usage() {
    echo -e "Cách dùng:"
    echo -e "  ${CYAN}./install.sh${NC}                   — Cài đầy đủ ${TOTAL_STEPS} bước theo thứ tự"
    echo -e "  ${CYAN}./install.sh --only zsh${NC}        — Chỉ cài zsh env (bước 1–8)"
    echo -e "  ${CYAN}./install.sh --only sandbox${NC}    — Chỉ cài Sandbox Manager"
    echo -e "  ${CYAN}./install.sh --only etool${NC}      — Chỉ cài etool updater"
    echo -e "  ${CYAN}./install.sh --only npkg${NC}       — Chỉ cài NPM Package Manager"
    echo -e "  ${CYAN}./install.sh --only warp${NC}       — Chỉ copy Warp terminal config"
    echo -e "  ${CYAN}./install.sh --help${NC}            — Hiển thị trợ giúp này"
}

# Hàm tiện ích cho --only zsh: reset bộ đếm và chạy chỉ các bước môi trường
install_zsh_env_only() {
    TOTAL_STEPS=8
    CURRENT_STEP=0
    step_homebrew
    step_zsh
    step_ohmyzsh
    step_p10k
    step_autosuggestions
    step_syntax_highlighting
    step_nvm
    step_zshrc
    echo -e "\n${GREEN}${BOLD}  ✔ Zsh environment hoàn tất (${TOTAL_STEPS} bước)${NC}"
    echo -e "  ${CYAN}Mở terminal mới hoặc: exec zsh${NC}\n"
}

print_header

case "${1:-}" in
    --only)
        case "${2:-}" in
            zsh)     install_zsh_env_only ;;
            sandbox) TOTAL_STEPS=1; step_sandbox ;;
            etool)   TOTAL_STEPS=1; step_etool ;;
            npkg)    TOTAL_STEPS=1; step_npkg ;;
            warp)    TOTAL_STEPS=1; step_warp ;;
            *)
                error "Tool không hợp lệ: '${2:-}'"
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
