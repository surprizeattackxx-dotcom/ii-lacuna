import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Live thumbnail of a workspace's active window, shown on hover.
// Hyprland-only: needs a qs.wayland.toplevel_management.Toplevel handle,
// which the caller resolves via Hyprland.toplevels (see Workspace.qml).
PopupWindow {
  id: root

  property var targetItem: null
  property var toplevel: null

  // Fit within this box, preserving the captured window's actual aspect
  // ratio, instead of a fixed size that letterboxes anything that doesn't
  // match it.
  readonly property real maxWidth: 320
  readonly property real maxHeight: 200
  readonly property real boxAspect: maxWidth / maxHeight
  readonly property real contentAspect: (capture.sourceSize.width > 0 && capture.sourceSize.height > 0) ? (capture.sourceSize.width / capture.sourceSize.height) : boxAspect

  implicitWidth: contentAspect >= boxAspect ? maxWidth : Math.round(maxHeight * contentAspect)
  implicitHeight: contentAspect >= boxAspect ? Math.round(maxWidth / contentAspect) : maxHeight
  visible: false
  color: "transparent"

  anchor.item: targetItem
  anchor.rect.y: targetItem ? targetItem.height + Style.marginXS : 0
  anchor.rect.x: targetItem ? Math.round((targetItem.width - implicitWidth) / 2) : 0

  function show(item, tl) {
    if (!tl)
      return;
    targetItem = item;
    toplevel = tl;
    visible = true;
  }

  function hide() {
    visible = false;
    toplevel = null;
  }

  Rectangle {
    anchors.fill: parent
    color: Color.mSurface
    border.color: Color.mOutline
    border.width: Style.borderS
    radius: Style.radiusM
    clip: true

    ScreencopyView {
      id: capture
      anchors.fill: parent
      anchors.margins: Style.borderS
      captureSource: root.toplevel
      live: root.visible
      paintCursor: false
      constraintSize: Qt.size(width, height)
    }
  }
}
