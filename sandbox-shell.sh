#!/bin/bash
# version: 1.0.0

# --- CONFIGURATION ---
SANDBOX_DIR="$HOME/.sandbox"
LOG_FILE="$SANDBOX_DIR/.sandbox_log"
LOG_DIR="$SANDBOX_DIR/logs"

# Project workspace context — captured at script start from $PWD
PROJECT_DIR="$PWD"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
PROJECT_DMG="$PROJECT_DIR/$PROJECT_NAME.dmg"
PROJECT_MNT="/Volumes/$PROJECT_NAME"

# --- ANSI COLORS ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── HELPERS ──────────────────────────────────────────────────────────────────

log_event() {
    local type="$1"; shift
    local msg="$*"
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] [%-6s] %s\n" "$ts" "$type" "$msg" >> "$LOG_FILE"
}

# Mount workspace disk của project hiện tại.
# Trả về mount path nếu thành công, chuỗi rỗng nếu không có DMG.
mount_project_dmg() {
    if [ ! -f "$PROJECT_DMG" ]; then
        return 1
    fi
    if [ ! -d "$PROJECT_MNT" ]; then
        hdiutil attach "$PROJECT_DMG" -mountpoint "$PROJECT_MNT" -quiet > /dev/null 2>&1
    fi
    echo "$PROJECT_MNT"
}

# Unmount workspace disk của project hiện tại.
unmount_project_dmg() {
    [ -d "$PROJECT_MNT" ] && hdiutil detach "$PROJECT_MNT" -quiet > /dev/null 2>&1
    return 0
}

# Tạo workspace disk trong thư mục project hiện tại.
create_project_dmg() {
    local size="$1"
    hdiutil create -size "$size" -fs HFS+ -volname "$PROJECT_NAME" "$PROJECT_DMG" > /dev/null
}

is_locked() { grep -q ";; locked" "$SANDBOX_DIR/$1" 2>/dev/null; }

lock_profile() {
    local f="$SANDBOX_DIR/$1"
    grep -q ";; locked" "$f" 2>/dev/null && return
    # Thêm marker vào dòng 2
    local tmp; tmp=$(mktemp)
    head -1 "$f" > "$tmp"
    echo ";; locked" >> "$tmp"
    tail -n +2 "$f" >> "$tmp"
    mv "$tmp" "$f"
    log_event "LOCK" "Profile: $1"
}

unlock_profile() {
    local f="$SANDBOX_DIR/$1"
    local tmp; tmp=$(mktemp)
    grep -v "^;; locked$" "$f" > "$tmp"
    mv "$tmp" "$f"
    log_event "UNLOCK" "Profile: $1"
}

# Đảm bảo ~/.zshrc có sandbox prompt indicator
ensure_prompt_indicator() {
    if ! grep -q "SB_NAME" "$HOME/.zshrc" 2>/dev/null; then
        cat >> "$HOME/.zshrc" <<'ZSHEOF'

# Sandbox prompt indicator (added by sbox)
if [[ -n "$SB_NAME" ]]; then
    RPROMPT="[${SB_NAME%.sb}] $RPROMPT"
fi
ZSHEOF
        echo -e "${GREEN}  ✔ Sandbox prompt indicator added to ~/.zshrc${NC}"
    fi
}

print_header() {
    tput clear
    echo -e "${CYAN}${BOLD}┌───────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│                      MAC OS HARDENED SANDBOX MANAGER                      │${NC}"
    echo -e "${CYAN}${BOLD}│                  Developed by Dinh Trung Kien (Experience)                │${NC}"
    echo -e "${CYAN}${BOLD}└───────────────────────────────────────────────────────────────────────────┘${NC}"
}

# ─── INIT ─────────────────────────────────────────────────────────────────────

init_system() {
    [ ! -d "$SANDBOX_DIR" ] && mkdir -p "$SANDBOX_DIR"
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    find "$SANDBOX_DIR" -maxdepth 1 -type f ! -name "*.sb" ! -name ".*" -delete
    ensure_prompt_indicator
}

# ─── DMG SIZE PICKER (dùng chung cho create_profile & template) ───────────────

pick_dmg_size() {
    echo -e "\n${YELLOW}  Choose Workspace Disk size:${NC}"
    echo -e "  ${CYAN}[1] 512MB  [2] 1GB  [3] 2GB  [ESC] Skip${NC}"
    read -rsn1 choice
    case "$choice" in
        1) echo "512m" ;;
        2) echo "1g" ;;
        3) echo "2g" ;;
        *) echo "" ;;
    esac
}

# ─── LAUNCH SANDBOX ───────────────────────────────────────────────────────────

do_launch() {
    local profile="$1"
    local cmd="${2:-/bin/zsh}"
    local p_file="$SANDBOX_DIR/$profile"

    if [ ! -f "$p_file" ]; then
        echo -e "${RED}  [ERROR] Profile not found: $profile${NC}"
        return 1
    fi

    local mnt; mnt=$(mount_project_dmg)
    if [ -z "$mnt" ]; then
        echo -e "${YELLOW}  [WARN] No workspace disk found in '$PROJECT_DIR' — MNT unavailable.${NC}"
        echo -e "${YELLOW}         Run sbox and press [W] to create one.${NC}"
        mnt="/tmp"
    fi

    local start_ts; start_ts=$(date +%s)
    log_event "LAUNCH" "Profile: $profile | Project: $PROJECT_NAME | MNT: $mnt"

    if [[ "$cmd" == "/bin/zsh" ]]; then
        sandbox-exec -f "$p_file" -D HOME="$HOME" -D MNT="$mnt" \
            /usr/bin/env SB_NAME="$profile" SB_PROJECT="$PROJECT_NAME" /bin/zsh
    else
        sandbox-exec -f "$p_file" -D HOME="$HOME" -D MNT="$mnt" \
            /usr/bin/env SB_NAME="$profile" SB_PROJECT="$PROJECT_NAME" /bin/zsh -c "$cmd"
    fi

    local exit_code=$?
    local end_ts; end_ts=$(date +%s)
    local duration=$(( end_ts - start_ts ))
    local mins=$(( duration / 60 )); local secs=$(( duration % 60 ))
    log_event "EXIT" "Profile: $profile | Project: $PROJECT_NAME | Duration: ${mins}m${secs}s | Exit: $exit_code"

    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}  [ERROR] sandbox-exec exited with code $exit_code${NC}"
    fi

    unmount_project_dmg
    return $exit_code
}

# ─── QUICK-LAUNCH (CLI args) ──────────────────────────────────────────────────

quick_launch() {
    local profile="$1"
    # Thêm .sb nếu chưa có
    [[ "$profile" != *.sb ]] && profile="${profile}.sb"
    init_system
    echo -e "${GREEN} Launching Sandbox: ${BOLD}$profile${NC}\n"
    do_launch "$profile"
    exit $?
}

run_in_sandbox() {
    local profile="$1"
    local cmd="$2"
    [[ "$profile" != *.sb ]] && profile="${profile}.sb"
    init_system
    echo -e "${GREEN} Running in Sandbox: ${BOLD}$profile${NC} → $cmd\n"
    do_launch "$profile" "$cmd"
    exit $?
}

# ─── CREATE PROFILE WIZARD ────────────────────────────────────────────────────

create_profile() {
    local p_name=""
    local -a perms=("Internet (Outbound)" "Network (Inbound/Server)" "System Write Access" "Process Forking" "Hardware (USB/Serial)" "Shared Memory (IPC)")
    local -a p_status=("OFF" "OFF" "OFF" "ON" "OFF" "OFF")

    local -a paths=($(find "$HOME" -maxdepth 1 -type d -not -path '*/.*' -exec basename {} \; | sort))
    local -a usb_ports=($(ls /dev/cu.* 2>/dev/null))
    local -a items=("${paths[@]}" "${usb_ports[@]}" "MANUAL_INPUT")
    local -a item_status=()
    local -a manual_paths=()
    for i in "${items[@]}"; do item_status+=("BLOCK"); done

    local step=0
    local page_size=6
    local total_perms=${#perms[@]}
    local total_items=$(( total_perms + ${#items[@]} ))

    tput cnorm
    print_header
    echo -ne "${YELLOW}  Enter Profile Name: ${NC}"; read raw_name
    [ -z "$raw_name" ] && return
    p_name=$(echo "$raw_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

    tput civis
    while true; do
        tput cup 5 0
        echo -e "${BOLD}▶ CONFIGURING: ${YELLOW}$p_name.sb${NC}                                     "
        echo -e "${BLUE}┌──────┬──────────────────────────────────────────────────────────┬─────────┐${NC}"
        echo -e "${BLUE}│      │ SYSTEM PERMISSIONS                                       │ STATUS  │${NC}"
        echo -e "${BLUE}├──────┼──────────────────────────────────────────────────────────┼─────────┤${NC}"

        for i in "${!perms[@]}"; do
            echo -ne "${BLUE}│ ${NC}"
            [ $step -eq $i ] && echo -ne "${CYAN}  ➜   ${NC}" || echo -ne "      "
            printf "%-56s ${BLUE}│${NC} " "${perms[$i]}"
            [ "${p_status[$i]}" == "ON" ] && echo -ne "${GREEN}" || echo -ne "${RED}"
            printf "%-7s" "[${p_status[$i]}]"
            echo -e "${NC} ${BLUE}│${NC}"
        done

        echo -e "${BLUE}├──────┼──────────────────────────────────────────────────────────┼─────────┤${NC}"
        echo -e "${BLUE}│      │ SCANNED PATHS & USB PORTS (Scroll)                       │ ACCESS  │${NC}"
        echo -e "${BLUE}├──────┼──────────────────────────────────────────────────────────┼─────────┤${NC}"

        local start_idx=0
        [ $step -ge $total_perms ] && start_idx=$(( ((step - total_perms) / page_size) * page_size ))

        for (( j=0; j<page_size; j++ )); do
            local idx=$(( start_idx + j ))
            echo -ne "${BLUE}│ ${NC}"
            if [ $idx -lt ${#items[@]} ]; then
                curr_step_idx=$(( idx + total_perms ))
                [ $step -eq $curr_step_idx ] && echo -ne "${CYAN}  ➜   ${NC}" || echo -ne "      "

                if [[ "${items[$idx]}" == "MANUAL_INPUT" ]]; then label="[Add Custom Path...]"
                elif [[ "${items[$idx]}" == /dev/* ]]; then label="USB: ${items[$idx]}"
                else label="Dir: ~/${items[$idx]}"; fi

                printf "%-56s ${BLUE}│${NC} " "${label:0:56}"
                [ "${item_status[$idx]}" == "ALLOW" ] && echo -ne "${GREEN}" || echo -ne "${RED}"
                printf "%-7s" "[${item_status[$idx]}]"
                echo -e "${NC} ${BLUE}│${NC}"
            else
                printf "      %-56s ${BLUE}│${NC} %-7s ${BLUE}│${NC}\n" "" ""
            fi
        done
        echo -e "${BLUE}└──────┴──────────────────────────────────────────────────────────┴─────────┘${NC}"
        echo -e "\n${CYAN}  [↑/↓] Nav | [Enter] Toggle | [S] Save | [ESC] Cancel${NC}"
        tput ed

        read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 1 key_rest 2>/dev/null
            if [[ "$key_rest" == "[A" ]]; then ((step--)); [ $step -lt 0 ] && step=$((total_items - 1))
            elif [[ "$key_rest" == "[B" ]]; then ((step++)); [ $step -ge $total_items ] && step=0
            else tput cnorm; return 0; fi
        elif [[ "$key" == "" ]]; then
            if [ $step -lt $total_perms ]; then [ "${p_status[$step]}" == "ON" ] && p_status[$step]="OFF" || p_status[$step]="ON"
            else
                p_idx=$(( step - total_perms ))
                if [[ "${items[$p_idx]}" == "MANUAL_INPUT" ]]; then
                    tput cnorm; tput cup $(($(tput lines) - 1)) 0
                    echo -ne "${YELLOW}Enter Absolute Path: ${NC}"; read custom_p
                    [ -n "$custom_p" ] && manual_paths+=("$custom_p")
                    tput civis; print_header
                else [ "${item_status[$p_idx]}" == "ALLOW" ] && item_status[$p_idx]="BLOCK" || item_status[$p_idx]="ALLOW"; fi
            fi
        elif [[ "$key" == "s" || "$key" == "S" ]]; then
            _save_profile "$p_name" p_status item_status items manual_paths
            break
        fi
    done
    tput cnorm
}

_save_profile() {
    local p_name="$1"
    local -n _p_status=$2
    local -n _item_status=$3
    local -n _items=$4
    local -n _manual_paths=$5
    local p_file="$SANDBOX_DIR/$p_name.sb"

    {
        echo ";; [cyan] Custom: $p_name"
        echo "(version 1)"
        [[ "${_p_status[0]}" == "ON" ]] && echo "(allow network-outbound)" || echo "(deny network-outbound)"
        [[ "${_p_status[1]}" == "ON" ]] && echo "(allow network-inbound)"
        [[ "${_p_status[3]}" == "ON" ]] && echo "(allow process-fork)"
        [[ "${_p_status[2]}" == "OFF" ]] && echo "(deny file-write* (subpath \"/usr\") (subpath \"/bin\") (subpath \"/System\") (subpath \"/Library\"))"
        [[ "${_p_status[4]}" == "ON" ]] && echo "(allow iokit-open) (allow device-mount)"
        [[ "${_p_status[5]}" == "ON" ]] && echo "(allow ipc-posix*)"
        for k in "${!_items[@]}"; do
            [[ "${_items[$k]}" == "MANUAL_INPUT" || "${_item_status[$k]}" == "BLOCK" ]] && continue
            if [[ "${_items[$k]}" == /dev/* ]]; then echo "(allow file-read* file-write* (path \"${_items[$k]}\"))"
            else echo "(allow file-read* file-write* (subpath (string-append (param \"HOME\") \"/${_items[$k]}\")))" ; fi
        done
        for mp in "${_manual_paths[@]}"; do echo "(allow file-read* file-write* (subpath \"$mp\"))"; done
        echo "(allow file-read* file-write* (subpath (param \"MNT\")))"
        echo "(allow default) (allow process-exec) (allow file-read* file-write* (tty))"
    } > "$p_file"

    log_event "CREATE" "Profile: $p_name.sb"
    echo -e "${GREEN}  ✔ Profile saved!${NC}"; sleep 1
}

# ─── TEMPLATES ────────────────────────────────────────────────────────────────

create_from_template() {
    local templates=("web-dev" "data-science" "minimal")
    local selected_t=0

    tput civis
    while true; do
        print_header
        echo -e "${BOLD}▶ SELECT TEMPLATE${NC}\n"
        echo -e "┌──────┬──────────────────────┬─────────────────────────────────────────────┐"
        echo -e "│      │ TEMPLATE             │ DESCRIPTION                                 │"
        echo -e "├──────┼──────────────────────┼─────────────────────────────────────────────┤"

        local descs=("Network OUT, no system writes, dev dirs" "No network, read/write docs & downloads" "Maximum isolation, MNT only")
        for i in "${!templates[@]}"; do
            if [ $i -eq $selected_t ]; then
                printf "│ ${CYAN}➜${NC} %-3s │ ${CYAN}${BOLD}%-20s${NC} │ %-43s │\n" "$i" "${templates[$i]}" "${descs[$i]}"
            else
                printf "│    %-3s │ %-20s │ %-43s │\n" "$i" "${templates[$i]}" "${descs[$i]}"
            fi
        done
        echo -e "└──────┴──────────────────────┴─────────────────────────────────────────────┘"
        echo -e "\n${CYAN}  [↑/↓] Nav | [Enter] Select | [ESC] Cancel${NC}"

        read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 1 key_rest 2>/dev/null
            if [[ "$key_rest" == "[A" ]]; then ((selected_t--)); [ $selected_t -lt 0 ] && selected_t=$(( ${#templates[@]} - 1 ))
            elif [[ "$key_rest" == "[B" ]]; then ((selected_t++)); [ $selected_t -ge ${#templates[@]} ] && selected_t=0
            else tput cnorm; return; fi
        elif [[ "$key" == "" ]]; then
            break
        fi
    done

    tput cnorm
    local tpl="${templates[$selected_t]}"
    print_header
    echo -ne "${YELLOW}  Profile name (template: $tpl): ${NC}"; read raw_name
    [ -z "$raw_name" ] && return
    local p_name; p_name=$(echo "$raw_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    local p_file="$SANDBOX_DIR/$p_name.sb"

    case "$tpl" in
        web-dev)
            cat > "$p_file" <<EOF
;; [green] Template: web-dev ($p_name)
(version 1)
(allow network-outbound)
(deny network-inbound)
(allow process-fork)
(deny file-write* (subpath "/usr") (subpath "/bin") (subpath "/System") (subpath "/Library"))
(allow file-read* file-write* (subpath (string-append (param "HOME") "/Downloads")))
(allow file-read* file-write* (subpath (string-append (param "HOME") "/Developer")))
(allow file-read* file-write* (subpath (param "MNT")))
(allow default) (allow process-exec) (allow file-read* file-write* (tty))
EOF
        ;;
        data-science)
            cat > "$p_file" <<EOF
;; [yellow] Template: data-science ($p_name)
(version 1)
(deny network-outbound)
(deny network-inbound)
(allow process-fork)
(deny file-write* (subpath "/usr") (subpath "/bin") (subpath "/System") (subpath "/Library"))
(allow file-read* file-write* (subpath (string-append (param "HOME") "/Documents")))
(allow file-read* file-write* (subpath (string-append (param "HOME") "/Downloads")))
(allow file-read* file-write* (subpath (param "MNT")))
(allow default) (allow process-exec) (allow file-read* file-write* (tty))
EOF
        ;;
        minimal)
            cat > "$p_file" <<EOF
;; [red] Template: minimal ($p_name)
(version 1)
(deny network-outbound)
(deny network-inbound)
(deny file-write* (subpath "/usr") (subpath "/bin") (subpath "/System") (subpath "/Library"))
(allow file-read* file-write* (subpath (param "MNT")))
(allow default) (allow process-exec) (allow file-read* file-write* (tty))
EOF
        ;;
    esac

    log_event "CREATE" "Profile: $p_name.sb (template: $tpl)"
    echo -e "${GREEN}  ✔ Profile '$p_name' created from template '$tpl'!${NC}"
    sleep 1
}

# ─── WORKSPACE DISK CREATION ──────────────────────────────────────────────────

create_workspace_disk() {
    tput cnorm
    print_header
    echo -e "${BOLD}▶ CREATE WORKSPACE DISK${NC}"
    echo -e "  Project : ${CYAN}$PROJECT_DIR${NC}"
    echo -e "  DMG     : ${CYAN}$PROJECT_DMG${NC}"
    echo -e "  Mount   : ${CYAN}$PROJECT_MNT${NC}\n"

    if [ -f "$PROJECT_DMG" ]; then
        echo -e "${YELLOW}  Workspace disk already exists for this project.${NC}"
        sleep 1.5; return
    fi

    local size; size=$(pick_dmg_size)
    if [ -z "$size" ]; then return; fi

    echo -e "${YELLOW}  Creating ${size} workspace disk...${NC}"
    create_project_dmg "$size"
    log_event "WDISK" "Created: $PROJECT_DMG (${size})"
    echo -e "${GREEN}  ✔ Workspace disk created: $PROJECT_DMG${NC}"
    sleep 1.2
}

# ─── LOG VIEWER ───────────────────────────────────────────────────────────────

view_logs() {
    tput cnorm
    if [ ! -s "$LOG_FILE" ]; then
        echo -e "\n${YELLOW}  No log entries yet.${NC}"; sleep 1.5; return
    fi
    less -R "$LOG_FILE"
}

# ─── DASHBOARD TABLE ──────────────────────────────────────────────────────────

display_table() {
    echo -e "${BOLD}▶ SYSTEM STATUS${NC}"

    PROFILES=($(ls "$SANDBOX_DIR"/*.sb 2>/dev/null | xargs -n 1 basename 2>/dev/null))

    # Workspace disk dựa trên project (thư mục hiện tại)
    echo -e "  ${BOLD}Project:${NC} ${CYAN}$PROJECT_DIR${NC}"
    if [ -d "$PROJECT_MNT" ]; then
        echo -e "  [${GREEN}OK${NC}] Workspace Disk: ${GREEN}Mounted → $PROJECT_MNT${NC}"
    elif [ -f "$PROJECT_DMG" ]; then
        echo -e "  [${YELLOW}--${NC}] Workspace Disk: ${YELLOW}Found but not mounted ($PROJECT_NAME.dmg)${NC}"
    else
        echo -e "  [${RED}!!${NC}] ${RED}No workspace disk in this project — press [W] to create${NC}"
    fi

    if [ ${#PROFILES[@]} -eq 0 ]; then
        echo -e "  [${YELLOW}!!${NC}] ${YELLOW}WARNING: No profiles found. Press [C] or [T] to create one.${NC}"
    fi

    echo -e "\n${BOLD}▶ SECURITY PROFILES${NC}"
    echo -e "┌──────┬────────────────────────┬──────┬─────────────────────────────────────────┐"
    echo -e "│  ID  │ PROFILE NAME           │ LOCK │ DESCRIPTION                             │"
    echo -e "├──────┼────────────────────────┼──────┼─────────────────────────────────────────┤"
    for i in "${!PROFILES[@]}"; do
        local file_path="$SANDBOX_DIR/${PROFILES[$i]}"
        local line1; line1=$(head -n 1 "$file_path" 2>/dev/null)
        local color; color=$(echo "$line1" | grep -o "\[.*\]" | tr -d '[]' | head -1)
        local desc; desc=$(echo "$line1" | sed 's/;; \[.*\] //')
        local lock_str="    "
        is_locked "${PROFILES[$i]}" && lock_str=" [L]"
        case $color in red) c=$RED ;; yellow) c=$YELLOW ;; green) c=$GREEN ;; cyan) c=$CYAN ;; *) c=$NC ;; esac
        if [ $i -eq $selected ]; then
            printf "│ ${CYAN}➜${NC} %-3s │ ${c}${BOLD}%-22s${NC} │${YELLOW}%4s${NC}  │ ${c}%-39s${NC} │\n" "$i" "${PROFILES[$i]}" "$lock_str" "${desc:0:39}"
        else
            printf "│    %-3s │ %-22s │%4s  │ %-39s │\n" "$i" "${PROFILES[$i]}" "$lock_str" "${desc:0:39}"
        fi
    done
    echo -e "└──────┴────────────────────────┴──────┴─────────────────────────────────────────┘"
}

# ─── ARGUMENT PARSING ─────────────────────────────────────────────────────────

if [[ -n "$1" && "$1" != "--run" ]]; then
    quick_launch "$1"
elif [[ "$1" == "--run" ]]; then
    if [[ -z "$2" || -z "$3" ]]; then
        echo -e "${RED}Usage: sbox --run <profile> <command>${NC}"
        exit 1
    fi
    run_in_sandbox "$2" "$3"
fi

# ─── MAIN TUI LOOP ────────────────────────────────────────────────────────────

selected=0
init_system
tput civis
trap "tput cnorm; tput ed; exit" INT TERM

while true; do
    print_header
    display_table
    echo -e "\n${BLUE}┌───────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "│ ${BOLD}KEYS:${NC} [C] Create | [T] Template | [W] Workspace | [K] Lock | [D] Delete  │"
    echo -e "│       [L] Logs | [ENTER] Launch | [CTRL+C] Exit                           │"
    echo -e "${BLUE}└───────────────────────────────────────────────────────────────────────────┘${NC}"

    read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 1 key_rest 2>/dev/null
        if [[ "$key_rest" == "[A" ]]; then ((selected--)); [ $selected -lt 0 ] && selected=$(( ${#PROFILES[@]} - 1 ))
        elif [[ "$key_rest" == "[B" ]]; then ((selected++)); [ $selected -ge ${#PROFILES[@]} ] && selected=0; fi
    elif [[ "$key" == "" ]]; then
        [ ${#PROFILES[@]} -gt 0 ] && break || sleep 0.1
    elif [[ "$key" == "c" || "$key" == "C" ]]; then
        create_profile
    elif [[ "$key" == "t" || "$key" == "T" ]]; then
        create_from_template
    elif [[ "$key" == "w" || "$key" == "W" ]]; then
        create_workspace_disk
        tput civis
    elif [[ "$key" == "k" || "$key" == "K" ]]; then
        target="${PROFILES[$selected]:-}"
        if [ -n "$target" ]; then
            if is_locked "$target"; then
                unlock_profile "$target"
                echo -e "\n${GREEN}  Unlocked: $target${NC}"; sleep 0.8
            else
                lock_profile "$target"
                echo -e "\n${YELLOW}  Locked: $target${NC}"; sleep 0.8
            fi
        fi
    elif [[ "$key" == "d" || "$key" == "D" ]]; then
        target="${PROFILES[$selected]:-}"
        if [ -n "$target" ] && is_locked "$target"; then
            tput cnorm; echo -e "\n${RED}${BOLD}  [ERROR] $target is locked — unlock with [K] first.${NC}"
            tput civis; sleep 1.2
        elif [ -n "$target" ]; then
            rm "$SANDBOX_DIR/$target"
            log_event "DELETE" "Profile: $target"
            sleep 0.5
        fi
    elif [[ "$key" == "l" || "$key" == "L" ]]; then
        view_logs
        tput civis
    fi
done

tput cnorm
SELECTED_PROFILE="${PROFILES[$selected]}"
echo -e "\n${GREEN} Launching Sandbox: ${BOLD}$SELECTED_PROFILE${NC}\n"
do_launch "$SELECTED_PROFILE"
