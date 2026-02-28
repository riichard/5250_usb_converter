# Deployment guide – 5250 USB Converter on Raspberry Pi

This guide covers deploying the 5250 terminal emulator as a managed systemd
service on a Raspberry Pi (tested on Raspberry Pi OS / Debian Bookworm).

## Prerequisites

- Raspberry Pi with Raspberry Pi OS (or any Debian-based Linux)
- Python 3 installed (`python3 --version`)
- The `ebcdic` Python package: `pip3 install ebcdic`
- The Teensy 4 USB converter plugged into a USB port
- The Twinax cable connected to **port 1** on the IBM terminal

## 1. Clone the repository

```bash
mkdir -p ~/dev
cd ~/dev
git clone https://github.com/riichard/5250_usb_converter.git
cd 5250_usb_converter
```

If you are updating an existing installation:

```bash
cd ~/dev/5250_usb_converter
git pull
```

## 2. Install the systemd service

Run the install script as root. By default it targets the user `pi`; pass
`SERVICE_USER` to override.

```bash
sudo SERVICE_USER=pi bash systemd/install.sh
```

The script will:

1. Copy `systemd/ibm5250.service` to `/lib/systemd/system/`, substituting the
   correct install path and user.
2. Run `systemctl enable ibm5250.service` and `systemctl start ibm5250.service`.
3. Create `/etc/sudoers.d/ibm5250` so the service user can run
   `sudo systemctl start/stop/restart/status/daemon-reload ibm5250.service`
   **without a password**.

### Verify it is running

```bash
sudo systemctl status ibm5250.service
journalctl -u ibm5250.service -f
```

If the Teensy is not yet connected you will see:

```
[5250] USB device not found at /dev/ttyACM0. Waiting 10s before retry...
```

The service will connect automatically once the USB converter is plugged in.

## 3. Verify the USB converter is detected

```bash
lsusb | grep -i teensy      # should show "16c0:0483 Van Ooijen Technische Informatica"
ls -la /dev/ttyACM0         # device node must exist
```

If the device appears on a different node (e.g. `/dev/ttyACM1`), pass the `-t`
flag by editing the `ExecStart` line in the service file:

```ini
ExecStart=/usr/bin/python3 -u 5250_terminal.py -t /dev/ttyACM1
```

Then reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ibm5250.service
```

## 4. Configure the keyboard mapping

Edit `5250_terminal.py` and set `DEFAULT_SCANCODE_DICTIONARY` near the top of
the file to match the physical keyboard connected to your IBM terminal:

| Terminal keyboard | Dictionary name |
|-------------------|----------------|
| IBM 5251 German typewriter | `5250_DE` |
| IBM 5251 Spanish typewriter | `5250_ES` |
| IBM 5251 US English | `5250_US` |
| Enhanced (PC-style) German | `ENHANCED_DE` |
| Enhanced (PC-style) US | `ENHANCED_US` |
| 122-key German | `122KEY_DE` |

```python
DEFAULT_SCANCODE_DICTIONARY = '5250_ES'   # ← change this
```

To discover which scancode a key generates, run the script with `-k` and watch
`debug.log`:

```bash
python3 5250_terminal.py -k
tail -f debug.log
# press keys on the IBM terminal keyboard – scancodes appear in the log
```

## 5. Configure the EBCDIC codepage (for non-German terminals)

The default codepage is `cp273` (German EBCDIC). For other terminals set
`DEFAULT_CODEPAGE`:

```python
DEFAULT_CODEPAGE = 'cp037'   # US EBCDIC
```

Alternatively specify on the command line:

```bash
python3 5250_terminal.py 0:5250_US:0:cp037
```

### German IBM 5251 – known character mapping

The IBM 5251 German terminal uses a German national character set. The following
`CUSTOM_CHARACTER_CONVERSIONS` entries in `5250_ES` (and `5250_DE`) override the
default cp273 encoding to match the physical terminal's character ROM:

| Character | EBCDIC byte sent | Reason |
|-----------|-----------------|--------|
| `{` | 0xC0 | cp037 position; terminal ROM has `{` here |
| `}` | 0xD0 | cp037 position |
| `@` | 0x7C | cp037 position |
| `[` | *(default cp273 → 0x63)* | German NRC position on terminal |
| `]` | *(default cp273 → 0xFC)* | German NRC position on terminal |

Use the `txchartable` CLI command to display all 256 EBCDIC byte positions on
the physical terminal and identify correct mappings for other characters:

```
# Stop the service, run manually, then type the command:
sudo systemctl stop ibm5250.service
python3 5250_terminal.py
5250> txchartable
```

## 6. Deploying code updates to the Pi

From your development machine (where the Git repo lives):

```bash
# Copy changed script to Pi and restart service
scp 5250_terminal.py pi@pdp11:~/dev/5250_usb_converter/
ssh pi@pdp11 "sudo systemctl restart ibm5250.service"

# Or if you have committed changes and want to pull on the Pi:
ssh pi@pdp11 "cd ~/dev/5250_usb_converter && git pull && sudo systemctl restart ibm5250.service"
```

## 7. Useful day-to-day commands

```bash
# Follow live service logs
journalctl -u ibm5250.service -f

# Restart the service (no password needed after install)
sudo systemctl restart ibm5250.service

# Stop the service (to run manually for debugging)
sudo systemctl stop ibm5250.service
python3 ~/dev/5250_usb_converter/5250_terminal.py

# Check what is on the tty1 console
sudo chvt 1        # switch to tty1 to see the terminal session
sudo chvt 2        # switch back to a normal login console
```

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `USB device not found` repeated every 10 s | Teensy USB cable not connected | Plug in the USB converter |
| Service connects but terminal blank | Twinax cable in wrong port | Move Twinax to **port 1** on the IBM terminal |
| Garbled control sequences on screen | ANSI color codes from shell programs | Handled automatically by `ANSI_STRIP_RE` stripping in `master_read()` |
| Box-drawing chars show as spaces | Unicode not in terminal character set | Handled by `UNICODE_FALLBACK` translation table |
| Wrong characters (`Ä` for `[`, `§` for `@`) | Wrong `CUSTOM_CHARACTER_CONVERSIONS` for this terminal | See section 5 above and the `txchartable` command |
| Service dies immediately | Script calling `os.kill(SIGKILL)` when USB missing | Fixed: `openSerial()` now retries every 10 s instead |
| Service never restarts after failure | `StartLimitIntervalSec` in wrong section | Must be in `[Unit]`, not `[Service]` |
| Log output missing from `journalctl` | Python stdout buffering | Ensure `ExecStart` uses `python3 -u` and `PYTHONUNBUFFERED=1` is set |
