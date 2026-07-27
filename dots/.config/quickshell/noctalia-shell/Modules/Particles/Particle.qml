// dots/.config/quickshell/noctalia-shell/Modules/Particles/Particle.qml
import QtQuick

Rectangle {
  id: root

  property real angle: 0
  property real distance: 40
  property color particleColor: "white"
  property int particleSize: 5
  property int particleDuration: 400

  width: particleSize
  height: particleSize
  radius: particleSize / 2
  color: particleColor

  Component.onCompleted: {
    xAnim.to = x + Math.cos(angle) * distance
    yAnim.to = y + Math.sin(angle) * distance
    xAnim.start()
    yAnim.start()
    fadeAnim.start()
    shrinkAnim.start()
    lifeTimer.start()
  }

  NumberAnimation {
    id: xAnim
    target: root
    property: "x"
    duration: root.particleDuration
    easing.type: Easing.OutQuad
  }

  NumberAnimation {
    id: yAnim
    target: root
    property: "y"
    duration: root.particleDuration
    easing.type: Easing.OutQuad
  }

  NumberAnimation {
    id: fadeAnim
    target: root
    property: "opacity"
    to: 0
    duration: root.particleDuration
    easing.type: Easing.InQuad
  }

  NumberAnimation {
    id: shrinkAnim
    target: root
    property: "scale"
    to: 0.2
    duration: root.particleDuration
    easing.type: Easing.InQuad
  }

  Timer {
    id: lifeTimer
    interval: root.particleDuration
    onTriggered: root.destroy()
  }
}
