#!/bin/bash
# version: 1.0.0
# etool — macOS Tool Collection Updater
# Installed at: ~/.local/bin/etool
# check: reads only line 2 of each remote script to compare versions (lightweight)
# update: downloads full file, shows diff, confirms before overwriting
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
    "NPM Package Manager|npkg.sh|npkg"
    "etool (self)|update.sh|etool"
)

# ─── HELPERS ──────────────────────────────────────────────────────────────────

# Read version from line 2 of a local file: "# version: X.Y.Z" → "X.Y.Z"
local_version() {
    sed -n '2p' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "?"
}

# Fetch line 2 of a remote script and extract version. Prints empty string on failure.
# curl pipes into head -2 — connection is closed after 2 lines, so minimal data is transferred.
remote_version() {
    curl -fsSL --max-time 10 "$REPO_RAW/$1" 2>/dev/null \
        | head -2 | tail -1 \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
        || echo ""
}

# Download full file to a temp path. Prints temp path on success, empty on failure.
fetch_remote_full() {
    local tmp; tmp=$(mktemp /tmp/etool_XXXXXX)
    if curl -fsSL --max-time 15 "$REPO_RAW/$1" -o "$tmp" 2>/dev/null; then
        echo "$tmp"
    else
        rm -f "$tmp"
        echo ""
    fi
}

# Print a colored diff between installed file and remote temp file.
show_diff() {
    local installed="$1" remote_tmp="$2"
    local added removed
    added=$(diff   "$installed" "$remote_tmp" | grep -c "^>" 2>/dev/null || true)
    removed=$(diff "$installed" "$remote_tmp" | grep -c "^<" 2>/dev/null || true)
    echo -e "  ${GREEN}+${added} lines added${NC}   ${RED}-${removed} lines removed${NC}"
    echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"

    diff --color=always "$installed" "$remote_tmp" 2>/dev/null \
        | grep -v "^---\|^+++" | head -30 | sed 's/^/    /' \
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
            echo -e "  ${DIM}[--]${NC} ${BOLD}$bin_name${NC}  —  not installed"
            continue
        fi

        local lver; lver=$(local_version "$installed")
        info "Checking $display_name  (local: v${lver})..."

        local rver; rver=$(remote_version "$repo_file")

        if [ -z "$rver" ]; then
            echo -e "  ${RED}[??]${NC} ${BOLD}$bin_name${NC}  —  could not reach GitHub"
            continue
        fi

        if [ "$lver" != "$rver" ]; then
            echo -e "  ${YELLOW}[!!]${NC} ${BOLD}$bin_name${NC}  —  update available  ${DIM}v${lver} → v${rver}${NC}"
            any_outdated=true
        else
            echo -e "  ${GREEN}[OK]${NC} ${BOLD}$bin_name${NC}  —  up to date  ${DIM}(v${lver})${NC}"
        fi
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
        local lver; lver=$([ -f "$installed" ] && local_version "$installed" || echo "?")

        echo -e "${BOLD}[$bin_name]${NC} $display_name  ${DIM}(v${lver})${NC}"

        if [ ! -f "$installed" ]; then
            warn "Not installed. Run ./install.sh first."
            echo ""; continue
        fi

        info "Fetching latest from GitHub..."
        local remote_tmp; remote_tmp=$(fetch_remote_full "$repo_file")

        if [ -z "$remote_tmp" ]; then
            error "Could not reach GitHub. Check your internet connection."
            echo ""; continue
        fi

        local rver; rver=$(local_version "$remote_tmp")

        if [ "$lver" = "$rver" ]; then
            success "Already up to date — skipping  ${DIM}(v${lver})${NC}"
            rm -f "$remote_tmp"; echo ""; continue
        fi

        echo -e "  ${YELLOW}v${lver} → v${rver}${NC}"
        show_diff "$installed" "$remote_tmp"
        echo ""

        echo -ne "  Update ${BOLD}$display_name${NC} to v${rver}? [y/N] "
        read -r confirm || true

        if [[ "$confirm" =~ ^[yY]$ ]]; then
            cp "$installed" "${installed}.bak"
            cp "$remote_tmp" "$installed"
            chmod +x "$installed"
            updated=$(( updated + 1 ))
            success "Updated  v${lver} → v${rver}  ${DIM}(backup: ${installed}.bak)${NC}"
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
            local ver; ver=$(local_version "$installed")
            echo -e "    ${GREEN}✔${NC}  ${BOLD}$bin_name${NC}  v${ver}  —  $display_name"
        else
            echo -e "    ${DIM}–   $bin_name  —  $display_name  (not installed)${NC}"
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
