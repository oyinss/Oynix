#!/usr/bin/env python3
"""hypr-clipboard-manager

A lightweight GTK4 clipboard manager for Hyprland built around cliphist.

- View / search clipboard history (text + images) from cliphist
- Copy entries back to the Wayland clipboard (wl-copy)
- Delete individual history entries and clear all history
- Favorites are stored in a separate SQLite DB (keyed by a content hash) so
  they survive `cliphist wipe`
- Single-instance window that toggles on repeated activation (SUPER + V)
"""

import hashlib
import os
import re
import shutil
import sqlite3
import subprocess
import threading
import time
import sys

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk, GLib, GObject, Gio

APP_ID = "org.hypr.ClipboardManager"
APP_NAME = "Clipboard Manager"

DATA_DIR = os.path.expanduser("~/.local/share/hypr-clipboard-manager")
DB_PATH = os.path.join(DATA_DIR, "favorites.sqlite")
THUMB_DIR = os.path.join(DATA_DIR, "thumbs")

HISTORY_MAX = 300  # how many cliphist entries to show

# ---------------------------------------------------------------------------
# Backend helpers (cliphist / wl-copy)
# ---------------------------------------------------------------------------

def _run(cmd, input_data=None, timeout=8):
    """Run a command, returning a CompletedProcess (never raises on ret code)."""
    try:
        return subprocess.run(
            cmd,
            input=input_data,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
        )
    except Exception:
        return None


def cliphist_list():
    """Return [(id, is_image, preview), ...] newest first from cliphist."""
    r = _run(["cliphist", "list"], timeout=8)
    if r is None or r.returncode != 0:
        return []
    entries = []
    for line in r.stdout.decode("utf-8", "replace").splitlines():
        if "\t" not in line:
            continue
        eid, payload = line.split("\t", 1)
        is_image = payload.startswith("[[ binary data")
        preview = payload if not is_image else payload
        entries.append((eid, is_image, preview))
    return entries


def cliphist_decode(eid):
    r = _run(["cliphist", "decode", str(eid)], timeout=8)
    if r is None or r.returncode != 0:
        return b""
    return r.stdout


def cliphist_delete(ids):
    if not ids:
        return
    payload = "\n".join(str(i) for i in ids) + "\n"
    _run(["cliphist", "delete"], input_data=payload.encode(), timeout=8)


def cliphist_wipe():
    _run(["cliphist", "wipe"], timeout=8)


def _content_hash(data):
    return hashlib.sha256(data or b"").hexdigest()


_ACTIVE_COPY_PROCS = set()


def copy_to_clipboard(entry):
    """Copy an entry to the Wayland clipboard, keeping it alive afterwards."""
    if entry.data is not None:
        data = entry.data
    else:
        data = cliphist_decode(entry.id)

    if entry.is_image:
        proc = subprocess.Popen(
            ["wl-copy", "--type", entry.mime or "image/png"],
            stdin=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        try:
            proc.stdin.write(data)
            proc.stdin.close()
        except Exception:
            pass
    else:
        text = data.decode("utf-8", "replace")
        proc = subprocess.Popen(
            ["wl-copy"], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL
        )
        try:
            proc.stdin.write(text.encode("utf-8", "replace"))
            proc.stdin.close()
        except Exception:
            pass
    _ACTIVE_COPY_PROCS.add(proc)
    for p in list(_ACTIVE_COPY_PROCS):
        if p.poll() is not None:
            _ACTIVE_COPY_PROCS.discard(p)


# ---------------------------------------------------------------------------
# Favorites storage (SQLite, keyed by content hash, survives `cliphist wipe`)
# ---------------------------------------------------------------------------

_FTS = (
    "CREATE TABLE IF NOT EXISTS favorites ("
    " content_hash TEXT PRIMARY KEY,"
    " id TEXT,"
    " content BLOB,"
    " mime TEXT,"
    " is_image INTEGER DEFAULT 0,"
    " preview TEXT,"
    " created_at INTEGER)"
)


def _connect_db():
    os.makedirs(DATA_DIR, mode=0o700, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cols = [r[1] for r in conn.execute("PRAGMA table_info(favorites)").fetchall()]
    if cols and "content_hash" not in cols:
        # Migrate an early schema that keyed on cliphist id.
        conn.execute("DROP TABLE favorites")
    conn.execute(_FTS)
    conn.commit()
    try:
        os.chmod(DB_PATH, 0o600)
    except OSError:
        pass
    return conn


def favorite_hashes():
    conn = _connect_db()
    try:
        return {r[0] for r in conn.execute("SELECT content_hash FROM favorites").fetchall()}
    finally:
        conn.close()


def add_favorite(entry):
    """Persist an entry to favorites. Returns the content hash used as key."""
    if entry.data is not None:
        data = entry.data
    else:
        data = cliphist_decode(entry.id)
    ch = _content_hash(data)
    preview = entry.preview or ""
    if not entry.is_image:
        preview = data.decode("utf-8", "replace")[:140]
    mime = entry.mime or ("image/png" if entry.is_image else "text/plain;charset=utf-8")
    conn = _connect_db()
    try:
        conn.execute(
            "INSERT OR REPLACE INTO favorites "
            "(content_hash, id, content, mime, is_image, preview, created_at) "
            "VALUES (?,?,?,?,?,?,?)",
            (ch, str(entry.id), data, mime, 1 if entry.is_image else 0, preview, int(time.time())),
        )
        conn.commit()
    finally:
        conn.close()
    return ch


def remove_favorite_by_hash(content_hash):
    conn = _connect_db()
    try:
        conn.execute("DELETE FROM favorites WHERE content_hash = ?", (content_hash,))
        conn.commit()
    finally:
        conn.close()


def clear_favorites():
    conn = _connect_db()
    try:
        conn.execute("DELETE FROM favorites")
        conn.commit()
    finally:
        conn.close()


def list_favorites():
    conn = _connect_db()
    try:
        rows = conn.execute(
            "SELECT content_hash, id, content, mime, is_image, preview, created_at "
            "FROM favorites ORDER BY created_at DESC"
        ).fetchall()
    finally:
        conn.close()
    out = []
    for ch, rid, content, mime, is_image, preview, created in rows:
        out.append(
            Entry(
                eid=rid,
                content_hash=ch,
                is_favorite=True,
                is_image=bool(is_image),
                preview=preview or ("Image" if is_image else ""),
                data=bytes(content) if content else None,
                mime=mime,
                created=created,
            )
        )
    return out


# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------

class Entry(GObject.Object):
    __gtype_name__ = "ClipEntry"

    def __init__(self, eid, content_hash="", is_image=False, preview="",
                 is_favorite=False, data=None, mime="", created=None):
        super().__init__()
        self.id = eid
        self.content_hash = content_hash
        self.is_image = bool(is_image)
        self.preview = preview
        self.is_favorite = bool(is_favorite)
        self.data = data
        self.mime = mime
        self.created = created


# ---------------------------------------------------------------------------
# Main window
# ---------------------------------------------------------------------------

# Tokyo Night Storm palette (source of truth)
#   background            #24283b
#   dark_bg / titlebar    #1f2335
#   elevated / card       #292e42
#   selection / hover     #3b4261
#   border                #414868
#   fg                    #c0caf5
#   fg_secondary          #a9b1d6
#   muted / comment       #565f89
#   blue                  #7aa2f7
#   cyan                  #7dcfff
#   purple                #bb9af7
#   green                 #9ece6a
#   yellow                #e0af68
#   orange                #ff9e64
#   red                   #f7768e
CSS = """
/* ===== Top-level surfaces ===== */
window,
.background {
    background-color: #24283b;
    color: #c0caf5;
}
box,
stack,
view {
    color: #c0caf5;
}

/* ===== Title bar ===== */
headerbar,
.titlebar,
window.csd headerbar,
window.csd headerbar.titlebar {
    background-color: #1f2335;
    background-image: none;
    color: #c0caf5;
    border-bottom: 1px solid #414868;
    min-height: 46px;
    padding: 0 6px;
    box-shadow: none;
}
headerbar label,
.titlebar label {
    color: #a9b1d6;
}
headerbar .title,
.titlebar .title {
    color: #c0caf5;
    font-weight: 600;
}

/* ===== Window controls (close / minimize / maximize) ===== */
headerbar windowcontrols button,
.titlebar windowcontrols button,
headerbar .titlebutton,
.titlebar .titlebutton {
    background-color: transparent;
    background-image: none;
    border: none;
    border-radius: 8px;
    min-width: 28px;
    min-height: 28px;
    margin: 2px;
    padding: 0;
    color: #a9b1d6;
    box-shadow: none;
}
headerbar windowcontrols button:hover,
.titlebar windowcontrols button:hover {
    background-color: #292e42;
    background-image: none;
    color: #c0caf5;
}
headerbar windowcontrols button:not(.close):hover,
.titlebar windowcontrols button:not(.close):hover {
    background-color: #3b4261;
    background-image: none;
    color: #c0caf5;
}
headerbar windowcontrols button.close:hover,
.titlebar windowcontrols button.close:hover {
    background-color: #f7768e;
    background-image: none;
    color: #1f2335;
}
headerbar windowcontrols button:active,
.titlebar windowcontrols button:active {
    background-color: #3b4261;
    background-image: none;
    color: #c0caf5;
}
headerbar windowcontrols button.close:active,
.titlebar windowcontrols button.close:active {
    background-color: #e05f78;
    background-image: none;
    color: #1f2335;
}

/* ===== Generic buttons (no GTK light leak) ===== */
button {
    background-color: #292e42;
    background-image: none;
    color: #c0caf5;
    border: 1px solid #414868;
    border-radius: 8px;
    padding: 4px 10px;
    min-height: 28px;
    box-shadow: none;
}
button:hover {
    background-color: #3b4261;
    background-image: none;
    color: #c0caf5;
    border-color: #565f89;
}
button:active {
    background-color: #3b4261;
    background-image: none;
}
button:focus {
    outline: none;
    border-color: #7aa2f7;
}
button:disabled {
    background-color: #1f2335;
    background-image: none;
    color: #565f89;
    border: 1px solid #292e42;
}
button.flat {
    background-color: transparent;
    background-image: none;
    border: none;
    color: #a9b1d6;
}
button.flat:hover {
    background-color: #292e42;
    background-image: none;
    color: #c0caf5;
}

/* ===== Clear History button ===== */
.clip-clear-history {
    background-color: #7aa2f7;
    background-image: none;
    color: #1f2335;
    border: none;
    font-weight: 600;
    box-shadow: none;
}
.clip-clear-history:hover {
    background-color: #9db6ff;
    background-image: none;
    color: #1f2335;
    border: none;
}
.clip-clear-history:active {
    background-color: #6c93f6;
    background-image: none;
    color: #1f2335;
}

/* ===== Clear Favorites button ===== */
.clip-clear-fav {
    background-color: #292e42;
    background-image: none;
    color: #c0caf5;
    border: 1px solid #414868;
}
.clip-clear-fav:hover {
    background-color: #3b4261;
    background-image: none;
    color: #c0caf5;
}
.clip-clear-fav:disabled {
    background-color: #1f2335;
    background-image: none;
    color: #565f89;
    border: 1px solid #292e42;
}

/* ===== Search box ===== */
.clip-search,
.search-entry {
    background-color: #1f2335;
    background-image: none;
    color: #c0caf5;
    border: 1px solid #414868;
    border-radius: 8px;
    padding: 4px 8px;
    min-height: 30px;
    box-shadow: none;
}
.clip-search:focus,
.clip-search:focus-within,
.search-entry:focus {
    border-color: #7aa2f7;
    outline: none;
    box-shadow: none;
}
.clip-search image,
.search-entry image {
    color: #565f89;
}
.clip-search text,
.search-entry text {
    color: #c0caf5;
}
.clip-search placeholder,
.search-entry placeholder,
.clip-search placeholder label,
.search-entry placeholder label {
    color: #565f89;
}

/* Entry inner nodes (GTK theme leak guard) */
entry,
entry box,
entry > box,
searchbar,
searchbar entry,
entry text {
    background-color: #1f2335;
    background-image: none;
    color: #c0caf5;
    border: none;
    border-image: none;
    box-shadow: none;
}
.clip-search,
.search-entry {
    border: 1px solid #414868;
    border-image: none;
    box-shadow: none;
}
.clip-search:focus,
.clip-search:focus-within,
.search-entry:focus,
.search-entry:focus-within {
    border-color: #7aa2f7;
}

/* ===== Notebook / History-Favorites tabs ===== */
notebook {
    background-color: #24283b;
    background-image: none;
    border: none;
    border-image: none;
    box-shadow: none;
    color: #c0caf5;
}
notebook > header {
    background-color: #24283b;
    background-image: none;
    border: none;
    border-image: none;
    border-bottom: 1px solid #414868;
    box-shadow: none;
    margin: 0;
    padding: 0;
}
notebook > header tabs {
    border: none;
    border-image: none;
    box-shadow: none;
    margin: 0;
    padding: 0;
}
notebook > header tabs > tab {
    background-color: transparent;
    background-image: none;
    border: none;
    border-image: none;
    box-shadow: none;
    padding: 7px 16px;
}
notebook > header tabs > tab label {
    color: #565f89;
    font-size: 13px;
    font-weight: 600;
}
notebook > header tabs > tab:hover label {
    color: #c0caf5;
}
notebook > header tabs > tab:checked label {
    color: #7aa2f7;
}
notebook > header tabs > tab:checked {
    box-shadow: inset 0 -2px 0 0 #7aa2f7;
}
notebook > header tabs > tab:disabled label {
    color: #565f89;
}

/* ===== Content area / list ===== */
scrolledwindow {
    background-color: #24283b;
    background-image: none;
}
viewport {
    background-color: #24283b;
    background-image: none;
}
list,
listview,
.clip-list {
    background-color: #24283b;
    background-image: none;
    color: #c0caf5;
}
row {
    background-color: transparent;
    background-image: none;
    color: #c0caf5;
}

/* ===== Clipboard cards ===== */
.clip-row {
    background-color: #292e42;
    background-image: none;
    border-radius: 10px;
    border: 1px solid #414868;
    padding: 6px;
    margin: 3px 6px;
}
.clip-row:hover {
    background-color: #3b4261;
    background-image: none;
    border-color: #565f89;
}
.clip-label {
    color: #c0caf5;
    font-size: 13px;
}
.clip-row:selected {
    background-color: #3b4261;
}

/* ===== Row icon buttons ===== */
.clip-copy {
    color: #c0caf5;
}
.clip-copy:hover {
    color: #7dcfff;
}
.clip-fav {
    color: #a9b1d6;
}
.clip-fav:hover {
    color: #e0af68;
}
.clip-fav.fav-active {
    color: #e0af68;
}
.clip-fav:not(.fav-active):hover {
    color: #e0af68;
}
.clip-del {
    color: #a9b1d6;
}
.clip-del:hover {
    color: #f7768e;
}

/* ===== Status bar ===== */
.clip-status {
    background-color: #1f2335;
    background-image: none;
    color: #565f89;
    border-top: 1px solid #414868;
    padding: 4px 8px;
    font-size: 11px;
}

/* ===== Scrollbars ===== */
scrollbar {
    background-color: #1f2335;
    background-image: none;
}
scrollbar slider {
    background-color: #414868;
    background-image: none;
    border-radius: 4px;
    min-width: 6px;
    min-height: 6px;
}
scrollbar slider:hover {
    background-color: #565f89;
    background-image: none;
}
scrollbar trough {
    background-color: #1f2335;
    background-image: none;
}

/* ===== Selection / misc ===== */
selection {
    background-color: #3b4261;
    background-image: none;
    color: #c0caf5;
}
separator {
    background-color: #414868;
    background-image: none;
}
tooltip {
    background-color: #292e42;
    background-image: none;
    color: #c0caf5;
    border: 1px solid #414868;
    border-radius: 8px;
}
tooltip label {
    color: #c0caf5;
}
"""




class ClipboardWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title=APP_NAME)
        self.set_default_size(480, 640)
        self.set_size_request(380, 400)

        self._stop = threading.Event()
        self._lock = threading.Lock()
        self._query = ""
        self._fulltext = {}  # cliphist id -> full decoded text (search cache)
        self._hash_cache = {}  # cliphist id -> content hash (avoids re-decode)
        self._thumb_cache = {}  # cliphist id -> GdkTexture thumbnail
        self._current_tab = "history"
        self._pending_history = []
        self._fav_hashes = set()
        self._status = None
        self._b_clear_fav = None

        self._history_store = Gio.ListStore.new(Entry)
        self._fav_store = Gio.ListStore.new(Entry)
        self._history_selection = Gtk.SingleSelection.new(self._history_store)
        self._fav_selection = Gtk.SingleSelection.new(self._fav_store)
        self._history_signature = None
        self._fav_signature = None

        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        self._build_ui()
        self._build_listviews()

        # Escape closes the window. Use a ShortcutController (capture phase) so
        # it fires before the SearchEntry can consume the key, plus a capture-
        # phase key controller as a fallback.
        esc_shortcut = Gtk.Shortcut.new(
            Gtk.KeyvalTrigger.new(Gdk.KEY_Escape, 0),
            Gtk.CallbackAction.new(self._on_escape_action),
        )
        shortcut_ctrl = Gtk.ShortcutController()
        shortcut_ctrl.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        shortcut_ctrl.add_shortcut(esc_shortcut)
        self.add_controller(shortcut_ctrl)

        key_ctrl = Gtk.EventControllerKey()
        key_ctrl.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        key_ctrl.connect("key-pressed", self._on_key_pressed)
        self.add_controller(key_ctrl)

        self._worker = threading.Thread(target=self._background_loop, daemon=True)
        self._worker.start()

    def _on_escape_action(self, shortcut, args):
        self.set_visible(False)
        return True

    def _on_key_pressed(self, controller, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self.set_visible(False)
            return True
        return False

    def _set_pointer_cursor(self, widget):
        """Show a pointer cursor over a widget on hover (GTK4 has no CSS
        `cursor` property, so set the cursor programmatically)."""
        display = Gdk.Display.get_default()
        if display is None:
            return
        try:
            cursor = Gdk.Cursor.new_from_name(display, "pointer")
        except Exception:
            cursor = None
        if cursor is not None:
            widget.set_cursor(cursor)

    # ----- UI construction ------------------------------------------------

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(root)

        hb = Gtk.HeaderBar()
        hb.set_show_title_buttons(True)
        hb.set_title_widget(Gtk.Label(label=APP_NAME))
        self.set_titlebar(hb)

        b_clear_history = Gtk.Button(label="Clear History")
        b_clear_history.add_css_class("clip-clear-history")
        b_clear_history.connect("clicked", self._on_clear_history)
        self._set_pointer_cursor(b_clear_history)
        hb.pack_end(b_clear_history)

        b_clear_fav = Gtk.Button(label="Clear Favorites")
        b_clear_fav.add_css_class("clip-clear-fav")
        b_clear_fav.connect("clicked", self._on_clear_favorites)
        self._set_pointer_cursor(b_clear_fav)
        self._b_clear_fav = b_clear_fav
        hb.pack_end(b_clear_fav)

        self._search = Gtk.SearchEntry()
        self._search.set_placeholder_text("Search clipboard...")
        self._search.add_css_class("clip-search")
        self._search.set_margin_top(6)
        self._search.set_margin_bottom(2)
        self._search.set_margin_start(8)
        self._search.set_margin_end(8)
        self._search.connect("search-changed", self._on_search_changed)
        root.append(self._search)

        self._notebook = Gtk.Notebook()
        self._notebook.add_css_class("clip-tabs")
        self._notebook.set_tab_pos(Gtk.PositionType.TOP)
        self._notebook.connect("switch-page", self._on_switch_page)

        self._history_scroll = Gtk.ScrolledWindow()
        self._history_scroll.add_css_class("clip-scroll")
        self._history_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self._history_scroll.set_vexpand(True)

        self._fav_scroll = Gtk.ScrolledWindow()
        self._fav_scroll.add_css_class("clip-scroll")
        self._fav_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self._fav_scroll.set_vexpand(True)

        lab_hist = Gtk.Label(label="History")
        lab_fav = Gtk.Label(label="Favorites")
        lab_hist.add_css_class("notebook-tab-label")
        lab_fav.add_css_class("notebook-tab-label")

        self._notebook.append_page(self._history_scroll, lab_hist)
        self._notebook.append_page(self._fav_scroll, lab_fav)
        root.append(self._notebook)

        self._status = Gtk.Label(label="")
        self._status.set_xalign(0)
        self._status.set_margin_start(0)
        self._status.set_margin_end(0)
        self._status.set_margin_top(0)
        self._status.set_margin_bottom(0)
        self._status.add_css_class("clip-status")
        root.append(self._status)

    def _make_listview(self, selection):
        factory = Gtk.SignalListItemFactory()
        factory.connect("setup", self._row_setup)
        factory.connect("bind", self._row_bind)
        lv = Gtk.ListView(model=selection, factory=factory)
        lv.add_css_class("clip-list")
        lv.connect("activate", self._on_activate)
        return lv

    def _build_listviews(self):
        self._history_lv = self._make_listview(self._history_selection)
        self._history_scroll.set_child(self._history_lv)
        self._fav_lv = self._make_listview(self._fav_selection)
        self._fav_scroll.set_child(self._fav_lv)

    # ----- Row factory -----------------------------------------------------

    def _row_setup(self, factory, listitem):
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        box.add_css_class("clip-row")

        thumb = Gtk.Picture()
        thumb.set_size_request(44, 44)
        thumb.set_visible(False)
        thumb.set_margin_end(2)
        thumb.set_content_fit(Gtk.ContentFit.CONTAIN)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        vbox.set_hexpand(True)
        label = Gtk.Label()
        label.add_css_class("clip-label")
        label.set_ellipsize(3)  # Pango.EllipsizeMode.END
        label.set_xalign(0.0)
        label.set_wrap(False)
        vbox.append(label)

        b_copy = Gtk.Button(icon_name="edit-copy-symbolic")
        b_fav = Gtk.Button(icon_name="non-starred-symbolic")
        b_del = Gtk.Button(icon_name="user-trash-symbolic")
        b_copy.add_css_class("clip-copy")
        b_fav.add_css_class("clip-fav")
        b_del.add_css_class("clip-del")
        for b in (b_copy, b_fav, b_del):
            b.add_css_class("flat")
            b.set_valign(Gtk.Align.CENTER)

        box.append(thumb)
        box.append(vbox)
        box.append(b_copy)
        box.append(b_fav)
        box.append(b_del)

        box._thumb = thumb
        box._label = label
        box._fav_btn = b_fav

        b_copy.connect("clicked", self._on_copy_clicked, box)
        b_fav.connect("clicked", self._on_fav_clicked, box)
        b_del.connect("clicked", self._on_delete_clicked, box)

        listitem.set_child(box)

    def _row_bind(self, factory, listitem):
        box = listitem.get_child()
        entry = listitem.get_item()
        box._entry = entry

        if entry.is_image:
            tex = self._thumbnail(entry)
            if tex is not None:
                box._thumb.set_paintable(tex)
                box._thumb.set_visible(True)
            else:
                box._thumb.set_visible(False)
            label_text = entry.preview
            if not label_text or label_text.startswith("[["):
                label_text = "Image"
            box._label.set_text(label_text)
        else:
            box._thumb.set_visible(False)
            box._label.set_text(entry.preview or "(empty)")

        box._fav_btn.set_icon_name("starred-symbolic" if entry.is_favorite else "non-starred-symbolic")
        box._fav_btn.remove_css_class("fav-active")
        box._fav_btn.remove_css_class("fav-inactive")
        box._fav_btn.add_css_class("fav-active" if entry.is_favorite else "fav-inactive")

    def _thumbnail(self, entry):
        if entry.id in self._thumb_cache:
            return self._thumb_cache[entry.id]
        data = entry.data if entry.data is not None else cliphist_decode(entry.id)
        tex = None
        if data:
            try:
                tex = Gdk.Texture.new_from_bytes(GLib.Bytes.new(data))
            except Exception:
                tex = None
        self._thumb_cache[entry.id] = tex
        return tex

    # ----- Actions ---------------------------------------------------------

    def _copy_entry(self, entry):
        copy_to_clipboard(entry)
        self.set_visible(False)

    def _on_activate(self, lv, position):
        model = lv.get_model()
        if model is not None:
            item = model.get_item(position)
            if item is not None:
                self._copy_entry(item)

    def _on_copy_clicked(self, btn, box):
        self._copy_entry(box._entry)

    def _on_fav_clicked(self, btn, box):
        entry = box._entry
        if entry.is_favorite:
            remove_favorite_by_hash(entry.content_hash)
            entry.is_favorite = False
            self._fav_hashes.discard(entry.content_hash)
            # Unfavoriting from the Favorites tab: remove just this row in place
            # so the list doesn't jump back to the top. On the History tab we
            # only refresh (the entry stays, only its star changes).
            if self._current_tab == "favorites":
                self._remove_from_fav_store(entry)
                return
        else:
            entry.content_hash = add_favorite(entry)
            entry.is_favorite = True
            self._fav_hashes.add(entry.content_hash)
        btn.set_icon_name("starred-symbolic" if entry.is_favorite else "non-starred-symbolic")
        btn.remove_css_class("fav-active")
        btn.remove_css_class("fav-inactive")
        btn.add_css_class("fav-active" if entry.is_favorite else "fav-inactive")
        self._fav_signature = None
        self.refresh_favorites()

    def _remove_from_fav_store(self, entry):
        """Remove a single entry from the favorites store in place (preserves
        scroll position instead of rebuilding the whole list)."""
        store = self._fav_store
        n = store.get_n_items()
        for i in range(n):
            item = store.get_item(i)
            if item is not None and item.content_hash == entry.content_hash:
                store.remove(i)
                break
        self._fav_signature = None
        self._update_status()

    def _on_delete_clicked(self, btn, box):
        entry = box._entry
        if self._current_tab == "history":
            cliphist_delete([entry.id])
            self._history_signature = None
        else:
            remove_favorite_by_hash(entry.content_hash)
            self._fav_hashes.discard(entry.content_hash)
            self._fav_signature = None
        self.refresh_all()

    def _on_clear_history(self, btn):
        self._confirm(
            "Clear clipboard history?",
            "Favorites will be kept. This cannot be undone.",
            on_confirm=self._do_clear_history,
        )

    def _do_clear_history(self):
        # "Clear history" must preserve favorited entries: favorites are the
        # user's saved items, so we delete only the non-favorite cliphist
        # entries instead of a blanket `cliphist wipe`. Decoding every entry to
        # identify favorites can take a moment, so run it off the UI thread.
        def work():
            favs = favorite_hashes()
            to_delete = []
            for eid, is_image, preview in cliphist_list():
                # Compute the hash locally (not via _ensure_hash) so we never
                # mutate the shared UI caches from this background thread.
                data = cliphist_decode(eid)
                ch = _content_hash(data)
                if ch not in favs:
                    to_delete.append(eid)
            if to_delete:
                cliphist_delete(to_delete)
            return favs

        def done(favs):
            self._fulltext.clear()
            self._hash_cache.clear()
            self._thumb_cache.clear()
            self._history_signature = None
            # Drop the cached history so the list reflects the deletion right
            # away instead of the stale `_pending_history` re-populating it
            # until the next background tick. Keep only favorite entries (the
            # non-favorites were deleted above).
            with self._lock:
                self._pending_history = [
                    e for e in (self._pending_history or []) if e.content_hash in favs
                ]
            self.refresh_all()

        def run_work():
            favs = work()
            GLib.idle_add(done, favs)

        threading.Thread(target=run_work, daemon=True).start()

    def _on_clear_favorites(self, btn):
        self._confirm(
            "Clear all favorites?",
            "Normal clipboard history will be kept. This cannot be undone.",
            on_confirm=self._do_clear_favorites,
        )

    def _do_clear_favorites(self):
        clear_favorites()
        self._fav_hashes.clear()
        self._fav_signature = None
        # Clear favorite flags on the cached history rows so star icons update
        # immediately instead of waiting for the next background pass.
        with self._lock:
            for e in self._pending_history or []:
                e.is_favorite = False
        self.refresh_all()

    def _confirm(self, message, detail, on_confirm):
        alert = Gtk.AlertDialog(message=message, detail=detail)
        alert.set_buttons(["Cancel", "Clear"])
        alert.set_cancel_button(0)
        self._pending_confirm = on_confirm
        alert.choose(self, None, self._on_confirm_response)

    def _on_confirm_response(self, source, result):
        try:
            resp = source.choose_finish(result)
        except Exception:
            resp = -1
        if resp == 1 and self._pending_confirm:
            cb = self._pending_confirm
            self._pending_confirm = None
            cb()

    # ----- Search / tabs ---------------------------------------------------

    def _on_search_changed(self, entry):
        with self._lock:
            self._query = entry.get_text().strip().lower()
        self._history_signature = None
        self._fav_signature = None
        self.refresh_all()

    def _on_switch_page(self, nb, page, page_num):
        self._current_tab = "history" if page_num == 0 else "favorites"
        self.refresh_all()

    # ----- Model updates ---------------------------------------------------

    def _matches(self, entry, query):
        if not query:
            return True
        if entry.is_image:
            return False
        if query in entry.preview.lower():
            return True
        full = self._fulltext.get(str(entry.id))
        if full is None and entry.data is not None:
            full = entry.data.decode("utf-8", "replace")
        if full and query in full.lower():
            return True
        return False

    def refresh_all(self):
        self.refresh_history()
        self.refresh_favorites()

    def _preserve_scroll(self, scroll, rebuild):
        """Run `rebuild()` (which splices a ListView model) while restoring the
        ScrolledWindow's vertical scroll position afterwards. Without this, any
        store rebuild (e.g. unfavoriting, or the periodic background refresh)
        snaps the list back to the top."""
        adj = scroll.get_vadjustment() if scroll else None
        old = adj.get_value() if adj else 0.0
        rebuild()
        if adj is not None:
            def _restore(*_a):
                adj.set_value(min(old, adj.get_upper() - adj.get_page_size()))
                return False
            GLib.idle_add(_restore)

    def refresh_history(self):
        with self._lock:
            query = self._query
        entries = self._pending_history or []
        filtered = [e for e in entries if self._matches(e, query)]
        # NOTE: `is_favorite` is intentionally left out of the signature. Favoriting
        # updates the star in-place via _on_fav_clicked/_row_bind, so including it
        # here would force a full history rebuild (and a scroll jump) on every
        # favorite toggle.
        sig = (tuple((e.id, e.preview) for e in filtered[:HISTORY_MAX]), query)
        if sig == self._history_signature:
            return
        self._history_signature = sig
        self._preserve_scroll(self._history_scroll, lambda: (
            self._history_store.splice(0, self._history_store.get_n_items(), filtered[:HISTORY_MAX]),
            self._update_status(),
        ))

    def refresh_favorites(self):
        with self._lock:
            query = self._query
        favs = list_favorites()
        filtered = [e for e in favs if self._matches(e, query)]
        sig = tuple((e.id, e.preview) for e in filtered)
        if sig == self._fav_signature:
            return
        self._fav_signature = sig
        self._preserve_scroll(self._fav_scroll, lambda: (
            self._fav_store.splice(0, self._fav_store.get_n_items(), filtered),
            self._update_status(),
        ))

    def _update_status(self):
        if self._status is None:
            return
        if self._b_clear_fav is not None:
            self._b_clear_fav.set_sensitive(self._fav_store.get_n_items() > 0)
        self._status.set_text(
            f"{self._history_store.get_n_items()} history  ·  "
            f"{self._fav_store.get_n_items()} favorites"
        )

    # ----- Background worker ----------------------------------------------

    def _background_loop(self):
        first = True
        while not self._stop.is_set():
            try:
                raw = cliphist_list()
                if first:
                    # Phase A: populate instantly with the cliphist previews so
                    # the window shows content without waiting to decode every
                    # entry (decoding is only needed for favorite hashes).
                    self._pending_history = [
                        Entry(eid=eid, is_image=is_image, preview=preview)
                        for eid, is_image, preview in raw[:HISTORY_MAX]
                    ]
                    GLib.idle_add(self.refresh_all)
                    first = False
                # Phase B: full population with content hashes + favorites.
                favs = favorite_hashes()
                self._fav_hashes = favs
                entries = []
                for eid, is_image, preview in raw[:HISTORY_MAX]:
                    e = Entry(eid=eid, is_image=is_image, preview=preview)
                    e.content_hash = self._ensure_hash(e)
                    e.is_favorite = e.content_hash in favs
                    entries.append(e)
                self._pending_history = entries
                GLib.idle_add(self.refresh_all)
            except Exception:
                pass
            self._stop.wait(1.5)

    def _ensure_hash(self, entry):
        """Return (and cache) the content hash of an entry."""
        key = str(entry.id)
        if key in self._hash_cache:
            return self._hash_cache[key]
        if entry.data is not None:
            data = entry.data
        else:
            data = cliphist_decode(key)
        ch = _content_hash(data)
        self._hash_cache[key] = ch
        if not entry.is_image and data:
            # Reuse the decode for full-text search.
            self._fulltext[key] = data.decode("utf-8", "replace")
        return ch


class ClipboardApp(Gtk.Application):
    def __init__(self, daemon=False):
        super().__init__(application_id=APP_ID)
        self._window = None
        self._daemon = daemon

    def do_activate(self):
        win = self._window
        if win is not None:
            if win.is_visible():
                win.set_visible(False)  # toggle closed
            else:
                win.present()  # toggle open
                win.grab_focus()
            return
        win = ClipboardWindow(self)
        self._window = win
        # In daemon mode (started at login) keep the window hidden so the
        # first SUPER+SHIFT+V toggles it open instantly via single-instance
        # activation, exactly like swaync.
        if not self._daemon:
            win.present()
            win.grab_focus()


def main():
    for binary in ("cliphist", "wl-copy", "wl-paste"):
        if shutil.which(binary) is None:
            print(f"hypr-clipboard-manager: required command not found: {binary}",
                  file=sys.stderr)
            return 1
    # --daemon: start hidden and keep running so later invocations activate
    # the live instance instantly (single-instance D-Bus activation).
    daemon = "--daemon" in sys.argv[1:]
    app = ClipboardApp(daemon=daemon)
    return app.run(None)


if __name__ == "__main__":
    sys.exit(main())
