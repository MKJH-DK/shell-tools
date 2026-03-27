#!/usr/bin/env bash
# native_template.sh - v2.0
# Optimized Nano-Style TUI (Responsive & Mobile Ready)

set -u

# ── Global Config ─────────────────────────────────────────

APP_TITLE="Bash TUI v2"

# ── Terminal Capabilities ─────────────────────────────────

# Save formatting codes
REV=$(tput rev)
NORM=$(tput sgr0)
BOLD=$(tput bold)
CIVIS=$(tput civis) # Hide cursor
CNORM=$(tput cnorm) # Show cursor
SMCUP=$(tput smcup) # Save screen
RMCUP=$(tput rmcup) # Restore screen

# Key codes
KEY_UP=$'\e[A'
KEY_DOWN=$'\e[B'
KEY_RIGHT=$'\e[C'
KEY_LEFT=$'\e[D'
# Fallbacks for some terms
KEY_UP_ALT=$'\eOA'
KEY_DOWN_ALT=$'\eOB'

# Global State
LINES=0
COLS=0
SELECTED=0

# ── Core Engine ───────────────────────────────────────────

init_term() {
    echo -n "$SMCUP"
    echo -n "$CIVIS"
    stty -echo
    trap cleanup INT TERM EXIT
    # Trap resize signal (SIGWINCH) to redraw immediately
    trap 'get_term_size; DRAW_REQ=true' WINCH
}

cleanup() {
    stty echo
    echo -n "$CNORM"
    echo -n "$RMCUP"
    exit 0
}

get_term_size() {
    LINES=$(tput lines)
    COLS=$(tput cols)
}

# String Truncate/Pad Helper
# Usage: fit_string "Text" "Width" "AlignLeft=1"
fit_string() {
    local str="$1"
    local width="$2"
    local align="${3:-1}" # 1=Left, 0=Right (not impl, usually left)
    
    if [ ${#str} -gt $width ]; then
        echo -n "${str:0:$width}"
    else
        printf "%-${width}s" "$str"
    fi
}

# ── Drawing Primitives ────────────────────────────────────

draw_header() {
    local title="$1"
    tput cup 0 0
    
    # Adapt header based on width
    local header_text=""
    if [ "$COLS" -lt 40 ]; then
        header_text=" $title" # Minimal header for phones
    else
        header_text="  GNU nano-bash  |  $APP_TITLE  |  $title"
    fi
    
    printf "${REV}%-${COLS}.${COLS}s${NORM}" "$header_text"
}

draw_footer() {
    local hints="$1" # e.g., "^X Exit"
    local extra="$2" # e.g., "^M Select"
    
    # Calculate Y position (Last line)
    local y=$((LINES - 1))
    tput cup $y 0
    
    # Combine hints
    local full_hint="$hints   $extra"
    
    # If screen is wide, use full hint. If narrow, prioritize 'hints' (usually Exit/Back)
    local display_text=""
    if [ ${#full_hint} -lt $COLS ]; then
        display_text="$full_hint"
    else
        display_text="$hints" # Collapse priority
    fi
    
    printf "${REV}%-${COLS}.${COLS}s${NORM}" "$display_text"
}

# Generic Item Drawer
# type: MENU, CHECK, RADIO, INPUT
draw_item() {
    local idx="$1"
    local is_sel="$2"
    local type="$3"
    local label="$4"
    local val="$5"
    
    local row=$((2 + idx))
    # Safety check: Don't draw off screen
    if [ "$row" -ge $((LINES - 1)) ]; then return; fi
    
    tput cup $row 0
    
    # ── Responsive Layout Logic ──
    # Determine column widths dynamically
    local lbl_w=0
    local val_w=0
    
    if [ "$COLS" -lt 40 ]; then
        # Mobile / Narrow: Label gets 40%, Value gets 60% (minus margins)
        lbl_w=$(( (COLS * 40) / 100 ))
        val_w=$(( COLS - lbl_w - 3 ))
    else
        # Desktop / Wide: Label fixed ~25 chars, Value takes rest
        lbl_w=25
        val_w=$(( COLS - lbl_w - 4 ))
    fi
    
    # Construct Content
    local draw_lbl=""
    local draw_val=""
    
    case "$type" in
        MENU)
            # Menu items use full width
            draw_lbl="$label"
            draw_val="$val" # Description
            ;;
        CHECK)
            local mark="[ ]"
            [[ "$val" == "true" ]] && mark="[x]"
            draw_lbl="$mark $label"
            draw_val=""
            ;;
        RADIO)
            draw_lbl="$label:"
            draw_val="< $val >"
            ;;
        INPUT)
            draw_lbl="$label:"
            draw_val="$val"
            ;;
    esac
    
    # Render line with truncation
    # 1. Prepare Label
    local fin_lbl=$(fit_string "$draw_lbl" "$lbl_w")
    
    # 2. Prepare Value
    local fin_val=$(fit_string "$draw_val" "$val_w")
    
    local line_content=" ${fin_lbl}  ${fin_val}"
    
    if [ "$is_sel" -eq 1 ]; then
        printf "${REV}%-${COLS}.${COLS}s${NORM}" "$line_content"
    else
        printf "%-${COLS}.${COLS}s" "$line_content"
    fi
}

# ── Input Logic ──────────────────────────────────────────

# Simple input prompt overlay
get_user_input() {
    local label="$1"
    local default="$2"
    
    tput cup $((LINES-2)) 0
    printf "${REV}%-${COLS}.${COLS}s${NORM}" "  $label: $default"
    tput cup $((LINES-2)) $(( ${#label} + 4 ))
    
    echo -n "$CNORM"
    read -r -e -i "$default" RESULT
    echo -n "$CIVIS"
    
    # Clear input line
    tput cup $((LINES-2)) 0
    printf "%-${COLS}s" " "
}

# ── Views ────────────────────────────────────────────────

view_form() {
    local sel=0
    local inputs=("Username" "API Key" "Server IP" "Port")
    local vals=("guest" "" "192.168.1.1" "8080")
    local btns=("Save" "Cancel")
    
    DRAW_REQ=true
    
    while true; do
        if [ "$DRAW_REQ" = true ]; then
            get_term_size
            tput clear
            draw_header "Form Data"
            
            # Draw Inputs
            for i in "${!inputs[@]}"; do
                local is_s=0; [ $i -eq $sel ] && is_s=1
                draw_item "$i" "$is_s" "INPUT" "${inputs[$i]}" "${vals[$i]}"
            done
            
            # Draw Buttons
            local offset=${#inputs[@]}
            for j in "${!btns[@]}"; do
                local idx=$((offset + j))
                local is_s=0; [ $idx -eq $sel ] && is_s=1
                draw_item "$idx" "$is_s" "MENU" "[ ${btns[$j]} ]" ""
            done
            
            draw_footer "^X Cancel" "^M Edit/Save"
            DRAW_REQ=false
        fi
        
        read -rsn1 key
        if [[ "$key" == $'\e' ]]; then read -rsn2 -t 0.01 seq; key="$key$seq"; fi
        
        local max_idx=$(( ${#inputs[@]} + ${#btns[@]} ))
        
        case "$key" in
            $KEY_UP|$KEY_UP_ALT|k) 
                ((sel--)); [[ $sel -lt 0 ]] && sel=$((max_idx-1))
                DRAW_REQ=true
                ;;
            $KEY_DOWN|$KEY_DOWN_ALT|j)
                ((sel++)); [[ $sel -ge $max_idx ]] && sel=0
                DRAW_REQ=true
                ;;
            "") # Enter
                if [ $sel -lt ${#inputs[@]} ]; then
                    get_user_input "${inputs[$sel]}" "${vals[$sel]}"
                    vals[$sel]="$RESULT"
                    DRAW_REQ=true
                elif [ $sel -eq ${#inputs[@]} ]; then
                    return 0 # Save
                else
                    return 0 # Cancel
                fi
                ;;
            q|x) return 0 ;;
        esac
    done
}

view_main() {
    local sel=0
    local options=("Form Demo" "Checkboxes" "System Info" "Exit")
    local descs=("Inputs & Data" "Toggles" "OS Details" "Quit App")
    
    DRAW_REQ=true
    
    while true; do
        if [ "$DRAW_REQ" = true ]; then
            get_term_size
            tput clear
            draw_header "Main Menu"
            
            for i in "${!options[@]}"; do
                local is_s=0; [ $i -eq $sel ] && is_s=1
                draw_item "$i" "$is_s" "MENU" "${options[$i]}" "${descs[$i]}"
            done
            
            draw_footer "^X Exit" "^M Select"
            DRAW_REQ=false
        fi

        read -rsn1 key
        # Handle escape sequences properly
        if [[ "$key" == $'\e' ]]; then
             read -rsn2 -t 0.01 seq
             key="$key$seq"
        fi
        
        case "$key" in
            $KEY_UP|$KEY_UP_ALT|k)
                ((sel--)); [[ $sel -lt 0 ]] && sel=$((${#options[@]} - 1))
                DRAW_REQ=true
                ;;
            $KEY_DOWN|$KEY_DOWN_ALT|j)
                ((sel++)); [[ $sel -ge ${#options[@]} ]] && sel=0
                DRAW_REQ=true
                ;;
            "") # Enter
                case $sel in
                    0) view_form; DRAW_REQ=true ;;
                    1) # Checkboxes demo (simplified for brevity)
                       DRAW_REQ=true ;; 
                    2) # Info
                       get_term_size; tput clear; echo "OS: $(uname -a)"; read -n1; DRAW_REQ=true ;;
                    3) return 0 ;;
                esac
                ;;
            q|x) return 0 ;;
        esac
    done
}

# ── Entry Point ──────────────────────────────────────────

main() {
    init_term
    view_main
    cleanup
}

main
