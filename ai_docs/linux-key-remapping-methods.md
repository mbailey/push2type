# Linux System-Wide Key Remapping Methods

This document covers various methods for remapping keys on Linux systems, with a focus on solutions that work across both X11 and Wayland display servers.

## 1. udev/hwdb Rules

udev provides a low-level, system-wide method for remapping keys that works at the kernel level before any display server.

### How it works
- Uses hardware database (hwdb) rules to remap keys at the evdev level
- Rules are stored in `/etc/udev/hwdb.d/` (system) or `/usr/lib/udev/hwdb.d/` (distribution)
- Changes are persistent and work in console, X11, and Wayland

### Example: Remapping CapsLock
Create a file `/etc/udev/hwdb.d/10-my-keyboard.hwdb`:
```
evdev:atkbd:dmi:*                    # built-in keyboard
 KEYBOARD_KEY_3a=leftctrl            # map caps lock to left control

evdev:input:b0003v*p*                # USB keyboards
 KEYBOARD_KEY_70039=leftctrl         # map caps lock to left control
```

### Applying changes
```bash
# Update the hardware database
sudo systemd-hwdb update

# Reload udev rules
sudo udevadm trigger

# Or reboot the system
```

### Finding key codes
```bash
# Monitor key events
sudo evtest
# or
sudo showkey --scancodes
```

### Limitations
- Can only do simple 1:1 key mappings
- Cannot create complex behaviors (like tap vs hold)
- Cannot execute commands or control LEDs independently

## 2. keyd Daemon

keyd is a powerful key remapping daemon that operates at the kernel level using evdev and uinput.

### Features
- Works on both X11 and Wayland
- Supports complex mappings (tap/hold behaviors, layers, macros)
- Can remap any key to any other key or key combination
- Supports per-application configurations
- Runs as a system service

### Installation
```bash
# From source
git clone https://github.com/rvaiya/keyd
cd keyd
make && sudo make install
sudo systemctl enable keyd && sudo systemctl start keyd

# On Arch Linux
sudo pacman -S keyd
```

### Configuration
Configuration file: `/etc/keyd/default.conf`

```ini
[ids]
# List keyboard IDs to apply config to
*

[main]
# Map capslock to escape on tap, control on hold
capslock = overload(control, esc)

# Map escape to capslock
esc = capslock

# Custom layers
capslock = layer(nav)

[nav:C]
# When holding Control (via capslock)
h = left
j = down
k = up
l = right
```

### Monitoring keys
```bash
# See key names and codes
sudo keyd monitor

# Test configuration
sudo keyd reload
```

### Advanced features
- Layers: Create custom key layers activated by modifier keys
- Overload: Different behavior for tap vs hold
- Oneshot: Sticky keys functionality
- Macros: Send sequences of keys
- Timeouts: Configure tap/hold timing

## 3. Controlling Keyboard LEDs

### Using sysfs
LEDs can be controlled through the sysfs filesystem:

```bash
# List available LEDs
ls /sys/class/leds/

# Common keyboard LEDs:
# input*::capslock
# input*::numlock
# input*::scrolllock

# Turn on CapsLock LED
echo 1 | sudo tee /sys/class/leds/input*::capslock/brightness

# Turn off CapsLock LED
echo 0 | sudo tee /sys/class/leds/input*::capslock/brightness
```

### Using ioctl with evdev
Control LEDs programmatically using C:

```c
#include <linux/input.h>
#include <sys/ioctl.h>
#include <fcntl.h>

int fd = open("/dev/input/eventX", O_RDWR);
struct input_event ev;

ev.type = EV_LED;
ev.code = LED_CAPSL;  // or LED_NUML, LED_SCROLLL
ev.value = 1;         // 1 = on, 0 = off

write(fd, &ev, sizeof(ev));
```

### Using xset (X11 only)
```bash
# Turn on specific LED
xset led named "Caps Lock"
xset led 1  # 1=ScrollLock, 2=NumLock, 3=CapsLock

# Turn off LED
xset -led named "Caps Lock"
```

## 4. Selective Key Capture (Push-to-Talk)

### Using evdev with grab
To capture specific keys without affecting the entire keyboard:

```python
import evdev
from evdev import InputDevice, categorize, ecodes

# Find keyboard device
devices = [InputDevice(path) for path in evdev.list_devices()]
keyboard = None
for device in devices:
    if "keyboard" in device.name.lower():
        keyboard = device
        break

# Grab only specific keys (not entire device)
# This requires custom filtering in your event loop
for event in keyboard.read_loop():
    if event.type == ecodes.EV_KEY:
        if event.code == ecodes.KEY_CAPSLOCK:
            # Handle CapsLock events
            if event.value == 1:  # Key down
                # Start push-to-talk
                pass
            elif event.value == 0:  # Key up
                # Stop push-to-talk
                pass
```

### Using keyd for push-to-talk
Configure keyd to run commands on key press/release:

```ini
[main]
# Note: keyd doesn't directly support running commands,
# but can remap to unused F-keys that your app monitors
capslock = f13
```

### Alternative: Global hotkeys
- **X11**: Use XGrabKey API or tools like xbindkeys
- **Wayland**: More restricted, need compositor support or use keyd/evdev

## 5. Other Tools and Methods

### xremap (Rust-based, X11/Wayland)
- Written in Rust
- Supports both X11 and Wayland
- YAML configuration
- Application-specific remapping

### input-remapper (GUI tool)
- Provides both GUI and CLI interfaces
- Works with X11 and Wayland
- Can remap keys, mouse buttons, and gamepad inputs

### evremap (Rust-based)
- Simple evdev-based remapper
- Minimal dependencies
- System-wide remapping

## Best Practices

1. **For simple remapping**: Use udev/hwdb rules
2. **For complex behaviors**: Use keyd or xremap
3. **For GUI configuration**: Use input-remapper
4. **For push-to-talk**: Use keyd with monitoring or evdev with selective capture
5. **For LED control**: Use sysfs for simple control, evdev ioctls for programmatic control

## Troubleshooting

### Finding device information
```bash
# List input devices
sudo libinput list-devices

# Monitor all input events
sudo evtest

# Find keyboard device paths
ls -la /dev/input/by-id/*kbd*
```

### Debugging keyd
```bash
# Check service status
sudo systemctl status keyd

# View logs
sudo journalctl -u keyd -f

# Test configuration
sudo keyd reload
```

### Common issues
- **Changes not taking effect**: Restart keyd service or update hwdb
- **LED sync issues**: LEDs may not reflect actual lock states when remapped
- **Wayland restrictions**: Some methods only work with specific compositors
- **Device permissions**: May need to add user to `input` group or run as root