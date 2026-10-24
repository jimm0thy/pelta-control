# ROG Pelta for Linux

Linux tools for the **ASUS ROG Pelta** wireless headset, used with its 2.4 GHz USB dongle or connected directly by USB-C cable:

- **Fixes the volume bug.** On Linux the headset wakes from sleep at max volume no matter what the system volume is. A small background service catches every wake and puts the volume back.
- **Battery in the system tray**, with a charging indicator, a low-battery notification and a "fully charged" notification.
- **Settings without Armoury Crate**: RGB lighting, auto-sleep timer, low-battery warning level, sidetone and echo cancellation, from a settings window or the command line.

Everything runs as your normal user. Root is only needed once, to install a udev rule.

**This project has been vibe coded with Claude**


![Settings window](docs/screenshot.png)

## Install

```
git clone https://github.com/jimm0thy/pelta-control.git
cd pelta-control
./install.sh
```

The installer:

- installs any missing dependencies with pacman, apt, dnf or zypper (see [Other distros](#other-distros))
- copies the scripts to `~/.local/bin`
- installs the udev rule to `/etc/udev/rules.d/` (asks for your sudo password)
- installs and starts the `pelta-wake` user service
- adds a **ROG Pelta** entry to the app launcher, and starts the tray app at login
- starts the tray app

Run `./install.sh` again after pulling updates. To remove everything, run `./install.sh --uninstall`.

## Usage

### Tray icon and settings window

The tray icon shows the battery level in steps of 10%, with a plug badge while charging. Hover over it for the exact percentage. **Left-click** it (or right-click → **Settings…**) to open the settings window:

| Section | What it does |
|---|---|
| Headset | Battery level and status (awake, asleep, charging) |
| Lighting | Mode (static, breathing, strobing, color cycle, off), color picker or preset swatches, brightness |
| Power | Auto-sleep timer and low-battery warning level. Read from the headset each time the window opens, so it's greyed out while the headset is asleep |
| Microphone | Sidetone (hear your own voice) and echo cancellation |

Changes are sent to the headset as you make them. Closing the window hides it; the tray icon keeps running. If you quit the tray app, start it again from **ROG Pelta** in the app launcher.

If KDE hides the icon in the tray's overflow area, right-click the tray → **Configure System Tray → Entries** and set the Pelta entry to **Always shown**.

### Command line: `pelta-ctl`

```
pelta-ctl status                      # battery, sleep timer, low-battery alert, last-set settings

pelta-ctl rgb static purple -b 100    # mode, color, brightness (0-100, default 50)
pelta-ctl rgb breathing 00aaff        # hex colors work too
pelta-ctl rgb strobing red
pelta-ctl rgb cycle -b 75             # color cycle ignores the color
pelta-ctl off                         # lights off
pelta-ctl colors                      # list color names

pelta-ctl sleep 10                    # auto-sleep: never, 5, 10 or 15 minutes
pelta-ctl alert 15                    # low-battery warning at 15% (5-50)
pelta-ctl alert off

pelta-ctl sidetone on                 # on / off
pelta-ctl echo-cancel on              # on / off
```

**Color names:** red, orange, amber, yellow, lime, green, mint, cyan, sky, blue, purple, violet, magenta, pink, white. They aren't case-sensitive. Some are adjusted for LEDs, which make mixed colors look more yellow than a screen does (orange is `ff4000`, for example).

**Lighting** commands set everything at once: anything you leave out goes back to its default. `pelta-ctl rgb static green` sets brightness to 50 even if it was at 100.

**Sleep timer and alert** are read back from the headset after each change, so the command tells you if the headset didn't take it. Both need the headset to be awake.

### What `status` can and can't read

The headset reports its **battery level, charging state, sleep timer and low-battery alert** when asked. It has no way to report **lighting, sidetone or echo cancellation**, so `pelta-ctl` and the settings window remember the last values you set in `~/.config/pelta/settings.json`. Those will be wrong if something else changes the headset (Armoury Crate on another PC, for example).

### Battery and notifications

The `pelta-wake` service reads the battery level when it starts, every time the headset wakes, and whenever the headset reports a change. It sends a desktop notification:

- when the battery drops to the headset's low-battery warning level (set with `pelta-ctl alert` or the settings window; no notification if the alert is off)
- when charging reaches 100%

While the headset is asleep or off, the tray shows the last known level, marked **last known** in the tooltip.

### Wired (USB-C) mode

With the headset plugged in by cable, it shows up as its own USB device (`0b05:1b82`) instead of the dongle (`0b05:1b84`), with the same command interface. The udev rule matches both, so the tray, settings window and `pelta-ctl` work the same way, and the battery shows as charging. The headset shouldn't sleep while wired, so the volume fix has nothing to do in this mode.

Each connection gets its own device: `/dev/pelta-hid-dongle` and `/dev/pelta-hid-usb`. The daemon checks every few seconds which one is present and switches automatically, preferring the cable when both are connected. The settings window's title and the tray tooltip show the current connection (**ROG Pelta 2.4GHz** or **ROG Pelta USB**), and `pelta-ctl status` prints it.

## Files

| Installed to | What it is |
|---|---|
| `~/.local/bin/pelta-wake-hid` | Background daemon: wake volume fix and battery tracking |
| `~/.local/bin/pelta-recover` | Re-syncs the headset volume after a wake (called by the daemon) |
| `~/.local/bin/pelta-ctl` | Command-line tool |
| `~/.local/bin/pelta-tray` | Tray icon and settings window (must sit next to `pelta-ctl`) |
| `~/.config/systemd/user/pelta-wake.service` | User service that runs the daemon |
| `/etc/udev/rules.d/70-pelta.rules` | Creates `/dev/pelta-hid-dongle` / `/dev/pelta-hid-usb` and gives your user access to them |
| `~/.local/share/applications/pelta-tray.desktop` | App launcher entry |
| `~/.config/autostart/pelta-tray.desktop` | Starts the tray app at login |

Runtime files: `$XDG_RUNTIME_DIR/pelta.json` (current status, written by the daemon), `~/.cache/pelta-battery` (last known level), `~/.config/pelta/settings.json` (last-set lighting and mic settings).

`tools/pelta-probe` isn't installed. It sends the headset's status queries and prints the raw replies, which is useful for working out new parts of the protocol.

## Requirements

- Linux with PipeWire (`pactl` from `libpulse` / `pipewire-pulse`)
- systemd (user services) and udev
- Python 3 and PyQt6
- `notify-send` (libnotify)

Tested on CachyOS with KDE Plasma 6. The tray app should work on any desktop with a system tray, but the battery icons come from your icon theme, so they may look different outside KDE.

### Other distros

Nothing in the tools is Arch-specific. The installer detects your package manager and installs these:

| | Arch / CachyOS | Debian / Ubuntu | Fedora | openSUSE |
|---|---|---|---|---|
| PyQt6 | `python-pyqt6` | `python3-pyqt6` | `python3-pyqt6` | `python3-PyQt6` |
| notify-send | `libnotify` | `libnotify-bin` | `libnotify` | `libnotify-tools` |
| pactl | `libpulse` | `pulseaudio-utils` | `pulseaudio-utils` | `pulseaudio-utils` |

`pactl` works with PipeWire as well as PulseAudio. Package names can change between releases; if the install fails, install the equivalents yourself and run `./install.sh` again.

- **Older releases:** PyQt6 is packaged in Debian 12 and Ubuntu 22.04 and newer. On older releases, install it with `pip install --user PyQt6`.
- **GNOME:** GNOME has no system tray by default, so the battery icon won't appear. Ubuntu already includes the AppIndicator extension. On Debian and other GNOME setups, install and enable **AppIndicator and KStatusNotifierItem Support** (Debian package `gnome-shell-extension-appindicator`), then log out and back in. The installer warns if it's missing. The volume fix, notifications and `pelta-ctl` work without it.
- **`~/.local/bin` not in PATH:** Debian and Ubuntu only add it at login if the folder already exists, so on a new account you may need to log out and back in once after installing.
- **PulseAudio instead of PipeWire:** the tools should work, but the wake bug and fix have only been tested with PipeWire.

## Troubleshooting

**`/dev/pelta-hid-dongle` (or `-usb`) doesn't exist.** Make sure the dongle (or the headset's USB-C cable) is plugged in and check that the rule matches it:

```
udevadm info /dev/hidrawN | grep -E 'ID_VENDOR_ID|ID_MODEL_ID|ID_USB_INTERFACE_NUM'
```

Try each `hidrawN` that belongs to the headset (`ls -l /sys/class/hidraw/ | grep -iE '0b05:1b8(4|2)'` lists them). The rule expects vendor `0b05`, model `1b84` (dongle) or `1b82` (cable) and interface `03`. If yours differs, change it in `udev/70-pelta.rules` and run `./install.sh` again.

**Volume still jumps to max after a wake.** Check the service log while waking the headset:

```
journalctl --user -u pelta-wake -f
```

You should see `Wake detected` and a `Restored volume` line. If the wake is detected but the volume isn't corrected, the headset needs more time after waking: raise `sleep 1` at the top of `~/.local/bin/pelta-recover` to `sleep 2`.

**The tray says "no data yet" or "last known".** The daemon only gets a reading while the headset is awake. Turn it on, or check that the service is running: `systemctl --user status pelta-wake`.

**`pelta-ctl` says the headset is asleep.** Sleep timer and alert changes need the headset awake. Lighting and mic commands are sent without a check, so they won't take effect while it's asleep either.

**Upgrading from an older root/usbmon-based fix.** The installer warns if it finds a system service whose name starts with `pelta`. Disable it with `sudo systemctl disable --now <name>` so the two don't both nudge the volume.

## How it works

### The volume bug

PipeWire controls the Pelta's volume in the headset's hardware (the sink has the `HW_VOLUME_CTRL` flag). When the headset sleeps and wakes, its firmware resets its internal volume to max, but nothing tells Linux, so PipeWire never re-sends the level. Changing the volume by any amount forces a write and fixes it.

`pelta-recover` reads the exact raw volume, nudges it up 2%, then sets the exact raw value back. Restoring the raw number instead of a rounded percentage means the volume never drifts, however many wakes there are.

Switching PipeWire to software volume (`api.alsa.soft-mixer`) avoids the bug, but this headset only accepts 16-bit audio, and doing the large volume cut in software makes audible static during playback. Hardware volume plus the wake fix sounds better.

### Detecting a wake

The dongle reports headset events as HID input reports on its vendor interface (interface 3, report ID `0xCC`). The headset has the same interface when connected by cable. The daemon reads that device directly, which needs no root, no usbmon and no polling. The udev rule gives that interface a fixed name, so it doesn't matter which `hidrawN` number or USB port it gets.

### Protocol

Everything goes through report ID `0xCC`, 64 bytes, in both directions. Commands from the computer are HID output reports (`SET_REPORT`). These were worked out from the dongle's HID descriptor and USB captures of Armoury Crate on Windows.

**Sent by the headset on its own**

| Report | Meaning |
|---|---|
| `cc 12 0e 00 00 00 00 00` | Woke up |
| `cc 12 0e …` (other bytes nonzero) | Went to sleep |
| `cc 12 09 00 00 <pct>` | Battery level changed |
| `cc 12 08 00 00 <0/1>` | Charging cable unplugged / plugged in |
| `cc 99 …`, `cc 70 …` | Button presses (play/pause); media keys arrive as report `02` |

**Status queries** (each reply starts with the same three bytes; the same queries work over the USB-C cable)

| Query | Reply |
|---|---|
| `cc 12 00 00 01` | Dongle: byte 5 `1` = headset connected, all zeros = asleep. Cable: byte 5 is `0` followed by other data (`07 00 04` on the tested unit, possibly a version) |
| `cc 12 08` | byte 5: `1` = charging |
| `cc 12 07` | byte 5: sleep timer (minutes, 0 = never), byte 6: battery %, byte 7: alert level %, byte 8: alert on/off |
| `cc 12 13`, `cc 12 18` | Sent by Armoury Crate; meaning unknown (not surround, sidetone or mic state as far as tested) |

A sleeping headset answers every query with `ff aa` in bytes 5–6. Querying `cc 12 09` (the battery push type) isn't supported and also returns `ff aa`.

**Settings**

| Command | Meaning |
|---|---|
| `cc 51 28 00 00 <mode> <brightness> <R> <G> <B>` | Lighting. Mode 1 static, 2 breathing, 3 strobing, 4 color cycle. Brightness 0–100 |
| `cc 51 37 00 00 <minutes> <alert %> <alert on>` | Sleep timer and low-battery alert (always set together) |
| `cc 41 11 00 00 <0/1>` | Sidetone |
| `cc 41 02 00 00 <0/1>` | Echo cancellation |
| `cc 41 03 00 00 <0/1>`, `cc 41 04 00 00 <10 bytes>` | Sent by Armoury Crate with its EQ presets (`0x0c` = flat band). No audible effect on Linux, so not implemented. Armoury Crate's EQ and virtual surround appear to be done in software on Windows |

For EQ on Linux, use a system-wide equalizer such as JamesDSP or EasyEffects.

## Disclaimer

Not affiliated with or endorsed by ASUS. ROG and Armoury Crate are trademarks of ASUSTeK Computer Inc. The protocol was worked out by observing the headset; use these tools at your own risk.

## License

[MIT](LICENSE)
