# Push2Type Daemon Architecture

## Overview

The push2type daemon architecture solves the keyboard lockup issue by using a proper system-level key remapping approach instead of grabbing the entire keyboard device.

## Key Components

### 1. keyd - System Key Remapper
- Remaps CapsLock to F13 at the kernel level
- Works before any application sees the key events
- Allows normal keyboard operation while push2type monitors F13
- No keyboard grabbing required

### 2. push2type-daemon
- Monitors F13 key events (the remapped CapsLock)
- Controls CapsLock LED to indicate recording status
- Runs as a systemd service
- Does NOT grab the keyboard device

### 3. LED Control
- Uses sysfs interface `/sys/class/leds/*/brightness`
- Udev rules grant input group access to LED control
- Provides visual feedback during recording

### 4. systemd Service
- Runs as user service with `@` template
- Starts on boot if enabled
- Manages environment variables (API keys)
- Provides logging via journald

## Data Flow

1. User presses CapsLock
2. keyd intercepts and converts to F13
3. push2type-daemon detects F13 press
4. Daemon turns on CapsLock LED and starts recording
5. User releases CapsLock
6. keyd converts release to F13 release
7. Daemon stops recording, turns off LED
8. Audio sent to Whisper API
9. Text pasted or copied to clipboard

## Advantages Over Standalone Mode

1. **No Keyboard Grabbing**: Keyboard remains fully functional
2. **System Integration**: Works across all applications
3. **LED Feedback**: Visual recording indicator
4. **Background Service**: No need to start/stop manually
5. **Crash Recovery**: systemd restarts on failure
6. **Proper Permissions**: Runs with minimal privileges

## Security Considerations

1. **Input Group**: Required for reading keyboard events
2. **LED Access**: Controlled via udev rules
3. **API Keys**: Stored in systemd service environment
4. **Temporary Files**: Audio stored briefly in /tmp
5. **No Root Required**: Runs as user service

## Configuration Files

- `/etc/keyd/default.conf` - Key remapping configuration
- `/etc/systemd/system/push2type@.service` - Service definition
- `/etc/udev/rules.d/99-push2type-leds.rules` - LED permissions

## Troubleshooting

Common issues and solutions:

1. **Keyboard not working**: keyd not installed/running
2. **No LED feedback**: Check udev rules and permissions
3. **Service won't start**: Check API key configuration
4. **No paste on Wayland**: Start ydotoold daemon
5. **CapsLock still toggles**: keyd configuration issue