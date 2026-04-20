import qs.services
import qs
import QtQuick
import qs.modules.ii.onScreenDisplay
import qs.modules.common.widgets

OsdValueIndicator {
    id: osdValues
    value: GlobalStates.osdVolumeOverride >= 0 ? GlobalStates.osdVolumeOverride : (Audio.sink?.audio.volume ?? 0)
    icon: Audio.sink?.audio.muted ? "volume_off" : "volume_up"
    name: Translation.tr("Volume")
    shape: MaterialShape.Shape.Cookie7Sided
}
