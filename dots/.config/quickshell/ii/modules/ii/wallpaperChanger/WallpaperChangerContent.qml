import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import Qt.labs.folderlistmodel
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.ii.bar
import "WindowRegistry.js" as LayoutMath

Item {
    id: root
    implicitHeight: 760
    implicitWidth: 1400

    Scaler {
        id: scaler
        currentWidth: root.implicitWidth
    }

    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }

    // Monitor the changer was opened on — preview and apply must both target
    // this, not Hyprland.focusedMonitor, which follows the mouse and can point
    // at a different monitor by the time the user commits.
    property string targetMonitor: Hyprland.focusedMonitor?.name ?? ""

    property string originalWallpaper: ""
    property string targetWallName: ""
    property bool initialFocusSet: false
    property int visibleItemCount: -1
    property int scrollAccum: 0
    property real scrollThreshold: s(300)

    property string currentFilter: "All"
    property string _lastFilter: "All"
    property string searchQuery: ""
    property bool isOnlineSearch: false
    property bool isSearchPaused: false
    property bool hasSearched: false
    property string lastSearchName: ""
    property bool searchIndexRestored: false
    property var colorMap: ({})
    property var brightnessMap: ({})
    property int cacheVersion: 0

    readonly property var _previewItem: {
        let tm = getModelForFilter(currentFilter);
        if (!tm || view.currentIndex < 0 || view.currentIndex >= tm.count) return null;
        return tm.get(view.currentIndex);
    }
    readonly property bool previewIsVideo: _previewItem ? String(_previewItem.fileName || "").startsWith("000_") : false
    readonly property bool previewIsWpe: _previewItem ? _previewItem.isWpe === true : false
    readonly property bool previewUseThumb: previewIsVideo || previewIsWpe
    readonly property string previewSource: {
        let it = _previewItem;
        if (!it) return "";
        if (previewIsWpe) return it.previewPath || "";
        if (previewIsVideo) return it.filePath || (srcDir + "/" + getCleanName(String(it.fileName || "")));
        return it.fileUrl || "";
    }
    // Plain absolute path for the live background preview (images & WPE preview images only;
    // videos don't preview as a still in the background — the coverflow card plays them).
    readonly property string previewPlainPath: {
        if (previewIsVideo) return "";
        let it = _previewItem;
        if (!it) return "";
        if (previewIsWpe) return it.previewPath || "";
        let fp = it.filePath || "";
        if (fp.length > 0) return fp;
        return String(it.fileUrl || "").replace(/^file:\/\//, "");
    }
    // Debounced: swiping through the list fires per item, and each background
    // preview costs a full-res decode + shape transition. Only preview the
    // wallpaper the user actually rests on.
    onPreviewPlainPathChanged: previewDebounce.restart()
    Timer {
        id: previewDebounce
        interval: 250
        onTriggered: {
            if (GlobalStates.wallpaperChangerOpen) {
                GlobalStates.wallpaperPreviewMonitor = root.targetMonitor;
                GlobalStates.wallpaperPreviewPath = root.previewPlainPath;
            }
        }
    }

    property bool isDownloadingWallpaper: false
    property string currentDownloadName: ""
    property bool isApplying: false
    property bool isModelChanging: false
    property bool isAiThinking: false

    property bool isScrollingBlocked: false
    property bool jumpToLastOnFilterChange: false

    property bool isStartup: false
    property bool isReady: true
    property bool isLoading: srcModel.status === FolderListModel.Loading ||
                             (currentFilter === "Search" && searchFolderModel.status === FolderListModel.Loading)

    property bool showSpinner: isDownloadingWallpaper || isAiThinking ||
                               (currentFilter === "Search" && hasSearched && !isSearchPaused) ||
                               (currentFilter !== "Search" && isLoading)

    property string currentNotification: {
        if (isAiThinking) return aiPickProc.mode === "local" ? "AI is choosing a wallpaper..." : "AI is picking a theme...";
        if (isDownloadingWallpaper) return "Downloading wallpaper...";
        if (currentFilter === "Search") {
            if (!hasSearched) return "Type something to search...";
            if (isSearchPaused) return "Search Paused";
            if (visibleItemCount === 0) return "Searching DDG (FHD+)...";
            return "Generating thumbnails...";
        }
        if (isLoading) return "Generating thumbnails...";
        if (visibleItemCount === 0) return "No wallpapers found";
        if (currentFilter === "All") return "";
        if (currentFilter === "Video") return "Videos";
        return currentFilter;
    }

    property bool showNotification: !isStartup && currentNotification !== ""

    readonly property string homeDir: "file://" + Quickshell.env("HOME")
    readonly property string thumbDir: homeDir + "/.cache/wallpaper_picker/thumbs"
    readonly property string searchDir: homeDir + "/.cache/wallpaper_picker/search_thumbs"
    property string srcDir: FileUtils.trimFileProtocol(Wallpapers.directory.toString()) || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    readonly property string moduleDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
    readonly property string wpeDir: Quickshell.env("HOME") + "/.local/share/Steam/steamapps/workshop/content/431960"
    readonly property bool wpeAvailable: wpeDiscovery.ready && wpeModel.count > 0

    readonly property var filterData: [
        { name: "All", hex: "", label: "All" },
        { name: "Video", hex: "", label: "Vid" },
        { name: "WPE", hex: "", label: "WPE" },
        { name: "Red", hex: "#FF4500", label: "" },
        { name: "Orange", hex: "#FFA500", label: "" },
        { name: "Yellow", hex: "#FFD700", label: "" },
        { name: "Green", hex: "#32CD32", label: "" },
        { name: "Blue", hex: "#1E90FF", label: "" },
        { name: "Purple", hex: "#8A2BE2", label: "" },
        { name: "Pink", hex: "#FF69B4", label: "" },
        { name: "Monochrome", hex: "#A9A9A9", label: "" },
        { name: "Light", hex: "#F5F0E8", label: "" },
        { name: "Dark", hex: "#1A1A2E", label: "" },
        { name: "Search", hex: "", label: "Search" }
    ]

    readonly property real itemWidth: s(500)
    readonly property real itemHeight: s(520)
    readonly property real borderWidth: s(3)
    readonly property real spacing: s(10)
    readonly property real skewFactor: -0.35

    Timer { id: scrollThrottle; interval: 150 }
    property bool isFilterAnimating: false
    Timer { id: filterAnimationTimer; interval: 800; onTriggered: root.isFilterAnimating = false }
    property bool isItemAnimating: false
    Timer { id: itemAnimationTimer; interval: 500; onTriggered: root.isItemAnimating = false }

    Process {
        id: wpSettingsReader
        command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                        let parsed = JSON.parse(this.text);
                        if (parsed.wallpaperDir) {
                            let dir = parsed.wallpaperDir.trim();
                            if (dir.startsWith("~/")) dir = Quickshell.env("HOME") + dir.substring(1);
                            if (dir.endsWith("/")) dir = dir.substring(0, dir.length - 1);
                            root.srcDir = dir;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    function getHexBucket(hexStr) {
        if (!hexStr) return "Monochrome";
        hexStr = String(hexStr).trim().replace(/#/g, '');
        if (hexStr.length > 6) hexStr = hexStr.substring(0, 6);
        if (hexStr.length !== 6) return "Monochrome";
        let r = parseInt(hexStr.substring(0,2), 16) / 255;
        let g = parseInt(hexStr.substring(2,4), 16) / 255;
        let b = parseInt(hexStr.substring(4,6), 16) / 255;
        if (isNaN(r) || isNaN(g) || isNaN(b)) return "Monochrome";
        let max = Math.max(r, g, b), min = Math.min(r, g, b);
        let d = max - min;
        let h = 0, sv = max === 0 ? 0 : d / max, v = max;
        if (max !== min) {
            if (max === r) { h = (g - b) / d + (g < b ? 6 : 0); }
            else if (max === g) { h = (b - r) / d + 2; }
            else { h = (r - g) / d + 4; }
            h /= 6;
        }
        h *= 360;
        if (sv < 0.05 || v < 0.08) return "Monochrome";
        if (h >= 345 || h < 15) return "Red";
        if (h >= 15 && h < 45) return "Orange";
        if (h >= 45 && h < 75) return "Yellow";
        if (h >= 75 && h < 165) return "Green";
        if (h >= 165 && h < 260) return "Blue";
        if (h >= 260 && h < 315) return "Purple";
        if (h >= 315 && h < 345) return "Pink";
        return "Monochrome";
    }

    function computeBrightness(hexStr) {
        if (!hexStr) return -1;
        hexStr = String(hexStr).trim().replace(/#/g, '');
        if (hexStr.length > 6) hexStr = hexStr.substring(0, 6);
        if (hexStr.length !== 6) return -1;
        let r = parseInt(hexStr.substring(0,2), 16) / 255;
        let g = parseInt(hexStr.substring(2,4), 16) / 255;
        let b = parseInt(hexStr.substring(4,6), 16) / 255;
        if (isNaN(r) || isNaN(g) || isNaN(b)) return -1;
        return 0.299 * r + 0.587 * g + 0.114 * b;
    }

    function checkItemMatchesFilter(fileName, isVid, isWpeItem, cv, filter) {
        if (filter === "Search") return true;
        if (filter === "All") return true;
        if (filter === "Video") return isVid;
        if (filter === "WPE") return isWpeItem;
        if (filter === "Light" || filter === "Dark") {
            let brightness = root.brightnessMap[String(fileName)];
            if (brightness === undefined) {
                let hex = root.colorMap[String(fileName)];
                brightness = hex !== undefined ? root.computeBrightness(hex) : -1;
            }
            if (brightness < 0) return false;
            return filter === "Light" ? brightness > 0.45 : brightness <= 0.45;
        }
        if (isWpeItem) return false;
        let hexColor = root.colorMap[String(fileName)];
        if (!hexColor) return filter === "Monochrome";
        return root.getHexBucket(hexColor) === filter;
    }

    FolderListModel {
        id: markerModel
        folder: "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_picker/colors_markers"
        showDirs: false; nameFilters: ["*_HEX_*"]
        onCountChanged: root.processMarkers()
        onStatusChanged: { if (status === FolderListModel.Ready) root.processMarkers() }
    }

    function processBrightnessMarkers() {
        let newMap = {};
        for (let i = 0; i < brightnessModel.count; i++) {
            let markerName = brightnessModel.get(i, "fileName") || "";
            if (!markerName) continue;
            let splitIdx = markerName.lastIndexOf("_BRIGHT_");
            if (splitIdx !== -1) {
                let val = parseFloat(markerName.substring(splitIdx + 8));
                if (!isNaN(val)) newMap[markerName.substring(0, splitIdx)] = val;
            }
        }
        root.brightnessMap = newMap;
    }

    FolderListModel {
        id: brightnessModel
        folder: "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_picker/brightness_markers"
        showDirs: false; nameFilters: ["*_BRIGHT_*"]
        onCountChanged: root.processBrightnessMarkers()
        onStatusChanged: { if (status === FolderListModel.Ready) root.processBrightnessMarkers() }
    }

    FolderListModel {
        id: srcModel
        folder: "file://" + root.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false
        onCountChanged: { if (isDownloadingWallpaper && root.isDownloaded(currentDownloadName)) isDownloadingWallpaper = false; }
    }

    Process {
        id: wpeDiscovery
        property bool ready: false
        command: ["bash", "-c", "WPE=\"" + root.wpeDir + "\"; [ -d \"$WPE\" ] || exit 0; ls \"$WPE\"/*/project.json 2>/dev/null | while read f; do d=$(dirname \"$f\"); id=$(basename \"$d\"); found=\"\"; for ext in jpg png gif jpeg webp; do for name in preview.$ext \"$id\".$ext scene.$ext; do p=\"$d/$name\"; [ -f \"$p\" ] && { found=\"$p\"; break 2; }; done; done; p=\"${found:-}\"; echo \"$id|$d|$p\"; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                wpeModel.clear()
                if (!this.text || this.text.trim().length === 0) {
                    wpeModel.ready = true
                    wpeDiscovery.ready = true
                    root.syncLocalModel()
                    return
                }
                let lines = this.text.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (!line) continue
                    let parts = line.split("|")
                    if (parts.length < 2) continue
                    let id = parts[0]
                    let dir = parts[1]
                    let preview = parts.length > 2 ? parts[2] : ""
                    wpeModel.append({ "fileName": id, "fileUrl": "file://" + dir, "filePath": dir, "isWpe": true, "previewPath": preview })
                }
                wpeModel.ready = true
                wpeDiscovery.ready = true
                try {
                    root.syncLocalModel()
                } catch (e) {
                    console.log("WPE: syncLocalModel error: " + e)
                }
            }
        }

    }

    function processMarkers() {
        let newMap = {};
        for (let i = 0; i < markerModel.count; i++) {
            let markerName = markerModel.get(i, "fileName") || "";
            if (!markerName) continue;
            let splitIdx = markerName.lastIndexOf("_HEX_");
            if (splitIdx !== -1) newMap[markerName.substring(0, splitIdx)] = "#" + markerName.substring(splitIdx + 5);
        }
        root.colorMap = newMap;
        root.cacheVersion++;
        root.updateVisibleCount();
    }

    function triggerColorExtraction() {
        let src = StringUtils.shellSingleQuoteEscape(Wallpapers.effectiveDirectory || root.srcDir);
        Quickshell.execDetached(["bash", "-c", `
            SRC='${src}'
            COLOR_DIR="$HOME/.cache/wallpaper_picker/colors_markers"
            BRIGHT_DIR="$HOME/.cache/wallpaper_picker/brightness_markers"
            CSV="$HOME/.cache/wallpaper_picker/colors.csv"
            mkdir -p "$COLOR_DIR" "$BRIGHT_DIR"
            [ -d "$SRC" ] || exit 0
            if [ -f "$CSV" ]; then
                while IFS=, read -r fname hexcode; do
                    cleanhex=$(echo "$hexcode" | tr -d '\r#' | cut -c 1-6)
                    [ -n "$cleanhex" ] && [ -n "$fname" ] && touch "$COLOR_DIR/$fname""_HEX_$cleanhex" 2>/dev/null
                done < "$CSV"
                mv "$CSV" "$CSV.bak" 2>/dev/null
            fi
            if command -v magick &> /dev/null; then CMD="magick"; else CMD="convert"; fi

            extract_one() {
                file="$1"
                filename=$(basename "$file")
                found=0
                for marker in "$COLOR_DIR/$filename"_HEX_*; do [ -e "$marker" ] && found=1 && break; done
                if [ "$found" -eq 0 ]; then
                    hex=$(nice -n 19 "$CMD" "$file" -modulate 100,200 -resize "1x1^" -gravity center -extent 1x1 -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null | grep -oiE '[0-9a-f]{6}' | head -n 1)
                    [ -n "$hex" ] && touch "$COLOR_DIR/$filename""_HEX_$hex"
                fi
                found=0
                for marker in "$BRIGHT_DIR/$filename"_BRIGHT_*; do [ -e "$marker" ] && found=1 && break; done
                if [ "$found" -eq 0 ]; then
                    bright=$(nice -n 19 "$CMD" "$file" -colorspace Gray -resize "1x1^" -gravity center -extent 1x1 -format "%[fx:mean]" info: 2>/dev/null)
                    [ -n "$bright" ] && touch "$BRIGHT_DIR/$filename""_BRIGHT_$bright"
                fi
            }
            export -f extract_one
            export COLOR_DIR BRIGHT_DIR CMD

            JOBS=$(( $(nproc) / 2 )); [ "$JOBS" -lt 2 ] && JOBS=2
            find "$SRC" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \\) -print0 | ionice -c 3 xargs -0 -r -P "$JOBS" -I {} bash -c 'extract_one "$@"' _ {}
        `]);
    }

    ListModel { id: localProxyModel }
    ListModel { id: searchProxyModel }
    ListModel {
        id: wpeModel
        property bool ready: false
    }
    readonly property var activeModel: currentFilter === "Search" ? searchProxyModel : localProxyModel

    function syncLocalModel() {
        localProxyModel.clear();
        let fm = Wallpapers.folderModel;
        for (let i = 0; i < fm.count; i++) {
            let fp = fm.get(i, "filePath");
            if (!fp) fp = FileUtils.trimFileProtocol(fm.get(i, "fileURL"));
            if (fp) {
                let fname = fp.split("/").pop() || fp;
                localProxyModel.append({ "fileName": fname, "fileUrl": "file://" + fp, "filePath": fp, "isWpe": false, "previewPath": "" });
            }
        }
        if (wpeModel.ready) {
            for (let i = 0; i < wpeModel.count; i++) {
                let item = wpeModel.get(i);
                localProxyModel.append({ "fileName": item.fileName, "fileUrl": item.fileUrl, "filePath": item.filePath, "isWpe": true, "previewPath": item.previewPath });
            }
        }
        if (currentFilter !== "Search") root.updateVisibleCount();
        if (!initialFocusSet && currentFilter !== "Search" && localProxyModel.count > 0) root.tryFocus();
    }

    Connections {
        target: Wallpapers.folderModel
        function onCountChanged() { root.syncLocalModel() }
        function onStatusChanged() {
            if (Wallpapers.folderModel.status === FolderListModel.Ready) {
                root.syncLocalModel();
                root.triggerColorExtraction();
            }
        }
    }

    FolderListModel {
        id: searchFolderModel
        folder: root.searchDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false; sortField: FolderListModel.Name
        onFolderChanged: { isModelChanging = true; searchProxyModel.clear(); isModelChanging = false; }
        onCountChanged: root.syncSearchModel()
        onStatusChanged: { if (status === FolderListModel.Ready) root.syncSearchModel() }
    }

    function syncSearchModel() {
        let startIdx = searchProxyModel.count;
        let endIdx = searchFolderModel.count;
        if (endIdx < startIdx) { isModelChanging = true; searchProxyModel.clear(); startIdx = 0; isModelChanging = false; }
        for (let i = startIdx; i < endIdx; i++) {
            let fn = searchFolderModel.get(i, "fileName");
            let fu = searchFolderModel.get(i, "fileUrl");
            if (fn !== undefined) searchProxyModel.append({ "fileName": fn, "fileUrl": String(fu) });
        }
        if (currentFilter === "Search") root.updateVisibleCount();
        if (currentFilter === "Search" && hasSearched) {
            if (!searchIndexRestored) root.trySearchFocus();
            if (isScrollingBlocked && startIdx === 0 && searchProxyModel.count > 0 && lastSearchName === "") {
                view.forceLayout(); view.currentIndex = 0; view.positionViewAtIndex(0, ListView.Center);
            }
        }
    }

    function applyWallpaper(safeFileName, isVideo, fullPath) {
        if (!safeFileName || isApplying) return;
        isApplying = true;
        targetWallName = safeFileName;

        root.setColorModeForWallpaper(safeFileName);

        if (currentFilter === "Search" && safeFileName.startsWith("ddg_")) {
            let destFile = srcDir + "/" + safeFileName;
            let mapFile = Quickshell.env("HOME") + "/.cache/wallpaper_picker/search_map.txt";
            let esc = (str) => String(str).replace(/(["\\$`])/g, '\\$1');
            searchDownloadProc.destFile = destFile;
            searchDownloadProc.command = ["bash", "-c", `
                DEST="${esc(destFile)}"; MAP="${esc(mapFile)}"; NAME="${esc(safeFileName)}"
                if [ -s "$DEST" ]; then echo OK; exit 0; fi
                URL=$(awk -F'|' -v f="$NAME" '$1 == f {print $2; exit}' "$MAP")
                [ -z "$URL" ] && exit 1
                curl -s -L -m 25 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$URL" -o "$DEST.tmp" || exit 1
                [ -s "$DEST.tmp" ] || exit 1
                if file -b --mime-type "$DEST.tmp" | grep -qi webp; then
                    magick "$DEST.tmp" "$DEST" 2>/dev/null && rm -f "$DEST.tmp" || mv "$DEST.tmp" "$DEST"
                else
                    mv "$DEST.tmp" "$DEST"
                fi
                [ -s "$DEST" ] && echo OK || exit 1
            `];
            isDownloadingWallpaper = true;
            currentDownloadName = safeFileName;
            searchDownloadProc.running = true;
            return;
        }

        let path = fullPath || (srcDir + "/" + getCleanName(safeFileName));
        if (!previewIsVideo && !previewIsWpe) {
            GlobalStates.wallpaperPreviewMonitor = root.targetMonitor;
            GlobalStates.wallpaperPreviewPath = path;
            GlobalStates.wallpaperPreviewCommitted = true;
        }
        Wallpapers.apply(path, Wallpapers.preferredDarkMode, root.targetMonitor, true);
        GlobalStates.wallpaperChangerOpen = false;
    }

    function setColorModeForWallpaper(fileName) {
        if (!fileName) return;
        let brightness = root.brightnessMap[String(fileName)];
        if (brightness === undefined) {
            let hex = root.colorMap[String(fileName)];
            brightness = hex !== undefined ? root.computeBrightness(hex) : -1;
        }
        if (brightness >= 0) {
            let newMode = brightness > 0.45 ? "light" : "dark";
            if (Config.options.appearance.colorMode !== newMode) {
                Config.options.appearance.colorMode = newMode;
                Quickshell.execDetached([Directories.darkModeToggleScriptPath, newMode]);
            }
        }
    }

    function getCleanName(name) {
        if (!name) return "";
        let clean = String(name);
        let idx = clean.lastIndexOf("/");
        if (idx !== -1) clean = clean.substring(idx + 1);
        return clean.startsWith("000_") ? clean.substring(4) : clean;
    }

    function isDownloaded(name) {
        if (!name) return false;
        for (let i = 0; i < srcModel.count; i++) if (srcModel.get(i, "fileName") === name) return true;
        return false;
    }

    function executeFocusRestore(targetIndex, isSearchRestore, requirePositioning) {
        let targetModel = getModelForFilter(currentFilter);
        if (targetIndex !== -1 && targetIndex < targetModel.count) {
            isModelChanging = true;
            if (requirePositioning) { view.forceLayout(); view.positionViewAtIndex(targetIndex, ListView.Center); }
            view.currentIndex = targetIndex;
            if (isSearchRestore) searchIndexRestored = true;
            isModelChanging = false;
            initialFocusSet = true;
        } else if (isSearchRestore) searchIndexRestored = true;
    }

    function tryFocus() {
        if (initialFocusSet || localProxyModel.count === 0) return;
        let foundIndex = -1;
        let cleanTarget = getCleanName(targetWallName);
        if (cleanTarget !== "") {
            for (let i = 0; i < localProxyModel.count; i++) {
                if (getCleanName(localProxyModel.get(i).fileName || "") === cleanTarget) { foundIndex = i; break; }
            }
        }
        executeFocusRestore(foundIndex !== -1 ? foundIndex : 0, false, true);
    }

    function trySearchFocus() {
        if (searchIndexRestored || searchProxyModel.count === 0) return;
        if (lastSearchName === "") { searchIndexRestored = true; return; }
        for (let i = 0; i < searchProxyModel.count; i++) {
            if (searchProxyModel.get(i).fileName === lastSearchName) { executeFocusRestore(i, true, true); return; }
        }
        if (searchFolderModel.status === FolderListModel.Ready && searchProxyModel.count === searchFolderModel.count) searchIndexRestored = true;
    }

    function getModelForFilter(filter) { return filter === "Search" ? searchProxyModel : localProxyModel; }

    function updateVisibleCount() {
        let targetModel = getModelForFilter(currentFilter);
        if (!targetModel || targetModel.count === 0) { visibleItemCount = 0; return; }
        let count = 0;
        for (let i = 0; i < targetModel.count; i++) {
            let item = targetModel.get(i);
            let fname = item.fileName || "";
            let isWpeItem = item.isWpe === true;
            if (checkItemMatchesFilter(fname, fname.startsWith("000_"), isWpeItem, cacheVersion, currentFilter)) count++;
        }
        visibleItemCount = count;
    }

    function stepToNextValidIndex(direction) {
        let targetModel = getModelForFilter(currentFilter);
        if (!targetModel || targetModel.count === 0) return;
        let start = view.currentIndex, found = -1;
        if (direction === 1) {
            for (let i = start + 1; i < targetModel.count; i++) {
                let item = targetModel.get(i);
                let fname = item.fileName || "";
                let isWpeItem = item.isWpe === true;
                if (checkItemMatchesFilter(fname, fname.startsWith("000_"), isWpeItem, cacheVersion, currentFilter)) { found = i; break; }
            }
        } else {
            for (let i = start - 1; i >= 0; i--) {
                let item = targetModel.get(i);
                let fname = item.fileName || "";
                let isWpeItem = item.isWpe === true;
                if (checkItemMatchesFilter(fname, fname.startsWith("000_"), isWpeItem, cacheVersion, currentFilter)) { found = i; break; }
            }
        }
        if (found !== -1) { view.currentIndex = found; return; }
        let filterOrder = ["All", "Video", "WPE", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome", "Light", "Dark"];
        let currentFilterIdx = filterOrder.indexOf(currentFilter);
        if (currentFilterIdx === -1) {
            let current = start;
            for (let i = 0; i < targetModel.count; i++) {
                current = (current + direction + targetModel.count) % targetModel.count;
                let item = targetModel.get(current);
                let fname = item.fileName || "";
                let isWpeItem = item.isWpe === true;
                if (checkItemMatchesFilter(fname, fname.startsWith("000_"), isWpeItem, cacheVersion, currentFilter)) { view.currentIndex = current; return; }
            }
            return;
        }
        let nextFilterIdx = currentFilterIdx + direction;
        if (nextFilterIdx >= 0 && nextFilterIdx < filterOrder.length) {
            jumpToLastOnFilterChange = (direction === -1);
            currentFilter = filterOrder[nextFilterIdx];
        }
    }

    function cycleFilter(direction) {
        let currentIdx = -1;
        for (let i = 0; i < filterData.length; i++) if (filterData[i].name === currentFilter) { currentIdx = i; break; }
        if (currentIdx !== -1) currentFilter = filterData[(currentIdx + direction + filterData.length) % filterData.length].name;
    }

    function applyFilters(forceSnap) {
        let targetModel = getModelForFilter(currentFilter);
        if (!targetModel || targetModel.count === 0) { updateVisibleCount(); return; }
        if (currentFilter === "Search") { updateVisibleCount(); return; }
        let firstValidIndex = -1, lastValidIndex = -1, targetIndex = -1;
        let cleanTarget = getCleanName(targetWallName);
        for (let i = 0; i < targetModel.count; i++) {
            let item = targetModel.get(i);
            let fname = item.fileName || "";
            let isVid = fname.startsWith("000_");
            let isWpeItem = item.isWpe === true;
            if (checkItemMatchesFilter(fname, isVid, isWpeItem, cacheVersion, currentFilter)) {
                if (firstValidIndex === -1) firstValidIndex = i;
                lastValidIndex = i;
                if (cleanTarget !== "" && getCleanName(fname) === cleanTarget) targetIndex = i;
            }
        }
        let indexToFocus = -1;
        if (targetIndex !== -1) indexToFocus = targetIndex;
        else if (jumpToLastOnFilterChange && lastValidIndex !== -1) indexToFocus = lastValidIndex;
        else if (firstValidIndex !== -1) indexToFocus = firstValidIndex;
        jumpToLastOnFilterChange = false;
        if (indexToFocus !== -1) executeFocusRestore(indexToFocus, false, forceSnap === true);
        updateVisibleCount();
    }

    function triggerOnlineSearch() {
        if (searchInput.text.trim() === "") return;
        isModelChanging = true; searchProxyModel.clear(); lastSearchName = "";
        if (currentFilter === "Search") { view.currentIndex = 0; view.positionViewAtIndex(0, ListView.Center); }
        isModelChanging = false; searchIndexRestored = true; isOnlineSearch = true; hasSearched = true;
        visibleItemCount = 0; searchQuery = searchInput.text.trim(); isSearchPaused = false;
        let rawSearchDir = decodeURIComponent(searchDir.replace(/^file:\/\//, ""));
        let scriptPath = decodeURIComponent(Qt.resolvedUrl("ddg_search.sh").toString().replace(/^file:\/\//, ""));
        Quickshell.execDetached(["bash", "-c", `
            exec > /tmp/qs_ddg_run.log 2>&1
            echo 'stop' > /tmp/ddg_search_control
            for p in $(pgrep -f ddg_search.sh); do [ "$p" != "$$" ] && [ "$p" != "$BASHPID" ] && kill -9 $p 2>/dev/null; done
            pkill -f "[g]et_ddg_links.py" || true; sleep 0.2
            rm -rf "${rawSearchDir}"/* || true; rm -f "${rawSearchDir}/../search_map.txt" || true
            echo 'run' > /tmp/ddg_search_control
            bash "${scriptPath}" "${searchQuery}" &
        `]);
        searchInput.focus = false; view.forceActiveFocus();
    }

    onCurrentFilterChanged: {
        isFilterAnimating = true; filterAnimationTimer.restart(); isModelChanging = true;
        let returningFromSearch = (_lastFilter === "Search" && currentFilter !== "Search");
        _lastFilter = currentFilter;
        if (returningFromSearch) searchIndexRestored = false;
        Qt.callLater(() => {
            view.forceActiveFocus();
            if (currentFilter === "Search") { if (hasSearched) { searchIndexRestored = false; trySearchFocus(); } }
            else applyFilters(returningFromSearch);
            isModelChanging = false;
        });
    }

    Shortcut { sequence: "Left"; enabled: !isScrollingBlocked && !isApplying; onActivated: stepToNextValidIndex(-1) }
    Shortcut { sequence: "Right"; enabled: !isScrollingBlocked && !isApplying; onActivated: stepToNextValidIndex(1) }
    Shortcut {
        sequence: "Return"; enabled: !searchInput.activeFocus && !isScrollingBlocked && !isApplying
        onActivated: {
            let tm = getModelForFilter(currentFilter);
            if (view.currentIndex >= 0 && view.currentIndex < tm.count) {
                let fname = tm.get(view.currentIndex).fileName;
                let fpath = tm.get(view.currentIndex).filePath || "";
                if (fname) applyWallpaper(String(fname), String(fname).startsWith("000_"), fpath || undefined);
            }
        }
    }
    Shortcut { sequence: "Escape"; enabled: !isApplying; onActivated: { if (currentFilter === "Search") currentFilter = "All"; else GlobalStates.wallpaperChangerOpen = false; } }
    Shortcut { sequence: "Tab"; enabled: !isApplying; onActivated: cycleFilter(1) }
    Shortcut { sequence: "Backtab"; enabled: !isApplying; onActivated: cycleFilter(-1) }

    ListView {
        id: view
        anchors.fill: parent
        opacity: isReady ? 1.0 : 0.0
        anchors.margins: isReady ? 0 : s(40)
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutQuart } }
        Behavior on anchors.margins { NumberAnimation { duration: 700; easing.type: Easing.OutExpo } }
        spacing: 0; orientation: ListView.Horizontal; clip: false
        interactive: !isScrollingBlocked && !isApplying; cacheBuffer: 2000
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((itemWidth * 1.5 + spacing) / 2)
        preferredHighlightEnd: (width / 2) + ((itemWidth * 1.5 + spacing) / 2)
        highlightMoveDuration: initialFocusSet ? 500 : 0; focus: true

        onCurrentIndexChanged: {
            isItemAnimating = true; itemAnimationTimer.restart();
            if (view.model !== searchProxyModel || currentFilter !== "Search") return;
            if (!isModelChanging && hasSearched && searchIndexRestored && currentIndex >= 0 && currentIndex < searchProxyModel.count) {
                let fname = searchProxyModel.get(currentIndex).fileName;
                if (fname !== undefined && fname !== "") lastSearchName = String(fname);
            }
        }

        add: Transition { enabled: initialFocusSet; ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.5; to: 1; duration: 400; easing.type: Easing.OutBack }
        }}
        addDisplaced: Transition { enabled: initialFocusSet; NumberAnimation { property: "x"; duration: 400; easing.type: Easing.OutCubic } }

        header: Item { width: Math.max(0, (view.width / 2) - ((itemWidth * 1.5) / 2)) }
        footer: Item { width: Math.max(0, (view.width / 2) - ((itemWidth * 1.5) / 2)) }
        model: activeModel

        MouseArea {
            anchors.fill: parent; acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (isScrollingBlocked || isApplying || scrollThrottle.running) { wheel.accepted = true; return; }
                let dx = wheel.angleDelta.x, dy = wheel.angleDelta.y;
                let delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;
                scrollAccum += delta;
                if (Math.abs(scrollAccum) >= scrollThreshold) { stepToNextValidIndex(scrollAccum > 0 ? -1 : 1); scrollAccum = 0; scrollThrottle.start(); }
                wheel.accepted = true;
            }
        }

        delegate: Item {
            id: delegateRoot
            readonly property string safeFileName: fileName !== undefined ? String(fileName) : ""
            readonly property string filePath: model.filePath !== undefined ? String(model.filePath) : ""
            readonly property bool isCurrent: ListView.isCurrentItem && !isScrollingBlocked
            readonly property bool isFakeSelected: isScrollingBlocked && index === 0
            readonly property bool isVisuallyEnlarged: isCurrent || isFakeSelected
            readonly property bool isVideo: safeFileName.startsWith("000_")
            readonly property bool isWpe: model.isWpe === true
            readonly property string previewPath: model.previewPath !== undefined ? String(model.previewPath) : ""
            readonly property bool matchesFilter: checkItemMatchesFilter(safeFileName, isVideo, isWpe, cacheVersion, currentFilter)
            readonly property real targetWidth: isVisuallyEnlarged ? (itemWidth * 1.5) : (itemWidth * 0.5)
            readonly property real targetHeight: isVisuallyEnlarged ? (itemHeight + s(30)) : itemHeight
            property bool isPlayingVideo: false

            Timer {
                id: videoPlayTimer; interval: 250
                running: delegateRoot.isVisuallyEnlarged && delegateRoot.isVideo && !isScrollingBlocked && !isFilterAnimating && !isItemAnimating
                onTriggered: { if (delegateRoot.isVisuallyEnlarged && delegateRoot.isVideo) { delegateRoot.isPlayingVideo = true; previewPlayer.play(); } }
            }
            onIsVisuallyEnlargedChanged: { if (!isVisuallyEnlarged) { isPlayingVideo = false; videoPlayTimer.stop(); previewPlayer.stop(); } }

            width: matchesFilter ? (targetWidth + spacing) : 0
            visible: width > 0.1 || opacity > 0.01
            opacity: matchesFilter ? 1.0 : 0.0
            scale: matchesFilter ? 1.0 : 0.5
            height: matchesFilter ? targetHeight : 0
            anchors.verticalCenter: parent?.verticalCenter ?? undefined; anchors.verticalCenterOffset: s(15)
            z: isVisuallyEnlarged ? 10 : 1

            Behavior on scale { enabled: initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            Behavior on width { enabled: initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            Behavior on height { enabled: initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            Behavior on opacity { enabled: initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

            Item {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: ((itemHeight - height) / 2) * skewFactor
                width: parent.width > 0 ? parent.width * (targetWidth / (targetWidth + spacing)) : 0
                height: parent.height
                transform: Matrix4x4 { property real sf: skewFactor; matrix: Qt.matrix4x4(1, sf, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }

                Image {
                    anchors.fill: parent
                    source: delegateRoot.isWpe ? ("file://" + delegateRoot.previewPath) : (fileUrl !== undefined ? fileUrl : "")
                    sourceSize: Qt.size(1, 1); fillMode: Image.Stretch; visible: true; asynchronous: true
                }

                Item {
                    anchors.fill: parent; anchors.margins: borderWidth
                    Rectangle { anchors.fill: parent; color: "black" }
                    clip: true

                    ThumbnailImage {
                        anchors.centerIn: parent; anchors.horizontalCenterOffset: s(-50)
                        width: (itemWidth * 1.5) + ((itemHeight + s(30)) * Math.abs(skewFactor)) + s(50)
                        height: itemHeight + s(30); fillMode: Image.PreserveAspectCrop
                        sourcePath: delegateRoot.isWpe ? (delegateRoot.previewPath || "") : (delegateRoot.filePath || FileUtils.trimFileProtocol(fileUrl || ""))
                        generateThumbnail: true
                        transform: Matrix4x4 { property real sf: -skewFactor; matrix: Qt.matrix4x4(1, sf, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    }

                    MediaPlayer {
                        id: previewPlayer
                        source: delegateRoot.isPlayingVideo ? (delegateRoot.filePath !== undefined ? delegateRoot.filePath : ("file://" + srcDir + "/" + getCleanName(delegateRoot.safeFileName))) : ""
                        audioOutput: AudioOutput { muted: true }
                        videoOutput: previewOutput
                        loops: MediaPlayer.Infinite
                    }

                    VideoOutput {
                        id: previewOutput
                        anchors.centerIn: parent; anchors.horizontalCenterOffset: s(-50)
                        width: (itemWidth * 1.5) + ((itemHeight + s(30)) * Math.abs(skewFactor)) + s(50)
                        height: itemHeight + s(30); fillMode: VideoOutput.PreserveAspectCrop
                        visible: delegateRoot.isPlayingVideo && previewPlayer.playbackState === MediaPlayer.PlayingState
                        transform: Matrix4x4 { property real sf: -skewFactor; matrix: Qt.matrix4x4(1, sf, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    }

                    Rectangle {
                        visible: delegateRoot.isVideo && (!delegateRoot.isPlayingVideo || previewPlayer.playbackState !== MediaPlayer.PlayingState)
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: s(10)
                        width: s(32); height: s(32); radius: s(6); color: "#60000000"
                        transform: Matrix4x4 { property real sf: -skewFactor; matrix: Qt.matrix4x4(1, sf, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                        Canvas {
                            renderStrategy: Canvas.Cooperative
                            anchors.fill: parent; anchors.margins: s(8)
                            property real scaleTrigger: s(1); onScaleTriggerChanged: requestPaint()
                            onPaint: { var ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = "#EEFFFFFF"; ctx.beginPath(); ctx.moveTo(s(4), 0); ctx.lineTo(s(14), s(8)); ctx.lineTo(s(4), s(16)); ctx.closePath(); ctx.fill(); }
                    }
                    Rectangle {
                        visible: delegateRoot.isWpe
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: s(10)
                        width: s(44); height: s(24); radius: s(6); color: "#C00070D0"
                        transform: Matrix4x4 { property real sf: -skewFactor; matrix: Qt.matrix4x4(1, sf, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                        Text {
                            anchors.centerIn: parent
                            text: "WPE"; font.pixelSize: s(12); font.weight: Font.Bold
                            color: "#FFFFFF"; font.letterSpacing: 0.5
                        }
                    }
                }
                }

                MouseArea {
                    anchors.fill: parent
                    z: 100
                    enabled: delegateRoot.matchesFilter && !isScrollingBlocked && !isApplying
                    onClicked: { view.currentIndex = index; applyWallpaper(delegateRoot.safeFileName, delegateRoot.isVideo, delegateRoot.filePath); }
                }
            }
        }
    }

    Rectangle {
        id: filterBarBackground
        anchors.top: parent.top; anchors.topMargin: isReady ? s(40) : s(-100)
        opacity: isReady ? 1.0 : 0.0
        Behavior on anchors.topMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter; z: 20
        height: s(56); width: filterRow.width + s(24); radius: s(14)
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.90)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.8); border.width: 1

        Row {
            id: filterRow; anchors.centerIn: parent; spacing: s(12)

            Rectangle {
                id: notifDrawer; height: s(44)
                property real paddingLeft: showSpinner ? s(40) : s(16)
                property real targetWidth: showNotification ? Math.min(notifTextDrawer.implicitWidth + paddingLeft + s(20), s(300)) : 0
                width: targetWidth; visible: width > 0.1; radius: s(10); clip: true
                color: showNotification ? Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5) : "transparent"
                border.color: showNotification ? Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8) : "transparent"; border.width: 1
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                Behavior on color { ColorAnimation { duration: 400 } }
                Behavior on border.color { ColorAnimation { duration: 400 } }

                Item { visible: showSpinner; width: s(44); height: s(44); anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    Canvas {
                        renderStrategy: Canvas.Cooperative
                        id: notifSpinner; width: s(14); height: s(14); anchors.centerIn: parent
                        property real scaleTrigger: s(1); onScaleTriggerChanged: requestPaint()
                        onPaint: { var ctx = getContext("2d"); ctx.reset(); ctx.lineWidth = s(2); ctx.strokeStyle = Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.3); ctx.beginPath(); ctx.arc(s(7), s(7), s(5), 0, Math.PI * 2); ctx.stroke(); ctx.strokeStyle = Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.9); ctx.beginPath(); ctx.arc(s(7), s(7), s(5), 0, Math.PI * 0.5); ctx.stroke(); }
                        RotationAnimation on rotation { loops: Animation.Infinite; from: 0; to: 360; duration: 800; running: showSpinner && showNotification }
                    }
                }
                Text {
                    id: notifTextDrawer; anchors.left: parent.left; anchors.leftMargin: showSpinner ? s(40) : s(16); anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, s(300) - anchors.leftMargin - s(16)); text: currentNotification
                    color: _theme.text; font.family: "JetBrains Mono"; font.pixelSize: s(14); font.bold: true; elide: Text.ElideRight
                    opacity: showNotification ? 0.9 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    Behavior on anchors.leftMargin { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                }
            }

            Repeater {
                model: filterData
                delegate: Item {
                    visible: modelData.name !== "Search"
                    width: !visible ? 0 : ((modelData.name === "Video" || modelData.name === "All") ? s(44) : (modelData.hex === "" ? filterText.contentWidth + s(24) : s(36)))
                    height: !visible ? 0 : s(36); anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent; radius: s(10)
                        color: modelData.hex === "" ? (currentFilter === modelData.name ? _theme.surface2 : "transparent") : modelData.hex
                        border.color: currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.6)
                        border.width: currentFilter === modelData.name ? s(2) : 1
                        scale: currentFilter === modelData.name ? 1.15 : (filterMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                        Text {
                            id: filterText; visible: modelData.hex === "" && modelData.name !== "Video" && modelData.name !== "All"
                            text: modelData.label; anchors.centerIn: parent
                            color: currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                            font.family: "JetBrains Mono"; font.pixelSize: s(14); font.bold: currentFilter === modelData.name
                            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
                        }
                        Canvas {
                            renderStrategy: Canvas.Cooperative
                            visible: modelData.name === "Video"; width: s(14); height: s(16); anchors.centerIn: parent; anchors.horizontalCenterOffset: s(2)
                            property string activeColor: currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                            onActiveColorChanged: requestPaint(); property real scaleTrigger: s(1); onScaleTriggerChanged: requestPaint()
                            onPaint: { var ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = activeColor; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(s(14), s(8)); ctx.lineTo(0, s(16)); ctx.closePath(); ctx.fill(); }
                        }
                        Canvas {
                            renderStrategy: Canvas.Cooperative
                            visible: modelData.name === "All"; width: s(14); height: s(14); anchors.centerIn: parent
                            property string activeColor: currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                            onActiveColorChanged: requestPaint(); property real scaleTrigger: s(1); onScaleTriggerChanged: requestPaint()
                            onPaint: { var ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = activeColor; ctx.fillRect(0, 0, s(6), s(6)); ctx.fillRect(s(8), 0, s(6), s(6)); ctx.fillRect(0, s(8), s(6), s(6)); ctx.fillRect(s(8), s(8), s(6), s(6)); }
                        }
                    }
                    MouseArea { id: filterMouse; anchors.fill: parent; hoverEnabled: true; enabled: !isApplying; onClicked: currentFilter = modelData.name; cursorShape: Qt.PointingHandCursor }
                }
            }

            Rectangle {
                id: searchControlBtn; visible: currentFilter === "Search" && hasSearched
                width: visible ? s(44) : 0; height: s(44); radius: s(10); clip: true
                color: isSearchPaused ? _theme.surface2 : "transparent"
                border.color: isSearchPaused ? _theme.text : Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.6)
                border.width: isSearchPaused ? s(2) : 1
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
                MouseArea { id: scMouse; anchors.fill: parent; hoverEnabled: true; enabled: !isApplying; cursorShape: Qt.PointingHandCursor; onClicked: isSearchPaused = !isSearchPaused }
                Canvas {
                    renderStrategy: Canvas.Cooperative
                    width: s(44); height: s(44); anchors.centerIn: parent
                    property bool paused: isSearchPaused
                    property string activeColor: paused ? _theme.text : (scMouse.containsMouse ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7))
                    onActiveColorChanged: requestPaint(); onPausedChanged: requestPaint(); property real scaleTrigger: s(1); onScaleTriggerChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = activeColor;
                        if (!paused) { ctx.fillRect(s(15), s(14), s(4), s(16)); ctx.fillRect(s(25), s(14), s(4), s(16)); }
                        else { ctx.beginPath(); ctx.moveTo(s(16), s(12)); ctx.lineTo(s(32), s(22)); ctx.lineTo(s(16), s(32)); ctx.closePath(); ctx.fill(); }
                    }
                }
            }

            Rectangle {
                id: searchBox; height: s(44)
                width: currentFilter === "Search" ? s(360) : s(44); radius: s(10); clip: true
                color: currentFilter === "Search" ? Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.8) : "transparent"
                border.color: currentFilter === "Search" ? Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.5) : Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.6)
                border.width: currentFilter === "Search" ? s(2) : 1
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
                Behavior on border.color { ColorAnimation { duration: 400 } }
                MouseArea {
                    id: searchMouseArea; anchors.fill: parent; hoverEnabled: true; enabled: !isApplying; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (currentFilter !== "Search") currentFilter = "Search"; else currentFilter = "All"; }
                }
                Canvas {
                    renderStrategy: Canvas.Cooperative
                    id: searchIcon; width: s(44); height: s(44); anchors.left: parent.left
                    anchors.leftMargin: currentFilter === "Search" ? s(5) : 0; anchors.verticalCenter: parent.verticalCenter
                    Behavior on anchors.leftMargin { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
                    property string activeColor: currentFilter === "Search" ? _theme.text : (searchMouseArea.containsMouse ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7))
                    onActiveColorChanged: requestPaint(); property real scaleTrigger: s(1); onScaleTriggerChanged: requestPaint()
                    onPaint: { var ctx = getContext("2d"); ctx.reset(); ctx.lineWidth = s(3); ctx.strokeStyle = activeColor; ctx.beginPath(); ctx.arc(s(18), s(18), s(7), 0, Math.PI * 2); ctx.stroke(); ctx.beginPath(); ctx.moveTo(s(23), s(23)); ctx.lineTo(s(31), s(31)); ctx.stroke(); }
                }
                TextInput {
                    id: searchInput; anchors.left: searchIcon.right; anchors.right: submitBtn.left; anchors.rightMargin: s(8); anchors.verticalCenter: parent.verticalCenter
                    opacity: currentFilter === "Search" ? 1.0 : 0.0; visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    color: _theme.text; font.family: "JetBrains Mono"; font.pixelSize: s(16); clip: true
                    onTextEdited: { hasSearched = false; }
                    onAccepted: { triggerOnlineSearch(); searchInput.focus = false; view.forceActiveFocus(); }
                }
                Rectangle {
                    id: submitBtn; width: s(32); height: s(32); radius: s(8)
                    anchors.right: parent.right; anchors.rightMargin: s(8); anchors.verticalCenter: parent.verticalCenter
                    opacity: currentFilter === "Search" ? 1.0 : 0.0; visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    color: submitMouseArea.containsMouse ? Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.1) : "transparent"
                    border.color: submitMouseArea.containsMouse ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.3); border.width: 1
                    Behavior on color { ColorAnimation { duration: 300 } }
                    MouseArea { id: submitMouseArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; enabled: !isApplying; onClicked: triggerOnlineSearch() }
                    Canvas {
                        renderStrategy: Canvas.Cooperative
                        width: s(16); height: s(16); anchors.centerIn: parent
                        property string activeColor: submitMouseArea.containsMouse ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                        onActiveColorChanged: requestPaint(); property real scaleTrigger: s(1); onScaleTriggerChanged: requestPaint()
                        onPaint: { var ctx = getContext("2d"); ctx.reset(); ctx.lineWidth = s(2); ctx.lineCap = "round"; ctx.lineJoin = "round"; ctx.strokeStyle = activeColor; ctx.beginPath(); ctx.moveTo(s(2), s(8)); ctx.lineTo(s(14), s(8)); ctx.moveTo(s(9), s(3)); ctx.lineTo(s(14), s(8)); ctx.lineTo(s(9), s(13)); ctx.stroke(); }
                    }
                }
            }

            Rectangle {
                id: aiBtn; width: s(44); height: s(44); radius: s(10)
                color: isAiThinking ? Qt.rgba(_theme.mauve.r, _theme.mauve.g, _theme.mauve.b, 0.35)
                       : (aiMouseArea.containsMouse ? Qt.rgba(_theme.mauve.r, _theme.mauve.g, _theme.mauve.b, 0.22) : Qt.rgba(_theme.mauve.r, _theme.mauve.g, _theme.mauve.b, 0.12))
                border.color: aiMouseArea.containsMouse || isAiThinking ? _theme.mauve : Qt.rgba(_theme.mauve.r, _theme.mauve.g, _theme.mauve.b, 0.5); border.width: 1
                Behavior on color { ColorAnimation { duration: 300 } }
                Behavior on border.color { ColorAnimation { duration: 300 } }
                MouseArea { id: aiMouseArea; anchors.fill: parent; hoverEnabled: true; enabled: !isApplying && !isAiThinking; cursorShape: Qt.PointingHandCursor; onClicked: aiPickWallpaper() }
                Canvas {
                    renderStrategy: Canvas.Cooperative
                    id: aiStar; width: s(20); height: s(20); anchors.centerIn: parent
                    property string activeColor: aiMouseArea.containsMouse || isAiThinking ? _theme.mauve : Qt.rgba(_theme.mauve.r, _theme.mauve.g, _theme.mauve.b, 0.85)
                    onActiveColorChanged: requestPaint(); property real scaleTrigger: s(1); onScaleTriggerChanged: requestPaint()
                    RotationAnimation on rotation { loops: Animation.Infinite; from: 0; to: 360; duration: 1400; running: isAiThinking }
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = activeColor;
                        function star(cx, cy, r) {
                            ctx.beginPath();
                            ctx.moveTo(cx, cy - r); ctx.quadraticCurveTo(cx, cy, cx + r, cy);
                            ctx.quadraticCurveTo(cx, cy, cx, cy + r); ctx.quadraticCurveTo(cx, cy, cx - r, cy);
                            ctx.quadraticCurveTo(cx, cy, cx, cy - r); ctx.fill();
                        }
                        star(s(8), s(8), s(6)); star(s(15), s(14), s(3.5));
                    }
                }
            }
        }
    }

    Process {
        id: searchDownloadProc
        property string destFile: ""
        onExited: (exitCode, exitStatus) => {
            isDownloadingWallpaper = false;
            currentDownloadName = "";
            if (exitCode === 0) {
                GlobalStates.wallpaperPreviewMonitor = root.targetMonitor;
                GlobalStates.wallpaperPreviewPath = searchDownloadProc.destFile;
                GlobalStates.wallpaperPreviewCommitted = true;
                Wallpapers.apply(searchDownloadProc.destFile, Wallpapers.preferredDarkMode, root.targetMonitor, true);
                GlobalStates.wallpaperChangerOpen = false;
            } else {
                isApplying = false;
            }
        }
    }

    property var aiLocalCandidates: []

    readonly property string aiModel: "opencode/deepseek-v4-flash-free"
    readonly property string aiCmdScript: `D="$HOME/.cache/wallpaper_picker/ai_scratch"
mkdir -p "$D"
cd "$D" && opencode run -m ` + aiModel + ` "$1" </dev/null 2>/dev/null`

    Timer {
        id: aiTimeout; interval: 90000
        onTriggered: { aiPickProc.running = false; isAiThinking = false; }
    }

    Process {
        id: aiPickProc
        property string mode: "search"
        stdout: StdioCollector { id: aiPickOut }
        onExited: (exitCode, exitStatus) => {
            aiTimeout.stop();
            isAiThinking = false;
            let cleaned = aiPickOut.text.replace(/\x1b\[[0-9;]*m/g, "").replace(/\x1b\][^\x07]*\x07/g, "");
            let lines = cleaned.split("\n").map(l => l.trim()).filter(l => l.length > 0 && !l.startsWith(">"));
            if (lines.length === 0) return;
            if (aiPickProc.mode === "local") {
                let last = lines.length > 0 ? lines[lines.length - 1] : "";
                let m = last.match(/\d+/);
                let idx = m ? parseInt(m[0]) : -1;
                if (idx >= 0 && idx < aiLocalCandidates.length) {
                    let c = aiLocalCandidates[idx];
                    applyWallpaper(c.fileName, c.isVideo, c.filePath);
                }
            } else {
                let q = lines.length > 0 ? lines[lines.length - 1].trim().replace(/^["'`]+|["'`]+$/g, "") : "";
                if (q.length > 0 && q.length < 60) {
                    if (currentFilter !== "Search") currentFilter = "Search";
                    searchInput.text = q;
                    triggerOnlineSearch();
                }
            }
        }
    }

    function aiPickWallpaper() {
        if (isAiThinking || isApplying) return;

        if (currentFilter === "Search") {
            isAiThinking = true;
            aiPickProc.mode = "search";
            let seed = Math.floor(Math.random() * 1000000);
            let prompt = "Pick a desktop wallpaper theme. Output ONLY one short search phrase, 2 to 4 words, lowercase, no punctuation, no quotes, nothing else. Be creative and visually striking - vary across landscapes, abstract, anime, space, cyberpunk, nature, architecture, minimal, moody art. Avoid cliches. Random seed " + seed + ".";
            aiPickProc.command = ["bash", "-c", aiCmdScript, "_", prompt];
            aiPickProc.running = true;
            aiTimeout.restart();
            return;
        }

        let cands = [];
        for (let i = 0; i < localProxyModel.count; i++) {
            let item = localProxyModel.get(i);
            let fname = item.fileName || "";
            let isVid = fname.startsWith("000_");
            let isWpeItem = item.isWpe === true;
            if (isWpeItem) continue;
            if (!checkItemMatchesFilter(fname, isVid, isWpeItem, cacheVersion, currentFilter)) continue;
            let hex = colorMap[String(fname)];
            cands.push({ fileName: fname, filePath: item.filePath || "", isVideo: isVid, color: hex ? getHexBucket(hex) : "unknown" });
        }
        if (cands.length === 0) return;
        if (cands.length === 1) { applyWallpaper(cands[0].fileName, cands[0].isVideo, cands[0].filePath); return; }

        if (cands.length > 80) {
            for (let i = cands.length - 1; i > 0; i--) { let j = Math.floor(Math.random() * (i + 1)); let t = cands[i]; cands[i] = cands[j]; cands[j] = t; }
            cands = cands.slice(0, 80);
        }
        aiLocalCandidates = cands;

        let listText = cands.map((c, i) => i + ": " + getCleanName(c.fileName) + " [" + c.color + "]").join("\n");
        let seed = Math.floor(Math.random() * 1000000);
        let prompt = "From this numbered list of desktop wallpapers (filename and dominant color), pick the ONE that would make the most striking and pleasing wallpaper for a fresh random vibe. Use the names and colors to choose something interesting and varied. Reply with ONLY the number, nothing else. Random seed " + seed + ".\n\n" + listText;
        isAiThinking = true;
        aiPickProc.mode = "local";
        aiPickProc.command = ["bash", "-c", aiCmdScript, "_", prompt];
        aiPickProc.running = true;
        aiTimeout.restart();
    }

    Component.onCompleted: {
        originalWallpaper = Config.options.background?.wallpaperPath ?? "";
        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + decodeURIComponent(searchDir.replace("file://", "")) + "'"]);
        root.syncLocalModel();
        root.forceActiveFocus();
        processMarkers();
        processBrightnessMarkers();
        triggerColorExtraction();
    }

    Component.onDestruction: {
        if (hasSearched) Quickshell.execDetached(["bash", "-c", "echo 'pause' > /tmp/ddg_search_control"]);
        else Quickshell.execDetached(["bash", "-c", "echo 'stop' > /tmp/ddg_search_control; for p in $(pgrep -f ddg_search.sh); do if [ \"$p\" != \"$$\" ] && [ \"$p\" != \"$BASHPID\" ]; then kill -9 $p 2>/dev/null || true; fi; done; pkill -f '[g]et_ddg_links.py'"]);
    }
}
