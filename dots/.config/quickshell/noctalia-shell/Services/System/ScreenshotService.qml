pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

Singleton {
  id: root

  enum Action {
    Copy,
    Edit,
    Search,
    CharRecognition,
    Record,
    RecordWithSound
  }

  readonly property string tempDir: "/tmp/quickshell/media/screenshot"
  readonly property string uploadApiEndpoint: "https://uguu.se/upload"

  property string imageSearchEngineBaseUrl: Settings.data.regionSelector?.imageSearchEngineBaseUrl ?? "https://lens.google.com/uploadbyurl?url="
  property string screenshotSaveDir: Settings.data.regionSelector?.screenshotSaveDir ?? ""
  property string recordScriptPath: Quickshell.shellPath("Scripts/bash/record.sh")

  function shellEscape(str) {
    return "'" + str.replace(/'/g, "'\\''") + "'";
  }

  function getCommand(x, y, width, height, screenshotPath, action, saveDir) {
    if (saveDir === undefined || saveDir === null)
      saveDir = root.screenshotSaveDir;

    var rx = Math.round(x);
    var ry = Math.round(y);
    var rw = Math.round(width);
    var rh = Math.round(height);
    var escPath = root.shellEscape(screenshotPath);
    var cropBase = "magick " + escPath + " -crop " + rw + "x" + rh + "+" + rx + "+" + ry + " +repage";
    var cropToStdout = cropBase + " -";
    var cropInPlace = cropBase + " " + escPath;
    var cleanup = "rm -f " + escPath;
    var slurpRegion = rx + "," + ry + " " + rw + "x" + rh;
    var uploadCmd = "curl -sF files[]=@" + escPath + " " + root.uploadApiEndpoint + " | jq -r '.files[0].url'";
    var annotationTool = Settings.data.appLauncher.screenshotAnnotationTool || "swappy";
    var annotationCmd = annotationTool + " -f -";
    // Append a best-effort desktop notification (no-op if notify-send absent).
    var notify = function (title, body) {
      return " && (command -v notify-send >/dev/null && notify-send -a 'Screenshot' "
        + root.shellEscape(title) + " " + root.shellEscape(body || "")
        + " -i image-x-generic || true)";
    };

    switch (action) {
    case ScreenshotService.Action.Copy:
      if (!saveDir || saveDir === "") {
        // Copy to clipboard only
        return ["bash", "-c", cropToStdout + " | wl-copy && " + cleanup + notify("Region copied", "Saved to clipboard")];
      }
      // Save and copy
      return ["bash", "-c",
        "mkdir -p " + root.shellEscape(saveDir) + " && "
        + "saveFileName=\"screenshot-$(date '+%Y-%m-%d_%H.%M.%S').png\" && "
        + "savePath=\"" + saveDir + "/$saveFileName\" && "
        + cropToStdout + " | tee >(wl-copy) > \"$savePath\" && "
        + cleanup
        + " && (command -v notify-send >/dev/null && notify-send -a 'Screenshot' 'Screenshot saved' \"$savePath\" -i image-x-generic || true)"];
    case ScreenshotService.Action.Edit:
      return ["bash", "-c", cropToStdout + " | " + annotationCmd + " && " + cleanup];
    case ScreenshotService.Action.Search:
      return ["bash", "-c", cropInPlace + " && xdg-open \"" + root.imageSearchEngineBaseUrl + "$(" + uploadCmd + ")\" && " + cleanup + notify("Reverse image search", "Opening in browser…")];
    case ScreenshotService.Action.CharRecognition:
      return ["bash", "-c",
        cropInPlace + " && tesseract " + escPath + " stdout -l $(tesseract --list-langs | awk 'NR>1{print $1}' | tr '\\n' '+' | sed 's/\\+$/\\n/') | wl-copy && "
        + cleanup + notify("Text recognized", "Copied to clipboard")];
    case ScreenshotService.Action.Record:
      return [root.recordScriptPath, "--region", slurpRegion];
    case ScreenshotService.Action.RecordWithSound:
      return [root.recordScriptPath, "--region", slurpRegion, "--sound"];
    }

    return [];
  }

  function captureScreenshot(width, height) {
    return ["bash", "-c",
      "mkdir -p " + root.shellEscape(root.tempDir) + " && "
      + "grim -l 1 -o \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')\" "
      + root.shellEscape(root.tempDir + "/screen-" + "$(cat /proc/sys/kernel/random/uuid)") + ".png && "
      + "echo done"];
  }
}
