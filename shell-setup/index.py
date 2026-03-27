#!/usr/bin/env python3
import curses
import os
import subprocess
import platform

# ── Configuration ─────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def run_script(stdscr, script_name):
    script_path = os.path.join(SCRIPT_DIR, script_name)
    curses.endwin()
    print(f"\033[1m\n>> Running: {script_name}\033[0m\n")
    if os.path.exists(script_path):
        os.chmod(script_path, 0o755)
        subprocess.run(["bash", script_path])
    else:
        print(f"\033[31mError: Script not found: {script_path}\033[0m")
    print("\033[7m Press Enter to continue \033[0m")
    input()
    stdscr.refresh()

# ── TUI Logic ─────────────────────────────────────────────

def draw_menu(stdscr, title, options, selected_idx):
    stdscr.clear()
    h, w = stdscr.getmaxyx()
    
    # Header
    header_text = f"  GNU nano setup 2.0  |  {title}"
    header_text = f"{header_text[:w]:<{w}}"
    try:
        stdscr.addstr(0, 0, header_text, curses.A_REVERSE)
    except: pass

    # Column calc
    lbl_w = max(15, min(int(w * 0.4), 35))
    desc_w = max(0, w - lbl_w - 4)

    max_lines = h - 3
    start_idx = 0
    if selected_idx >= max_lines:
        start_idx = selected_idx - max_lines + 1

    for i in range(min(len(options), max_lines)):
        idx = start_idx + i
        if idx >= len(options): break
        
        label, desc = options[idx]
        line_str = f" {label[:lbl_w]:<{lbl_w}}  {desc[:desc_w]:<{desc_w}}"
        
        attr = curses.A_NORMAL
        if idx == selected_idx:
            attr = curses.A_REVERSE
            line_str = f"{line_str:<{w}}" 
        else:
            attr = curses.A_BOLD

        try:
            stdscr.addstr(2 + i, 0, line_str[:w], attr)
        except: pass

    # Footer
    footer = "^X Exit  ^M Select  Type to search"
    footer = f"{footer:<{w}}"
    try:
        stdscr.addstr(h-1, 0, footer[:w], curses.A_REVERSE)
    except: pass

    stdscr.refresh()

def menu_loop(stdscr, title, options):
    selected = 0
    while True:
        draw_menu(stdscr, title, options, selected)
        key = stdscr.getch()

        if key == curses.KEY_UP or key == ord('k'):
            selected = max(0, selected - 1)
        elif key == curses.KEY_DOWN or key == ord('j'):
            selected = min(len(options) - 1, selected + 1)
        elif key == ord('\n') or key == 13:
            return selected
        elif key in [ord('q'), ord('x'), 24]:
            return -1
        elif ord('1') <= key <= ord('9'):
            idx = key - ord('1')
            if idx < len(options): selected = idx

# ── Submenus ──────────────────────────────────────────────

def ai_menu(stdscr):
    curses.endwin()
    ret = os.system("askall-config")
    if ret != 0:
        print("\033[31maskall-config not installed.\033[0m")
        print()
        print("Install from: ~/vault/04-repos/01-active/askall/")
        print("  cd ~/vault/04-repos/01-active/askall && ./install.sh")
        print()
        input("\033[7m Press Enter to continue \033[0m")
    stdscr.refresh()

def install_menu(stdscr):
    while True:
        opts = [
            ("Full Setup", "Install everything"),
            ("ShellGPT Setup", "AI CLI tools only"),
            ("Micro Editor", "Config only"),
            ("Termux Keys", "Fix keyboard"),
            ("Reset History", "Clear & Seed Zsh"),
            ("Back", "Return")
        ]
        choice = menu_loop(stdscr, "Installations", opts)
        if choice == 0: run_script(stdscr, "install.sh")
        elif choice == 1: run_script(stdscr, "setup-shellgpt.sh")
        elif choice == 2: run_script(stdscr, "setup-micro-minimal.sh")
        elif choice == 3: run_script(stdscr, "setup-termux-keys-layout.sh")
        elif choice == 4: run_script(stdscr, "reset-zsh-history.sh")
        elif choice == 5 or choice == -1: return

def main(stdscr):
    curses.start_color()
    curses.use_default_colors()
    curses.curs_set(0)

    while True:
        opts = [
            ("Installations", "Run setup scripts"),
            ("AI Configuration", "Configure .env, models, tools"),
            ("System Info", "View OS details"),
            ("Exit", "Quit")
        ]
        
        choice = menu_loop(stdscr, "Main Menu", opts)
        
        if choice == 0: install_menu(stdscr)
        elif choice == 1: ai_menu(stdscr)
        elif choice == 2:
            curses.endwin()
            print(f"\nOS: {platform.system()} {platform.release()}")
            input("\nPress Enter...")
            stdscr.refresh()
        elif choice == 3 or choice == -1:
            break

if __name__ == "__main__":
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        pass
