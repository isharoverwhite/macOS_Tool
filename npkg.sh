#!/bin/bash
# version: 1.0.0
# npkg — NPM Package Manager TUI
# Manage global and project-level NPM packages: list, update, install, remove.
# Requires: npm, python3 | Installed at: ~/.local/bin/npkg

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

PROJECT_DIR="$PWD"
MODE="project"
TMP_DIR=$(mktemp -d /tmp/npkg_XXXXXX)
trap 'rm -rf "$TMP_DIR"; tput cnorm; tput ed' EXIT INT TERM

if ! command -v npm &>/dev/null; then
    echo -e "${RED}Error: npm not found. Install Node.js: https://nodejs.org${NC}"; exit 1
fi
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}Error: python3 not found.${NC}"; exit 1
fi

[ ! -f "$PROJECT_DIR/package.json" ] && MODE="global"

# ── DATA ──────────────────────────────────────────────────────────────────────

declare -a PKG_NAMES=()
declare -a PKG_INSTALLED=()
declare -a PKG_LATEST=()
declare -a PKG_TYPE=()
declare -a PKG_STATUS=()
declare -A PKG_MARKED=()  # indices of packages marked for bulk delete

cat > "$TMP_DIR/parse.py" << 'PYEOF'
import json, sys, os

tmp = os.environ['NPKG_TMP']
mode = sys.argv[1]
project_dir = sys.argv[2]

def semver_gt(v1, v2):
    """True if v1 > v2 by numeric segment comparison."""
    try:
        p1 = [int(x) for x in v1.split('.')]
        p2 = [int(x) for x in v2.split('.')]
        n = max(len(p1), len(p2))
        p1 += [0] * (n - len(p1))
        p2 += [0] * (n - len(p2))
        return p1 > p2
    except Exception:
        return v1 > v2

try:
    with open(f'{tmp}/list.json') as f:
        list_data = json.load(f)
except Exception:
    list_data = {}

try:
    with open(f'{tmp}/outdated.json') as f:
        outdated_data = json.load(f)
except Exception:
    outdated_data = {}

dep_types = {}
if mode == 'project':
    try:
        with open(os.path.join(project_dir, 'package.json')) as f:
            pkg_json = json.load(f)
        for n in pkg_json.get('dependencies', {}):
            dep_types[n] = 'dep'
        for n in pkg_json.get('devDependencies', {}):
            dep_types[n] = 'dev'
    except Exception:
        pass

for name in sorted(list_data.get('dependencies', {})):
    info = list_data['dependencies'][name]
    installed = info.get('version', '?')
    if name in outdated_data:
        latest = outdated_data[name].get('latest', '?')
        # Only outdated if latest is strictly newer than installed
        if semver_gt(latest, installed):
            status = 'outdated'
        else:
            latest = installed
            status = 'ok'
    else:
        latest = installed
        status = 'ok'
    pkg_type = 'global' if mode == 'global' else dep_types.get(name, 'dep')
    print(f"{name}|{installed}|{latest}|{pkg_type}|{status}")
PYEOF

load_packages() {
    PKG_NAMES=(); PKG_INSTALLED=(); PKG_LATEST=(); PKG_TYPE=(); PKG_STATUS=()
    PKG_MARKED=()

    tput clear; print_header
    echo -e "\n  ${CYAN}→ Loading ${MODE} packages...${NC}"
    echo -e "  ${DIM}npm outdated queries the registry — may take a few seconds${NC}\n"

    local flags=""; [ "$MODE" = "global" ] && flags="-g"

    npm list $flags --depth=0 --json 2>/dev/null  > "$TMP_DIR/list.json"     || true
    npm outdated $flags --json 2>/dev/null         > "$TMP_DIR/outdated.json" || true

    while IFS='|' read -r name inst latest ptype status; do
        PKG_NAMES+=("$name"); PKG_INSTALLED+=("$inst"); PKG_LATEST+=("$latest")
        PKG_TYPE+=("$ptype"); PKG_STATUS+=("$status")
    done < <(NPKG_TMP="$TMP_DIR" python3 "$TMP_DIR/parse.py" "$MODE" "$PROJECT_DIR" 2>/dev/null)
}

# ── DISPLAY ───────────────────────────────────────────────────────────────────

print_header() {
    tput clear
    echo -e "${CYAN}${BOLD}┌───────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│                   NPM PACKAGE MANAGER  ·  npkg                            │${NC}"
    echo -e "${CYAN}${BOLD}└───────────────────────────────────────────────────────────────────────────┘${NC}"
}

display_table() {
    local cur="$1"

    print_header

    # Mode tabs
    local gtab ptab
    if [ "$MODE" = "global" ]; then
        gtab="${CYAN}${BOLD}[G] Global${NC}"; ptab="${DIM}[P] Project${NC}"
    else
        gtab="${DIM}[G] Global${NC}";         ptab="${CYAN}${BOLD}[P] Project${NC}"
    fi
    echo -e "\n  $gtab     $ptab"

    if [ "$MODE" = "project" ]; then
        if [ -f "$PROJECT_DIR/package.json" ]; then
            local pname; pname=$(python3 -c "import json; print(json.load(open('$PROJECT_DIR/package.json')).get('name','?'))" 2>/dev/null || echo "?")
            echo -e "  ${DIM}$PROJECT_DIR${NC}  ${GREEN}✔ $pname${NC}"
        else
            echo -e "  ${RED}✘ No package.json in $PROJECT_DIR${NC}"
        fi
    else
        echo -e "  ${DIM}node $(node --version 2>/dev/null || echo '?')  ·  npm $(npm --version 2>/dev/null || echo '?')${NC}"
    fi

    local total=${#PKG_NAMES[@]}
    local outdated_count=0
    local marked_count=${#PKG_MARKED[@]}
    [ "$total" -gt 0 ] && for s in "${PKG_STATUS[@]}"; do [ "$s" = "outdated" ] && (( outdated_count++ )) || true; done

    echo -e "\n${BOLD}▶ PACKAGES${NC}  ${DIM}$total installed${NC}$([ "$outdated_count" -gt 0 ] && echo "  ${YELLOW}$outdated_count outdated${NC}" || echo "  ${GREEN}all up to date${NC}")$([ "$marked_count" -gt 0 ] && echo "  ${RED}$marked_count marked${NC}" || true)"
    echo -e "┌──────┬───┬────────────────────────┬──────────┬──────────┬──────┬──────────┐"
    echo -e "│  ID  │ ● │ PACKAGE                │ INSTLD   │ LATEST   │ TYPE │ STATUS   │"
    echo -e "├──────┼───┼────────────────────────┼──────────┼──────────┼──────┼──────────┤"

    if [ "$total" -eq 0 ]; then
        echo -e "│             No packages found. Press [I] to install.                      │"
    else
        local page=12
        local start=0
        [ "$cur" -ge "$page" ] && start=$(( (cur / page) * page ))

        for (( i=start; i<start+page && i<total; i++ )); do
            # Cursor indicator
            local cursor_str="   "; [ "$i" -eq "$cur" ] && cursor_str="${CYAN}➜${NC} "
            # Mark indicator
            local mark_str=" "; [ "${PKG_MARKED[$i]+_}" ] && mark_str="${RED}*${NC}"
            # Type column (4 chars, plain text for printf alignment)
            local type_str type_color
            case "${PKG_TYPE[$i]}" in
                dev)    type_str="dev "; type_color="$BLUE"  ;;
                dep)    type_str="dep "; type_color="$GREEN" ;;
                global) type_str="glbl"; type_color="$CYAN"  ;;
                *)      type_str="    "; type_color="$NC"    ;;
            esac
            # Status column
            local status_str status_color
            if [ "${PKG_STATUS[$i]}" = "outdated" ]; then
                status_str="OUTDATED"; status_color="$YELLOW"
            else
                status_str="OK      "; status_color="$GREEN"
            fi
            # Package name color when highlighted
            local name_open="" name_close=""
            [ "$i" -eq "$cur" ] && name_open="${CYAN}${BOLD}" && name_close="${NC}"

            # Row: build piece by piece so printf handles plain-text widths correctly
            echo -ne "│ ${cursor_str}"
            printf "%-2s" "$i"
            echo -ne " │ ${mark_str} │ ${name_open}"
            printf "%-24s" "${PKG_NAMES[$i]:0:24}"
            echo -ne "${name_close} │ "
            printf "%-8s" "${PKG_INSTALLED[$i]:0:8}"
            echo -ne " │ "
            printf "%-8s" "${PKG_LATEST[$i]:0:8}"
            echo -ne " │ ${type_color}${type_str}${NC} │ ${status_color}${status_str}${NC} │\n"
        done

        local remaining=$(( total - start - page ))
        [ "$remaining" -gt 0 ] && \
            printf "│ %-75s│\n" "  ${DIM}... $remaining more packages (scroll down)${NC}"
    fi

    echo -e "└──────┴───┴────────────────────────┴──────────┴──────────┴──────┴──────────┘"
    echo -e "\n${BLUE}┌───────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "│ ${BOLD}[↑↓]${NC} Nav  ${BOLD}[SPACE]${NC} Mark  ${BOLD}[U]${NC} Update sel  ${BOLD}[A]${NC} Update all  ${BOLD}[I]${NC} Install  │"
    echo -e "│ ${BOLD}[D]${NC} Delete  ${BOLD}[G]${NC} Global  ${BOLD}[P]${NC} Project  ${BOLD}[R]${NC} Reload  ${BOLD}[CTRL+C]${NC} Exit      │"
    echo -e "${BLUE}└───────────────────────────────────────────────────────────────────────────┘${NC}"
}

# ── ACTIONS ───────────────────────────────────────────────────────────────────

do_install() {
    tput cnorm; print_header
    echo -e "\n${BOLD}▶ INSTALL PACKAGE${NC}\n"
    echo -ne "  ${YELLOW}Package name (or name@version): ${NC}"; read -r pkg_name || return
    [ -z "$pkg_name" ] && return

    local flags=""; [ "$MODE" = "global" ] && flags="-g"
    local save_flag=""

    if [ "$MODE" = "project" ]; then
        echo -ne "  ${YELLOW}Save as: [1] dependency  [2] devDependency: ${NC}"
        read -rsn1 dtype; echo ""
        [ "$dtype" = "2" ] && save_flag="--save-dev"
    fi

    echo -e "\n  ${CYAN}→ Installing ${BOLD}$pkg_name${NC}${CYAN}...${NC}\n"
    if npm install $flags $save_flag "$pkg_name"; then
        echo -e "\n  ${GREEN}✔ Installed: $pkg_name${NC}"
    else
        echo -e "\n  ${RED}✘ Install failed${NC}"
    fi
    sleep 1.5; load_packages
}

do_update_one() {
    local idx="$1"
    [ "${#PKG_NAMES[@]}" -eq 0 ] && return
    local pkg="${PKG_NAMES[$idx]}"
    local inst="${PKG_INSTALLED[$idx]}"
    local latest="${PKG_LATEST[$idx]}"
    local flags=""; [ "$MODE" = "global" ] && flags="-g"

    [ "$inst" = "$latest" ] && \
        echo -e "\n  ${GREEN}$pkg is already up to date ($inst)${NC}" && sleep 1.2 && return

    tput cnorm; print_header
    echo -e "\n  ${CYAN}→ Updating ${BOLD}$pkg${NC}${CYAN}  ($inst → $latest)...${NC}\n"
    if npm install $flags "${pkg}@latest"; then
        echo -e "\n  ${GREEN}✔ Updated: $pkg  ($inst → $latest)${NC}"
    else
        echo -e "\n  ${RED}✘ Update failed${NC}"
    fi
    sleep 1.2; load_packages
}

do_update_all() {
    local flags=""; [ "$MODE" = "global" ] && flags="-g"
    local outdated_list=()
    for i in "${!PKG_STATUS[@]}"; do
        [ "${PKG_STATUS[$i]}" = "outdated" ] && outdated_list+=("${PKG_NAMES[$i]}")
    done

    if [ "${#outdated_list[@]}" -eq 0 ]; then
        echo -e "\n  ${GREEN}All packages are already up to date.${NC}"; sleep 1.2; return
    fi

    tput cnorm; print_header
    echo -e "\n${BOLD}▶ UPDATING ${#outdated_list[@]} OUTDATED PACKAGES${NC}\n"
    local ok=0 fail=0
    for pkg in "${outdated_list[@]}"; do
        echo -ne "  ${CYAN}→ $pkg${NC}  "
        if npm install $flags "${pkg}@latest" > /dev/null 2>&1; then
            echo -e "${GREEN}✔${NC}"; (( ok++ )) || true
        else
            echo -e "${RED}✘${NC}"; (( fail++ )) || true
        fi
    done
    echo -e "\n  ${GREEN}Done: $ok updated${NC}$([ "$fail" -gt 0 ] && echo "  ${RED}$fail failed${NC}" || true)"
    sleep 1.5; load_packages
}

do_delete() {
    local cur="$1"
    local flags=""; [ "$MODE" = "global" ] && flags="-g"

    # Targets = all marked, or just cursor if nothing marked
    local targets=()
    if [ "${#PKG_MARKED[@]}" -gt 0 ]; then
        for i in "${!PKG_MARKED[@]}"; do targets+=("${PKG_NAMES[$i]}"); done
    else
        [ "${#PKG_NAMES[@]}" -eq 0 ] && return
        targets+=("${PKG_NAMES[$cur]}")
    fi

    tput cnorm; print_header
    echo -e "\n${BOLD}▶ REMOVE PACKAGES${NC}\n"
    for t in "${targets[@]}"; do echo -e "  ${RED}–  $t${NC}"; done
    echo -ne "\n  Confirm removing ${#targets[@]} package(s)? [y/N] "
    read -r confirm || true

    if [[ "$confirm" =~ ^[yY]$ ]]; then
        local ok=0 fail=0
        for pkg in "${targets[@]}"; do
            echo -ne "  ${CYAN}→ Removing $pkg...${NC}  "
            if npm uninstall $flags "$pkg" > /dev/null 2>&1; then
                echo -e "${GREEN}✔${NC}"; (( ok++ )) || true
            else
                echo -e "${RED}✘${NC}"; (( fail++ )) || true
            fi
        done
        echo -e "\n  ${GREEN}Done: $ok removed${NC}$([ "$fail" -gt 0 ] && echo "  ${RED}$fail failed${NC}" || true)"
    else
        echo -e "  ${DIM}Cancelled.${NC}"
    fi
    sleep 1.2; load_packages
}

# ── MAIN LOOP ─────────────────────────────────────────────────────────────────

selected=0
load_packages
tput civis

while true; do
    local_total="${#PKG_NAMES[@]}"
    [ "$local_total" -gt 0 ] && [ "$selected" -ge "$local_total" ] && selected=$(( local_total - 1 ))

    display_table "$selected"

    read -rsn1 key
    [[ -z "$key" ]] && continue
    if [[ "$key" == $'\x1b' ]]; then
        key_rest=""
        read -rsn2 -t 1 key_rest 2>/dev/null || true
        if   [[ "${key_rest}" == "[A" ]]; then
            [ "$local_total" -gt 0 ] && selected=$(( (selected - 1 + local_total) % local_total ))
        elif [[ "${key_rest}" == "[B" ]]; then
            [ "$local_total" -gt 0 ] && selected=$(( (selected + 1) % local_total ))
        fi
    else
    case "$key" in
        " ")
            if [ "$local_total" -gt 0 ]; then
                if [ "${PKG_MARKED[$selected]+_}" ]; then
                    unset "PKG_MARKED[$selected]"
                else
                    PKG_MARKED[$selected]=1
                fi
            fi
            ;;
        u|U) tput cnorm; do_update_one "$selected"; tput civis ;;
        a|A) tput cnorm; do_update_all; tput civis ;;
        i|I) tput cnorm; do_install; tput civis ;;
        d|D) tput cnorm; do_delete "$selected"; tput civis ;;
        r|R) selected=0; load_packages ;;
        g|G) MODE="global"; selected=0; load_packages ;;
        p|P)
            if [ ! -f "$PROJECT_DIR/package.json" ]; then
                tput cnorm; print_header
                echo -e "\n  ${RED}No package.json found in:${NC}\n  ${DIM}$PROJECT_DIR${NC}"
                echo -e "\n  ${YELLOW}cd into a Node.js project directory first, then run npkg.${NC}"
                sleep 2; tput civis
            else
                MODE="project"; selected=0; load_packages
            fi
            ;;
    esac
    fi
done
