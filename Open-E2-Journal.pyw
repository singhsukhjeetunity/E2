"""Double-click launcher: no shell, broker login, or controller token."""
import sys
from journal.app import data_directory, main

if __name__ == "__main__":
    data_directory().mkdir(parents=True, exist_ok=True)
    with (data_directory() / "journal.log").open("a", encoding="utf-8") as log:
        sys.stdout = sys.stderr = log
        try:
            main()
        except Exception as exc:
            import traceback
            traceback.print_exc()
            try:
                import tkinter as tk
                from tkinter import messagebox
                root = tk.Tk(); root.withdraw()
                messagebox.showerror("E2 Journal", str(exc)); root.destroy()
            except Exception:
                pass
