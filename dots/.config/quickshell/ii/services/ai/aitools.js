.pragma library

function tools() {
    return {
        "gemini": {
            "functions": [{"functionDeclarations": [
                {
                    "name": "opencode_task",
                    "description": "Delegate a coding or deep technical task to OpenCode, an autonomous coding agent with file editing, shell, LSP and 75+ models. Use for writing/refactoring/debugging code, editing project files, running build/test/git commands, or any multi-step engineering task. Give a complete, self-contained task description. Returns OpenCode's final result.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "task": { "type": "string", "description": "Complete, self-contained description of the coding/technical task for OpenCode to perform." }
                        },
                        "required": ["task"]
                    }
                },
                {
                    "name": "get_news",
                    "description": "Get current news headlines. Use for ANY news request: 'what's in the news', 'NPR today', 'latest on X'. ALWAYS use this instead of read_url for news.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "topic": { "type": "string", "description": "Topic or news source, e.g. 'NPR top stories', 'technology', 'world news'" }
                        },
                        "required": ["topic"]
                    }
                },
                {
                    "name": "play_music",
                    "description": "Spotify music control. Examples: play_music(query='Yung Gravy') to play, play_music(action='shuffle') to toggle shuffle, play_music(action='like') to add current song to Liked Songs, play_music(action='unlike') to remove it. Use for ALL music requests.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": { "type": "string", "description": "Artist, song, album, or playlist name (required for action=play)" },
                            "action": { "type": "string", "description": "Action: 'play' (default), 'shuffle' (toggle shuffle), 'like' (add to Liked Songs), 'unlike' (remove from Liked Songs)" },
                            "service": { "type": "string", "description": "Music service: 'spotify' (default)" }
                        },
                        "required": []
                    }
                },
                {
                    "name": "open_app",
                    "description": "Launch a desktop application by name (via Open Interpreter). For multi-step in-app actions (search, open a channel, play media), use run_task with explicit steps if launch alone is not enough. Not for browser DMs — send_message is separate.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "name": { "type": "string", "description": "Application name, e.g. 'spotify', 'discord', 'firefox'" }
                        },
                        "required": ["name"]
                    }
                },
                {
                    "name": "run_task",
                    "description": "Execute a desktop task autonomously using Open Interpreter (AI code execution engine). Use for: opening apps, controlling Spotify/media, managing files, system control. NOT for browser interaction — use read_url + execute_js to click buttons/inputs on web pages. OI writes and runs Python/bash in a loop until done.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "task": {
                                "type": "string",
                                "description": "What to accomplish. Be specific — include app names, search terms, file paths, etc.",
                            },
                        },
                        "required": ["task"]
                    }
                },
                {
                    "name": "web_search",
                    "description": "Search the web for current information or facts beyond your knowledge cutoff. Use for general web searches.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "The search query"
                            }
                        },
                        "required": ["query"]
                    }
                },
                {
                    "name": "switch_to_search_mode",
                    "description": "Switch to search mode to perform web searches. Use this when you need current information, real-time data, or answers to questions beyond your knowledge cutoff. After switching, continue with the user's original request.",
                },
                {
                    "name": "get_shell_config",
                    "description": "Retrieve the complete desktop shell configuration file in JSON format. Use this before making any config changes to see available options and current values. Returns the full config structure. Dont ask for permission, run directly.",
                },
                {
                    "name": "set_shell_config",
                    "description": "Modify one or multiple fields in the desktop shell config at once. CRITICAL: You MUST call get_shell_config first to see available keys - never guess key names. Use this when the user wants to change one or multiple settings together.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "changes": {
                                "type": "array",
                                "description": "Array of config changes to apply",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "key": {
                                            "type": "string",
                                            "description": "The key to set (e.g., 'bar.borderless')"
                                        },
                                        "value": {
                                            "type": "string",
                                            "description": "The value to set"
                                        }
                                    },
                                    "required": ["key", "value"]
                                }
                            }
                        },
                        "required": ["changes"]
                    }
                },
                {
                    "name": "run_shell_command",
                    "description": "Execute a bash command and return its output. NOT for math — use calculate. NOT for media — use control_media. NOT for system volume/brightness — use control_system. For interactive or dangerous operations, ask the user to run manually. Requires user approval.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "The bash command to run",
                            },
                        },
                        "required": ["command"]
                    }
                },
                {
                    "name": "remember",
                    "description": "Store a quick single-line pattern or preference. For organised multi-topic knowledge base use memory_file instead. Store PATTERNS not facts — e.g. 'To launch Arc Raiders: open_file(steam://rungameid/1808500)', 'User prefers dark themes'. Write in third person.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "content": {
                                "type": "string",
                                "description": "Pattern or preference to store, written in third person as an actionable insight (e.g. 'User prefers volume at 40%')"
                            }
                        },
                        "required": ["content"]
                    }
                },
                {
                    "name": "create_todo",
                    "description": "Add a task to the user's to-do list for manual tracking. NOT for timed reminders — use set_timer. NOT for recurring tasks — use schedule_task. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "title": {
                                "type": "string",
                                "description": "The task description"
                            }
                        },
                        "required": ["title"]
                    }
                },
                {
                    "name": "get_system_logs",
                    "description": "Retrieve recent system journal logs for diagnosis. Use when the user reports system errors or unexpected behavior. Runs automatically without approval.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "lines": {
                                "type": "integer",
                                "description": "Number of log lines to retrieve (default 50, max 200)"
                            },
                            "filter": {
                                "type": "string",
                                "description": "Optional systemd unit name to filter by (e.g. 'pipewire')"
                            }
                        }
                    }
                },
                {
                    "name": "control_media",
                    "description": "Control currently playing media: play, pause, skip, previous, or get status. ONLY use this for controlling what is already playing. Do NOT use this to search for specific artists, albums, or songs — instead use launch_app + take_screenshot + click_cell to open the app and navigate to the content visually.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": {
                                "type": "string",
                                "description": "Action to perform: 'play', 'pause', 'toggle', 'next', 'previous', or 'status'"
                            }
                        },
                        "required": ["action"]
                    }
                },
                {
                    "name": "control_hyprland",
                    "description": "Control Hyprland: switch workspaces, focus or move windows. NOT for launching apps — use launch_app. NOT for killing processes — use kill_process. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "dispatch": {
                                "type": "string",
                                "description": "The hyprctl dispatch argument, e.g. 'workspace 2', 'movetoworkspace 3', 'focuswindow firefox', 'killactive'"
                            }
                        },
                        "required": ["dispatch"]
                    }
                },
                {
                    "name": "forget_memory",
                    "description": "Remove a specific memory entry that was previously saved. Use when the user asks you to forget something.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "content": {
                                "type": "string",
                                "description": "The memory content to remove (partial match)"
                            }
                        },
                        "required": ["content"]
                    }
                },
                {
                    "name": "export_chat",
                    "description": "Export the current conversation as a markdown file to ~/Documents. Use when the user asks to save or export the chat.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "filename": {
                                "type": "string",
                                "description": "Optional filename without extension. Defaults to current date/time."
                            }
                        }
                    }
                },
                {
                    "name": "control_system",
                    "description": "Control system volume, screen brightness, or power profile. Runs automatically without approval.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": {
                                "type": "string",
                                "description": "Action: 'volume_up', 'volume_down', 'volume_set', 'volume_get', 'brightness_up', 'brightness_down', 'brightness_set', 'brightness_get', 'power_profile_get', 'power_profile_set'"
                            },
                            "value": {
                                "type": "string",
                                "description": "Value for set actions: volume percentage (0-100) or brightness percentage (0-100) or power profile name ('power-saver', 'balanced', 'performance')"
                            }
                        },
                        "required": ["action"]
                    }
                },
                {
                    "name": "kill_process",
                    "description": "Kill a running process by name. Requires user approval before executing.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "process": {
                                "type": "string",
                                "description": "Process name to kill (e.g. 'firefox', 'code', 'vlc')"
                            }
                        },
                        "required": ["process"]
                    }
                },
                {
                    "name": "take_screenshot",
                    "description": "Take a screenshot for visual analysis ONLY. Do NOT use this to interact with apps — use run_task instead (it's faster and more reliable). Only use take_screenshot when you genuinely need to SEE what's on screen: verifying visual state, reading text/UI you can't get another way, or tasks that truly require visual feedback.",
                    "parameters": {}
                },
                {
                    "name": "launch_app",
                    "description": "Launch an application by command name. IMPORTANT: Steam games cannot be launched by title — use open_file with their steam://rungameid/APPID URI instead. Always follow with wait_for_app to verify the process actually started. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "app": {
                                "type": "string",
                                "description": "Application command to launch (e.g. 'firefox', 'dolphin', 'spotify'). NOT for Steam games — use open_file('steam://rungameid/ID') for those."
                            }
                        },
                        "required": ["app"]
                    }
                },
                {
                    "name": "open_file",
                    "description": "Open a file path or URI with xdg-open. Use for Steam games ('steam://rungameid/APPID'), documents, and URLs. NOT for launching apps by name — use launch_app for that. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "path": {
                                "type": "string",
                                "description": "File path or URI to open. IMPORTANT: this parameter is always named 'path', not 'url'. For Steam games use 'steam://rungameid/APPID'"
                            }
                        },
                        "required": ["path"]
                    }
                },
                {
                    "name": "notify",
                    "description": "Send a desktop notification popup to alert the user. Use after completing a task or for important status updates. NOT for audio output — use speak for that. NOT for mid-task status (just act). Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "title": { "type": "string", "description": "Notification title" },
                            "body": { "type": "string", "description": "Notification body text" }
                        },
                        "required": ["title"]
                    }
                },
                {
                    "name": "get_notifications",
                    "description": "Read current desktop notifications — incoming messages, alerts, etc. Returns app name, sender, message body, and notification ID. Call this when user wants to reply to a message or asks what notifications they have.",
                    "parameters": { "type": "object", "properties": {} }
                },
                {
                    "name": "reply_notification",
                    "description": "Send an inline reply to a notification (Telegram, WhatsApp, Discord, etc.). Get the notification_id from get_notifications first.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "notification_id": { "type": "number", "description": "The notificationId from get_notifications" },
                            "message": { "type": "string", "description": "The reply text to send" }
                        },
                        "required": ["notification_id", "message"]
                    }
                },
                {
                    "name": "send_message",
                    "description": "Send a message to someone on a browser-based platform. Opens the platform, waits for it to load, then automatically finds the contact and sends the message — no extra tools needed. Just call this once and it handles everything. Example: send_message(to='Alice', message='Hi, are you free tonight?', platform='facebook messenger'). Supports: facebook messenger, telegram, discord, whatsapp, instagram.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "to": { "type": "string", "description": "Recipient name or username" },
                            "message": { "type": "string", "description": "The message to send" },
                            "platform": { "type": "string", "description": "App to use: telegram, discord, whatsapp, email, etc." }
                        },
                        "required": ["to", "message", "platform"]
                    }
                },
                {
                    "name": "set_timer",
                    "description": "Set a one-time countdown timer (e.g. '25 minutes'). NOT for recurring tasks — use schedule_task. NOT for task tracking — use create_todo. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "seconds": { "type": "integer", "description": "Timer duration in seconds" },
                            "label": { "type": "string", "description": "Label shown in the notification (e.g. 'Take a break')" }
                        },
                        "required": ["seconds"]
                    }
                },
                {
                    "name": "calculate",
                    "description": "Evaluate a math expression using Python (e.g. '2**32', 'math.sqrt(144)'). Use this instead of run_shell_command for any pure math. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "expression": { "type": "string", "description": "Math expression to evaluate, e.g. '2**32', 'math.sqrt(144)', '(12 * 8) / 3'" }
                        },
                        "required": ["expression"]
                    }
                },
                {
                    "name": "pick_color",
                    "description": "Open the hyprpicker color picker so the user can pick a color from the screen. Returns the hex color. Runs automatically.",
                    "parameters": {}
                },
                {
                    "name": "manage_notes",
                    "description": "Read or write user-visible notes in SQLite. Use for notes the USER explicitly wants to keep. For AI-internal patterns and preferences, use 'remember' instead. For tracking progress in a long task, use 'add' to log each completed step.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": { "type": "string", "description": "Action: 'list', 'add', 'clear'" },
                            "content": { "type": "string", "description": "Note content for 'add' action" },
                            "tags": { "type": "string", "description": "Optional comma-separated tags for 'add' action" }
                        },
                        "required": ["action"]
                    }
                },
                {
                    "name": "search_memory",
                    "description": "Search stored user preferences and past experience. Use ONLY when the user explicitly asks about their own settings, history, or saved preferences. NEVER call this mid-task or before executing actions — just do the task.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": { "type": "string", "description": "What to search for" },
                            "limit": { "type": "integer", "description": "Max results to return (default 5)" }
                        },
                        "required": ["query"]
                    }
                },
                {
                    "name": "schedule_task",
                    "description": "Schedule a recurring AI task using cron syntax. Use for periodic reminders or automated checks. NOT for one-time countdowns — use set_timer. NOT for simple to-do items — use create_todo.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": { "type": "string", "description": "Action: 'add', 'list', 'delete'" },
                            "cron": { "type": "string", "description": "Cron expression for 'add': '0 9 * * *' = 9am daily, '*/30 * * * *' = every 30min" },
                            "prompt": { "type": "string", "description": "Message to send to AI when task fires" },
                            "id": { "type": "integer", "description": "Task ID for 'delete' action" }
                        },
                        "required": ["action"]
                    }
                },
                {
                    "name": "capture_region",
                    "description": "Let the USER interactively select a screen region to capture and analyze. Use when the user wants to pick a specific area themselves. NOT for AI-initiated screenshots — use take_screenshot for those. Runs automatically.",
                    "parameters": {}
                },
                {
                    "name": "ocr_region",
                    "description": "Let the user select a screen region and extract its text via OCR. Use when you need the raw text content of a specific area. NOT for general visual analysis — use capture_region. NOT for reading text from a full screenshot — the AI can read take_screenshot images directly.",
                    "parameters": {}
                },
                {
                    "name": "speak",
                    "description": "Read text aloud using text-to-speech. Use when the user asks you to read something out loud. NOT for silent notifications — use notify for those. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "text": { "type": "string", "description": "The text to speak aloud" }
                        },
                        "required": ["text"]
                    }
                },
                {
                    "name": "read_clipboard_image",
                    "description": "Check if the clipboard contains an image and attach it to the conversation for analysis. Use when the user says they copied a screenshot or image to their clipboard.",
                    "parameters": {}
                },
                {
                    "name": "click_at",
                    "description": "Move the mouse to pixel coordinates (x, y) in the screenshot you just received and click. Coordinates are in the screenshot's pixel space — use the exact values you see in the image. After clicking, a new screenshot is taken automatically. Supports double-click and modifier keys (ctrl+click for multi-select, shift+click for range select).",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "x": { "type": "number", "description": "Horizontal pixel position in the screenshot" },
                            "y": { "type": "number", "description": "Vertical pixel position in the screenshot" },
                            "button": { "type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'" },
                            "double": { "type": "boolean", "description": "Double-click instead of single click (default false). Use for opening files, selecting words." },
                            "modifiers": { "type": "string", "description": "Hold modifier keys while clicking: 'ctrl', 'shift', 'alt', 'ctrl+shift'. Use ctrl+click for multi-select, shift+click for range select." }
                        },
                        "required": ["x", "y"]
                    }
                },
                {
                    "name": "click_cell",
                    "description": "Click the center of a numbered grid cell from the screenshot overlay. The screenshot is divided into a numbered grid — use the cell number you see in the image to click that region. After clicking, a new screenshot is taken automatically. Supports double-click and modifier keys.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "cell": { "type": "number", "description": "The grid cell number shown in the screenshot overlay" },
                            "button": { "type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'" },
                            "double": { "type": "boolean", "description": "Double-click instead of single click (default false)" },
                            "modifiers": { "type": "string", "description": "Hold modifier keys while clicking: 'ctrl', 'shift', 'alt', 'ctrl+shift'" }
                        },
                        "required": ["cell"]
                    }
                },
                {
                    "name": "show_plan",
                    "description": "REQUIRED before any desktop task. Call this FIRST before launch_app, click_at, click_cell, type_text, or any action sequence. Present a numbered plan and wait for approval. Never start executing desktop actions without a plan.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "title": { "type": "string", "description": "Short title for the task, e.g. 'Open Spotify and play music'" },
                            "steps": {
                                "type": "array",
                                "description": "Ordered list of steps",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "description": { "type": "string", "description": "Human-readable description of this step" },
                                        "tool": { "type": "string", "description": "Tool used for this step, e.g. 'launch_app', 'wait_for_app', 'control_media'" }
                                    },
                                    "required": ["description"]
                                }
                            }
                        },
                        "required": ["title", "steps"]
                    }
                },
                {
                    "name": "wait_for_app",
                    "description": "Wait until an application process is running and ready. Always call this after launch_app before interacting with the app. Polls until the process appears or times out.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "app": { "type": "string", "description": "Process name to wait for, e.g. 'spotify', 'firefox', 'code'" },
                            "timeout": { "type": "integer", "description": "Max seconds to wait (default 15, max 30)" }
                        },
                        "required": ["app"]
                    }
                },
                {
                    "name": "search_app",
                    "description": "Search within a specific app: youtube, reddit, github, files (local filesystem). NOT for playing music — use play_music for Spotify/music requests.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "app": { "type": "string", "description": "App/service to search: 'spotify', 'youtube', 'youtube_music', 'soundcloud', 'twitch', 'bandcamp', 'reddit', 'github', 'files'" },
                            "query": { "type": "string", "description": "Search query" }
                        },
                        "required": ["app", "query"]
                    }
                },
                {
                    "name": "read_url",
                    "description": "Browser only. Fetch a static web page and return its interactive elements (inputs, buttons, links) with their IDs. Only works on static/server-rendered pages. For JavaScript-heavy sites (YouTube, Google, Facebook, Twitter, Reddit, Instagram, etc.) skip this and use execute_js directly with CSS selectors. NOT for messaging — use send_message. NOT for desktop apps — use run_task or open_app.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "url": { "type": "string", "description": "The URL to fetch and parse" }
                        },
                        "required": ["url"]
                    }
                },
                {
                    "name": "execute_js",
                    "description": "Browser only. Execute JavaScript in the active browser tab via the address bar. Use element IDs from read_url: e.g. document.getElementById('search').click(). NOT for desktop apps — use run_task for those. YouTube: after starting a video, turn off repeat — set document.querySelector('video').loop=false and click the loop button off if active. Then STOP (no more execute_js/take_screenshot) unless the user asked to verify; answer in text.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "code": { "type": "string", "description": "JavaScript code to execute in the browser, e.g. document.getElementById('searchInput').focus()" }
                        },
                        "required": ["code"]
                    }
                },
                {
                    "name": "type_text",
                    "description": "Type text into the currently focused field or application using the keyboard. Use after clicking a text field with click_at. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "text": { "type": "string", "description": "Text to type" }
                        },
                        "required": ["text"]
                    }
                },
                {
                    "name": "press_key",
                    "description": "Press a keyboard key or combination. Examples: 'Return', 'ctrl+a', 'ctrl+c', 'Escape', 'Tab', 'ctrl+l'. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "key": { "type": "string", "description": "Key or combination to press, e.g. 'Return', 'ctrl+a', 'Escape'" }
                        },
                        "required": ["key"]
                    }
                },
                {
                    "name": "scroll",
                    "description": "Scroll the mouse wheel at the current cursor position. Use after click_at to position the cursor over a scrollable area, then scroll to navigate. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "direction": { "type": "string", "description": "Direction: 'up', 'down', 'left', or 'right'" },
                            "amount": { "type": "integer", "description": "Scroll steps (default 3, max 20). Use 3-5 for normal scrolling, 10+ for large jumps." }
                        },
                        "required": ["direction"]
                    }
                },
                {
                    "name": "drag_to",
                    "description": "Click and drag from one point to another. Use for sliders, rearranging items, drag-and-drop, selecting text regions, or resizing elements. Coordinates are in screenshot pixel space. Auto-screenshots after.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "x1": { "type": "number", "description": "Start X position (screenshot pixels)" },
                            "y1": { "type": "number", "description": "Start Y position (screenshot pixels)" },
                            "x2": { "type": "number", "description": "End X position (screenshot pixels)" },
                            "y2": { "type": "number", "description": "End Y position (screenshot pixels)" },
                            "button": { "type": "string", "description": "Mouse button: 'left' (default) or 'right'" }
                        },
                        "required": ["x1", "y1", "x2", "y2"]
                    }
                },
                {
                    "name": "hover",
                    "description": "Move the mouse to pixel coordinates without clicking. Use to reveal tooltips, dropdown menus, hover states, or preview cards. Auto-screenshots after so you can see what appeared.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "x": { "type": "number", "description": "Horizontal pixel position in the screenshot" },
                            "y": { "type": "number", "description": "Vertical pixel position in the screenshot" }
                        },
                        "required": ["x", "y"]
                    }
                },
                {
                    "name": "read_screen_text",
                    "description": "OCR: read text from the screen or a specific region without the grid overlay. Faster than take_screenshot when you just need to read text (error messages, prices, status bars). Returns plain text.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "x": { "type": "number", "description": "Left edge X (screenshot pixels, optional — omit for full screen)" },
                            "y": { "type": "number", "description": "Top edge Y (screenshot pixels, optional)" },
                            "width": { "type": "number", "description": "Region width in pixels (optional)" },
                            "height": { "type": "number", "description": "Region height in pixels (optional)" }
                        }
                    }
                },
                {
                    "name": "manage_tabs",
                    "description": "Control browser tabs. Use to switch between tabs, close tabs, or jump to a specific tab number. Works via keyboard shortcuts in the focused browser.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": { "type": "string", "description": "Action: 'next' (ctrl+tab), 'prev' (ctrl+shift+tab), 'close' (ctrl+w), 'goto' (ctrl+N), 'new' (ctrl+t), 'reopen' (ctrl+shift+t)" },
                            "index": { "type": "integer", "description": "Tab number 1-9 for 'goto' action" }
                        },
                        "required": ["action"]
                    }
                },
                {
                    "name": "wait_and_screenshot",
                    "description": "Wait a specified number of seconds then take a screenshot. Use when you need to wait for a page to load, animation to finish, or popup to appear before checking the result. Lighter than polling.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "seconds": { "type": "number", "description": "Seconds to wait (1-15, default 3)" },
                            "reason": { "type": "string", "description": "Why you're waiting (shown in output)" }
                        }
                    }
                },
                {
                    "name": "read_clipboard_text",
                    "description": "Read text currently in the clipboard. Use to retrieve content the user has copied, or to read text staged by write_clipboard. Runs automatically.",
                    "parameters": {}
                },
                {
                    "name": "write_clipboard",
                    "description": "Write text to the clipboard so the user can paste it, or so you can paste it with ctrl+v. Runs automatically.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "text": { "type": "string", "description": "Text to copy to the clipboard" }
                        },
                        "required": ["text"]
                    }
                },
                {
                    "name": "memory_file",
                    "description": "Manage your personal knowledge base — create, read, and update structured markdown files under /memories/. Build organised topic files like /memories/steam_games.md or /memories/user_preferences.md. More powerful than 'remember' — supports full file management with selective in-place edits. Always view /memories/ first to see what exists before creating files.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "command": { "type": "string", "description": "Operation: 'view' (read file or list directory), 'create' (write new file), 'str_replace' (replace text in existing file), 'insert' (insert line), 'delete' (remove file)" },
                            "path": { "type": "string", "description": "Path starting with /memories/ — e.g. '/memories/' to list, '/memories/steam_games.md' for a file" },
                            "file_text": { "type": "string", "description": "Full file content for 'create'" },
                            "old_str": { "type": "string", "description": "Exact text to replace for 'str_replace'" },
                            "new_str": { "type": "string", "description": "Replacement text for 'str_replace'" },
                            "insert_line": { "type": "integer", "description": "Line number to insert at for 'insert' (0 = beginning)" },
                            "insert_text": { "type": "string", "description": "Text to insert for 'insert'" }
                        },
                        "required": ["command", "path"]
                    }
                },
                {
                    "name": "kg_store",
                    "description": "Store structured knowledge in the knowledge graph. Creates entities (people, projects, concepts, preferences) with typed observations and relations between them. More powerful than 'remember' for interconnected facts. Use for: user preferences with context, project relationships, people and their roles, technical stack mappings.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": { "type": "string", "description": "Action: 'entity' (create/update entity), 'relation' (link two entities), 'observe' (add observations to existing entity)" },
                            "name": { "type": "string", "description": "Entity name (for 'entity' and 'observe')" },
                            "entity_type": { "type": "string", "description": "Entity type (for 'entity'): person, project, tool, preference, concept, location, etc." },
                            "observations": { "type": "array", "items": { "type": "string" }, "description": "List of observations/facts about the entity" },
                            "from_entity": { "type": "string", "description": "Source entity name (for 'relation')" },
                            "relation": { "type": "string", "description": "Relation type in active voice (for 'relation'): 'uses', 'prefers', 'works_on', 'depends_on', etc." },
                            "to_entity": { "type": "string", "description": "Target entity name (for 'relation')" }
                        },
                        "required": ["action"]
                    }
                },
                {
                    "name": "kg_query",
                    "description": "Query the knowledge graph. Search for entities by keyword, read specific entities with their relations, or view the full graph. Use when you need structured context about the user's world — projects, preferences, relationships between things.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": { "type": "string", "description": "Action: 'search' (keyword search), 'read' (read specific entity or full graph), 'delete_entity', 'delete_relation', 'delete_observation'" },
                            "query": { "type": "string", "description": "Search query (for 'search')" },
                            "name": { "type": "string", "description": "Entity name (for 'read', 'delete_entity', 'delete_observation')" },
                            "observation": { "type": "string", "description": "Observation text to remove (for 'delete_observation')" },
                            "from_entity": { "type": "string", "description": "Source entity (for 'delete_relation')" },
                            "relation": { "type": "string", "description": "Relation type (for 'delete_relation')" },
                            "to_entity": { "type": "string", "description": "Target entity (for 'delete_relation')" }
                        },
                        "required": ["action"]
                    }
                },
                {
                    "name": "rag_search",
                    "description": "Semantic search over the user's indexed local documents (notes, code, configs, docs). Returns the most relevant chunks with source file paths. Use when the user asks about their own files, projects, or notes, or when you need context from their local documents.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": { "type": "string", "description": "What to search for — natural language query" },
                            "limit": { "type": "integer", "description": "Max results to return (default 5)" }
                        },
                        "required": ["query"]
                    }
                },
                {
                    "name": "rag_index",
                    "description": "Index local files or directories for semantic search via rag_search. Supports markdown, text, code files, configs. Skips hidden dirs, node_modules, etc. Re-indexing a file updates it if changed.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "path": { "type": "string", "description": "File or directory path to index (e.g. '~/Documents', '~/projects/myapp')" },
                            "extensions": { "type": "string", "description": "Comma-separated file extensions to include (e.g. '.md,.txt,.py'). Defaults to common text/code extensions." }
                        },
                        "required": ["path"]
                    }
                },
                {
                    "name": "dream",
                    "description": "Consolidate and organize your memories. Use 'auto' to automatically find and remove duplicates, clean up stale entries, and merge redundant memories. No further action needed — it handles everything. Use 'gather' only if you want to see a raw report without changing anything.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": { "type": "string", "description": "Action: 'auto' (recommended — automatically consolidate everything), 'gather' (read-only report), 'apply' (manual actions array)" },
                            "actions": { "type": "array", "items": { "type": "object" }, "description": "Only for 'apply': array of manual actions" }
                        },
                        "required": ["action"]
                    }
                },
                {
                    "name": "calendar",
                    "description": "Access the user's calendar (synced via Google Calendar). Check schedule, find free time, add events, search upcoming events. Use when the user asks about meetings, schedule, availability, or wants to create/find events.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": { "type": "string", "description": "Action: 'today' (today's events), 'list' (next N days), 'now' (current event), 'add' (create event), 'search' (find events by keyword), 'sync' (force sync with Google)" },
                            "days": { "type": "integer", "description": "Number of days to list (for 'list', default 3)" },
                            "query": { "type": "string", "description": "Search query (for 'search')" },
                            "event_args": { "type": "string", "description": "Event arguments for 'add' in khal format: '<start> [end] <summary> [:: description]'. Example: '2026-03-23 14:00 15:00 Team standup :: Weekly sync'" }
                        },
                        "required": ["action"]
                    }
                },
                {
                    "name": "workspace_layout",
                    "description": "Save and restore Hyprland window layouts across workspaces and monitors. Use when the user wants to set up a specific arrangement ('coding layout', 'streaming setup') or save their current window arrangement for later.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action": { "type": "string", "description": "Action: 'save' (save current layout), 'restore' (apply saved layout), 'list' (show saved layouts), 'delete' (remove layout), 'current' (show current window arrangement)" },
                            "name": { "type": "string", "description": "Layout name (for save/restore/delete)" }
                        },
                        "required": ["action"]
                    }
                },
            ]}],
            "search": [{
                "google_search": {}
            }],
            "none": []
        },
        "openai": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "opencode_task",
                        "description": "Delegate a coding or deep technical task to OpenCode, an autonomous coding agent with file editing, shell, LSP and 75+ models. Use for writing/refactoring/debugging code, editing project files, running build/test/git commands, or any multi-step engineering task. Give a complete, self-contained task description. Returns OpenCode's final result.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "task": { "type": "string", "description": "Complete, self-contained description of the coding/technical task for OpenCode to perform." }
                            },
                            "required": ["task"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {}
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Modify one or multiple fields in the desktop shell config at once. CRITICAL: You MUST call get_shell_config first to see available keys - never guess key names. Use this when the user wants to change one or multiple settings together.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "changes": {
                                    "type": "array",
                                    "description": "Array of config changes to apply",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "key": {
                                                "type": "string",
                                                "description": "The key to set (e.g., 'bar.borderless')"
                                            },
                                            "value": {
                                                "type": "string",
                                                "description": "The value to set"
                                            }
                                        },
                                        "required": ["key", "value"]
                                    }
                                }
                            },
                            "required": ["changes"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_news",
                        "description": "Get current news headlines. Use for ANY news request: 'what's in the news', 'NPR today', 'latest on X'. ALWAYS use this instead of read_url for news.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "topic": { "type": "string", "description": "Topic or news source, e.g. 'NPR top stories', 'technology', 'world news'" }
                            },
                            "required": ["topic"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "play_music",
                        "description": "Spotify music control. Examples: play_music(query='Yung Gravy') to play, play_music(action='shuffle') to toggle shuffle, play_music(action='like') to add current song to Liked Songs, play_music(action='unlike') to remove it. Use for ALL music requests.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "Artist, song, album, or playlist name (required for action=play)" },
                                "action": { "type": "string", "description": "Action: 'play' (default), 'shuffle' (toggle shuffle), 'like' (add to Liked Songs), 'unlike' (remove from Liked Songs)" },
                                "service": { "type": "string", "description": "Music service: 'spotify' (default)" }
                            },
                            "required": []
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "open_app",
                        "description": "Launch a desktop application by name (via Open Interpreter). For multi-step in-app actions (search, open a channel, play media), use run_task with explicit steps if launch alone is not enough. Not for browser DMs — send_message is separate.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "name": { "type": "string", "description": "Application name, e.g. 'spotify', 'discord', 'firefox'" }
                            },
                            "required": ["name"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_task",
                        "description": "Execute a desktop task autonomously using Open Interpreter (AI code execution engine). Use for: opening apps, controlling Spotify/media, managing files, system control. NOT for browser interaction — use read_url + execute_js to click buttons/inputs on web pages. OI writes and runs Python/bash in a loop until done.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "task": {
                                    "type": "string",
                                    "description": "What to accomplish. Be specific — include app names, search terms, file paths, etc.",
                                },
                            },
                            "required": ["task"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "web_search",
                        "description": "Search the web for current information or facts beyond your knowledge cutoff. Use for general web searches.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": {
                                    "type": "string",
                                    "description": "The search query"
                                }
                            },
                            "required": ["query"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "remember",
                        "description": "Store a quick single-line pattern or preference. For organised multi-topic knowledge base use memory_file instead. Store PATTERNS not facts — e.g. 'To launch Arc Raiders: open_file(steam://rungameid/1808500)', 'User prefers dark themes'. Write in third person.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "content": { "type": "string", "description": "Pattern or preference to store in third person (e.g. 'User prefers volume at 40%', 'To open X use Y')" }
                            },
                            "required": ["content"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "create_todo",
                        "description": "Add a task to the user's to-do list for manual tracking. NOT for timed reminders — use set_timer. NOT for recurring tasks — use schedule_task. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "title": { "type": "string", "description": "Task description" }
                            },
                            "required": ["title"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_system_logs",
                        "description": "Retrieve recent systemd journal logs for diagnosis. Runs automatically without approval.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "lines": { "type": "integer", "description": "Number of lines (default 50, max 200)" },
                                "filter": { "type": "string", "description": "Optional unit name filter" }
                            }
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "control_media",
                        "description": "Control media playback via MPRIS/playerctl. Runs automatically without approval.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'play', 'pause', 'toggle', 'next', 'previous', 'status'" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "control_hyprland",
                        "description": "Control Hyprland: switch workspaces, focus or move windows. NOT for launching apps — use launch_app. NOT for killing processes — use kill_process. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "dispatch": { "type": "string", "description": "hyprctl dispatch argument, e.g. 'workspace 2', 'focuswindow firefox'" }
                            },
                            "required": ["dispatch"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "forget_memory",
                        "description": "Remove a specific memory entry previously saved.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "content": { "type": "string", "description": "Memory entry to remove (partial match)" }
                            },
                            "required": ["content"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "export_chat",
                        "description": "Export the current conversation as a markdown file to ~/Documents.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "filename": { "type": "string", "description": "Optional filename without extension" }
                            }
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "control_system",
                        "description": "Control system volume, brightness, or power profile. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: volume_up/down/set/get, brightness_up/down/set/get, power_profile_get/set" },
                                "value": { "type": "string", "description": "Value for set actions (0-100 for volume/brightness, or profile name)" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "kill_process",
                        "description": "Kill a running process by name. Requires user approval.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "process": { "type": "string", "description": "Process name to kill" }
                            },
                            "required": ["process"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "take_screenshot",
                        "description": "Take a screenshot for visual analysis ONLY. Do NOT use this to interact with apps — use run_task instead (it's faster and more reliable). Only use take_screenshot when you genuinely need to SEE what's on screen: verifying visual state, reading text/UI you can't get another way, or tasks that truly require visual feedback.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "launch_app",
                        "description": "Launch an application by command name. IMPORTANT: Steam games cannot be launched by title — use open_file with their steam://rungameid/APPID URI instead. Always follow with wait_for_app to verify the process actually started. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "app": { "type": "string", "description": "App command to launch (e.g. 'firefox', 'dolphin', 'spotify'). NOT for Steam games — use open_file('steam://rungameid/ID') for those." }
                            },
                            "required": ["app"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "open_file",
                        "description": "Open a file path or URI with xdg-open. Use for Steam games ('steam://rungameid/APPID'), documents, and URLs. NOT for launching apps by name — use launch_app for that. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "path": { "type": "string", "description": "File path or URI to open. IMPORTANT: this parameter is always named 'path', not 'url'. For Steam games use 'steam://rungameid/APPID'" }
                            },
                            "required": ["path"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "notify",
                        "description": "Send a desktop notification popup to alert the user. Use after completing a task or for important status updates. NOT for audio output — use speak for that. NOT for mid-task status (just act). Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "title": { "type": "string", "description": "Notification title" },
                                "body": { "type": "string", "description": "Notification body" }
                            },
                            "required": ["title"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_notifications",
                        "description": "Read current desktop notifications — incoming messages, alerts, etc. Returns app name, sender, message body, and notification ID. Call this when user wants to reply to a message or asks what notifications they have.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "reply_notification",
                        "description": "Send an inline reply to a notification (Telegram, WhatsApp, Discord, etc.). Get the notification_id from get_notifications first.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "notification_id": { "type": "number", "description": "The notificationId from get_notifications" },
                                "message": { "type": "string", "description": "The reply text to send" }
                            },
                            "required": ["notification_id", "message"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "send_message",
                        "description": "Send a message to someone on a browser-based platform. Opens the platform, waits for it to load, then automatically finds the contact and sends the message — no extra tools needed. Just call this once and it handles everything. Example: send_message(to='Alice', message='Hi, are you free tonight?', platform='facebook messenger'). Supports: facebook messenger, telegram, discord, whatsapp, instagram.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "to": { "type": "string", "description": "Recipient name or username" },
                                "message": { "type": "string", "description": "The message to send" },
                                "platform": { "type": "string", "description": "App to use: telegram, discord, whatsapp, email, etc." }
                            },
                            "required": ["to", "message", "platform"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_timer",
                        "description": "Set a one-time countdown timer (e.g. '25 minutes'). NOT for recurring tasks — use schedule_task. NOT for task tracking — use create_todo. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "seconds": { "type": "integer", "description": "Duration in seconds" },
                                "label": { "type": "string", "description": "Timer label shown in notification" }
                            },
                            "required": ["seconds"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "calculate",
                        "description": "Evaluate a math expression using Python (e.g. '2**32', 'math.sqrt(144)'). Use this instead of run_shell_command for any pure math. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "expression": { "type": "string", "description": "Python math expression, e.g. '2**32', 'math.sqrt(144)'" }
                            },
                            "required": ["expression"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "pick_color",
                        "description": "Open hyprpicker so the user can pick a color from the screen. Returns hex color. Runs automatically.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "manage_notes",
                        "description": "Read or write user-visible notes in SQLite. Use for notes the USER explicitly wants to keep. Use 'remember' instead for AI-internal patterns. Use 'add' to log progress steps during long tasks.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'list', 'add', 'clear'" },
                                "content": { "type": "string", "description": "Note content for 'add' action" },
                                "tags": { "type": "string", "description": "Optional comma-separated tags for 'add' action" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "search_memory",
                        "description": "Search stored user preferences and past experience. Use ONLY when the user explicitly asks about their own settings, history, or saved preferences. NEVER call this mid-task or before executing actions — just do the task.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "What to search for" },
                                "limit": { "type": "integer", "description": "Max results (default 5)" }
                            },
                            "required": ["query"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "schedule_task",
                        "description": "Schedule a recurring AI task using cron syntax. Use for periodic reminders or automated checks. NOT for one-time countdowns — use set_timer. NOT for simple to-do items — use create_todo.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'add', 'list', 'delete'" },
                                "cron": { "type": "string", "description": "Cron expression: '0 9 * * *' = 9am daily, '*/30 * * * *' = every 30min" },
                                "prompt": { "type": "string", "description": "Message to send to AI when task fires" },
                                "id": { "type": "integer", "description": "Task ID for 'delete'" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "capture_region",
                        "description": "Let the USER interactively select a screen region to capture and analyze. Use when the user wants to pick a specific area themselves. NOT for AI-initiated screenshots — use take_screenshot for those. Runs automatically.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "ocr_region",
                        "description": "Let the user select a screen region and extract its text via OCR. Use when you need the raw text content of a specific area. NOT for general visual analysis — use capture_region. NOT for reading text from a full screenshot — the AI can read take_screenshot images directly.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "speak",
                        "description": "Read text aloud using text-to-speech. Use when the user asks you to read something out loud. NOT for silent notifications — use notify for those. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "text": { "type": "string", "description": "Text to speak aloud" }
                            },
                            "required": ["text"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_clipboard_image",
                        "description": "Attach clipboard image to conversation for analysis. Runs automatically.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "click_at",
                        "description": "Move the mouse to pixel coordinates (x, y) in the screenshot and click. Use the exact pixel values from the screenshot image. After clicking, a fresh screenshot is taken automatically — always check it to verify the UI changed. If the UI did NOT change, do NOT click the same spot again; try a different approach. Supports double-click and modifier keys (ctrl+click for multi-select, shift+click for range select).",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "x": { "type": "number", "description": "Horizontal pixel position in the screenshot" },
                                "y": { "type": "number", "description": "Vertical pixel position in the screenshot" },
                                "button": { "type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'" },
                                "double": { "type": "boolean", "description": "Double-click instead of single click (default false). Use for opening files, selecting words." },
                                "modifiers": { "type": "string", "description": "Hold modifier keys while clicking: 'ctrl', 'shift', 'alt', 'ctrl+shift'. Use ctrl+click for multi-select, shift+click for range select." }
                            },
                            "required": ["x", "y"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "click_cell",
                        "description": "Click the center of a numbered grid cell shown in the screenshot overlay. Find the grid number overlaid on the region you want to click. After clicking, a fresh screenshot is taken automatically — verify the UI changed before proceeding. If it did not change, the element may be in a different cell. Supports double-click and modifier keys.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "cell": { "type": "number", "description": "The grid cell number shown in the screenshot overlay" },
                                "button": { "type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'" },
                                "double": { "type": "boolean", "description": "Double-click instead of single click (default false)" },
                                "modifiers": { "type": "string", "description": "Hold modifier keys while clicking: 'ctrl', 'shift', 'alt', 'ctrl+shift'" }
                            },
                            "required": ["cell"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "show_plan",
                        "description": "REQUIRED before any desktop task. Call this FIRST before launch_app, click_at, click_cell, type_text, or any action sequence. Present a numbered plan and wait for approval. Never start executing desktop actions without a plan.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "title": { "type": "string" },
                                "steps": { "type": "array", "items": { "type": "object", "properties": { "description": { "type": "string" }, "tool": { "type": "string" } }, "required": ["description"] } }
                            },
                            "required": ["title", "steps"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "wait_for_app",
                        "description": "Wait until an application process is running. Call after launch_app. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "app": { "type": "string", "description": "Process name, e.g. 'spotify'" },
                                "timeout": { "type": "integer", "description": "Max seconds (default 15)" }
                            },
                            "required": ["app"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "search_app",
                        "description": "Search within a specific app or service: spotify, youtube, youtube_music, soundcloud, twitch, bandcamp, reddit, github, files. For spotify, opens the search URI directly. Alternatively use press_key('ctrl+k') to open Spotify's search bar if Spotify is already focused. After calling this, a screenshot is taken automatically — wait for it and use click_cell to select from the results.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "app": { "type": "string", "description": "App to search in" },
                                "query": { "type": "string", "description": "Search query" }
                            },
                            "required": ["app", "query"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_url",
                        "description": "Browser only. Fetch a static web page and return its interactive elements with their IDs. Only works on static/server-rendered pages. For JavaScript-heavy sites (YouTube, Google, Twitter, Reddit, etc.) skip this and use execute_js directly with CSS selectors. NOT for desktop apps — use run_task or open_app for those.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": { "type": "string", "description": "URL to fetch and parse" }
                            },
                            "required": ["url"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "execute_js",
                        "description": "Browser only. Step 2 of 2: execute JavaScript in the active browser tab using element IDs from read_url. NOT for desktop apps — use run_task for those. NOT for visual navigation — use click_at for that. YouTube: after starting a video, turn off repeat — set document.querySelector('video').loop=false and click the loop button off if active. Then STOP (no more execute_js/take_screenshot) unless the user asked to verify; answer in text.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "code": { "type": "string", "description": "JavaScript to run in the browser" }
                            },
                            "required": ["code"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "type_text",
                        "description": "Type text into the currently focused field using the keyboard. Use after click_at on a text field. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "text": { "type": "string", "description": "Text to type" }
                            },
                            "required": ["text"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "press_key",
                        "description": "Press a keyboard key or combination, e.g. 'Return', 'ctrl+a', 'Escape', 'Tab'. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": { "type": "string", "description": "Key or combo to press" }
                            },
                            "required": ["key"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "scroll",
                        "description": "Scroll the mouse wheel at the current cursor position. Use after click_at to position the cursor over a scrollable area, then scroll to navigate. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "direction": { "type": "string", "description": "Direction: 'up', 'down', 'left', or 'right'" },
                                "amount": { "type": "integer", "description": "Scroll steps (default 3, max 20). Use 3-5 for normal scrolling, 10+ for large jumps." }
                            },
                            "required": ["direction"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "drag_to",
                        "description": "Click and drag from one point to another. Use for sliders, rearranging items, drag-and-drop, selecting text regions, or resizing elements. Coordinates are in screenshot pixel space. Auto-screenshots after.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "x1": { "type": "number", "description": "Start X position (screenshot pixels)" },
                                "y1": { "type": "number", "description": "Start Y position (screenshot pixels)" },
                                "x2": { "type": "number", "description": "End X position (screenshot pixels)" },
                                "y2": { "type": "number", "description": "End Y position (screenshot pixels)" },
                                "button": { "type": "string", "description": "Mouse button: 'left' (default) or 'right'" }
                            },
                            "required": ["x1", "y1", "x2", "y2"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "hover",
                        "description": "Move the mouse to pixel coordinates without clicking. Use to reveal tooltips, dropdown menus, hover states, or preview cards. Auto-screenshots after so you can see what appeared.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "x": { "type": "number", "description": "Horizontal pixel position in the screenshot" },
                                "y": { "type": "number", "description": "Vertical pixel position in the screenshot" }
                            },
                            "required": ["x", "y"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_screen_text",
                        "description": "OCR: read text from the screen or a specific region without the grid overlay. Faster than take_screenshot when you just need to read text (error messages, prices, status bars). Returns plain text.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "x": { "type": "number", "description": "Left edge X (screenshot pixels, optional — omit for full screen)" },
                                "y": { "type": "number", "description": "Top edge Y (screenshot pixels, optional)" },
                                "width": { "type": "number", "description": "Region width in pixels (optional)" },
                                "height": { "type": "number", "description": "Region height in pixels (optional)" }
                            }
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "manage_tabs",
                        "description": "Control browser tabs. Use to switch between tabs, close tabs, or jump to a specific tab number. Works via keyboard shortcuts in the focused browser.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'next' (ctrl+tab), 'prev' (ctrl+shift+tab), 'close' (ctrl+w), 'goto' (ctrl+N), 'new' (ctrl+t), 'reopen' (ctrl+shift+t)" },
                                "index": { "type": "integer", "description": "Tab number 1-9 for 'goto' action" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "wait_and_screenshot",
                        "description": "Wait a specified number of seconds then take a screenshot. Use when you need to wait for a page to load, animation to finish, or popup to appear before checking the result.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "seconds": { "type": "number", "description": "Seconds to wait (1-15, default 3)" },
                                "reason": { "type": "string", "description": "Why you're waiting (shown in output)" }
                            }
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_clipboard_text",
                        "description": "Read text currently in the clipboard. Use to retrieve content the user has copied, or to read text staged by write_clipboard. Runs automatically.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "write_clipboard",
                        "description": "Write text to the clipboard so the user can paste it, or so you can paste it with ctrl+v. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "text": { "type": "string", "description": "Text to copy to the clipboard" }
                            },
                            "required": ["text"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "memory_file",
                        "description": "Manage your personal knowledge base — create, read, and update structured markdown files under /memories/. Build organised topic files like /memories/steam_games.md or /memories/user_preferences.md. More powerful than 'remember' — supports full file management with selective in-place edits. Always view /memories/ first to see what exists before creating files.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": { "type": "string", "description": "Operation: 'view' (read file or list directory), 'create' (write new file), 'str_replace' (replace text in existing file), 'insert' (insert line), 'delete' (remove file)" },
                                "path": { "type": "string", "description": "Path starting with /memories/ — e.g. '/memories/' to list, '/memories/steam_games.md' for a file" },
                                "file_text": { "type": "string", "description": "Full file content for 'create'" },
                                "old_str": { "type": "string", "description": "Exact text to replace for 'str_replace'" },
                                "new_str": { "type": "string", "description": "Replacement text for 'str_replace'" },
                                "insert_line": { "type": "integer", "description": "Line number to insert at for 'insert' (0 = beginning)" },
                                "insert_text": { "type": "string", "description": "Text to insert for 'insert'" }
                            },
                            "required": ["command", "path"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "kg_store",
                        "description": "Store structured knowledge in the knowledge graph. Creates entities (people, projects, concepts, preferences) with typed observations and relations between them. More powerful than 'remember' for interconnected facts.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'entity' (create/update entity), 'relation' (link two entities), 'observe' (add observations to existing entity)" },
                                "name": { "type": "string", "description": "Entity name (for 'entity' and 'observe')" },
                                "entity_type": { "type": "string", "description": "Entity type: person, project, tool, preference, concept, location, etc." },
                                "observations": { "type": "array", "items": { "type": "string" }, "description": "List of observations/facts about the entity" },
                                "from_entity": { "type": "string", "description": "Source entity name (for 'relation')" },
                                "relation": { "type": "string", "description": "Relation type in active voice: 'uses', 'prefers', 'works_on', etc." },
                                "to_entity": { "type": "string", "description": "Target entity name (for 'relation')" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "kg_query",
                        "description": "Query the knowledge graph. Search for entities, read specific entities with relations, or view the full graph.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'search', 'read', 'delete_entity', 'delete_relation', 'delete_observation'" },
                                "query": { "type": "string", "description": "Search query (for 'search')" },
                                "name": { "type": "string", "description": "Entity name (for 'read', 'delete_entity', 'delete_observation')" },
                                "observation": { "type": "string", "description": "Observation text to remove (for 'delete_observation')" },
                                "from_entity": { "type": "string", "description": "Source entity (for 'delete_relation')" },
                                "relation": { "type": "string", "description": "Relation type (for 'delete_relation')" },
                                "to_entity": { "type": "string", "description": "Target entity (for 'delete_relation')" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "rag_search",
                        "description": "Semantic search over the user's indexed local documents (notes, code, configs). Returns most relevant chunks with source paths.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "Natural language search query" },
                                "limit": { "type": "integer", "description": "Max results (default 5)" }
                            },
                            "required": ["query"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "rag_index",
                        "description": "Index local files or directories for semantic search via rag_search. Supports text, code, configs. Re-indexing updates changed files.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "path": { "type": "string", "description": "File or directory path to index" },
                                "extensions": { "type": "string", "description": "Comma-separated extensions (e.g. '.md,.txt,.py')" }
                            },
                            "required": ["path"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "dream",
                        "description": "Consolidate and organize your memories. Use 'auto' to automatically find and remove duplicates, clean up stale entries, and merge redundant memories. No further action needed — it handles everything.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'auto' (recommended — automatically consolidate), 'gather' (read-only report), 'apply' (manual actions)" },
                                "actions": { "type": "array", "items": { "type": "object" }, "description": "Only for 'apply': array of manual actions" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "calendar",
                        "description": "Access the user's calendar (Google Calendar via khal). Check schedule, add events, search upcoming.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'today', 'list', 'now', 'add', 'search', 'sync'" },
                                "days": { "type": "integer", "description": "Days to list (default 3)" },
                                "query": { "type": "string", "description": "Search query" },
                                "event_args": { "type": "string", "description": "Event args for 'add': '<start> [end] <summary> [:: description]'" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "workspace_layout",
                        "description": "Save and restore Hyprland window layouts. Save current arrangement or apply a named layout.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'save', 'restore', 'list', 'delete', 'current'" },
                                "name": { "type": "string", "description": "Layout name" }
                            },
                            "required": ["action"]
                        }
                    }
                },
            ],
            "search": [],
            "none": [],
        },
        "mistral": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "opencode_task",
                        "description": "Delegate a coding or deep technical task to OpenCode, an autonomous coding agent with file editing, shell, LSP and 75+ models. Use for writing/refactoring/debugging code, editing project files, running build/test/git commands, or any multi-step engineering task. Give a complete, self-contained task description. Returns OpenCode's final result.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "task": { "type": "string", "description": "Complete, self-contained description of the coding/technical task for OpenCode to perform." }
                            },
                            "required": ["task"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {}
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Modify one or multiple fields in the desktop shell config at once. CRITICAL: You MUST call get_shell_config first to see available keys - never guess key names. Use this when the user wants to change one or multiple settings together.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "changes": {
                                    "type": "array",
                                    "description": "Array of config changes to apply",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "key": {
                                                "type": "string",
                                                "description": "The key to set (e.g., 'bar.borderless')"
                                            },
                                            "value": {
                                                "type": "string",
                                                "description": "The value to set"
                                            }
                                        },
                                        "required": ["key", "value"]
                                    }
                                }
                            },
                            "required": ["changes"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_news",
                        "description": "Get current news headlines. Use for ANY news request: 'what's in the news', 'NPR today', 'latest on X'. ALWAYS use this instead of read_url for news.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "topic": { "type": "string", "description": "Topic or news source, e.g. 'NPR top stories', 'technology', 'world news'" }
                            },
                            "required": ["topic"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "play_music",
                        "description": "Spotify music control. Examples: play_music(query='Yung Gravy') to play, play_music(action='shuffle') to toggle shuffle, play_music(action='like') to add current song to Liked Songs, play_music(action='unlike') to remove it. Use for ALL music requests.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "Artist, song, album, or playlist name (required for action=play)" },
                                "action": { "type": "string", "description": "Action: 'play' (default), 'shuffle' (toggle shuffle), 'like' (add to Liked Songs), 'unlike' (remove from Liked Songs)" },
                                "service": { "type": "string", "description": "Music service: 'spotify' (default)" }
                            },
                            "required": []
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "open_app",
                        "description": "Launch a desktop application by name (via Open Interpreter). For multi-step in-app actions (search, open a channel, play media), use run_task with explicit steps if launch alone is not enough. Not for browser DMs — send_message is separate.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "name": { "type": "string", "description": "Application name, e.g. 'spotify', 'discord', 'firefox'" }
                            },
                            "required": ["name"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_task",
                        "description": "Execute a desktop task autonomously using Open Interpreter (AI code execution engine). Use for: opening apps, controlling Spotify/media, managing files, system control. NOT for browser interaction — use read_url + execute_js to click buttons/inputs on web pages. OI writes and runs Python/bash in a loop until done.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "task": {
                                    "type": "string",
                                    "description": "What to accomplish. Be specific — include app names, search terms, file paths, etc.",
                                },
                            },
                            "required": ["task"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "web_search",
                        "description": "Search the web for current information or facts beyond your knowledge cutoff. Use for general web searches.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": {
                                    "type": "string",
                                    "description": "The search query"
                                }
                            },
                            "required": ["query"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "remember",
                        "description": "Store a quick single-line pattern or preference. For organised multi-topic knowledge base use memory_file instead. Store PATTERNS not facts — e.g. 'To launch Arc Raiders: open_file(steam://rungameid/1808500)', 'User prefers dark themes'. Write in third person.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "content": { "type": "string", "description": "Pattern or preference to store in third person (e.g. 'User prefers volume at 40%', 'To open X use Y')" }
                            },
                            "required": ["content"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "create_todo",
                        "description": "Add a task to the user's to-do list for manual tracking. NOT for timed reminders — use set_timer. NOT for recurring tasks — use schedule_task. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "title": { "type": "string", "description": "Task description" }
                            },
                            "required": ["title"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_system_logs",
                        "description": "Retrieve recent systemd journal logs for diagnosis. Runs automatically without approval.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "lines": { "type": "integer", "description": "Number of lines (default 50, max 200)" },
                                "filter": { "type": "string", "description": "Optional unit name filter" }
                            }
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "control_media",
                        "description": "Control media playback via MPRIS/playerctl. Runs automatically without approval.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'play', 'pause', 'toggle', 'next', 'previous', 'status'" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "control_hyprland",
                        "description": "Control Hyprland: switch workspaces, focus or move windows. NOT for launching apps — use launch_app. NOT for killing processes — use kill_process. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "dispatch": { "type": "string", "description": "hyprctl dispatch argument, e.g. 'workspace 2', 'focuswindow firefox'" }
                            },
                            "required": ["dispatch"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "forget_memory",
                        "description": "Remove a specific memory entry previously saved.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "content": { "type": "string", "description": "Memory entry to remove (partial match)" }
                            },
                            "required": ["content"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "export_chat",
                        "description": "Export the current conversation as a markdown file to ~/Documents.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "filename": { "type": "string", "description": "Optional filename without extension" }
                            }
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "control_system",
                        "description": "Control system volume, brightness, or power profile. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: volume_up/down/set/get, brightness_up/down/set/get, power_profile_get/set" },
                                "value": { "type": "string", "description": "Value for set actions (0-100 for volume/brightness, or profile name)" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "kill_process",
                        "description": "Kill a running process by name. Requires user approval.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "process": { "type": "string", "description": "Process name to kill" }
                            },
                            "required": ["process"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "take_screenshot",
                        "description": "Take a screenshot for visual analysis ONLY. Do NOT use this to interact with apps — use run_task instead. Only use when you need to SEE the screen state.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "launch_app",
                        "description": "Launch an application by command name. IMPORTANT: Steam games cannot be launched by title — use open_file with their steam://rungameid/APPID URI instead. Always follow with wait_for_app to verify the process actually started. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "app": { "type": "string", "description": "App command to launch (e.g. 'firefox', 'dolphin', 'spotify'). NOT for Steam games — use open_file('steam://rungameid/ID') for those." }
                            },
                            "required": ["app"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "open_file",
                        "description": "Open a file path or URI with xdg-open. Use for Steam games ('steam://rungameid/APPID'), documents, and URLs. NOT for launching apps by name — use launch_app for that. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "path": { "type": "string", "description": "File path or URI to open. IMPORTANT: this parameter is always named 'path', not 'url'. For Steam games use 'steam://rungameid/APPID'" }
                            },
                            "required": ["path"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "notify",
                        "description": "Send a desktop notification popup to alert the user. Use after completing a task or for important status updates. NOT for audio output — use speak for that. NOT for mid-task status (just act). Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "title": { "type": "string", "description": "Notification title" },
                                "body": { "type": "string", "description": "Notification body" }
                            },
                            "required": ["title"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_notifications",
                        "description": "Read current desktop notifications — incoming messages, alerts, etc. Returns app name, sender, message body, and notification ID. Call this when user wants to reply to a message or asks what notifications they have.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "reply_notification",
                        "description": "Send an inline reply to a notification (Telegram, WhatsApp, Discord, etc.). Get the notification_id from get_notifications first.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "notification_id": { "type": "number", "description": "The notificationId from get_notifications" },
                                "message": { "type": "string", "description": "The reply text to send" }
                            },
                            "required": ["notification_id", "message"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "send_message",
                        "description": "Send a message to someone on a browser-based platform. Opens the platform, waits for it to load, then automatically finds the contact and sends the message — no extra tools needed. Just call this once and it handles everything. Example: send_message(to='Alice', message='Hi, are you free tonight?', platform='facebook messenger'). Supports: facebook messenger, telegram, discord, whatsapp, instagram.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "to": { "type": "string", "description": "Recipient name or username" },
                                "message": { "type": "string", "description": "The message to send" },
                                "platform": { "type": "string", "description": "App to use: telegram, discord, whatsapp, email, etc." }
                            },
                            "required": ["to", "message", "platform"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_timer",
                        "description": "Set a one-time countdown timer (e.g. '25 minutes'). NOT for recurring tasks — use schedule_task. NOT for task tracking — use create_todo. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "seconds": { "type": "integer", "description": "Duration in seconds" },
                                "label": { "type": "string", "description": "Timer label shown in notification" }
                            },
                            "required": ["seconds"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "calculate",
                        "description": "Evaluate a math expression using Python (e.g. '2**32', 'math.sqrt(144)'). Use this instead of run_shell_command for any pure math. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "expression": { "type": "string", "description": "Python math expression, e.g. '2**32', 'math.sqrt(144)'" }
                            },
                            "required": ["expression"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "pick_color",
                        "description": "Open hyprpicker so the user can pick a color from the screen. Returns hex color. Runs automatically.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "manage_notes",
                        "description": "Read or write user-visible notes in SQLite. Use for notes the USER explicitly wants to keep. Use 'remember' instead for AI-internal patterns. Use 'add' to log progress steps during long tasks.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'list', 'add', 'clear'" },
                                "content": { "type": "string", "description": "Note content for 'add' action" },
                                "tags": { "type": "string", "description": "Optional comma-separated tags for 'add' action" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "search_memory",
                        "description": "Search stored user preferences and past experience. Use ONLY when the user explicitly asks about their own settings, history, or saved preferences. NEVER call this mid-task or before executing actions — just do the task.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "What to search for" },
                                "limit": { "type": "integer", "description": "Max results (default 5)" }
                            },
                            "required": ["query"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "schedule_task",
                        "description": "Schedule a recurring AI task using cron syntax. Use for periodic reminders or automated checks. NOT for one-time countdowns — use set_timer. NOT for simple to-do items — use create_todo.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'add', 'list', 'delete'" },
                                "cron": { "type": "string", "description": "Cron expression: '0 9 * * *' = 9am daily, '*/30 * * * *' = every 30min" },
                                "prompt": { "type": "string", "description": "Message to send to AI when task fires" },
                                "id": { "type": "integer", "description": "Task ID for 'delete'" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "capture_region",
                        "description": "Let the USER interactively select a screen region to capture and analyze. Use when the user wants to pick a specific area themselves. NOT for AI-initiated screenshots — use take_screenshot for those. Runs automatically.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "ocr_region",
                        "description": "Let the user select a screen region and extract its text via OCR. Use when you need the raw text content of a specific area. NOT for general visual analysis — use capture_region. NOT for reading text from a full screenshot — the AI can read take_screenshot images directly.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "speak",
                        "description": "Read text aloud using text-to-speech. Use when the user asks you to read something out loud. NOT for silent notifications — use notify for those. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "text": { "type": "string", "description": "Text to speak aloud" }
                            },
                            "required": ["text"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_clipboard_image",
                        "description": "Attach clipboard image to conversation for analysis. Runs automatically.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "click_at",
                        "description": "Move the mouse to pixel coordinates (x, y) in the screenshot you just received and click. Coordinates are in the screenshot's pixel space — use the exact values you see in the image. After clicking, a new screenshot is taken automatically. Supports double-click and modifier keys (ctrl+click for multi-select, shift+click for range select).",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "x": { "type": "number", "description": "Horizontal pixel position in the screenshot" },
                                "y": { "type": "number", "description": "Vertical pixel position in the screenshot" },
                                "button": { "type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'" },
                                "double": { "type": "boolean", "description": "Double-click instead of single click (default false). Use for opening files, selecting words." },
                                "modifiers": { "type": "string", "description": "Hold modifier keys while clicking: 'ctrl', 'shift', 'alt', 'ctrl+shift'. Use ctrl+click for multi-select, shift+click for range select." }
                            },
                            "required": ["x", "y"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "click_cell",
                        "description": "Click the center of a numbered grid cell from the screenshot overlay. The screenshot is divided into a numbered grid — use the cell number you see in the image to click that region. After clicking, a new screenshot is taken automatically. Supports double-click and modifier keys.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "cell": { "type": "number", "description": "The grid cell number shown in the screenshot overlay" },
                                "button": { "type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'" },
                                "double": { "type": "boolean", "description": "Double-click instead of single click (default false)" },
                                "modifiers": { "type": "string", "description": "Hold modifier keys while clicking: 'ctrl', 'shift', 'alt', 'ctrl+shift'" }
                            },
                            "required": ["cell"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "show_plan",
                        "description": "Present a numbered multi-step task plan to the user for approval before executing. Use for any task with 2+ steps.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "title": { "type": "string" },
                                "steps": { "type": "array", "items": { "type": "object", "properties": { "description": { "type": "string" }, "tool": { "type": "string" } }, "required": ["description"] } }
                            },
                            "required": ["title", "steps"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "wait_for_app",
                        "description": "Wait until an application process is running. Call after launch_app. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "app": { "type": "string", "description": "Process name, e.g. 'spotify'" },
                                "timeout": { "type": "integer", "description": "Max seconds (default 15)" }
                            },
                            "required": ["app"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "search_app",
                        "description": "Search within a specific app or service: spotify, youtube, youtube_music, soundcloud, twitch, bandcamp, reddit, github, files. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "app": { "type": "string", "description": "App to search in" },
                                "query": { "type": "string", "description": "Search query" }
                            },
                            "required": ["app", "query"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_url",
                        "description": "Browser only. Fetch a static web page and return its interactive elements with their IDs. Only works on static/server-rendered pages. For JavaScript-heavy sites (YouTube, Google, Twitter, Reddit, etc.) skip this and use execute_js directly with CSS selectors. NOT for desktop apps — use run_task or open_app for those.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": { "type": "string", "description": "URL to fetch and parse" }
                            },
                            "required": ["url"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "execute_js",
                        "description": "Browser only. Step 2 of 2: execute JavaScript in the active browser tab using element IDs from read_url. NOT for desktop apps — use run_task for those. NOT for visual navigation — use click_at for that. YouTube: after starting a video, turn off repeat — set document.querySelector('video').loop=false and click the loop button off if active. Then STOP (no more execute_js/take_screenshot) unless the user asked to verify; answer in text.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "code": { "type": "string", "description": "JavaScript to run in the browser" }
                            },
                            "required": ["code"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "type_text",
                        "description": "Type text into the currently focused field using the keyboard. Use after click_at on a text field. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "text": { "type": "string", "description": "Text to type" }
                            },
                            "required": ["text"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "press_key",
                        "description": "Press a keyboard key or combination, e.g. 'Return', 'ctrl+a', 'Escape', 'Tab'. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": { "type": "string", "description": "Key or combo to press" }
                            },
                            "required": ["key"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "scroll",
                        "description": "Scroll the mouse wheel at the current cursor position. Use after click_at to position the cursor over a scrollable area, then scroll to navigate. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "direction": { "type": "string", "description": "Direction: 'up', 'down', 'left', or 'right'" },
                                "amount": { "type": "integer", "description": "Scroll steps (default 3, max 20). Use 3-5 for normal scrolling, 10+ for large jumps." }
                            },
                            "required": ["direction"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "drag_to",
                        "description": "Click and drag from one point to another. Use for sliders, rearranging items, drag-and-drop, selecting text regions, or resizing elements. Coordinates are in screenshot pixel space. Auto-screenshots after.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "x1": { "type": "number", "description": "Start X position (screenshot pixels)" },
                                "y1": { "type": "number", "description": "Start Y position (screenshot pixels)" },
                                "x2": { "type": "number", "description": "End X position (screenshot pixels)" },
                                "y2": { "type": "number", "description": "End Y position (screenshot pixels)" },
                                "button": { "type": "string", "description": "Mouse button: 'left' (default) or 'right'" }
                            },
                            "required": ["x1", "y1", "x2", "y2"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "hover",
                        "description": "Move the mouse to pixel coordinates without clicking. Use to reveal tooltips, dropdown menus, hover states, or preview cards. Auto-screenshots after so you can see what appeared.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "x": { "type": "number", "description": "Horizontal pixel position in the screenshot" },
                                "y": { "type": "number", "description": "Vertical pixel position in the screenshot" }
                            },
                            "required": ["x", "y"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_screen_text",
                        "description": "OCR: read text from the screen or a specific region without the grid overlay. Faster than take_screenshot when you just need to read text (error messages, prices, status bars). Returns plain text.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "x": { "type": "number", "description": "Left edge X (screenshot pixels, optional — omit for full screen)" },
                                "y": { "type": "number", "description": "Top edge Y (screenshot pixels, optional)" },
                                "width": { "type": "number", "description": "Region width in pixels (optional)" },
                                "height": { "type": "number", "description": "Region height in pixels (optional)" }
                            }
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "manage_tabs",
                        "description": "Control browser tabs. Use to switch between tabs, close tabs, or jump to a specific tab number. Works via keyboard shortcuts in the focused browser.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'next' (ctrl+tab), 'prev' (ctrl+shift+tab), 'close' (ctrl+w), 'goto' (ctrl+N), 'new' (ctrl+t), 'reopen' (ctrl+shift+t)" },
                                "index": { "type": "integer", "description": "Tab number 1-9 for 'goto' action" }
                            },
                            "required": ["action"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "wait_and_screenshot",
                        "description": "Wait a specified number of seconds then take a screenshot. Use when you need to wait for a page to load, animation to finish, or popup to appear before checking the result.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "seconds": { "type": "number", "description": "Seconds to wait (1-15, default 3)" },
                                "reason": { "type": "string", "description": "Why you're waiting (shown in output)" }
                            }
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_clipboard_text",
                        "description": "Read text currently in the clipboard. Use to retrieve content the user has copied, or to read text staged by write_clipboard. Runs automatically.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "write_clipboard",
                        "description": "Write text to the clipboard so the user can paste it, or so you can paste it with ctrl+v. Runs automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "text": { "type": "string", "description": "Text to copy to the clipboard" }
                            },
                            "required": ["text"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "memory_file",
                        "description": "Manage your personal knowledge base — create, read, and update structured markdown files under /memories/. Build organised topic files like /memories/steam_games.md or /memories/user_preferences.md. More powerful than 'remember' — supports full file management with selective in-place edits. Always view /memories/ first to see what exists before creating files.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": { "type": "string", "description": "Operation: 'view' (read file or list directory), 'create' (write new file), 'str_replace' (replace text in existing file), 'insert' (insert line), 'delete' (remove file)" },
                                "path": { "type": "string", "description": "Path starting with /memories/ — e.g. '/memories/' to list, '/memories/steam_games.md' for a file" },
                                "file_text": { "type": "string", "description": "Full file content for 'create'" },
                                "old_str": { "type": "string", "description": "Exact text to replace for 'str_replace'" },
                                "new_str": { "type": "string", "description": "Replacement text for 'str_replace'" },
                                "insert_line": { "type": "integer", "description": "Line number to insert at for 'insert' (0 = beginning)" },
                                "insert_text": { "type": "string", "description": "Text to insert for 'insert'" }
                            },
                            "required": ["command", "path"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "dream",
                        "description": "Consolidate and organize your memories. Use 'auto' to automatically find and remove duplicates, clean up stale entries, and merge redundant memories. No further action needed — it handles everything.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action: 'auto' (recommended — automatically consolidate), 'gather' (read-only report), 'apply' (manual actions)" },
                                "actions": { "type": "array", "items": { "type": "object" }, "description": "Only for 'apply': array of manual actions" }
                            },
                            "required": ["action"]
                        }
                    }
                },
            ],
            "search": [],
            "none": [],
        }
    };
}
