#!/usr/bin/env bash
# native_template.sh - v2.1
# Optimized Nano-Style TUI (Flicker-free & Responsive)

set -u

# ── Global Config ─────────────────────────────────────────

APP_TITLE="Bash TUI v2"
VERSION="2.1"

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
# Fallbacks
KEY_UP_ALT=$'\eOA'
KEY_DOWN_ALT=$'\eOB'
KEY_ENTER='' 
KEY_ESC=$'\e'

# ── Core Engine ───────────────────────────────────────────

LINES=0
COLS=0
FULL_REDRAW=true

init_term() {
    echo -n "$SMCUP"
    echo -n "$CIVIS"
    stty -echo
    trap cleanup INT TERM EXIT
    # Trap resize signal (SIGWINCH) to trigger full redraw
    trap 'get_term_size; FULL_REDRAW=true' WINCH
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

# Helper: Print string padded/truncated to exact width
# Usage: fit_string "text" "width"
fit_string() {
    local str="$1"
    local width="$2"
    if [ "$width" -lt 1 ]; then width=1; fi
    # %-W.Ws pads to width AND truncates to width
    printf "%-${width}.${width}s" "$str"
}

# ── Drawing Primitives ────────────────────────────────────

draw_header() {
    local title="$1"
    local w=$COLS
    
    # Adaptive header
    local header_text
    if [ "$w" -lt 40 ]; then
        header_text=" $title"
    else
        header_text=" GNU nano-bash ${VERSION}   File: ${title}"
    fi

    tput cup 0 0
    echo -n "${REV}"
    fit_string "$header_text" "$w"
    echo -n "${NORM}"
}

draw_footer() {
    local hints="$1"
    local extra="${2:-}"
    local y=$((LINES - 1))
    # Use COLS-1 to prevent auto-wrap scroll on some terminals
    local w=$((COLS - 1))

    tput cup $y 0
    echo -n "${REV}"
    
    local full_hint="$hints"
    if [ -n "$extra" ] && [ "$w" -gt 60 ]; then
        full_hint="$hints   $extra"
    fi
    
    fit_string "$full_hint" "$w"
    echo -n "${NORM}"
}

draw_item() {
    local row="$1"     # Relative row index (0-based)
    local is_sel="$2"  # 0 or 1
    local type="$3"    # MENU, INPUT, CHECK
    local label="$4"
    local value="$5"

    local screen_row=$((row + 2))
    
    # Boundary check (don't draw over footer)
    if [ "$screen_row" -ge $((LINES - 1)) ]; then return; fi

    tput cup $screen_row 0
    
    # Calculate widths
    # Use COLS-1 for safety
    local total_w=$((COLS - 1))
    local lbl_w=20
    
    # Responsive widths
    if [ "$COLS" -lt 50 ]; then
        lbl_w=$((COLS * 40 / 100)) # 40% width for label
    fi
    
    local val_w=$((total_w - lbl_w - 2)) # -2 for spacing
    if [ "$val_w" -lt 1 ]; then val_w=1; fi

    # Construct the line content
    local line_content=""
    
    # Highlight logic
    if [ "$is_sel" -eq 1 ]; then
        echo -n "${REV}"
    fi

    # Draw Logic based on type
    case "$type" in
        MENU)
            # "[ Label ]      Value"
            local l_str=" $label"
            local v_str=" $value"
            
            # Print label
            fit_string "$l_str" "$lbl_w"
            
            # Print value
            fit_string "$v_str" $((total_w - lbl_w))
            ;;
            
        CHECK)
            # "[x] Label"
            local mark="[ ]"
            if [ "$value" == "true" ]; then mark="[x]"; fi
            local content=" $mark $label"
            fit_string "$content" "$total_w"
            ;;
            
        INPUT)
            # " Label: Value"
            local l_str=" $label:"
            local v_str=" $value"
            fit_string "$l_str" "$lbl_w"
            echo -n " " # spacer
            fit_string "$v_str" "$val_w"
            echo -n " " # spacer
            ;;
    esac

    echo -n "${NORM}"
}

# ── Input Widget ──────────────────────────────────────────

get_user_input() {
    local prompt="$1"
    local default="$2"
    local y=$((LINES - 2))
    
    tput cup $y 0
    echo -n "${REV}"
    fit_string " $prompt: " "$COLS"
    echo -n "${NORM}"
    
    tput cup $y $(( ${#prompt} + 3 ))
    echo -n "${CNORM}"
    
    # Read with default value (bash 4.0+)
    # If read -i fails (old bash), fallback to simple read
    read -e -i "$default" -p "" RESULT 2>/dev/null || read -e -p "" RESULT
    
    echo -n "${CIVIS}"
    FULL_REDRAW=true # Request full redraw to clear input line
}

# ── Views ─────────────────────────────────────────────────

# 1. Main Menu
view_main() {
    local selected=0
    local menu_items=("Form Demo" "Checkbox Demo" "About" "Exit")
    
    while true; do
        # 1. Handle Full Redraw (Resize or Init)
        if [ "$FULL_REDRAW" = true ]; then
            get_term_size
            tput clear
            draw_header "Main Menu"
            draw_footer "^X Exit   ENTER Select"
            FULL_REDRAW=false
        fi

        # 2. Draw Items (Double Buffer style: always overwrite)
        for i in "${!menu_items[@]}"; do
            local is_sel=0
            if [ "$i" -eq "$selected" ]; then is_sel=1; fi
            draw_item "$i" "$is_sel" "MENU" "${menu_items[$i]}" "..."
        done

        # 3. Input Handling
        read -rsn1 -t 0.1 key
        
        # Handle escape sequences
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 -t 0.01 seq
            key="$key$seq"
        fi

        case "$key" in
            $KEY_UP|$KEY_UP_ALT|k)
                ((selected--))
                [[ $selected -lt 0 ]] && selected=$((${#menu_items[@]} - 1))
                ;;
            $KEY_DOWN|$KEY_DOWN_ALT|j)
                ((selected++))
                [[ $selected -ge ${#menu_items[@]} ]] && selected=0
                ;;
            "") # Timeout/No key
                continue
                ;;
            $KEY_ENTER)
                case $selected in
                    0) view_form ;;
                    1) view_checks ;;
                    2) view_info ;;
                    3) return 0 ;;
                esac
                # Trigger redraw when returning from other views
                FULL_REDRAW=true 
                ;;
            q|x) return 0 ;;
        esac
    done
}

# 2. Form View
view_form() {
    local selected=0
    local inputs=("Username" "IP Address" "Port")
    local values=("guest" "127.0.0.1" "8080")
    
    FULL_REDRAW=true
    
    while true; do
        if [ "$FULL_REDRAW" = true ]; then
            get_term_size
            tput clear
            draw_header "Form Demo"
            draw_footer "^C Cancel   ENTER Edit   ^S Save"
            FULL_REDRAW=false
        fi

        # Draw Inputs
        for i in "${!inputs[@]}"; do
            local is_sel=0
            if [ "$i" -eq "$selected" ]; then is_sel=1; fi
            draw_item "$i" "$is_sel" "INPUT" "${inputs[$i]}" "${values[$i]}"
        done
        
        # Draw "Save" button at bottom
        local btn_idx=${#inputs[@]}
        local is_sel=0
        if [ "$selected" -eq "$btn_idx" ]; then is_sel=1; fi
        draw_item "$btn_idx" "$is_sel" "MENU" "[ Save Data ]" ""

        read -rsn1 -t 0.1 key
        if [[ "$key" == $'\e' ]]; then read -rsn2 -t 0.01 seq; key="$key$seq"; fi

        case "$key" in
            $KEY_UP|$KEY_UP_ALT|k)
                ((selected--))
                [[ $selected -lt 0 ]] && selected=$btn_idx
                ;;
            $KEY_DOWN|$KEY_DOWN_ALT|j)
                ((selected++))
                [[ $selected -gt $btn_idx ]] && selected=0
                ;;
            $KEY_ENTER)
                if [[ $selected -lt ${#inputs[@]} ]]; then
                    # Edit Input
                    get_user_input "Edit ${inputs[$selected]}" "${values[$selected]}"
                    values[$selected]="$RESULT"
                else
                    # Save
                    return 0
                fi
                ;;
            q|x) return 0 ;;
        esac
    done
}

# 3. Checkbox View
view_checks() {
    local selected=0
    local checks=("Enable Logging" "Dark Mode" "Auto-Update")
    local states=("true" "false" "true")
    
    FULL_REDRAW=true

    while true; do
        if [ "$FULL_REDRAW" = true ]; then
            get_term_size
            tput clear
            draw_header "Settings"
            draw_footer "Space Toggle   ENTER Confirm"
            FULL_REDRAW=false
        fi

        for i in "${!checks[@]}"; do
            local is_sel=0
            if [ "$i" -eq "$selected" ]; then is_sel=1; fi
            draw_item "$i" "$is_sel" "CHECK" "${checks[$i]}" "${states[$i]}"
        done
        
        # Back button
        local btn_idx=${#checks[@]}
        local is_sel=0
        if [ "$selected" -eq "$btn_idx" ]; then is_sel=1; fi
        draw_item "$btn_idx" "$is_sel" "MENU" "[ Back ]" ""

        read -rsn1 -t 0.1 key
        if [[ "$key" == $'\e' ]]; then read -rsn2 -t 0.01 seq; key="$key$seq"; fi

        case "$key" in
            $KEY_UP|$KEY_UP_ALT|k)
                ((selected--)); [[ $selected -lt 0 ]] && selected=$btn_idx ;;
            $KEY_DOWN|$KEY_DOWN_ALT|j)
                ((selected++)); [[ $selected -gt $btn_idx ]] && selected=0 ;;
            " ") # Space
                if [[ $selected -lt ${#checks[@]} ]]; then
                    if [[ "${states[$selected]}" == "true" ]]; then
                        states[$selected]="false"
                    else
                        states[$selected]="true"
                    fi
                fi
                ;;
            $KEY_ENTER)
                if [[ $selected -eq $btn_idx ]]; then return 0; fi
                ;;
            q|x) return 0 ;;
        esac
    done
}

# 4. Info View
view_info() {
    get_term_size
    tput clear
    draw_header "System Info"
    tput cup 2 0
    echo "  OS: $(uname -a)"
    echo "  Shell: $SHELL"
    echo "  Term: $TERM"
    echo ""
    echo "  Press any key to back..."
    read -rsn1
}

# ── Entry Point ───────────────────────────────────────────

main() {
    init_term
    view_main
    cleanup
}

main
