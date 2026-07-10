pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  // TODO Remove in may 2026
  Component.onCompleted: {
    _setBandsCount();
  }

  // Register a component that needs audio data, call this when a visualizer becomes active.
  // Pass a unique identifier (e.g., "lockscreen", "controlcenter:screen1", "plugin:fancy-audiovisualizer")
  function registerComponent(componentId) {
    root._registeredComponents[componentId] = true;
    root._registeredComponents = Object.assign({}, root._registeredComponents);
    Logger.d("Spectrum", "Component registered:", componentId, "- total:", root._registeredCount);
  }

  // Unregister a component when it no longer needs audio data.
  function unregisterComponent(componentId) {
    delete root._registeredComponents[componentId];
    root._registeredComponents = Object.assign({}, root._registeredComponents);
    Logger.d("Spectrum", "Component unregistered:", componentId, "- total:", root._registeredCount);
  }

  // Check if a component is registered
  function isRegistered(componentId) {
    return root._registeredComponents[componentId] === true;
  }

  // Component registration - any component needing audio data registers here
  property var _registeredComponents: ({})
  readonly property int _registeredCount: Object.keys(_registeredComponents).length
  property bool _shouldRun: _registeredCount > 0

  property var values: []
  property bool isIdle: true

  // Per-band peak-hold: each peak jumps to a new maximum instantly, sits there for
  // peakHoldSeconds, then falls under constant acceleration (gravity), which reads
  // far better than a linear fall. Computed once here so every visualizer shares it.
  property var peaks: []

  readonly property real peakHoldSeconds: 0.4
  readonly property real peakGravity: 1.6 // amplitude units per second squared

  // Internal, mutated in place; `peaks` gets a fresh copy so bindings re-evaluate.
  property var _peakValues: []
  property var _peakHold: []
  property var _peakVelocity: []

  function _resetPeaks(n) {
    root._peakValues = new Array(n).fill(0);
    root._peakHold = new Array(n).fill(0);
    root._peakVelocity = new Array(n).fill(0);
  }

  function _updatePeaks(dt) {
    const v = root.values;
    const n = (v && v.length !== undefined) ? v.length : 0;
    if (n === 0) {
      if (root.peaks.length !== 0) {
        root.peaks = [];
      }
      return;
    }

    if (root._peakValues.length !== n) {
      root._resetPeaks(n);
    }

    var p = root._peakValues;
    var hold = root._peakHold;
    var vel = root._peakVelocity;

    for (var i = 0; i < n; i++) {
      const amp = v[i] || 0;
      if (amp >= p[i]) {
        // New peak: snap up, restart the hold, cancel any fall.
        p[i] = amp;
        hold[i] = root.peakHoldSeconds;
        vel[i] = 0;
      } else if (hold[i] > 0) {
        hold[i] -= dt;
      } else {
        vel[i] += root.peakGravity * dt;
        p[i] = Math.max(amp, p[i] - vel[i] * dt);
      }
    }

    root.peaks = p.slice();
  }

  Timer {
    // Decay must advance on wall time, not on audio frames, or the caps freeze
    // in place whenever PipeWire stops emitting during silence.
    interval: Math.max(1, Math.round(1000 / Settings.data.audio.spectrumFrameRate))
    running: root._shouldRun && Settings.data.audio.spectrumPeaks
    repeat: true
    onTriggered: root._updatePeaks(interval / 1000)
  }

  onValuesChanged: {
    if (!Settings.data.audio.spectrumPeaks && root.peaks.length !== 0) {
      root.peaks = [];
    }
  }

  PwAudioSpectrum {
    id: spectrum
    node: Pipewire.defaultAudioSink
    enabled: root._shouldRun
    // TODO Uncomment this in may 2026
    // bandCount: Settings.data.audio.spectrumMirrored ? 32 : 64
    frameRate: Settings.data.audio.spectrumFrameRate
    lowerCutoff: 50
    upperCutoff: 12000
    noiseReduction: 0.77
    smoothing: true

    onValuesChanged: {
      root.values = spectrum.values;
    }

    onIdleChanged: {
      root.isIdle = spectrum.idle;
    }
  }

  // TODO Remove in may 2026 - temporary until noctalia-qs is fully propagated
  Connections {
    target: Settings.data.audio
    function onSpectrumMirroredChanged() {
      _setBandsCount();
    }
  }
  function _setBandsCount() {
    const bandCount = Settings.data.audio.spectrumMirrored ? 32 : 64;
    if (spectrum.bandCount !== undefined) {
      spectrum.bandCount = bandCount;
    } else if (spectrum.barCount !== undefined) {
      spectrum.barCount = bandCount;
    }
  }
}
