// Curated default tmux bindings — the ~40 worth learning, not the 200-entry
// list-keys dump. Keys are the stock defaults so the knowledge transfers to
// any machine; the live prefix is substituted in at display time.
//
// copyMode: true — the key is pressed inside copy mode, no prefix involved.
// viKeys: true — assumes vi copy-mode keys (mode-keys vi), noted in the UI.
.pragma library

var GROUPS = ["Panes", "Windows", "Sessions", "Copy mode", "Misc"]

var BINDINGS = [
  // Panes
  { id: "pane-split-h",   group: "Panes", key: "%",       desc: "Split pane left | right" },
  { id: "pane-split-v",   group: "Panes", key: "\"",      desc: "Split pane top / bottom" },
  { id: "pane-navigate",  group: "Panes", key: "↑ ↓ ← →", desc: "Move between panes" },
  { id: "pane-next",      group: "Panes", key: "o",       desc: "Go to the next pane" },
  { id: "pane-last",      group: "Panes", key: ";",       desc: "Toggle last active pane" },
  { id: "pane-zoom",      group: "Panes", key: "z",       desc: "Zoom pane to full window (toggle)" },
  { id: "pane-kill",      group: "Panes", key: "x",       desc: "Kill pane (asks to confirm)" },
  { id: "pane-break",     group: "Panes", key: "!",       desc: "Break pane out into its own window" },
  { id: "pane-swap",      group: "Panes", key: "{ or }",  desc: "Swap pane with previous / next" },
  { id: "pane-layouts",   group: "Panes", key: "Space",   desc: "Cycle through pane layouts" },
  { id: "pane-numbers",   group: "Panes", key: "q",       desc: "Flash pane numbers — press one to jump" },
  { id: "pane-resize",    group: "Panes", key: "C-↑↓←→",  desc: "Resize pane (repeats while held)" },

  // Windows
  { id: "win-new",        group: "Windows", key: "c",     desc: "New window" },
  { id: "win-rename",     group: "Windows", key: ",",     desc: "Rename window" },
  { id: "win-next",       group: "Windows", key: "n",     desc: "Next window" },
  { id: "win-prev",       group: "Windows", key: "p",     desc: "Previous window" },
  { id: "win-last",       group: "Windows", key: "l",     desc: "Toggle last active window" },
  { id: "win-jump",       group: "Windows", key: "0 … 9", desc: "Jump to window by number" },
  { id: "win-choose",     group: "Windows", key: "w",     desc: "Pick a window from a list" },
  { id: "win-find",       group: "Windows", key: "f",     desc: "Find a window by name" },
  { id: "win-kill",       group: "Windows", key: "&",     desc: "Kill window (asks to confirm)" },
  { id: "win-move",       group: "Windows", key: ".",     desc: "Move window to a new index" },

  // Sessions
  { id: "sess-detach",    group: "Sessions", key: "d",    desc: "Detach — session keeps running" },
  { id: "sess-choose",    group: "Sessions", key: "s",    desc: "Pick a session from a list" },
  { id: "sess-rename",    group: "Sessions", key: "$",    desc: "Rename session" },
  { id: "sess-prev",      group: "Sessions", key: "(",    desc: "Previous session" },
  { id: "sess-next",      group: "Sessions", key: ")",    desc: "Next session" },

  // Copy mode
  { id: "copy-enter",     group: "Copy mode", key: "[",     desc: "Enter copy mode (scroll & select)" },
  { id: "copy-pgup",      group: "Copy mode", key: "PgUp",  desc: "Enter copy mode, scrolled up a page" },
  { id: "copy-paste",     group: "Copy mode", key: "]",     desc: "Paste the last copied text" },
  { id: "copy-select",    group: "Copy mode", key: "Space", desc: "Start selection", copyMode: true, viKeys: true },
  { id: "copy-yank",      group: "Copy mode", key: "Enter", desc: "Copy selection and exit", copyMode: true, viKeys: true },
  { id: "copy-search",    group: "Copy mode", key: "/",     desc: "Search down", copyMode: true, viKeys: true },
  { id: "copy-search-up", group: "Copy mode", key: "?",     desc: "Search up", copyMode: true, viKeys: true },
  { id: "copy-top",       group: "Copy mode", key: "g / G", desc: "Jump to top / bottom", copyMode: true, viKeys: true },
  { id: "copy-quit",      group: "Copy mode", key: "q",     desc: "Exit copy mode", copyMode: true },

  // Misc
  { id: "misc-prompt",    group: "Misc", key: ":",  desc: "Command prompt — run any tmux command" },
  { id: "misc-bindings",  group: "Misc", key: "?",  desc: "List every key binding" },
  { id: "misc-buffers",   group: "Misc", key: "=",  desc: "Pick a paste buffer from a list" },
  { id: "misc-clock",     group: "Misc", key: "t",  desc: "Big clock (any key to close)" }
]

function total() { return BINDINGS.length }

function keyText(binding, prefix) {
  if (binding.copyMode) return binding.key
  return prefix + " " + binding.key
}

function searchText(binding) {
  return (binding.key + " " + binding.desc + " " + binding.group).toLowerCase()
}

// Keys the curated list already covers, per key table — used to filter the
// live list-keys dump so the "More" sections hold only genuinely new entries.
var COVERED = {
  "prefix": makeSet(["%", "\"", "Up", "Down", "Left", "Right", "o", ";", "z",
    "x", "!", "{", "}", "Space", "q", "C-Up", "C-Down", "C-Left", "C-Right",
    "c", ",", "n", "p", "l", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "w", "f", "&", ".", "d", "s", "$", "(", ")", "[", "]", "PPage", ":", "?",
    "=", "t"]),
  "copy-mode-vi": makeSet(["Space", "Enter", "/", "?", "g", "G", "q"])
}

function makeSet(list) {
  var out = {}
  for (var j = 0; j < list.length; j++) out[list[j]] = true
  return out
}

function isCovered(table, key) {
  var t = COVERED[table]
  return !!(t && t[key])
}
