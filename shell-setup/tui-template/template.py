#!/usr/bin/env python3
"""
TUI Project Template
Based on nano_framework.py

Usage:
1. Copy this file and nano_framework.py to your project.
2. Rename this file to main.py or similar.
3. Customize the views and widgets.
"""

from nano_framework import (
    NanoApp, View, MenuButton, Checkbox, 
    RadioGroup, InputField, TextArea
)

def main():
    # Initialize the App
    app = NanoApp(title="My New Project")

    # ── Define Views (Screens) ───────────────────────────

    # 1. Main Menu View
    main_menu = View("Main Menu")
    
    # Callback to switch views
    def goto_settings():
        app.push_view(settings_view)

    def goto_form():
        app.push_view(form_view)

    def goto_help():
        app.push_view(help_view)
    
    # Add Widgets to Main Menu
    main_menu.add_widget(MenuButton("Configuration Settings", goto_settings))
    main_menu.add_widget(MenuButton("Data Entry Form", goto_form))
    main_menu.add_widget(MenuButton("View Logs / Help", goto_help))
    main_menu.add_widget(MenuButton("Exit", lambda: app.pop_view()))

    # 2. Settings View
    settings_view = View("Settings")
    settings_view.add_widget(Checkbox("Enable Verbose Logging", checked=True))
    settings_view.add_widget(Checkbox("Use Dark Mode"))
    settings_view.add_widget(RadioGroup("Language", ["English", "Danish", "German"]))
    settings_view.add_widget(MenuButton("Back", lambda: app.pop_view()))

    # 3. Form View
    form_view = View("User Form")
    form_view.add_widget(InputField("Username", "guest"))
    form_view.add_widget(InputField("API Key", ""))
    form_view.add_widget(InputField("Server IP", "127.0.0.1"))
    
    def save_form():
        # Example of accessing data
        # In a real app, you would read .value from the InputField widgets
        app.pop_view()
        
    form_view.add_widget(MenuButton("Save Data", save_form))
    form_view.add_widget(MenuButton("Cancel", lambda: app.pop_view()))

    # 4. Help/Log View (Scrollable Text)
    help_text = """
    TUI Template Help
    =================
    
    Navigation:
      Use UP/DOWN arrows or j/k to move between items.
      Press ENTER to select an item or edit a field.
      Press SPACE to toggle checkboxes.
      Press CTRL+X to go back or exit.

    Design Principles:
      - Stateless: No hidden modes.
      - Visible: Shortcuts are always shown below.
      - Responsive: Resizes to terminal width.
      
    This is a scrollable text area.
    It can hold logs, documentation, or long output.
    
    (End of help)
    """
    help_view = View("Help & Documentation")
    help_view.add_widget(TextArea(help_text.strip()))

    # ── Start the App ────────────────────────────────────
    
    app.push_view(main_menu)
    app.run()

if __name__ == "__main__":
    main()
