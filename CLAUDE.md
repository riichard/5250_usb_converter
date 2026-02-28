# CLAUDE.md – Project context for Claude Code

## What this project is

An IBM 5251 green-screen terminal connected to a Linux host (Raspberry Pi) via USB.
A custom PCB with a **Teensy 4 microcontroller** bridges the Twinax bus to USB-serial.
`5250_terminal.py` runs on the Pi, handling the 5250 protocol, spawning a shell PTY,
and forwarding keystrokes/display data between the IBM terminal and the shell.

```
IBM 5251 keyboard ──┐
                    Twinax ── Teensy 4 (PCB) ── USB ── Pi (5250_terminal.py) ── bash
IBM 5251 display ───┘                             /dev/ttyACM0
```

## Deployment target

- **Pi hostname**: `pdp11` (SSH accessible as `ssh pdp11`)
- **Pi user**: `pi`
- **Pi repo**: `/home/pi/dev/5250_usb_converter/`
- **USB device**: `/dev/ttyACM0` (Teensy 4, USB ID `16c0:0483`)
- **systemd service**: `ibm5250.service`

## Key files

| File | Purpose |
|------|---------|
| `5250_terminal.py` | Main script – protocol, PTY, character encoding |
| `systemd/ibm5250.service` | systemd unit (template; substituted on install) |
| `systemd/install.sh` | Install script for Raspberry Pi |
| `doc/deploy.md` | Step-by-step deployment guide |

## Service management on Pi

```bash
sudo systemctl restart ibm5250.service   # restart (no sudo password needed)
sudo systemctl status  ibm5250.service
journalctl -u ibm5250.service -f         # live logs
```

The sudoers file `/etc/sudoers.d/ibm5250` grants `pi` passwordless access to
`systemctl start/stop/restart/status/daemon-reload` for this service.

## Character encoding – IBM 5251 German terminal

The IBM 5251 uses a German national character set based on cp037 (US EBCDIC) with
German NRC replacements at certain byte positions. `DEFAULT_CODEPAGE = 'cp273'` is
used for encoding, which correctly handles the NRC positions. However several byte
positions that Python's cp273 codec repurposes for extra characters (like `{` → 0x43)
still show the original cp037 character on the physical terminal hardware.

### CUSTOM_CHARACTER_CONVERSIONS in `5250_ES`

| Char | EBCDIC byte | Why |
|------|-------------|-----|
| `{` | 0xC0 | cp037 position; terminal ROM shows `{` here |
| `}` | 0xD0 | cp037 position; terminal ROM shows `}` here |
| `@` | 0x7C | cp037 position; terminal ROM shows `@` here |
| `^` | 0x95 | 5250 extended charset position |
| `#` | 0xBC | confirmed working on this terminal |
| `[` | *(removed)* | cp273 default (0x63) is correct German NRC position |
| `]` | *(removed)* | cp273 default (0xFC) is correct German NRC position |

The earlier mappings `'[': 0x4A` and `']': 0x5A` were designed for US IBM 5250
terminals where those bytes hold `[`/`]`. On the German IBM 5251 they hold `Ä`/`Ü`.

## Output pipeline (shell → IBM terminal display)

```
shell PTY output
  → master_read()
  → ANSI_STRIP_RE.sub()        # strip CSI/OSC/DCS sequences (colors, cursor)
  → str.translate(UNICODE_FALLBACK)  # box-drawing/blocks → ASCII look-alikes
  → write_stdout()
  → txStringWithEscapeChars()  # handle VT52 escape sequences
  → txString()                 # CUSTOM_CHARACTER_CONVERSIONS → cp273 → EBCDIC
  → txEbcdic()
  → Twinax/USB → IBM 5251 display
```

## Shell environment set in spawn()

```python
TWINAXTERM=y           # hint for scripts that they're on a 5250 terminal
NO_COLOR=1             # suppress ANSI color output from programs
PS1='\W\$ '            # short prompt – current directory name only
NCURSES_NO_UTF8_ACS=1  # force ncurses apps (htop etc.) to use ASCII box-drawing
```

## THE GOLDEN RULE — always save to the repo first

**If the Pi crashes, gets wiped, or is replaced, the repo is the only recovery
path. Every working change MUST be committed here before considering the work
done. Do not leave config only on the Pi.**

The Pi's `/home/pi/dev/5250_usb_converter/5250_terminal.py` must always be
identical to the committed `5250_terminal.py` in this repo. The Pi has no
independent git history — it is a deployed copy, not a development fork.

Also needed on the Pi (must match the repo):
- `5250_terminal.py` — main script
- `etc/` — login helper scripts required by the newer script version
- `/lib/systemd/system/ibm5250.service` — installed via `systemd/install.sh`
- `/etc/sudoers.d/ibm5250` — created by `systemd/install.sh`

### Workflow: make a change

1. Edit files in this local repo (`/Users/richard/dev/5250_usb_converter/`)
2. Test the logic or patch on the Pi if needed
3. **Commit** with `git commit`
4. Deploy to Pi:
   ```bash
   scp 5250_terminal.py pdp11:/home/pi/dev/5250_usb_converter/
   ssh pdp11 "sudo systemctl restart ibm5250.service"
   ```
5. Verify the service is still `active (running)`:
   ```bash
   ssh pdp11 "sudo systemctl status ibm5250.service --no-pager"
   ```

### Recovery: Pi wiped or replaced

```bash
# On the new Pi (as root or with sudo):
cd /home/pi/dev
git clone https://github.com/riichard/5250_usb_converter.git
cd 5250_usb_converter
sudo SERVICE_USER=pi bash systemd/install.sh
```

That's it — `install.sh` copies the service file, enables it, starts it, and
sets up the passwordless sudoers entry. See `doc/deploy.md` for full details.

### Full fresh install on a new Pi
See `doc/deploy.md`.

### Debug character encoding issues
Use the `txchartable` command via the 5250> CLI (stop the service, run the script
manually in a terminal, type `txchartable`) to display every EBCDIC byte position
on the physical IBM terminal and identify what glyphs the hardware ROM provides.

## Gotchas

- `StartLimitIntervalSec=0` must be in the `[Unit]` section of the service file,
  not `[Service]` (systemd will warn and ignore it if in the wrong section).
- `python3 -u` and `PYTHONUNBUFFERED=1` are required for log output to appear in
  journalctl without buffering delay.
- The Twinax cable must be in **port 1** on the IBM 5251 (port 2 does not respond).
- `StandardInput=tty-force` is needed so the script has a real TTY for terminal
  emulation; this conflicts with `getty@tty1.service` (handled with `Conflicts=`).
- ANSI escape stripping uses a regex that preserves VT52 single-char sequences
  (`ESC` + A/B/C/D/H/I/J/K/Y/Z/=/</>`) which pass through untouched.
