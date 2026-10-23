#!/usr/bin/env bash
# Install (or remove) the ROG Pelta Linux tools for the current user.
#   ./install.sh               install / update
#   ./install.sh --uninstall   remove everything this script installed
set -euo pipefail

SRC="$(dirname "$(readlink -f "$0")")"
BIN="$HOME/.local/bin"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
RULE=/etc/udev/rules.d/70-pelta.rules
SCRIPTS=(pelta-wake-hid pelta-recover pelta-ctl pelta-tray)
DESKTOP=pelta-tray.desktop

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root. It uses sudo only where needed."
    exit 1
fi

stop_tray() { pkill -f "$BIN/pelta-tray" 2>/dev/null || true; }

uninstall() {
    say "Stopping and removing the user service"
    systemctl --user disable --now pelta-wake.service 2>/dev/null || true
    rm -f "$UNITS/pelta-wake.service"
    systemctl --user daemon-reload

    say "Removing the tray app, scripts and shortcuts"
    stop_tray
    for s in "${SCRIPTS[@]}"; do rm -f "$BIN/$s"; done
    rm -f "$APPS/$DESKTOP" "$AUTOSTART/$DESKTOP"

    say "Removing the udev rule (needs sudo)"
    sudo rm -f "$RULE"
    sudo udevadm control --reload

    say "Done. Saved settings were kept in ~/.config/pelta and ~/.cache/pelta-battery;"
    say "delete them too if you want a completely clean removal."
    exit 0
}

[[ "${1:-}" == "--uninstall" ]] && uninstall
if [[ -n "${1:-}" ]]; then
    echo "Usage: $0 [--uninstall]"
    exit 1
fi

# --- dependencies -----------------------------------------------------------
# Needed: Python 3, PyQt6, notify-send and pactl. Package names per manager:
#                 python3   PyQt6           notify-send      pactl
pkg_pacman=(      python    python-pyqt6    libnotify        libpulse)
pkg_apt=(         python3   python3-pyqt6   libnotify-bin    pulseaudio-utils)
pkg_dnf=(         python3   python3-pyqt6   libnotify        pulseaudio-utils)
pkg_zypper=(      python3   python3-PyQt6   libnotify-tools  pulseaudio-utils)

need=()
command -v python3     >/dev/null || need+=(0)
python3 -c 'import PyQt6' 2>/dev/null || need+=(1)
command -v notify-send >/dev/null || need+=(2)
command -v pactl       >/dev/null || need+=(3)

if ((${#need[@]})); then
    if   command -v pacman >/dev/null; then pm=pacman; install_cmd=(sudo pacman -S --needed)
    elif command -v apt-get >/dev/null; then pm=apt;   install_cmd=(sudo apt-get install -y)
    elif command -v dnf    >/dev/null; then pm=dnf;    install_cmd=(sudo dnf install -y)
    elif command -v zypper >/dev/null; then pm=zypper; install_cmd=(sudo zypper install -y)
    else
        warn "Missing dependencies and no supported package manager found."
        warn "Install Python 3, PyQt6, notify-send (libnotify) and pactl"
        warn "(pulseaudio-utils / libpulse), then run this script again."
        exit 1
    fi
    declare -n names="pkg_$pm"
    pkgs=()
    for i in "${need[@]}"; do pkgs+=("${names[$i]}"); done
    say "Installing missing packages with $pm: ${pkgs[*]}"
    if ! "${install_cmd[@]}" "${pkgs[@]}"; then
        warn "Package install failed. Package names can differ between releases;"
        warn "install the equivalents of: ${pkgs[*]} and run this script again."
        exit 1
    fi
    if ! python3 -c 'import PyQt6' 2>/dev/null; then
        warn "PyQt6 still isn't importable. On older releases without a PyQt6"
        warn "package, try: pip install --user PyQt6"
        exit 1
    fi
fi

# --- files ------------------------------------------------------------------
say "Installing scripts to $BIN"
stop_tray
for s in "${SCRIPTS[@]}"; do
    install -Dm755 "$SRC/bin/$s" "$BIN/$s"
done

say "Installing the udev rule (needs sudo)"
sudo install -Dm644 "$SRC/udev/70-pelta.rules" "$RULE"
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=hidraw

say "Creating the app launcher and autostart entries"
mkdir -p "$APPS" "$AUTOSTART"
cat > "$APPS/$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=ROG Pelta
Comment=Headset battery, lighting and settings
Exec=$BIN/pelta-tray
Icon=audio-headset
Categories=Settings;HardwareSettings;System;
EOF
cp "$APPS/$DESKTOP" "$AUTOSTART/$DESKTOP"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true

say "Installing and starting the user service"
install -Dm644 "$SRC/systemd/pelta-wake.service" "$UNITS/pelta-wake.service"
systemctl --user daemon-reload
systemctl --user enable pelta-wake.service >/dev/null
systemctl --user restart pelta-wake.service

say "Starting the tray app"
nohup "$BIN/pelta-tray" >/dev/null 2>&1 &
disown

# --- checks -----------------------------------------------------------------
sleep 1
if [[ -e /dev/pelta-hid ]]; then
    say "Found the dongle at /dev/pelta-hid"
else
    warn "/dev/pelta-hid not found. Plug in the dongle; if it still doesn't"
    warn "appear, see Troubleshooting in the README."
fi

case ":$PATH:" in
    *":$BIN:"*) ;;
    *) warn "$BIN is not in your PATH, so 'pelta-ctl' won't run by name."
       warn "Add it in your shell config, or run $BIN/pelta-ctl." ;;
esac

old=$(systemctl list-unit-files --type=service --no-legend 'pelta*' 2>/dev/null | awk '{print $1}' || true)
if [[ -n "$old" ]]; then
    warn "Found an older system-level service: $old"
    warn "It does the same job as pelta-wake.service. Disable it with:"
    warn "  sudo systemctl disable --now $old"
fi

if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && ! gnome-extensions list --enabled 2>/dev/null | grep -qi appindicator; then
    warn "GNOME has no system tray by default, so the battery icon won't show."
    warn "Install and enable the \"AppIndicator and KStatusNotifierItem Support\""
    warn "extension (Debian: gnome-shell-extension-appindicator), then log out and in."
fi

say "Installed. Click the headset battery icon in the system tray to open settings."
