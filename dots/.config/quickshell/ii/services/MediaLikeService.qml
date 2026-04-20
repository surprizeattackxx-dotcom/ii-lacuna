pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

import qs.modules.common
import qs.modules.common.functions

/**
 * Like / dislike for the active MPRIS player. There is no portable MPRIS API for this;
 * we shell out to scripts/media-like.sh (focus app + shortcuts). Extend with media-like-user.sh.
 */
Singleton {
	id: root

	readonly property bool enabled: Config.options.media.likeDislike?.enable ?? true
	property bool userHookPresent: false

	function _norm(s) {
		return (s || "").toLowerCase()
	}

	/// Returns a short id used by media-like.sh: spotify, firefox, chromium, ...
	function playerKind(player) {
		if (!player)
			return ""
		const de = root._norm(player.desktopEntry)
		const bus = root._norm(player.dbusName)
		if (de.includes("spotify") || bus.includes("spotify"))
			return "spotify"
		if (de.includes("firefox") || bus.includes("firefox"))
			return "firefox"
		if (de.includes("chromium") || bus.includes("chromium"))
			return "chromium"
		if (de.includes("google-chrome") || bus.includes("chrome"))
			return "chromium"
		if (de.includes("vivaldi") || bus.includes("vivaldi"))
			return "chromium"
		if (de.includes("microsoft-edge") || bus.includes("edge"))
			return "chromium"
		if (de.includes("opera") || bus.includes("opera"))
			return "chromium"
		if (de.includes("brave") || bus.includes("brave"))
			return "brave"
		if (de.includes("zen") || bus.includes("zen"))
			return "zen"
		if (de.includes("youtube") || bus.includes("youtube") || de.includes("ytmdesktop") || bus.includes("ytmdesktop"))
			return "youtube"
		return ""
	}

	function supportsPlayer(player) {
		if (!root.enabled || !player)
			return false
		// Spotify + browsers (see scripts/media-like.sh). Unknown players: optional media-like-user.sh.
		if (root.playerKind(player) !== "")
			return true
		return root.userHookPresent
	}

	Process {
		id: hookCheck
		running: true
		command: ["bash", "-c", "test -f \"" + Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/media-like-user.sh\""]
		onExited: (exitCode, exitStatus) => {
			root.userHookPresent = exitCode === 0
		}
	}

	function _run(action, player) {
		if (!player)
			return
		const kind = root.playerKind(player) || "unknown"
		// Must use Quickshell.shellPath("scripts/…") — Directories.scriptPath is not the same as ii/scripts on all installs.
		const script = FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/media-like.sh"))
		Quickshell.execDetached([
			"bash",
			script,
			action,
			kind,
			player.desktopEntry ?? "",
			player.dbusName ?? ""
		])
	}

	function like(player) {
		root._run("like", player)
	}

	function dislike(player) {
		root._run("dislike", player)
	}
}
