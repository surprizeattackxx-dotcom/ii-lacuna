// dots/.config/quickshell/noctalia-shell/Modules/Particles/ParticlesOverlay.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Particles

Variants {
  id: root
  model: Quickshell.screens

  delegate: PanelWindow {
    id: overlayWindow
    required property ShellScreen modelData
    screen: modelData

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "noctalia-particles"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Click-through — particles are display-only, no input needed
    mask: Region {}

    readonly property real screenX: modelData.x
    readonly property real screenY: modelData.y

    property var particleComponent: Qt.createComponent("Particle.qml")

    function containsPoint(px, py) {
      return px >= modelData.x && px < modelData.x + modelData.width && py >= modelData.y && py < modelData.y + modelData.height;
    }

    function spawnBurst(localX, localY, kind) {
      if (particleComponent.status !== Component.Ready) return;
      const isBackspace = kind === "backspace";
      const count = isBackspace ? 4 : 8;
      for (let i = 0; i < count; i++) {
        const angle = Math.random() * Math.PI * 2;
        const distance = isBackspace ? 16 + Math.random() * 20 : 24 + Math.random() * 32;
        const duration = isBackspace ? 250 + Math.random() * 150 : 300 + Math.random() * 200;
        const size = isBackspace ? 3 + Math.random() * 2 : 4 + Math.random() * 3;
        const particleColor = isBackspace ? Color.mSecondary : (Math.random() < 0.5 ? Color.mPrimary : Color.mSecondary);
        particleComponent.createObject(overlayWindow.contentItem, {
          "x": localX - size / 2,
          "y": localY - size / 2,
          "angle": angle,
          "distance": distance,
          "particleDuration": duration,
          "particleSize": size,
          "particleColor": particleColor
        });
      }
    }

    Component.onCompleted: ParticlesService.registerOverlay(modelData.name, overlayWindow)
    Component.onDestruction: ParticlesService.unregisterOverlay(modelData.name)
  }
}
