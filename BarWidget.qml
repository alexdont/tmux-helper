import QtQuick
import qs.Ui

// Icon-only launcher for the cheat sheet overlay; progress lives in the
// overlay itself ("N to go"), not the bar.
BarWidget {
  id: root
  moduleName: "io.github.alexdont.tmux-helper"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰆍"
    horizontalMargin: 7.5
    onPressed: function(b) {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle io.github.alexdont.tmux-helper '{}'")
    }
  }
}
