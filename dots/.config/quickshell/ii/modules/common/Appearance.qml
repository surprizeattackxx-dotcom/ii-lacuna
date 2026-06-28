pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common.functions

Singleton {
    id: root
    property QtObject m3colors
    property QtObject animation
    property QtObject animationCurves
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes
    property string syntaxHighlightingTheme

    property bool darkmode: Config.options.appearance.colorMode === "dark"

    ColorQuantizer {
        id: wallColorQuant
        property string wallpaperPath: Config.options.background.wallpaperPath
        property bool wallpaperIsVideo: wallpaperPath.endsWith(".mp4") || wallpaperPath.endsWith(".webm") || wallpaperPath.endsWith(".mkv") || wallpaperPath.endsWith(".avi") || wallpaperPath.endsWith(".mov")
        source: Qt.resolvedUrl(wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath)
        depth: 0 
        rescaleSize: 10
    }
    property real wallpaperVibrancy: ((wallColorQuant.colors[0]?.hslSaturation ?? 0) + (wallColorQuant.colors[0]?.hslLightness ?? 0)) / 2
    property real autoBackgroundTransparency: { 
        let x = wallpaperVibrancy
        let y = 0.5768 * (x * x) - 0.759 * (x) + 0.2896
        return Math.max(0, Math.min(0.45, y + 0.15)) - 0.10 * (darkmode ? 0 : 1)
    }
    property real autoContentTransparency: 0.75
    property real backgroundTransparency: Config?.options.appearance.transparency.enable ? Config?.options.appearance.transparency.automatic ? autoBackgroundTransparency : Config?.options.appearance.transparency.backgroundTransparency : 0
    property real contentTransparency: Config?.options.appearance.transparency.automatic ? autoContentTransparency : Config?.options.appearance.transparency.contentTransparency

    m3colors: QtObject {
        property bool darkmode: root.darkmode
        property bool transparent: false
        
        // --- Dark Theme Defaults ---
        property color m3background: darkmode ? "#141313" : "#FEF8F5"
        property color m3onBackground: darkmode ? "#e6e1e1" : "#1D1B1A"
        property color m3surface: darkmode ? "#141313" : "#FEF8F5"
        property color m3surfaceDim: darkmode ? "#141313" : "#DED9D6"
        property color m3surfaceBright: darkmode ? "#3a3939" : "#FEF8F5"
        property color m3surfaceContainerLowest: darkmode ? "#0f0e0e" : "#FFFFFF"
        property color m3surfaceContainerLow: darkmode ? "#1c1b1c" : "#F8F3EF"
        property color m3surfaceContainer: darkmode ? "#201f20" : "#F2EDE9"
        property color m3surfaceContainerHigh: darkmode ? "#2b2a2a" : "#ECE7E4"
        property color m3surfaceContainerHighest: darkmode ? "#363435" : "#E6E2DE"
        property color m3onSurface: darkmode ? "#e6e1e1" : "#1D1B1A"
        property color m3surfaceVariant: darkmode ? "#49464a" : "#E9E1D5"
        property color m3onSurfaceVariant: darkmode ? "#cbc5ca" : "#4B463D"
        property color m3outline: darkmode ? "#948f94" : "#79746A"
        property color m3outlineVariant: darkmode ? "#49464a" : "#CDC6BA"
        property color m3primary: darkmode ? "#cbc4cb" : "#665E48"
        property color m3onPrimary: darkmode ? "#322f34" : "#FFFFFF"
        property color m3primaryContainer: darkmode ? "#2d2a2f" : "#F1E4C9"
        property color m3onPrimaryContainer: darkmode ? "#bcb6bc" : "#6E6550"
        property color m3secondary: darkmode ? "#cac5c8" : "#635E54"
        property color m3onSecondary: darkmode ? "#323032" : "#FFFFFF"
        property color m3secondaryContainer: darkmode ? "#4d4b4d" : "#EAE1D4"
        property color m3onSecondaryContainer: darkmode ? "#ece6e9" : "#696459"
        property color m3tertiary: darkmode ? "#d1c3c6" : "#707765"
        property color m3onTertiary: darkmode ? "#372e30" : "#FFFFFF"
        property color m3tertiaryContainer: darkmode ? "#31292b" : "#707765"
        property color m3onTertiaryContainer: darkmode ? "#c1b4b7" : "#FFFFFF"
        property color m3error: darkmode ? "#ffb4ab" : "#BA1A1A"
        property color m3onError: darkmode ? "#690005" : "#FFFFFF"
        property color m3errorContainer: darkmode ? "#93000a" : "#FFDAD6"
        property color m3onErrorContainer: darkmode ? "#ffdad6" : "#93000A"
        property color m3success: darkmode ? "#B5CCBA" : "#55624C"
        property color m3onSuccess: darkmode ? "#213528" : "#FFFFFF"
        property color m3successContainer: darkmode ? "#374B3E" : "#D8E7CB"
        property color m3onSuccessContainer: darkmode ? "#D1E9D6" : "#131E0C"
        property color m3inverseSurface: darkmode ? "#e6e1e1" : "#313030"
        property color m3inverseOnSurface: darkmode ? "#313030" : "#e6e1e1"
        property color m3scrim: "#000000"
        property color m3shadow: "#000000"

        // --- Mappings ---
        property color base: m3background
        property color mantle: m3surfaceContainerLow
        property color crust: m3surfaceContainerLowest
        property color text: m3onSurface
        property color subtext0: m3onSurfaceVariant
        property color subtext1: m3outline
        property color surface0: m3surfaceContainer
        property color surface1: m3surfaceContainerHigh
        property color surface2: m3surfaceContainerHighest
        property color overlay0: m3outline
        property color overlay1: m3outlineVariant
        property color overlay2: m3surfaceVariant
        
        property color blue: m3primary
        property color sapphire: m3secondary
        property color peach: m3tertiary
        property color green: m3success
        property color red: m3error
        property color mauve: ColorUtils.mix(m3primary, darkmode ? "#cba6f7" : "#8839ef", 0.4)
        property color pink: ColorUtils.mix(m3secondary, darkmode ? "#f5c2e7" : "#ea76cb", 0.4)
        property color yellow: ColorUtils.mix(m3tertiary, darkmode ? "#f9e2af" : "#df8e1d", 0.4)
        property color maroon: ColorUtils.mix(m3error, darkmode ? "#eba0ac" : "#e64553", 0.4)
        property color teal: ColorUtils.mix(m3success, darkmode ? "#94e2d5" : "#179299", 0.4)
    }

    colors: QtObject {
        property color colSubtext: m3colors.subtext0
        // ... (remaining mappings unchanged from previous turn)
        property color colLayer0Base: m3colors.base
        // Liquid glass: lift the fill toward white so blurred content reads as frosted material
        property color colLayer0: ColorUtils.transparentize(root.darkmode ? ColorUtils.mix("#ffffff", colLayer0Base, 0.07) : colLayer0Base, root.backgroundTransparency)
        property color colOnLayer0: m3colors.text
        property color colLayer0Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.9, root.contentTransparency))
        property color colLayer0Active: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.8, root.contentTransparency))
        // Specular rim — bright edge highlight instead of an outline color
        property color colLayer0Border: root.darkmode ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.7)
        property color colLayer1Base: m3colors.mantle
        property color colLayer1: ColorUtils.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - root.contentTransparency);
        property color colOnLayer1: m3colors.subtext0;
        property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45);
        property color colLayer1Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.92), root.contentTransparency)
        property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.85), root.contentTransparency);
        property color colLayer2Base: m3colors.surface0
        property color colLayer2: ColorUtils.solveOverlayColor(colLayer1Base, colLayer2Base, 1 - root.contentTransparency)
        property color colLayer2Hover: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.90), 1 - root.contentTransparency)
        property color colLayer2Active: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.80), 1 - root.contentTransparency);
        property color colLayer2Disabled: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, m3colors.m3background, 0.8), 1 - root.contentTransparency);
        property color colOnLayer2: m3colors.text;
        property color colOnLayer2Disabled: ColorUtils.mix(colOnLayer2, m3colors.m3background, 0.4);
        property color colLayer3Base: m3colors.surface1
        property color colLayer3: ColorUtils.solveOverlayColor(colLayer2Base, colLayer3Base, 1 - root.contentTransparency)
        property color colLayer3Hover: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.90), 1 - root.contentTransparency)
        property color colLayer3Active: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.80), 1 - root.contentTransparency);
        property color colOnLayer3: m3colors.text;
        property color colLayer4Base: m3colors.surface2
        property color colLayer4: ColorUtils.solveOverlayColor(colLayer3Base, colLayer4Base, 1 - root.contentTransparency)
        property color colLayer4Hover: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.90), 1 - root.contentTransparency)
        property color colLayer4Active: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.80), 1 - root.contentTransparency);
        property color colOnLayer4: m3colors.text;
        property color colPrimary: m3colors.mauve
        property color colOnPrimary: m3colors.m3onPrimary
        property color colPrimaryHover: ColorUtils.mix(colors.colPrimary, colLayer1Hover, 0.87)
        property color colPrimaryActive: ColorUtils.mix(colors.colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: m3colors.m3primaryContainer
        property color colPrimaryContainerHover: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.9)
        property color colPrimaryContainerActive: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.8)
        property color colOnPrimaryContainer: m3colors.m3onPrimaryContainer
        property color colSecondary: m3colors.blue
        property color colSecondaryHover: ColorUtils.mix(m3colors.blue, colLayer1Hover, 0.85)
        property color colSecondaryActive: ColorUtils.mix(m3colors.blue, colLayer1Active, 0.4)
        property color colOnSecondary: m3colors.m3onSecondary
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colSecondaryContainerHover: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.90)
        property color colSecondaryContainerActive: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.54)
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        property color colTertiary: m3colors.teal
        property color colTertiaryHover: ColorUtils.mix(m3colors.teal, colLayer1Hover, 0.85)
        property color colTertiaryActive: ColorUtils.mix(m3colors.teal, colLayer1Active, 0.4)
        property color colTertiaryContainer: m3colors.m3tertiaryContainer
        property color colTertiaryContainerHover: ColorUtils.mix(m3colors.m3tertiaryContainer, m3colors.m3onTertiaryContainer, 0.90)
        property color colTertiaryContainerActive: ColorUtils.mix(m3colors.m3tertiaryContainer, colLayer1Active, 0.54)
        property color colOnTertiary: m3colors.m3onTertiary
        property color colOnTertiaryContainer: m3colors.m3onTertiaryContainer
        property color colBackgroundSurfaceContainer: ColorUtils.transparentize(m3colors.surface0, root.backgroundTransparency)
        property color colSurfaceContainerLow: ColorUtils.transparentize(m3colors.mantle, root.contentTransparency)
        property color colSurfaceContainer: ColorUtils.transparentize(m3colors.surface0, root.contentTransparency)
        property color colSurfaceContainerHigh: ColorUtils.transparentize(m3colors.surface1, root.contentTransparency)
        property color colSurfaceContainerHighest: ColorUtils.transparentize(m3colors.surface2, root.contentTransparency)
        property color colSurfaceContainerHighestHover: ColorUtils.mix(m3colors.surface2, m3colors.text, 0.95)
        property color colSurfaceContainerHighestActive: ColorUtils.mix(m3colors.surface2, m3colors.text, 0.85)
        property color colOnSurface: m3colors.text
        property color colOnSurfaceVariant: m3colors.subtext0
        property color colTooltip: m3colors.m3inverseSurface
        property color colOnTooltip: m3colors.m3inverseOnSurface
        property color colScrim: ColorUtils.transparentize(m3colors.m3scrim, 0.5)
        property color colShadow: ColorUtils.transparentize(m3colors.m3shadow, 0.7)
        property color colOutline: m3colors.overlay0
        property color colOutlineVariant: m3colors.overlay1
        property color colError: m3colors.red
        property color colErrorHover: ColorUtils.mix(m3colors.red, colLayer1Hover, 0.85)
        property color colErrorActive: ColorUtils.mix(m3colors.red, colLayer1Active, 0.7)
        property color colOnError: m3colors.m3onError
        property color colErrorContainer: m3colors.m3errorContainer
        property color colErrorContainerHover: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.90)
        property color colErrorContainerActive: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.70)
        property color colOnErrorContainer: m3colors.m3onErrorContainer
    }

    rounding: QtObject {
        property int unsharpen: Config.options.appearance.sharpMode ? 0 : 2
        property int unsharpenmore: Config.options.appearance.sharpMode ? 0 : 6
        property int verysmall: Config.options.appearance.sharpMode ? 0 : 10
        property int small: Config.options.appearance.sharpMode ? 0 : 14
        property int medium: Config.options.appearance.sharpMode ? 0 : 17
        property int normal: Config.options.appearance.sharpMode ? 0 : 20
        property int large: Config.options.appearance.sharpMode ? 0 : 28
        property int verylarge: Config.options.appearance.sharpMode ? 0 : 36
        property int full: Config.options.appearance.sharpMode ? 0 : 9999
        property int screenRounding: large
        property int windowRounding: Config.options.appearance.sharpMode ? 0 : 24
    }

    font: QtObject {
        property QtObject family: QtObject {
            property string main: Config.options.appearance.fonts.main
            property string numbers: Config.options.appearance.fonts.numbers
            property string title: Config.options.appearance.fonts.title
            property string iconMaterial: "Material Symbols Rounded"
            property string iconNerd: Config.options.appearance.fonts.iconNerd
            property string monospace: Config.options.appearance.fonts.monospace
            property string reading: Config.options.appearance.fonts.reading
            property string expressive: Config.options.appearance.fonts.expressive
        }
        property QtObject variableAxes: QtObject {
            property var main: ({ "wght": 450, "wdth": 100 })
            property var numbers: ({ "wght": 450 })
            property var title: ({ "wght": 550 })
        }
        property QtObject pixelSize: QtObject {
            property int smallest: 10
            property int smaller: 12
            property int smallie: 13
            property int small: 15
            property int normal: 16
            property int large: 17
            property int larger: 19
            property int huge: 22
            property int hugeass: 23
            property int title: huge
        }
    }

    animationCurves: QtObject {
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1]
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1]
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1]
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedFirstHalf: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82]
        readonly property list<real> emphasizedLastHalf: [5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property real expressiveFastSpatialDuration: 350
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveSlowSpatialDuration: 650
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }
        property QtObject elementMoveSmall: QtObject {
            property int duration: animationCurves.expressiveFastSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveSmall.duration
                    easing.type: root.animation.elementMoveSmall.type
                    easing.bezierCurve: root.animation.elementMoveSmall.bezierCurve
                }
            }
        }
        property QtObject elementMoveEnter: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }
        property QtObject elementMoveExit: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedAccel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveExit.duration
                    easing.type: root.animation.elementMoveExit.type
                    easing.bezierCurve: root.animation.elementMoveExit.bezierCurve
                }
            }
        }
        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component { ColorAnimation {
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
        }
        property QtObject elementResize: QtObject {
            property int duration: 300
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasized
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementResize.duration
                    easing.type: root.animation.elementResize.type
                    easing.bezierCurve: root.animation.elementResize.bezierCurve
                }
            }
        }
        property QtObject clickBounce: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 850
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.clickBounce.duration
                easing.type: root.animation.clickBounce.type
                easing.bezierCurve: root.animation.clickBounce.bezierCurve
            }}
        }
        property QtObject scroll: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: root.animationCurves.standardDecel
        }
        property QtObject menuDecel: QtObject {
            property int duration: 350
            property int type: Easing.OutExpo
        }
    }

    sizes: QtObject {
        readonly property real densityMultiplier: Config.options.bar.density === "mini" ? 0.6
            : Config.options.bar.density === "compact" ? 0.8
            : Config.options.bar.density === "comfortable" ? 1.2
            : Config.options.bar.density === "spacious" ? 1.5
            : 1.0
        property real baseBarHeight: Config.options.bar.sizes.height * root.sizes.densityMultiplier
        property real barHeight: Config.options.bar.barType === "floating" ? 
            (baseBarHeight + root.sizes.hyprlandGapsOut * 2) : baseBarHeight
        property real barCenterSideModuleWidth: Config.options?.bar.verbose ? 360 : 140
        property real barCenterSideModuleWidthShortened: 280
        property real barCenterSideModuleWidthHellaShortened: 190
        property real barShortenScreenWidthThreshold: 1200 
        property real barHellaShortenScreenWidthThreshold: 1000 
        property real elevationMargin: 10
        property real fabShadowRadius: 5
        property real fabHoveredShadowRadius: 7
        property real hyprlandGapsOut: 5
        property real mediaControlsWidth: 440
        property real mediaControlsHeight: 160
        property real notificationPopupWidth: 410
        property real osdWidth: 200
        property real searchWidthCollapsed: 210
        property real searchWidth: 360
        property real sidebarWidth: 460
        property real sidebarWidthExpanded: 570 
        property real sidebarWidthExtended: 750
        property real baseVerticalBarWidth: Config.options.bar.sizes.width * root.sizes.densityMultiplier
        property real verticalBarWidth: Config.options.bar.barType === "floating" ? 
            (baseVerticalBarWidth + root.sizes.hyprlandGapsOut * 2) : baseVerticalBarWidth
        property real wallpaperSelectorWidth: 1200
        property real wallpaperSelectorHeight: 690
        property real wallpaperSelectorItemMargins: 8
        property real wallpaperSelectorItemPadding: 6
        property int dockButtonSize: Math.round((Config.options?.dock.height ?? 60) * 0.85)
    }

    syntaxHighlightingTheme: root.darkmode ? "Monokai" : "ayu Light"
}
