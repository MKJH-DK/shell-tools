#!/usr/bin/env python3
"""
nano_framework.py - A lightweight, Zero-Dependency Nano-Style TUI Framework.

Based on "Nano-Style TUI Design Research.pdf".
Implements stateless navigation, context-aware footers, and accessible UI patterns.
"""

import curses
import textwrap

# ── Keys & Constants ──────────────────────────────────────

KEY_ENTER = 10
KEY_ESC = 27
KEY_SPACE = 32
KEY_BACKSPACE = 127
KEY_TAB = 9

# Nano-style Control Keys
KEY_CTRL_X = 24  # Exit
KEY_CTRL_O = 15  # Save / Confirm
KEY_CTRL_W = 23  # Search / Filter
KEY_CTRL_G = 7   # Help

# Colors
COLOR_NORMAL = 1
COLOR_HL = 2      # Highlight / Selected
COLOR_HEADER = 3  # Top/Bottom Bars
COLOR_INPUT = 4   # Input Fields
COLOR_ERROR = 5   # Alerts

# ── Widget Base ──────────────────────────────────────────

class Widget:
    """Base UI Component."""
    def __init__(self, label):
        self.label = label
        self.focused = False

    def draw(self, stdscr, y, x, width):
        pass

    def handle_input(self, key):
        return None  # Return action or None

    def get_footer_hints(self):
        """Return list of (Key, Action) tuples for the footer."""
        return []

# ── Concrete Widgets ─────────────────────────────────────

class MenuButton(Widget):
    """A clickable menu item."""
    def __init__(self, label, callback=None):
        super().__init__(label)
        self.callback = callback

    def draw(self, stdscr, y, x, width):
        attr = curses.color_pair(COLOR_HL) if self.focused else curses.color_pair(COLOR_NORMAL)
        label = f" {self.label[:width-2]} "
        # Fill line
        line = f"{label:<{width}}"
        try:
            stdscr.addstr(y, x, line, attr)
        except curses.error: pass

    def handle_input(self, key):
        if key == KEY_ENTER and self.callback:
            return self.callback
        return None

    def get_footer_hints(self):
        return [("^M", "Select")]

class Checkbox(Widget):
    """Toggle option [x] / [ ]."""
    def __init__(self, label, checked=False):
        super().__init__(label)
        self.checked = checked

    def draw(self, stdscr, y, x, width):
        attr = curses.color_pair(COLOR_HL) if self.focused else curses.color_pair(COLOR_NORMAL)
        mark = "[x]" if self.checked else "[ ]"
        text = f" {mark} {self.label}"
        line = f"{text:<{width}}"
        try:
            stdscr.addstr(y, x, line, attr)
        except curses.error: pass

    def handle_input(self, key):
        if key == KEY_SPACE or key == KEY_ENTER:
            self.checked = not self.checked
            return "TOGGLED"
        return None

    def get_footer_hints(self):
        return [("Space", "Toggle")]

class RadioGroup(Widget):
    """Single select from multiple options."""
    def __init__(self, label, options, selected_idx=0):
        super().__init__(label)
        self.options = options
        self.selected_idx = selected_idx

    def draw(self, stdscr, y, x, width):
        attr = curses.color_pair(COLOR_HL) if self.focused else curses.color_pair(COLOR_NORMAL)
        
        current_opt = self.options[self.selected_idx]
        text = f" {self.label}: < {current_opt} > "
        line = f"{text:<{width}}"
        try:
            stdscr.addstr(y, x, line, attr)
        except curses.error: pass

    def handle_input(self, key):
        if key == KEY_SPACE or key == KEY_ENTER or key == curses.KEY_RIGHT:
            self.selected_idx = (self.selected_idx + 1) % len(self.options)
            return "CHANGED"
        elif key == curses.KEY_LEFT:
            self.selected_idx = (self.selected_idx - 1) % len(self.options)
            return "CHANGED"
        return None

    def get_footer_hints(self):
        return [("Space/→", "Next Option")]

class InputField(Widget):
    """Text input."""
    def __init__(self, label, value=""):
        super().__init__(label)
        self.value = value
        self.edit_mode = False

    def draw(self, stdscr, y, x, width):
        # Label part
        lbl_w = min(len(self.label) + 2, int(width * 0.4))
        val_w = width - lbl_w
        
        attr = curses.color_pair(COLOR_HL) if self.focused else curses.color_pair(COLOR_NORMAL)
        try:
            stdscr.addstr(y, x, f" {self.label}:".ljust(lbl_w), attr)
        except curses.error: pass
        
        # Value part
        val_attr = curses.color_pair(COLOR_INPUT) if self.edit_mode else curses.color_pair(COLOR_NORMAL)
        if self.focused:
             val_attr = val_attr | curses.A_BOLD

        display_val = self.value
        if self.focused and self.edit_mode:
             display_val += "_"

        if len(display_val) > val_w - 1:
            display_val = "..." + display_val[-(val_w-4):]

        try:
            stdscr.addstr(y, x + lbl_w, display_val.ljust(val_w), val_attr)
        except curses.error: pass

    def handle_input(self, key):
        if key == KEY_ENTER:
            self.edit_mode = not self.edit_mode
            return "EDIT_TOGGLE"
        
        if self.edit_mode:
            if 32 <= key <= 126:
                self.value += chr(key)
            elif key in (KEY_BACKSPACE, 8, 127):
                self.value = self.value[:-1]
            return "TYPING"
            
        return None

    def get_footer_hints(self):
        if self.edit_mode:
            return [("Enter", "Done"), ("Typing...", "")]
        return [("Enter", "Edit")]

class TextArea(Widget):
    """Scrollable multi-line text (Read-only logs/help)."""
    def __init__(self, content):
        super().__init__("")
        self.lines = content.split('\n')
        self.scroll_y = 0

    def draw(self, stdscr, y, x, width, height=10):
        for i in range(height):
            line_idx = self.scroll_y + i
            if line_idx < len(self.lines):
                line = self.lines[line_idx][:width]
                try:
                    stdscr.addstr(y + i, x, f"{line:<{width}}", curses.color_pair(COLOR_NORMAL))
                except curses.error: pass
            else:
                 try:
                    stdscr.addstr(y + i, x, " " * width, curses.color_pair(COLOR_NORMAL))
                 except curses.error: pass

    def handle_input(self, key):
        # Override scrolling handled by view for this specific widget if focused
        return None

# ── View (Screen) Class ──────────────────────────────────

class View:
    """A single screen in the app (e.g., Main Menu, Form)."""
    def __init__(self, title):
        self.title = title
        self.widgets = []
        self.selected_idx = 0
        self.scroll_offset = 0

    def add_widget(self, widget):
        self.widgets.append(widget)

    def on_enter(self):
        pass 

    def on_input(self, key):
        current = self.widgets[self.selected_idx]
        
        # If widget captures input (like editing text), let it handle everything
        if isinstance(current, InputField) and current.edit_mode:
             return current.handle_input(key)

        # Global Navigation
        if key == curses.KEY_DOWN or key == ord('j'):
            self.selected_idx = (self.selected_idx + 1) % len(self.widgets)
        elif key == curses.KEY_UP or key == ord('k'):
            self.selected_idx = (self.selected_idx - 1) % len(self.widgets)
        
        # Widget specific action
        else:
            return current.handle_input(key)

# ── Application Engine ───────────────────────────────────

class NanoApp:
    def __init__(self, title="Nano TUI"):
        self.title = title
        self.view_stack = []
        self.running = True

    def push_view(self, view):
        self.view_stack.append(view)
        view.on_enter()

    def pop_view(self):
        if len(self.view_stack) > 1:
            self.view_stack.pop()

    def run(self):
        curses.wrapper(self._main_loop)

    def _init_colors(self):
        curses.start_color()
        curses.use_default_colors()
        try:
            curses.init_pair(COLOR_NORMAL, -1, -1)
            curses.init_pair(COLOR_HL, curses.COLOR_BLACK, curses.COLOR_WHITE)
            curses.init_pair(COLOR_HEADER, curses.COLOR_WHITE, curses.COLOR_BLUE)
            curses.init_pair(COLOR_INPUT, curses.COLOR_CYAN, -1)
            curses.init_pair(COLOR_ERROR, curses.COLOR_WHITE, curses.COLOR_RED)
        except: pass

    def _draw_header(self, stdscr, view, width):
        header_text = f"  GNU nano 2.0  |  {self.title}  |  {view.title}"
        header_text = f"{header_text[:width]:<{width}}"
        try:
            stdscr.addstr(0, 0, header_text, curses.color_pair(COLOR_HEADER) | curses.A_BOLD)
        except: pass

    def _draw_footer(self, stdscr, view, height, width):
        y = height - 2
        hints = []
        if len(self.view_stack) > 1:
            hints.append(("^X", "Back"))
        else:
            hints.append(("^X", "Exit"))
        
        if view.widgets:
            current = view.widgets[view.selected_idx]
            hints.extend(current.get_footer_hints())
            
        hints.append(("↑/↓", "Nav"))

        hint_str = "  ".join([f"{k} {d}" for k, d in hints])
        hint_str = f"{hint_str[:width]:<{width}}"
        
        try:
            stdscr.addstr(y, 0, hint_str, curses.color_pair(COLOR_HEADER))
            stdscr.addstr(y+1, 0, " " * width, curses.color_pair(COLOR_HEADER))
        except: pass

    def _main_loop(self, stdscr):
        self._init_colors()
        curses.curs_set(0)
        stdscr.nodelay(False)
        stdscr.keypad(True)

        while self.running:
            if not self.view_stack: break
            view = self.view_stack[-1]
            height, width = stdscr.getmaxyx()
            stdscr.clear()

            self._draw_header(stdscr, view, width)

            body_h = height - 3
            start_y = 1
            
            # Scroll logic
            if view.selected_idx >= view.scroll_offset + body_h:
                view.scroll_offset = view.selected_idx - body_h + 1
            elif view.selected_idx < view.scroll_offset:
                view.scroll_offset = view.selected_idx

            for i in range(body_h):
                widget_idx = view.scroll_offset + i
                if widget_idx >= len(view.widgets): break
                
                w = view.widgets[widget_idx]
                w.focused = (widget_idx == view.selected_idx)
                w.draw(stdscr, start_y + i, 0, width)

            self._draw_footer(stdscr, view, height, width)
            stdscr.refresh()

            key = stdscr.getch()
            
            # Check for global exit if not in edit mode
            in_edit = False
            if view.widgets:
                cur = view.widgets[view.selected_idx]
                if isinstance(cur, InputField) and cur.edit_mode:
                    in_edit = True

            if key == KEY_CTRL_X and not in_edit:
                if len(self.view_stack) > 1:
                    self.pop_view()
                else:
                    self.running = False
            else:
                action = view.on_input(key)
                if callable(action): action()
