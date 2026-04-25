import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: page
    readonly property int index: 1
    property bool register: parent.register ?? false
    forceWidth: true

        Process {
            id: translationProc
            property string locale: ""
            command: [Directories.aiTranslationScriptPath, translationProc.locale]
        }

        ContentSection {
            icon: "volume_up"
            title: Translation.tr("Audio")

            ConfigSwitch {
                buttonIcon: "hearing"
                text: Translation.tr("Earbang protection")
                checked: Config.options.audio.protection.enable
                onCheckedChanged: {
                    Config.options.audio.protection.enable = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Prevents abrupt increments and restricts volume limit")
                }
            }
            ConfigRow {
                enabled: Config.options.audio.protection.enable
                ConfigSpinBox {
                    icon: "arrow_warm_up"
                    text: Translation.tr("Max allowed increase")
                    value: Config.options.audio.protection.maxAllowedIncrease
                    from: 0
                    to: 100
                    stepSize: 2
                    onValueChanged: {
                        Config.options.audio.protection.maxAllowedIncrease = value;
                    }
                }
                ConfigSpinBox {
                    icon: "vertical_align_top"
                    text: Translation.tr("Volume limit")
                    value: Config.options.audio.protection.maxAllowed
                    from: 0
                    to: 154 // pavucontrol allows up to 153%
                    stepSize: 2
                    onValueChanged: {
                        Config.options.audio.protection.maxAllowed = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "battery_android_full"
            title: Translation.tr("Battery")

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "warning"
                    text: Translation.tr("Low warning")
                    value: Config.options.battery.low
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.battery.low = value;
                    }
                }
                ConfigSpinBox {
                    icon: "dangerous"
                    text: Translation.tr("Critical warning")
                    value: Config.options.battery.critical
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.battery.critical = value;
                    }
                }
            }
            ConfigRow {
                uniform: false
                Layout.fillWidth: false
                ConfigSwitch {
                    buttonIcon: "pause"
                    text: Translation.tr("Automatic suspend")
                    checked: Config.options.battery.automaticSuspend
                    onCheckedChanged: {
                        Config.options.battery.automaticSuspend = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Automatically suspends the system when battery is low")
                    }
                }
                ConfigSpinBox {
                    enabled: Config.options.battery.automaticSuspend
                    text: Translation.tr("at")
                    value: Config.options.battery.suspend
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.battery.suspend = value;
                    }
                }
            }
            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "charger"
                    text: Translation.tr("Full warning")
                    value: Config.options.battery.full
                    from: 0
                    to: 101
                    stepSize: 5
                    onValueChanged: {
                        Config.options.battery.full = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "language"
            title: Translation.tr("Language")

            ContentSubsection {
                title: Translation.tr("Interface Language")
                tooltip: Translation.tr("Select the language for the user interface.\n\"Auto\" will use your system's locale.")

                StyledComboBox {
                    id: languageSelector
                    buttonIcon: "language"
                    textRole: "displayName"

                    model: [
                    {
                        displayName: Translation.tr("Auto (System)"),
                        value: "auto"
                    },
                    ...Translation.allAvailableLanguages.map(lang => {
                        return {
                            displayName: lang,
                            value: lang
                        };
                    })]

                    currentIndex: {
                        const index = model.findIndex(item => item.value === Config.options.language.ui);
                        return index !== -1 ? index : 0;
                    }

                    onActivated: index => {
                        Config.options.language.ui = model[index].value;
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Generate translation with Gemini")
                tooltip: Translation.tr("You'll need to enter your Gemini API key first.\nType /key on the sidebar for instructions.")

                ConfigRow {
                    MaterialTextArea {
                        id: localeInput
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Locale code, e.g. fr_FR, de_DE, zh_CN...")
                        text: Config.options.language.ui === "auto" ? Qt.locale().name : Config.options.language.ui
                    }
                    RippleButtonWithIcon {
                        id: generateTranslationBtn
                        Layout.fillHeight: true
                        nerdIcon: ""
                        enabled: !translationProc.running || (translationProc.locale !== localeInput.text.trim())
                        mainText: enabled ? Translation.tr("Generate\nTypically takes 2 minutes") : Translation.tr("Generating...\nDon't close this window!")
                        onClicked: {
                            translationProc.locale = localeInput.text.trim();
                            translationProc.running = false;
                            translationProc.running = true;
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Translation engine")

                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Engine (e.g. google, deepl)")
                    text: Config.options.language.translator.engine
                    wrapMode: TextEdit.NoWrap
                    onTextChanged: {
                        Config.options.language.translator.engine = text;
                    }
                }
                ConfigRow {
                    uniform: true
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Source language (e.g. auto, en)")
                        text: Config.options.language.translator.sourceLanguage
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: {
                            Config.options.language.translator.sourceLanguage = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Target language (e.g. fr, de, ja)")
                        text: Config.options.language.translator.targetLanguage
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: {
                            Config.options.language.translator.targetLanguage = text;
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "rule"
            title: Translation.tr("Policies")

            ConfigRow {
                Layout.fillHeight: false

                ContentSubsection {
                    title: Translation.tr("AI")
                    Layout.fillWidth: true

                    ConfigSelectionArray {
                        currentValue: Config.options.policies.ai
                        onSelected: newValue => {
                            Config.options.policies.ai = newValue;
                        }
                        options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Local only"),
                            icon: "sync_saved_locally",
                            value: 2
                        }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Weeb")
                    Layout.fillWidth: false

                    ConfigSelectionArray {
                        currentValue: Config.options.policies.weeb
                        onSelected: newValue => {
                            Config.options.policies.weeb = newValue;
                        }
                        options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Closet"),
                            icon: "ev_shadow",
                            value: 2
                        }
                        ]
                    }
                }
            }

            ConfigRow {
                Layout.fillHeight: false

                ContentSubsection {
                    title: Translation.tr("Wallpaper browser")
                    Layout.fillWidth: true

                    ConfigSelectionArray {
                        currentValue: Config.options.policies.wallpapers
                        onSelected: newValue => {
                            Config.options.policies.wallpapers = newValue;
                        }
                        options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: 1
                        }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Translator")
                    Layout.fillWidth: false

                    ConfigSelectionArray {
                        currentValue: Config.options.policies.translator
                        onSelected: newValue => {
                            Config.options.policies.translator = newValue;
                        }
                        options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: 1
                        }
                        ]
                    }
                }
            }

        }

        ContentSection {
            icon: "notification_sound"
            title: Translation.tr("Sounds")
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "battery_android_full"
                    text: Translation.tr("Battery")
                    checked: Config.options.sounds.battery
                    onCheckedChanged: {
                        Config.options.sounds.battery = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "av_timer"
                    text: Translation.tr("Pomodoro")
                    checked: Config.options.sounds.pomodoro
                    onCheckedChanged: {
                        Config.options.sounds.pomodoro = checked;
                    }
                }
            }
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Sound theme (e.g. freedesktop)")
                text: Config.options.sounds.theme
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.sounds.theme = text; }
            }
        }

        ContentSection {
            icon: "nest_clock_farsight_analog"
            title: Translation.tr("Time")

            ConfigSwitch {
                buttonIcon: "pace"
                text: Translation.tr("Second precision")
                checked: Config.options.time.secondPrecision
                onCheckedChanged: {
                    Config.options.time.secondPrecision = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Enable if you want clocks to show seconds accurately")
                }
            }

            ContentSubsection {
                title: Translation.tr("Format")
                tooltip: ""

                ConfigSelectionArray {
                    currentValue: Config.options.time.format
                    onSelected: newValue => {
                        if (newValue === "hh:mm") {
                            Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME12\\b/TIME/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                        } else {
                            Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME\\b/TIME12/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                        }

                        Config.options.time.format = newValue;
                    }
                    options: [
                    {
                        displayName: Translation.tr("24h"),
                        value: "hh:mm"
                    },
                    {
                        displayName: Translation.tr("12h am/pm"),
                        value: "h:mm ap"
                    },
                    {
                        displayName: Translation.tr("12h AM/PM"),
                        value: "h:mm AP"
                    },
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Pomodoro")

                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "timer"
                        text: Translation.tr("Focus (s)")
                        value: Config.options.time.pomodoro.focus
                        from: 60
                        to: 7200
                        stepSize: 60
                        onValueChanged: { Config.options.time.pomodoro.focus = value; }
                    }
                    ConfigSpinBox {
                        icon: "coffee"
                        text: Translation.tr("Break (s)")
                        value: Config.options.time.pomodoro.breakTime
                        from: 60
                        to: 3600
                        stepSize: 60
                        onValueChanged: { Config.options.time.pomodoro.breakTime = value; }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "hotel"
                        text: Translation.tr("Long break (s)")
                        value: Config.options.time.pomodoro.longBreak
                        from: 60
                        to: 7200
                        stepSize: 60
                        onValueChanged: { Config.options.time.pomodoro.longBreak = value; }
                    }
                    ConfigSpinBox {
                        icon: "repeat"
                        text: Translation.tr("Cycles before long break")
                        value: Config.options.time.pomodoro.cyclesBeforeLongBreak
                        from: 1
                        to: 10
                        stepSize: 1
                        onValueChanged: { Config.options.time.pomodoro.cyclesBeforeLongBreak = value; }
                    }
                }
            }
        }

        ContentSection {
            icon: "calendar_month"
            title: Translation.tr("Date")

            ContentSubsection {
                title: Translation.tr("Format")
                tooltip: Translation.tr("Changes the date format in the bar")

                ConfigSelectionArray {
                    currentValue: Config.options.time.dateFormat
                    onSelected: newValue => {
                        Config.options.time.dateFormat = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Date First dd/MM"),
                            value: "ddd dd/MM"
                        },
                        {
                            displayName: Translation.tr("Month First MM/dd"),
                            value: "ddd MM/dd"
                        }
                    ]
                }
            }

            ConfigSpinBox {
                icon: "event"
                text: Translation.tr("First day of week (0=Mon, 6=Sun)")
                value: Config.options.time.firstDayOfWeek
                from: 0
                to: 6
                stepSize: 1
                onValueChanged: { Config.options.time.firstDayOfWeek = value; }
            }

            ContentSubsection {
                title: Translation.tr("Date string formats")
                tooltip: Translation.tr("Qt date format strings, see Qt documentation")

                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Short date (e.g. dd/MM)")
                    text: Config.options.time.shortDateFormat
                    wrapMode: TextEdit.NoWrap
                    onTextChanged: { Config.options.time.shortDateFormat = text; }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Long date (e.g. dd/MM/yyyy)")
                    text: Config.options.time.longDateFormat
                    wrapMode: TextEdit.NoWrap
                    onTextChanged: { Config.options.time.longDateFormat = text; }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Date with year (e.g. dd/MM/yyyy)")
                    text: Config.options.time.dateWithYearFormat
                    wrapMode: TextEdit.NoWrap
                    onTextChanged: { Config.options.time.dateWithYearFormat = text; }
                }
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Calendar locale (e.g. en-GB)")
                text: Config.options.calendar.locale
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.calendar.locale = text; }
            }
        }

        ContentSection {
            icon: "nights_stay"
            title: Translation.tr("Light")

            ConfigSwitch {
                buttonIcon: "flare"
                text: Translation.tr("Anti-flashbang (reduce brightness on startup)")
                checked: Config.options.light.antiFlashbang.enable
                onCheckedChanged: { Config.options.light.antiFlashbang.enable = checked; }
            }

            ContentSubsection {
                title: Translation.tr("Night light")

                ConfigSwitch {
                    buttonIcon: "schedule"
                    text: Translation.tr("Automatic (use schedule)")
                    checked: Config.options.light.night.automatic
                    onCheckedChanged: { Config.options.light.night.automatic = checked; }
                }

                ConfigSpinBox {
                    icon: "thermostat"
                    text: Translation.tr("Color temperature (K)")
                    value: Config.options.light.night.colorTemperature
                    from: 1000
                    to: 10000
                    stepSize: 100
                    onValueChanged: { Config.options.light.night.colorTemperature = value; }
                }

                ConfigRow {
                    uniform: true
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("From (HH:mm)")
                        text: Config.options.light.night.from
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: { Config.options.light.night.from = text; }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("To (HH:mm)")
                        text: Config.options.light.night.to
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: { Config.options.light.night.to = text; }
                    }
                }
            }
        }

        ContentSection {
            icon: "security"
            title: Translation.tr("Conflict killer")

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "notifications_off"
                    text: Translation.tr("Auto-kill notification daemons")
                    checked: Config.options.conflictKiller.autoKillNotificationDaemons
                    onCheckedChanged: { Config.options.conflictKiller.autoKillNotificationDaemons = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "close"
                    text: Translation.tr("Auto-kill tray apps")
                    checked: Config.options.conflictKiller.autoKillTrays
                    onCheckedChanged: { Config.options.conflictKiller.autoKillTrays = checked; }
                }
            }
        }

        ContentSection {
            icon: "work_alert"
            title: Translation.tr("Work safety")

            ConfigSwitch {
                buttonIcon: "assignment"
                text: Translation.tr("Hide clipboard images copied from sussy sources")
                checked: Config.options.workSafety.enable.clipboard
                onCheckedChanged: {
                    Config.options.workSafety.enable.clipboard = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "wallpaper"
                text: Translation.tr("Hide sussy/anime wallpapers")
                checked: Config.options.workSafety.enable.wallpaper
                onCheckedChanged: {
                    Config.options.workSafety.enable.wallpaper = checked;
                }
            }
        }
}
