import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.panels.lock
import qs.modules.ii.bar as Bar
import Quickshell
import Quickshell.Services.SystemTray

MouseArea {
  id: root
  required property LockContext context
  property bool active: false
  property bool showInputField: active || context.currentText.length > 0
  readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower

  readonly property bool wallpaperIsVideo: {
    const p = Config.options.background.wallpaperPath.toLowerCase();
    return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".avi") || p.endsWith(".mov");
  }
  readonly property string wallpaperSource: wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath

  readonly property var media: MprisController
  readonly property bool showMedia: media.currentPlayer && (media.canPlay || media.canPause)

  property string pendingSessionAction: ""
  property bool sessionTimerActive: false
  property int sessionTimeRemaining: 0
  readonly property int sessionCountdown: 10

  // Force focus on entry
  function forceFieldFocus() {
    passwordBox.forceActiveFocus();
  }
  Connections {
    target: context
    function onShouldReFocus() { forceFieldFocus(); }
  }
  hoverEnabled: true
  acceptedButtons: Qt.LeftButton
  onPressed: mouse => forceFieldFocus()
  onPositionChanged: mouse => forceFieldFocus()

  property real toolbarScale: 0.9
  property real toolbarOpacity: 0
  Behavior on toolbarScale {
    NumberAnimation {
      duration: Appearance.animation.elementMove.duration
      easing.type: Appearance.animation.elementMove.type
      easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
    }
  }
  Behavior on toolbarOpacity {
    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
  }

  Component.onCompleted: {
    forceFieldFocus();
    toolbarScale = 1;
    toolbarOpacity = 1;
  }

  // Wallpaper background
  Image {
    anchors.fill: parent
    source: Qt.resolvedUrl(root.wallpaperSource)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    visible: root.wallpaperSource.length > 0

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: ColorUtils.transparentize("#000000", 0.55) }
        GradientStop { position: 0.4; color: ColorUtils.transparentize("#000000", 0.8) }
        GradientStop { position: 1.0; color: ColorUtils.transparentize("#000000", 0.45) }
      }
    }
  }

  // Clock + date + weather
  ColumnLayout {
    anchors {
      top: parent.top
      topMargin: parent.height * 0.12
      horizontalCenter: parent.horizontalCenter
    }
    spacing: 2
    scale: root.toolbarScale
    opacity: root.toolbarOpacity

    StyledText {
      Layout.alignment: Qt.AlignHCenter
      text: DateTime.time
      color: "#ffffff"
      font {
        pixelSize: 110
        family: Appearance.font.family.expressive
        weight: Font.Medium
      }
      style: Text.Raised
      styleColor: ColorUtils.transparentize("#000000", 0.6)
    }

    StyledText {
      Layout.alignment: Qt.AlignHCenter
      text: DateTime.longDate
      color: ColorUtils.transparentize("#ffffff", 0.15)
      font {
        pixelSize: Appearance.font.pixelSize.huge
        weight: Font.Medium
      }
      style: Text.Raised
      styleColor: ColorUtils.transparentize("#000000", 0.6)
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 10
      spacing: 6
      visible: Weather.data.temp.length > 0

      MaterialSymbol {
        fill: 1
        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
        iconSize: Appearance.font.pixelSize.huge
        color: "#ffffff"
      }
      StyledText {
        text: Weather.data.temp
        color: "#ffffff"
        font.pixelSize: Appearance.font.pixelSize.larger
        style: Text.Raised
        styleColor: ColorUtils.transparentize("#000000", 0.6)
      }
      StyledText {
        text: Weather.data.description
        color: ColorUtils.transparentize("#ffffff", 0.2)
        font.pixelSize: Appearance.font.pixelSize.larger
        style: Text.Raised
        styleColor: ColorUtils.transparentize("#000000", 0.6)
      }
    }
  }

  // Media player (between clock and password)
  Item {
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom: parent.verticalCenter
      bottomMargin: -60
    }
    width: 400
    height: 60
    scale: root.toolbarScale
    opacity: root.toolbarOpacity
    visible: root.showMedia

    Rectangle {
      anchors.fill: parent
      radius: 12
      color: ColorUtils.transparentize("#000000", 0.6)
      border.color: ColorUtils.transparentize("#ffffff", 0.85)
      border.width: 1
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: 6
      spacing: 10

      // Album art
      Rectangle {
        Layout.preferredWidth: 48
        Layout.preferredHeight: 48
        radius: 8
        color: ColorUtils.transparentize("#ffffff", 0.9)
        clip: true

        Image {
          anchors.fill: parent
          source: media.trackArtUrl ? Qt.resolvedUrl(media.trackArtUrl) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          visible: status === Image.Ready
        }

        MaterialSymbol {
          anchors.centerIn: parent
          text: "disc"
          iconSize: 20
          color: ColorUtils.transparentize("#ffffff", 0.5)
          visible: parent.children[1].status !== Image.Ready
        }
      }

      // Track info
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        StyledText {
          Layout.fillWidth: true
          text: media.trackTitle || "No media"
          color: "#ffffff"
          font.pixelSize: 13
          elide: Text.ElideRight
          font.weight: Font.Medium
        }
        StyledText {
          Layout.fillWidth: true
          text: media.trackArtist || ""
          color: ColorUtils.transparentize("#ffffff", 0.3)
          font.pixelSize: 11
          elide: Text.ElideRight
        }
      }

      // Controls
      RowLayout {
        spacing: 4

        MediaControlButton {
          icon: "skip_previous"
          visible: media.canGoPrevious
          onClicked: media.previous()
        }
        MediaControlButton {
          icon: media.isPlaying ? "pause" : "play_arrow"
          visible: media.canPlay || media.canPause
          accent: media.isPlaying
          onClicked: media.playPause()
        }
        MediaControlButton {
          icon: "skip_next"
          visible: media.canGoNext
          onClicked: media.next()
        }
      }
    }
  }

  // Notifications — swipe to dismiss, they stay in the sidebar
  LockNotifications {
    anchors {
      top: parent.top
      right: parent.right
      topMargin: 20
      rightMargin: 20
    }
    scale: root.toolbarScale
    opacity: root.toolbarOpacity
  }

  // Key presses
  property bool ctrlHeld: false
  Keys.onPressed: event => {
    root.context.resetClearTimer();
    if (event.key === Qt.Key_Control) root.ctrlHeld = true;
    if (event.key === Qt.Key_Escape) root.context.currentText = "";
    forceFieldFocus();
  }
  Keys.onReleased: event => {
    if (event.key === Qt.Key_Control) root.ctrlHeld = false;
    forceFieldFocus();
  }

  // Main toolbar: password box
  Toolbar {
    id: mainIsland
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom: sessionButtonRow.top
      bottomMargin: 12
    }
    Behavior on anchors.bottomMargin {
      animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }

    scale: root.toolbarScale
    opacity: root.toolbarOpacity

    // Fingerprint
    Loader {
      Layout.leftMargin: 10
      Layout.rightMargin: 6
      Layout.alignment: Qt.AlignVCenter
      active: root.context.fingerprintsConfigured
      visible: active

      sourceComponent: MaterialSymbol {
        id: fingerprintIcon
        fill: 1
        text: "fingerprint"
        iconSize: Appearance.font.pixelSize.hugeass
        color: Appearance.colors.colOnSurfaceVariant
      }
    }

    ToolbarTextField {
      id: passwordBox
      Layout.rightMargin: -Layout.leftMargin
      placeholderText: GlobalStates.screenUnlockFailed ? Translation.tr("Incorrect password") : Translation.tr("Enter password")

      clip: true
      font.pixelSize: Appearance.font.pixelSize.small
      selectedTextColor: materialShapeChars ? "transparent" : Appearance.colors.colOnSecondaryContainer
      selectionColor: materialShapeChars ? "transparent" : Appearance.colors.colSecondaryContainer

      enabled: !root.context.unlockInProgress
      echoMode: TextInput.Password
      inputMethodHints: Qt.ImhSensitiveData

      onTextChanged: root.context.currentText = this.text
      onAccepted: root.context.tryUnlock(ctrlHeld)
      Connections {
        target: root.context
        function onCurrentTextChanged() {
          passwordBox.text = root.context.currentText;
        }
      }

      Keys.onPressed: event => root.context.resetClearTimer()

      layer.enabled: true
      layer.effect: OpacityMask {
        maskSource: Rectangle {
          width: passwordBox.width - 8
          height: passwordBox.height
          radius: height / 2
        }
      }

      ErrorShakeAnimation {
        id: wrongPasswordShakeAnim
        target: passwordBox
      }
      Connections {
        target: GlobalStates
        function onScreenUnlockFailedChanged() {
          if (GlobalStates.screenUnlockFailed) wrongPasswordShakeAnim.restart();
        }
      }

      property bool materialShapeChars: Config.options.lock.materialShapeChars
      color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, materialShapeChars ? 1 : 0)
      Loader {
        active: passwordBox.materialShapeChars
        anchors {
          fill: parent
          leftMargin: passwordBox.padding
          rightMargin: passwordBox.padding
        }
        sourceComponent: PasswordChars {
          length: root.context.currentText.length
          selectionStart: passwordBox.selectionStart
          selectionEnd: passwordBox.selectionEnd
          cursorPosition: passwordBox.cursorPosition
        }
      }
    }

    ToolbarButton {
      id: confirmButton
      implicitWidth: height
      toggled: true
      enabled: !root.context.unlockInProgress
      colBackgroundToggled: Appearance.colors.colPrimary

      onClicked: root.context.tryUnlock()

      contentItem: MaterialSymbol {
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        iconSize: 24
        text: {
          if (root.context.targetAction === LockContext.ActionEnum.Unlock)
            return root.ctrlHeld ? "coffee" : "arrow_right_alt";
          else if (root.context.targetAction === LockContext.ActionEnum.Poweroff)
            return "power_settings_new";
          else if (root.context.targetAction === LockContext.ActionEnum.Reboot)
            return "restart_alt";
        }
        color: confirmButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
      }
    }
  }

  // Session buttons (below password)
  Toolbar {
    id: sessionButtonRow
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom: leftIsland.bottom
    }
    scale: root.toolbarScale
    opacity: root.toolbarOpacity
    visible: true

    Repeater {
      model: [
        { btnIcon: "logout", btnAction: "logout" },
        { btnIcon: "dark_mode", btnAction: "suspend" },
        { btnIcon: "restart_alt", btnAction: "reboot" },
        { btnIcon: "power_settings_new", btnAction: "shutdown" }
      ]

      delegate: ToolbarButton {
        id: sessionBtn
        implicitWidth: 60
        implicitHeight: 40
        required property string btnIcon
        required property string btnAction

        contentItem: ColumnLayout {
          spacing: 0
          MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: root.sessionTimerActive && root.pendingSessionAction === sessionBtn.btnAction
              ? root.sessionTimeRemaining.toString()
              : sessionBtn.btnIcon
            iconSize: root.sessionTimerActive && root.pendingSessionAction === sessionBtn.btnAction ? 14 : 20
            color: Appearance.colors.colOnSurfaceVariant
          }
        }

        onClicked: {
          if (root.sessionTimerActive && root.pendingSessionAction === sessionBtn.btnAction) {
            _executeSessionAction(sessionBtn.btnAction);
          } else {
            root.pendingSessionAction = sessionBtn.btnAction;
            root.sessionTimeRemaining = root.sessionCountdown;
            root.sessionTimerActive = true;
            sessionCountdownTimer.restart();
          }
        }
      }
    }
  }

  Timer {
    id: sessionCountdownTimer
    interval: 1000
    repeat: true
    onTriggered: {
      root.sessionTimeRemaining -= 1;
      if (root.sessionTimeRemaining <= 0) {
        stop();
        root.sessionTimerActive = false;
        root.pendingSessionAction = "";
      }
    }
  }

  function _executeSessionAction(action) {
    sessionCountdownTimer.stop();
    root.sessionTimerActive = false;
    root.pendingSessionAction = "";
    if (action === "logout") Session.logout();
    else if (action === "suspend") Session.suspend();
    else if (action === "reboot") Session.reboot();
    else if (action === "shutdown") Session.poweroff();
  }

  // Left toolbar
  Toolbar {
    id: leftIsland
    anchors {
      right: mainIsland.left
      top: mainIsland.top
      bottom: mainIsland.bottom
      rightMargin: 10
    }
    scale: root.toolbarScale
    opacity: root.toolbarOpacity

    IconAndTextPair {
      Layout.leftMargin: 8
      icon: "account_circle"
      text: SystemInfo.username
    }

    Loader {
      Layout.rightMargin: 8
      Layout.fillHeight: true
      active: true
      visible: active
      sourceComponent: Row {
        spacing: 8
        MaterialSymbol {
          id: keyboardIcon
          anchors.verticalCenter: parent.verticalCenter
          fill: 1
          text: "keyboard_alt"
          iconSize: Appearance.font.pixelSize.huge
          color: Appearance.colors.colOnSurfaceVariant
        }
        Loader {
          anchors.verticalCenter: parent.verticalCenter
          sourceComponent: StyledText {
            text: HyprlandXkb.currentLayoutCode
            color: Appearance.colors.colOnSurfaceVariant
            animateChange: true
          }
        }
      }
    }

    Bar.SysTray {
      Layout.rightMargin: 10
      Layout.alignment: Qt.AlignVCenter
      showSeparator: false
      showOverflowMenu: false
      pinnedItems: SystemTray.items.values.filter(i => i.id == "Fcitx")
      visible: pinnedItems.length > 0
    }
  }

  // Right toolbar
  Toolbar {
    id: rightIsland
    anchors {
      left: mainIsland.right
      top: mainIsland.top
      bottom: mainIsland.bottom
      leftMargin: 10
    }
    scale: root.toolbarScale
    opacity: root.toolbarOpacity

    IconAndTextPair {
      visible: Battery.available
      icon: Battery.isCharging ? "bolt" : "battery_android_full"
      text: Math.round(Battery.percentage * 100)
      color: (Battery.isLow && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
    }

    IconToolbarButton {
      id: sleepButton
      onClicked: Session.suspend()
      text: "dark_mode"
    }

    PasswordGuardedIconToolbarButton {
      id: powerButton
      text: "power_settings_new"
      targetAction: LockContext.ActionEnum.Poweroff
    }

    PasswordGuardedIconToolbarButton {
      id: rebootButton
      text: "restart_alt"
      targetAction: LockContext.ActionEnum.Reboot
    }
  }

  component PasswordGuardedIconToolbarButton: IconToolbarButton {
    id: guardedBtn
    required property var targetAction
    toggled: root.context.targetAction === guardedBtn.targetAction
    onClicked: {
      if (!root.requirePasswordToPower) {
        root.context.unlocked(guardedBtn.targetAction);
        return;
      }
      if (root.context.targetAction === guardedBtn.targetAction)
        root.context.resetTargetAction();
      else
        root.context.targetAction = guardedBtn.targetAction;
      root.context.shouldReFocus();
    }
  }

  component IconAndTextPair: Row {
    id: pair
    required property string icon
    required property string text
    property color color: Appearance.colors.colOnSurfaceVariant
    spacing: 4
    Layout.fillHeight: true
    Layout.leftMargin: 10
    Layout.rightMargin: 10

    MaterialSymbol {
      anchors.verticalCenter: parent.verticalCenter
      fill: 1
      text: pair.icon
      iconSize: Appearance.font.pixelSize.huge
      animateChange: true
      color: pair.color
    }
    StyledText {
      anchors.verticalCenter: parent.verticalCenter
      text: pair.text
      color: pair.color
    }
  }

  component MediaControlButton: Item {
    id: mediaBtn
    property string icon
    property bool accent: false
    signal clicked

    width: 34
    height: 34

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: mediaBtnArea.containsMouse ? ColorUtils.transparentize("#ffffff", 0.7)
        : mediaBtn.accent ? ColorUtils.transparentize("#ffffff", 0.2)
        : ColorUtils.transparentize("#ffffff", 0.1)
    }

    MaterialSymbol {
      anchors.centerIn: parent
      fill: 1
      text: mediaBtn.icon
      iconSize: 18
      color: mediaBtnArea.containsMouse ? "#000000" : "#ffffff"
    }

    MouseArea {
      id: mediaBtnArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: mediaBtn.clicked()
    }
  }
}
