pragma Singleton

import QtQuick
import Quickshell
import qs.Services.Power

Singleton {
  id: root

  // Font size
  readonly property real fontSizeXXS: 8
  readonly property real fontSizeXS: 9
  readonly property real fontSizeS: 10
  readonly property real fontSizeM: 11
  readonly property real fontSizeL: 13
  readonly property real fontSizeXL: 16
  readonly property real fontSizeXXL: 18
  readonly property real fontSizeXXXL: 24

  // Font weight
  readonly property int fontWeightRegular: 400
  readonly property int fontWeightMedium: 500
  readonly property int fontWeightSemiBold: 600
  readonly property int fontWeightBold: 700

  // M3 type scale: letter-spacing tapers from most tracking at small sizes
  // (legibility, matching M3's Label scale) down to ~0 by title/headline-scale
  // sizes (~24px+ in this shell's ramp) - the one type-scale dimension this
  // shell had none of. Continuous function, not a per-tier lookup, so any
  // custom/computed pointSize still gets a sensible value.
  function typeTracking(pointSize) {
    const minSize = fontSizeXXS, maxSize = fontSizeXXXL;
    const minTracking = 0.4, maxTracking = 0;
    const t = Math.max(0, Math.min(1, (pointSize - minSize) / (maxSize - minSize)));
    return minTracking + (maxTracking - minTracking) * t;
  }

  // Container Radii: major layout sections (sidebars, cards, content panels)
  readonly property int radiusXXXS: Math.round(3 * Settings.data.general.radiusRatio)
  readonly property int radiusXXS: Math.round(4 * Settings.data.general.radiusRatio)
  readonly property int radiusXS: Math.round(8 * Settings.data.general.radiusRatio)
  readonly property int radiusS: Math.round(12 * Settings.data.general.radiusRatio)
  readonly property int radiusM: Math.round(16 * Settings.data.general.radiusRatio)
  readonly property int radiusL: Math.round(20 * Settings.data.general.radiusRatio)

  // Input radii: interactive elements (buttons, toggles, text fields)
  readonly property int iRadiusXXXS: Math.round(3 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusXXS: Math.round(4 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusXS: Math.round(8 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusS: Math.round(12 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusM: Math.round(16 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusL: Math.round(20 * Settings.data.general.iRadiusRatio)

  readonly property int screenRadius: Math.round(20 * Settings.data.general.screenRadiusRatio)

  // Border
  readonly property int borderS: Math.max(1, Math.round(1 * uiScaleRatio))
  readonly property int borderM: Math.max(1, Math.round(2 * uiScaleRatio))
  readonly property int borderL: Math.max(1, Math.round(3 * uiScaleRatio))

  // Margins (for margins and spacing)
  readonly property int marginXXXS: Math.round(1 * uiScaleRatio)
  readonly property int marginXXS: Math.round(2 * uiScaleRatio)
  readonly property int marginXS: Math.round(4 * uiScaleRatio)
  readonly property int marginS: Math.round(6 * uiScaleRatio)
  readonly property int marginM: Math.round(9 * uiScaleRatio)
  readonly property int marginL: Math.round(13 * uiScaleRatio)
  readonly property int marginXL: Math.round(18 * uiScaleRatio)

  // Double margins, for proper container sizing only (e.g. height: id.implicitHeight + Style.margin2M)
  readonly property int margin2XXXS: marginXXXS * 2
  readonly property int margin2XXS: marginXXS * 2
  readonly property int margin2XS: marginXS * 2
  readonly property int margin2S: marginS * 2
  readonly property int margin2M: marginM * 2
  readonly property int margin2L: marginL * 2
  readonly property int margin2XL: marginXL * 2

  // Opacity
  readonly property real opacityNone: 0.0
  readonly property real opacityLight: 0.25
  readonly property real opacityMedium: 0.5
  readonly property real opacityHeavy: 0.75
  readonly property real opacityAlmost: 0.95
  readonly property real opacityFull: 1.0

  // M3 state layers: translucent tint of a widget's own content color, laid over its resting color
  readonly property real stateLayerHover: 0.08
  readonly property real stateLayerFocus: 0.10
  readonly property real stateLayerPress: 0.12
  readonly property real stateLayerDragged: 0.16

  // M3 motion: real published easing curves, in QML BezierSpline format (each 3-point group is
  // [control1, control2, endpoint]; the animation implicitly starts at (0,0)).
  // easingStandard is a single cubic-bezier(0.2, 0, 0, 1) segment - M3's workhorse curve for
  // anything that isn't a large spatial transition.
  readonly property var easingStandard: [0.2, 0, 0, 1, 1, 1]
  // easingEmphasized is the real multi-segment M3 Emphasized path (a single cubic-bezier can't
  // express its overshoot-and-settle character). Was already correctly ported into SmartPanel.qml
  // and settings-portal.qml as inline duplicates; this is the single shared copy both now use.
  readonly property var easingEmphasized: [0.05, 0, 0.133, 0.06, 0.166, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]

  readonly property real effectivePanelOpacity: PowerProfileService.noctaliaPerformanceMode ? 1.0 : Color.adaptiveOpacity(Settings.data.ui.panelBackgroundOpacity)
  readonly property real effectiveBarOpacity: PowerProfileService.noctaliaPerformanceMode ? 1.0 : Settings.data.bar.backgroundOpacity

  // M3 elevation scale, levels 0-5. Tint opacities are the real published M3 surface-tint
  // percentages (primary color blended into the surface via Color.elevatedSurface()); shadow
  // opacity/blur are this shell's own tuning, not spec values (M3 doesn't publish those as numbers).
  // Level 0: resting surfaces with no separation (base background layer, list rows).
  readonly property real elevation0TintOpacity: 0.0

  // Level 1: tooltips, context menus — small surfaces just off the base plane.
  readonly property real elevation1ShadowOpacity: 0.5
  readonly property real elevation1ShadowBlur: 0.6
  readonly property real elevation1TintOpacity: 0.05

  // Level 2: bar + all SmartPanel panels, unified single-pass shadow. The shell's main visible
  // surfaces — this is the tier that was missing its tonal tint entirely until 2026-07-22.
  readonly property real shadowOpacity: 0.85
  readonly property real shadowBlur: 1.0
  readonly property int shadowBlurMax: 22
  readonly property real shadowHorizontalOffset: Settings.data.general.shadowOffsetX
  readonly property real shadowVerticalOffset: Settings.data.general.shadowOffsetY
  readonly property real elevation2TintOpacity: 0.08

  // Level 3: toasts, notifications, OSD, media cards — float above the panel layer.
  readonly property real elevation3ShadowOpacity: 0.95
  readonly property real elevation3ShadowBlur: 1.3
  readonly property real elevation3TintOpacity: 0.11

  // Level 4/5: reserved for modal/dialog-class surfaces above everything else. Nothing in this
  // shell renders at these tiers yet (no true modal dialogs) — defined now for a complete scale.
  readonly property real elevation4TintOpacity: 0.12
  readonly property real elevation5TintOpacity: 0.14

  // Animation duration (ms)
  readonly property int animationFaster: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(75 / Settings.data.general.animationSpeed)
  readonly property int animationFast: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(150 / Settings.data.general.animationSpeed)
  readonly property int animationNormal: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(300 / Settings.data.general.animationSpeed)
  readonly property int animationSlow: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(450 / Settings.data.general.animationSpeed)
  readonly property int animationSlowest: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(750 / Settings.data.general.animationSpeed)

  // Delays
  readonly property int tooltipDelay: 300
  readonly property int tooltipDelayLong: 1200
  readonly property int pillDelay: 500

  // Widgets base size
  readonly property real baseWidgetSize: 33
  readonly property real sliderWidth: 200

  readonly property real uiScaleRatio: Settings.data.general.scaleRatio

  // Bar Height
  readonly property real barHeight: {
    let h;
    switch (Settings.data.bar.density) {
      case "mini":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 23 : 21;
      break;
      case "compact":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 27 : 25;
      break;
      case "comfortable":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 39 : 37;
      break;
      case "spacious":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 49 : 47;
      break;
      default:
      case "default":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 33 : 31;
    }
    return toOdd(h);
  }

  // Capsule Height
  // Note: capsule must always be smaller than barHeight to account for border rendering
  // Qt Quick Rectangle borders are drawn centered on edges (half inside, half outside)
  readonly property real capsuleHeight: {
    let h;
    switch (Settings.data.bar.density) {
      case "mini":
      h = Math.round(barHeight * 0.90);
      break;
      case "compact":
      h = Math.round(barHeight * 0.85);
      break;
      case "comfortable":
      h = Math.round(barHeight * 0.75);
      break;
      case "spacious":
      h = Math.round(barHeight * 0.65);
      break;
      default:
      h = Math.round(barHeight * 0.82);
      break;
    }
    return toOdd(h);
  }

  // The base/default font size for all texts in the bar
  readonly property real _barBaseFontSize: Math.max(1, (Style.barHeight / Style.capsuleHeight) * Style.fontSizeXXS)
  readonly property real barFontSize: (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? _barBaseFontSize * 0.9 * Settings.data.bar.fontScale : _barBaseFontSize * Settings.data.bar.fontScale

  readonly property color capsuleColor: Settings.data.bar.showCapsule ? Qt.alpha(Settings.data.bar.capsuleColorKey !== "none" ? Color.resolveColorKey(Settings.data.bar.capsuleColorKey) : Color.mSurfaceVariant, Settings.data.bar.capsuleOpacity) : "transparent"

  readonly property color capsuleBorderColor: Settings.data.bar.showOutline ? Color.mPrimary : "transparent"
  readonly property int capsuleBorderWidth: Settings.data.bar.showOutline ? Style.borderS : 0

  readonly property color boxBorderColor: Settings.data.ui.boxBorderEnabled ? Color.mOutline : "transparent"

  // Pixel-perfect utility for centering content without subpixel positioning
  function pixelAlignCenter(containerSize, contentSize) {
    return Math.round((containerSize - contentSize) / 2);
  }

  // Ensures a number is always odd (rounds down to nearest odd)
  function toOdd(n) {
    return Math.floor(n / 2) * 2 + 1;
  }

  // Ensures a number is always even (rounds down to nearest even)
  function toEven(n) {
    return Math.floor(n / 2) * 2;
  }

  // Get bar height for a specific density and orientation
  function getBarHeightForDensity(density, isVertical) {
    let h;
    switch (density) {
    case "mini":
      h = isVertical ? 23 : 21;
      break;
    case "compact":
      h = isVertical ? 27 : 25;
      break;
    case "comfortable":
      h = isVertical ? 39 : 37;
      break;
    case "spacious":
      h = isVertical ? 49 : 47;
      break;
    default:
    case "default":
      h = isVertical ? 33 : 31;
    }
    return toOdd(h);
  }

  // Get capsule height for a specific density and bar height
  function getCapsuleHeightForDensity(density, barHeight) {
    let h;
    switch (density) {
    case "mini":
      h = Math.round(barHeight * 0.90);
      break;
    case "compact":
      h = Math.round(barHeight * 0.85);
      break;
    case "comfortable":
      h = Math.round(barHeight * 0.75);
      break;
    case "spacious":
      h = Math.round(barHeight * 0.65);
      break;
    default:
      h = Math.round(barHeight * 0.82);
      break;
    }
    return toOdd(h);
  }

  // Get bar font size for a specific bar height, capsule height, and orientation
  function getBarFontSizeForDensity(barHeight, capsuleHeight, isVertical) {
    const baseFontSize = Math.max(1, (barHeight / capsuleHeight) * Style.fontSizeXXS);
    return isVertical ? baseFontSize * 0.9 * Settings.data.bar.fontScale : baseFontSize * Settings.data.bar.fontScale;
  }

  // Convenience functions for per-screen bar sizing
  function getBarHeightForScreen(screenName) {
    var density = Settings.getBarDensityForScreen(screenName);
    var position = Settings.getBarPositionForScreen(screenName);
    var isVertical = position === "left" || position === "right";
    return getBarHeightForDensity(density, isVertical);
  }

  function getCapsuleHeightForScreen(screenName) {
    var barHeight = getBarHeightForScreen(screenName);
    var density = Settings.getBarDensityForScreen(screenName);
    return getCapsuleHeightForDensity(density, barHeight);
  }

  function getBarFontSizeForScreen(screenName) {
    var barHeight = getBarHeightForScreen(screenName);
    var capsuleHeight = getCapsuleHeightForScreen(screenName);
    var position = Settings.getBarPositionForScreen(screenName);
    var isVertical = position === "left" || position === "right";
    return getBarFontSizeForDensity(barHeight, capsuleHeight, isVertical);
  }
}
