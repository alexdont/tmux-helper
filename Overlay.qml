import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Bindings.js" as Bindings

// The cheat sheet: a curated list of default tmux bindings you can search,
// pin, and shrink by marking entries learned or irrelevant. Both hidden
// states are soft — the archived view brings them back for review.
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property bool showArchived: false
  property bool showExtras: false

  // The rest of the live list-keys dump, minus what the curated list already
  // covers. Only prefix / root / copy-mode-vi tables; grouped under "More".
  property var extras: []

  // Live prefix from the user's real tmux config; a sheet that shows C-b to
  // a C-a user teaches wrong answers. Falls back to the stock default.
  property string tmuxPrefix: "C-b"

  property var learned: ({})
  property var irrelevant: ({})
  property var pinned: ({})
  property var undoStack: []

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/io.github.alexdont.tmux-helper"

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int rowHeight: Math.max(Style.space(40), Style.font.body + Style.spacing.md * 2)
  property int cardWidth: Math.min(Style.space(560), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(640), panel.height - Style.gapsOut * 2)

  readonly property int totalCount: Bindings.total()
  property int learnedCount: 0
  property int irrelevantCount: 0
  readonly property int remainingCount: totalCount - learnedCount - irrelevantCount

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuild()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.alexdont.tmux-helper")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function statusOf(id) {
    if (root.learned[id]) return "learned"
    if (root.irrelevant[id]) return "irrelevant"
    return "learning"
  }

  function recount() {
    var l = 0, i = 0
    var all = Bindings.BINDINGS
    for (var k = 0; k < all.length; k++) {
      if (root.learned[all[k].id]) l++
      else if (root.irrelevant[all[k].id]) i++
    }
    root.learnedCount = l
    root.irrelevantCount = i
  }

  function loadState(raw) {
    var learned = {}, irrelevant = {}, pinned = {}
    // Bound + descriptor-validate before parsing: the read is already capped at
    // 64KB (stateReader), and real state is far smaller. Reject anything over
    // the cap or that isn't a plain JSON object, so a swapped-in oversized or
    // malformed file is discarded rather than parsed into the shell.
    if (typeof raw !== "string" || raw.length > 65536) raw = "{}"
    try {
      var parsed = JSON.parse(raw)
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) parsed = {}
      // Ids are short slugs ("pane-zoom", "x:table:key"); anything longer, or
      // beyond 1000 per list, is not state this plugin wrote.
      var toSet = function(list, into) {
        if (!Array.isArray(list)) return
        for (var j = 0; j < Math.min(list.length, 1000); j++)
          if (typeof list[j] === "string" && list[j].length <= 128) into[list[j]] = true
      }
      toSet(parsed.learned, learned)
      toSet(parsed.irrelevant, irrelevant)
      toSet(parsed.pinned, pinned)
    } catch (e) {}
    root.learned = learned
    root.irrelevant = irrelevant
    root.pinned = pinned
    root.recount()
    if (root.opened) root.rebuild()
  }

  function saveState() {
    var toList = function(set) {
      var out = []
      for (var key in set) if (set[key]) out.push(key)
      out.sort()
      return out
    }
    stateFile.setText(JSON.stringify({
      version: 1,
      learned: toList(root.learned),
      irrelevant: toList(root.irrelevant),
      pinned: toList(root.pinned)
    }, null, 2) + "\n")
  }

  function pushUndo(id) {
    var stack = root.undoStack.slice()
    stack.push({
      id: id,
      learned: !!root.learned[id],
      irrelevant: !!root.irrelevant[id],
      pinned: !!root.pinned[id]
    })
    if (stack.length > 50) stack.shift()
    root.undoStack = stack
  }

  function undo() {
    if (root.undoStack.length === 0) return
    var stack = root.undoStack.slice()
    var last = stack.pop()
    root.undoStack = stack

    var learned = Object.assign({}, root.learned)
    var irrelevant = Object.assign({}, root.irrelevant)
    var pinned = Object.assign({}, root.pinned)
    delete learned[last.id]; delete irrelevant[last.id]; delete pinned[last.id]
    if (last.learned) learned[last.id] = true
    if (last.irrelevant) irrelevant[last.id] = true
    if (last.pinned) pinned[last.id] = true
    root.learned = learned
    root.irrelevant = irrelevant
    root.pinned = pinned
    root.afterChange()
  }

  // Marking learned clears irrelevant and vice versa: the two hidden states
  // are exclusive verdicts, and re-marking from the archived view flips the
  // verdict rather than stacking both.
  function markLearned(id) {
    root.pushUndo(id)
    var learned = Object.assign({}, root.learned)
    var irrelevant = Object.assign({}, root.irrelevant)
    if (learned[id]) delete learned[id]
    else { learned[id] = true; delete irrelevant[id] }
    root.learned = learned
    root.irrelevant = irrelevant
    root.afterChange()
  }

  function markIrrelevant(id) {
    root.pushUndo(id)
    var learned = Object.assign({}, root.learned)
    var irrelevant = Object.assign({}, root.irrelevant)
    if (irrelevant[id]) delete irrelevant[id]
    else { irrelevant[id] = true; delete learned[id] }
    root.learned = learned
    root.irrelevant = irrelevant
    root.afterChange()
  }

  function togglePin(id) {
    root.pushUndo(id)
    var pinned = Object.assign({}, root.pinned)
    if (pinned[id]) delete pinned[id]
    else pinned[id] = true
    root.pinned = pinned
    root.afterChange()
  }

  function afterChange() {
    root.recount()
    root.saveState()
    root.rebuild()
  }

  function parseListKeys(raw) {
    var tables = {
      "prefix": "More · prefix key",
      "root": "More · no prefix",
      "copy-mode-vi": "More · copy mode (vi)"
    }
    var out = []
    var lines = raw.split("\n")
    // Entry and field caps so a crafted config can't balloon the model; real
    // configs sit far below all three.
    for (var j = 0; j < lines.length && out.length < 400; j++) {
      var m = lines[j].match(/^bind-key\s+(?:-r\s+)?-T\s+(\S+)\s+(\S+)\s+(.*)$/)
      if (!m) continue
      var table = m[1]
      if (!(table in tables)) continue
      var key = m[2].replace(/^["']|["']$/g, "").replace(/^\\/, "").slice(0, 64)
      if (Bindings.isCovered(table, key)) continue
      out.push({ id: "x:" + table + ":" + key, group: tables[table], key: key, desc: m[3].slice(0, 200), table: table })
    }
    return out
  }

  function rebuild() {
    var q = root.filterText.toLowerCase()
    var all = Bindings.BINDINGS.concat(root.extras)
    var pinnedRows = [], rows = []

    for (var j = 0; j < all.length; j++) {
      var b = all[j]
      var isExtra = !!b.table
      var status = root.statusOf(b.id)
      var isPinned = !!root.pinned[b.id]

      // Pinned entries are always visible: a learned or irrelevant pin stays
      // in the Pinned section wearing its mark instead of vanishing.
      if (!isPinned) {
        if (status !== "learning" && !root.showArchived) continue
        if (isExtra && !root.showExtras) continue
      }
      var text = isExtra
        ? (b.key + " " + b.desc + " " + b.group).toLowerCase()
        : Bindings.searchText(b)
      if (q && text.indexOf(q) === -1) continue

      var row = {
        bid: b.id,
        keyText: isExtra
          ? (b.table === "prefix" ? root.tmuxPrefix + " " + b.key : b.key)
          : Bindings.keyText(b, root.tmuxPrefix),
        desc: b.desc + (b.viKeys ? "  (vi keys)" : ""),
        status: status,
        isPinned: isPinned,
        sectionLabel: isPinned ? "Pinned" : b.group
      }
      if (isPinned) pinnedRows.push(row)
      else rows.push(row)
    }

    var out = pinnedRows.concat(rows)
    displayModel.clear()
    for (var k = 0; k < out.length; k++) displayModel.append(out[k])

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0
    cursorActive = displayModel.count > 0

    Qt.callLater(function() {
      if (displayModel.count > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function select(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    }
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function selectPage(delta) {
    if (displayModel.count === 0) return
    var visibleRows = Math.max(1, Math.floor(resultList.height / root.rowHeight))
    var newIndex = selectedIndex + delta * visibleRows
    if (newIndex < 0) newIndex = 0
    if (newIndex >= displayModel.count) newIndex = displayModel.count - 1
    selectedIndex = newIndex
    cursorActive = true
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuild()
  }

  function selectedId() {
    if (!cursorActive || selectedIndex < 0 || selectedIndex >= displayModel.count) return ""
    return displayModel.get(selectedIndex).bid
  }

  Component.onCompleted: {
    Quickshell.execDetached(["mkdir", "-p", root.stateDir])
    root.reloadState()
  }

  ListModel { id: displayModel }

  // FileView is used for WRITING ONLY (atomic setText). preload: false stops it
  // from independently materializing state.json into the shell — otherwise it
  // could load the whole (replaceable, possibly oversized) file outside the
  // bounded, descriptor-safe read path. All reading goes through stateReader
  // (a no-follow/non-blocking descriptor capped at 64KB); nothing reads through
  // this FileView (no text()/reload()).
  FileView {
    id: stateFile
    path: root.stateDir + "/state.json"
    atomicWrites: true
    printErrors: false
    preload: false
  }

  // Bounded, descriptor-safe read of the persisted state. A plain `head -c`
  // still does a blocking, symlink-following open, so instead we open ONE
  // descriptor with O_NOFOLLOW (a symlink can't redirect the read) and
  // O_NONBLOCK (a planted FIFO can't block us), fstat it as a regular file,
  // and read the capped 64KB from that SAME descriptor before any parsing.
  // Real state is a few KB (three lists of ≤1000 short slugs). The path is
  // passed positionally as argv, never spliced into a shell string. If python3
  // is somehow absent the read just yields nothing and we fall back to empty
  // state — the plugin still runs, it just doesn't restore saved settings.
  Process {
    id: stateReader
    command: ["python3", "-c",
      "import os,sys,stat\n" +
      "try: fd=os.open(sys.argv[1],os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)\n" +
      "except OSError: sys.exit(0)\n" +
      "try:\n" +
      "    if stat.S_ISREG(os.fstat(fd).st_mode): sys.stdout.buffer.write(os.read(fd,65536))\n" +
      "finally: os.close(fd)\n",
      root.stateDir + "/state.json"]
    stdout: StdioCollector { onStreamFinished: root.loadState(text) }
  }
  function reloadState() { if (!stateReader.running) stateReader.running = true }

  Process {
    id: extrasProbe
    // head -c bounds what a huge or hostile tmux config can feed the parser;
    // a stock list-keys dump is ~10 KB, so 128 KB loses nothing real.
    command: ["sh", "-c", "{ tmux list-keys 2>/dev/null || tmux -L omarchy-tmux-helper -f /dev/null start-server \\; list-keys \\; kill-server 2>/dev/null || true; } | head -c 131072"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        root.extras = root.parseListKeys(text)
        if (root.opened) root.rebuild()
      }
    }
  }

  Process {
    id: prefixProbe
    command: ["sh", "-c", "{ tmux show-option -gv prefix 2>/dev/null || true; } | head -c 64"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var out = text.trim().slice(0, 32)
        if (out) root.tmuxPrefix = out
        if (root.opened) root.rebuild()
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "io.github.alexdont.tmux-helper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var ctrl = (event.modifiers & Qt.ControlModifier)
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (ctrl && event.key === Qt.Key_P) {
            if (root.selectedId()) root.togglePin(root.selectedId())
            event.accepted = true
          } else if (ctrl && event.key === Qt.Key_Z) {
            root.undo()
            event.accepted = true
          } else if (ctrl && event.key === Qt.Key_A) {
            root.showArchived = !root.showArchived
            root.rebuild()
            event.accepted = true
          } else if (ctrl && event.key === Qt.Key_E) {
            root.showExtras = !root.showExtras
            root.rebuild()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selectedId()) root.markLearned(root.selectedId())
            event.accepted = true
          } else if (event.key === Qt.Key_Delete) {
            if (root.selectedId()) root.markIrrelevant(root.selectedId())
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.selectPage(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.selectPage(1)
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.spacing.md

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"

          Text {
            anchors.left: parent.left
            anchors.right: progressLabel.left
            anchors.rightMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText || "Search tmux shortcuts…"
            textFormat: Text.PlainText
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Text {
            id: progressLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.showArchived
              ? root.learnedCount + " learned · " + root.irrelevantCount + " irrelevant"
              : root.remainingCount + " to go"
            color: root.foreground
            opacity: 0.65
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - footer.height - Style.spacing.md * 2

          ListView {
            id: resultList
            anchors.fill: parent
            model: displayModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            section.property: "sectionLabel"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
              required property string section
              width: resultList.width
              height: Math.max(Style.space(28), Style.font.body + Style.spacing.md)

              Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(4)
                text: section
                color: root.selectedText
                opacity: 0.85
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }

            delegate: Rectangle {
              id: rowItem
              required property int index
              required property string bid
              required property string keyText
              required property string desc
              required property string status
              required property bool isPinned

              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
              readonly property bool dimmed: status !== "learning"

              width: resultList.width
              height: root.rowHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.md
                anchors.right: actions.left
                anchors.rightMargin: Style.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.spacing.md

                Rectangle {
                  width: keyLabel.implicitWidth + Style.spacing.md * 2
                  height: keyLabel.implicitHeight + Style.space(8)
                  radius: root.cornerRadius / 2
                  color: root.selectedBackground
                  opacity: parent.parent.dimmed ? 0.4 : (parent.parent.hasCursor ? 1 : 0.7)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    id: keyLabel
                    anchors.centerIn: parent
                    text: keyText
                    // Live tmux strings render literally, never as rich text.
                    textFormat: Text.PlainText
                    color: root.selectedText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: (isPinned ? "󰐃 " : "") + desc
                    + (status === "learned" ? "  ✓ learned" : status === "irrelevant" ? "  ✕ irrelevant" : "")
                  textFormat: Text.PlainText
                  color: root.foreground
                  opacity: parent.parent.dimmed ? 0.45 : 1
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
              }

              Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)
                visible: parent.hasCursor

                Repeater {
                  model: ["learned", "irrelevant", "pin"]

                  Rectangle {
                    required property string modelData

                    // Each button is a toggle and looks like one: lit while
                    // its state is active, glyph flipped to the undo form.
                    readonly property bool active: modelData === "learned" ? rowItem.status === "learned"
                      : modelData === "irrelevant" ? rowItem.status === "irrelevant"
                      : rowItem.isPinned

                    width: Style.space(28)
                    height: Style.space(28)
                    radius: root.cornerRadius / 2
                    color: (actionHover.containsMouse || active) ? root.selectedBackground : "transparent"
                    opacity: actionHover.containsMouse ? 1 : (active ? 0.85 : 0.6)

                    Text {
                      anchors.centerIn: parent
                      text: parent.modelData === "pin" ? (rowItem.isPinned ? "󰐄" : "󰐃")
                        : parent.modelData === "learned" ? (rowItem.status === "learned" ? "↺" : "✓")
                        : (rowItem.status === "irrelevant" ? "↺" : "✕")
                      color: root.selectedText
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }

                    MouseArea {
                      id: actionHover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (parent.modelData === "learned") root.markLearned(rowItem.bid)
                        else if (parent.modelData === "irrelevant") root.markIrrelevant(rowItem.bid)
                        else root.togglePin(rowItem.bid)
                      }
                    }
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                anchors.rightMargin: parent.hasCursor ? Style.space(110) : 0
                hoverEnabled: true
                onContainsMouseChanged: if (containsMouse) {
                  root.cursorActive = true
                  root.selectedIndex = index
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0

            Text {
              text: root.filterText ? "No matches for “" + root.filterText + "”"
                : "All " + root.totalCount + " shortcuts handled — you know tmux."
              textFormat: Text.PlainText
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: root.cardWidth - root.contentMargin * 2
              wrapMode: Text.WordWrap
            }
          }
        }

        Text {
          id: footer
          width: parent.width
          text: "↵ learned · Del irrelevant · ^P pin · ^Z undo · ^A archived · ^E "
            + (root.showExtras ? "hide" : "show") + " all · Esc close"
            + "   —   prefix: " + root.tmuxPrefix
          textFormat: Text.PlainText
          color: root.foreground
          opacity: 0.5
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
