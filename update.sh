#!/bin/bash
# etool — macOS Tool Collection Updater
# Installed at: ~/.local/bin/etool
# Compares locally installed tools against the latest version on GitHub.
# Usage: etool | etool check | etool update [tool]

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
# Add new tools here when expanding the collection.
TOOL_REGISTRY=(
    "Sandbox Shell Manager|sandbox-shell.sh|sbox"
    "etool (self)|update.sh|etool"
)

# ─── HELPERS ──────────────────────────────────────────────────────────────────

# Download a file from GitHub to a temp path. Prints temp path on success, empty on failure.
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

# Print a colored diff between the installed file and the remote version.
show_diff() {
    local installed="$1"
    local remote_tmp="$2"

    local added removed
    added=$(diff   "$installed" "$remote_tmp" | grep -c "^>" 2>/dev/null || true)
    removed=$(diff "$installed" "$remote_tmp" | grep -c "^<" 2>/dev/null || true)
    echo -e "  ${GREEN}+${added} lines added${NC}   ${RED}-${removed} lines removed${NC}"
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
    [ "$total" -gt 30 ] && echo -e "    ${DIM}... $(( total - 30 )) more lines${NC}"
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
            echo -e "  ${DIM}[--]${NC} ${BOLD}$display_name${NC}  —  not installed"
            continue
        fi

        info "Checking $display_name..."
        local remote_tmp; remote_tmp=$(fetch_remote "$repo_file")

        if [ -z "$remote_tmp" ]; then
            echo -e "  ${RED}[??]${NC} ${BOLD}$display_name${NC}  —  could not reach GitHub"
            continue
        fi

        if files_differ "$installed" "$remote_tmp"; then
            echo -e "  ${YELLOW}[!!]${NC} ${BOLD}$display_name${NC}  —  update available"
            any_outdated=true
        else
            echo -e "  ${GREEN}[OK]${NC} ${BOLD}$display_name${NC}  —  up to date"
        fi
        rm -f "$remote_tmp"
    done

    echo ""
    $any_outdated && echo -e "  ${YELLOW}Run ${BOLD}etool update${NC}${YELLOW} to apply updates.${NC}" && echo ""
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
            warn "Not installed. Run ./install.sh first."
            echo ""; continue
        fi

        info "Fetching latest from GitHub..."
        local remote_tmp; remote_tmp=$(fetch_remote "$repo_file")

        if [ -z "$remote_tmp" ]; then
            error "Could not reach GitHub. Check your internet connection."
            echo ""; continue
        fi

        if ! files_differ "$installed" "$remote_tmp"; then
            success "Already up to date — skipping"
            rm -f "$remote_tmp"; echo ""; continue
        fi

        show_diff "$installed" "$remote_tmp"
        echo ""

        echo -ne "  Update ${BOLD}$display_name${NC}? [y/N] "
        read -r confirm || true

        if [[ "$confirm" =~ ^[yY]$ ]]; then
            cp "$installed" "${installed}.bak"
            cp "$remote_tmp" "$installed"
            chmod +x "$installed"
            updated=$(( updated + 1 ))
            success "Updated  ${DIM}(backup: ${installed}.bak)${NC}"
        else
            info "Skipped"
        fi

        rm -f "$remote_tmp"
        echo ""
    done

    [ "$updated" -gt 0 ] && echo -e "${GREEN}  $updated tool(s) updated.${NC}\n"
    true
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "┌───────────────────────────────────────────────────────┐"
    echo "│              etool — macOS Tool Updater               │"
    echo "│       Compare installed ↔ GitHub · Stay current       │"
    echo "└───────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_usage() {
    echo -e "  ${BOLD}Commands:${NC}"
    echo -e "    ${CYAN}etool check${NC}               Check all tools for available updates"
    echo -e "    ${CYAN}etool check <tool>${NC}        Check a specific tool  (e.g. sbox, etool)"
    echo -e "    ${CYAN}etool update${NC}              Show diff and update all outdated tools"
    echo -e "    ${CYAN}etool update <tool>${NC}       Update a specific tool"
    echo -e "    ${CYAN}etool update etool${NC}        Self-update etool"
    echo -e "    ${CYAN}etool help${NC}                Show this help message"
    echo ""
    echo -e "  ${BOLD}Installed tools:${NC}"
    for entry in "${TOOL_REGISTRY[@]}"; do
        IFS='|' read -r display_name _ bin_name <<< "$entry"
        local installed="$INSTALL_DIR/$bin_name"
        if [ -f "$installed" ]; then
            echo -e "    ${GREEN}✔${NC}  $bin_name  —  $display_name"
        else
            echo -e "    ${DIM}–${NC}  $bin_name  —  $display_name  ${DIM}(not installed)${NC}"
        fi
    done
}

print_header

case "${1:-help}" in
    check)       cmd_check  "${2:-}" ;;
    update)      cmd_update "${2:-}" ;;
    help|--help|-h) print_usage; echo "" ;;
    *)
        error "Unknown command: '${1:-}'"
        echo ""; print_usage; echo ""
        exit 1
        ;;
esac
