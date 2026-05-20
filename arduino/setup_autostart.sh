#!/bin/bash
# ============================================================
#  T2T Bridge – Autostart Setup for Raspberry Pi
#  Installs bridge.py as a systemd service so it runs
#  automatically every time the Raspberry Pi boots.
#
#  ARCHITECTURE:
#    qr_arduino   (CH340)  → /dev/t2t-qr     (QR scanner + IR sensor)
#    bottle_sensor (FTDI)  → /dev/t2t-sensor  (LCD, ultrasonic, servo)
#
#  Stable port names are assigned via udev rules so ports
#  never swap between reboots regardless of plug-in order.
#
#  Usage:
#    chmod +x setup_autostart.sh
#    sudo ./setup_autostart.sh
# ============================================================

set -e   # Exit immediately on any error

# ── Colours ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'  # No colour

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
info() { echo -e "${CYAN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERR]${NC}   $1"; }

# ── Detect paths ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE_PY="$SCRIPT_DIR/bridge.py"
SERVICE_TEMPLATE="$SCRIPT_DIR/t2t-bridge.service"
SERVICE_NAME="t2t-bridge"
SERVICE_DEST="/etc/systemd/system/${SERVICE_NAME}.service"
UDEV_RULES_FILE="/etc/udev/rules.d/99-t2t-arduino.rules"

CURRENT_USER="${SUDO_USER:-$USER}"
PYTHON_BIN="$(which python3)"

# Stable port names used by bridge.py on Linux
QR_PORT="/dev/t2t-qr"
SENSOR_PORT="/dev/t2t-sensor"

# USB Vendor/Product IDs
CH340_VID="1a86"   # qr_arduino   — CH340 USB-serial chip
CH340_PID="7523"
FTDI_VID="0403"    # bottle_sensor — FTDI USB-serial chip
FTDI_PID="6001"

echo ""
echo "============================================================"
echo "  T2T Bridge – Autostart Setup for Raspberry Pi"
echo "  QR Arduino (CH340) + Bottle Sensor (FTDI)"
echo "============================================================"
echo ""
info "Script directory : $SCRIPT_DIR"
info "Bridge script    : $BRIDGE_PY"
info "Python           : $PYTHON_BIN"
info "Service user     : $CURRENT_USER"
info "QR port (stable) : $QR_PORT   ← CH340, scanner + IR sensor"
info "Sensor port      : $SENSOR_PORT ← FTDI, LCD / ultrasonic / servo"
echo ""

# ── Must run as root ─────────────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
    err "Please run as root:  sudo ./setup_autostart.sh"
    exit 1
fi

# ── Check we're on Linux ─────────────────────────────────────
if [[ "$(uname)" != "Linux" ]]; then
    err "This script is for Raspberry Pi / Linux only."
    exit 1
fi

# ── Check bridge.py exists ───────────────────────────────────
if [[ ! -f "$BRIDGE_PY" ]]; then
    err "bridge.py not found at: $BRIDGE_PY"
    exit 1
fi

# ── Show connected USB-serial devices ───────────────────────
info "Scanning connected USB-serial devices..."
USB_DEVS=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true)
if [[ -z "$USB_DEVS" ]]; then
    warn "No USB serial devices found!"
    warn "Both Arduinos should be plugged in for udev rules to be verified."
else
    echo "  Found:"
    for dev in $USB_DEVS; do
        DEVINFO=$(udevadm info -q property "$dev" 2>/dev/null \
            | grep -E "ID_VENDOR_ID|ID_MODEL_ID|ID_SERIAL|ID_USB_DRIVER" \
            | head -4 || true)
        echo "    $dev"
        if [[ -n "$DEVINFO" ]]; then
            echo "$DEVINFO" | while IFS= read -r line; do echo "      $line"; done
        fi
    done
fi
echo ""

# ── Install Python dependencies ──────────────────────────────
info "Installing Python dependencies..."
# --break-system-packages is needed on Raspberry Pi OS Bookworm (Python 3.11+)
# which blocks pip from installing to system Python without this flag
if $PYTHON_BIN -m pip install --upgrade pyserial firebase-admin --quiet 2>/dev/null; then
    ok "Python packages installed (pyserial, firebase-admin)"
else
    info "Retrying with --break-system-packages (Raspberry Pi OS Bookworm)..."
    $PYTHON_BIN -m pip install --upgrade pyserial firebase-admin --quiet --break-system-packages
    ok "Python packages installed (pyserial, firebase-admin)"
fi

# ── Add user to dialout ──────────────────────────────────────
if ! groups "$CURRENT_USER" | grep -q "dialout"; then
    info "Adding $CURRENT_USER to 'dialout' group..."
    usermod -aG dialout "$CURRENT_USER"
    warn "Group change takes effect after next login or reboot."
else
    ok "User '$CURRENT_USER' already in 'dialout' group"
fi

# ── Verify serviceAccountKey.json exists ────────────────────
KEY_PATH="$(realpath "$SCRIPT_DIR/../serviceAccountKey.json" 2>/dev/null || echo "")"
if [[ -f "$KEY_PATH" ]]; then
    ok "Firebase key found       : $KEY_PATH"
else
    warn "Firebase key NOT found   : $KEY_PATH"
    warn "Bridge will run in OFFLINE mode until the key is placed there."
fi

# ── Install udev rules for stable port names ─────────────────
info "Installing udev rules for permanent port names..."
cat > "$UDEV_RULES_FILE" <<EOF
# T2T Arduino udev rules
# Assigns stable symlinks regardless of plug-in order.
# Generated by setup_autostart.sh

# qr_arduino (CH340 chip) → /dev/t2t-qr
SUBSYSTEM=="tty", ATTRS{idVendor}=="${CH340_VID}", ATTRS{idProduct}=="${CH340_PID}", SYMLINK+="t2t-qr", MODE="0666"

# bottle_sensor (FTDI chip) → /dev/t2t-sensor
SUBSYSTEM=="tty", ATTRS{idVendor}=="${FTDI_VID}", ATTRS{idProduct}=="${FTDI_PID}", SYMLINK+="t2t-sensor", MODE="0666"
EOF
ok "udev rules written to $UDEV_RULES_FILE"

info "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger
ok "udev rules active"

# Verify symlinks appeared (only if devices are plugged in)
sleep 1
if [[ -L "$QR_PORT" ]]; then
    ok "Stable link active : $QR_PORT → $(readlink -f $QR_PORT)"
else
    warn "$QR_PORT not yet visible — plug in qr_arduino (CH340) to verify"
fi
if [[ -L "$SENSOR_PORT" ]]; then
    ok "Stable link active : $SENSOR_PORT → $(readlink -f $SENSOR_PORT)"
else
    warn "$SENSOR_PORT not yet visible — plug in bottle_sensor (FTDI) to verify"
fi
echo ""

# ── Build the service file from template ─────────────────────
info "Creating systemd service file..."

if [[ ! -f "$SERVICE_TEMPLATE" ]]; then
    err "Service template not found: $SERVICE_TEMPLATE"
    exit 1
fi

TMP_SERVICE=$(mktemp)
sed "s|__USER__|$CURRENT_USER|g;
     s|__SCRIPT_DIR__|$SCRIPT_DIR|g;
     s|__PYTHON__|$PYTHON_BIN|g" \
     "$SERVICE_TEMPLATE" > "$TMP_SERVICE"

cp "$TMP_SERVICE" "$SERVICE_DEST"
rm -f "$TMP_SERVICE"
ok "Service file written to $SERVICE_DEST"

# ── Enable & start the service ───────────────────────────────
info "Reloading systemd daemon..."
systemctl daemon-reload

info "Enabling $SERVICE_NAME to start on every boot..."
systemctl enable "$SERVICE_NAME"
ok "Service enabled"

info "Starting $SERVICE_NAME now..."
systemctl start "$SERVICE_NAME"
sleep 4

# ── Show status ──────────────────────────────────────────────
echo ""
echo "============================================================"
STATUS=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || true)
if [[ "$STATUS" == "active" ]]; then
    ok "T2T Bridge is RUNNING!"
    echo ""
    info "Live log (last 20 lines):"
    journalctl -u "$SERVICE_NAME" -n 20 --no-pager
else
    warn "Service status: $STATUS"
    warn "Check logs with:  sudo journalctl -u t2t-bridge -n 50"
fi

echo ""
echo "============================================================"
echo "  Stable port names (set by udev):"
echo "    $QR_PORT     → qr_arduino (CH340) — scanner + IR"
echo "    $SENSOR_PORT  → bottle_sensor (FTDI) — LCD / ultrasonic / servo"
echo ""
echo "  Useful commands:"
echo "    Live logs        :  sudo journalctl -u t2t-bridge -f"
echo "    Check status     :  sudo systemctl status t2t-bridge"
echo "    Stop bridge      :  sudo systemctl stop t2t-bridge"
echo "    Start bridge     :  sudo systemctl start t2t-bridge"
echo "    Restart bridge   :  sudo systemctl restart t2t-bridge"
echo "    Disable autostart:  sudo systemctl disable t2t-bridge"
echo "    View udev rules  :  cat $UDEV_RULES_FILE"
echo "============================================================"
echo ""
