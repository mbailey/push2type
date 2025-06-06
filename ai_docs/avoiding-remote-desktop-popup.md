# Avoiding Remote Desktop Confirmation Popup on Fedora

## Why This Popup Appears

The "Remote Desktop - Allow Remote Interaction" popup appears when applications try to programmatically control your desktop (simulate keyboard/mouse input). This is a security feature in modern Linux desktop environments, particularly:

1. **Wayland Security Model**: Wayland has stricter security than X11. Applications cannot freely control input devices without explicit permission.

2. **Portal System**: GNOME uses XDG Desktop Portals to mediate access to system resources. The `RemoteDesktop` portal requires user consent for input simulation.

3. **Protection Against Malware**: Prevents malicious applications from controlling your system without your knowledge.

## When Push2Type Triggers This

Push2Type uses `ydotool` (on Wayland) or `xdotool` (on X11) to paste transcribed text. On Wayland systems, this triggers the security prompt because:
- `ydotool` needs to simulate keyboard input
- The system wants to confirm you trust this application

## Solutions to Avoid the Popup

### 1. Use X11 Instead of Wayland (Temporary)
```bash
# Log out, then at login screen:
# Click gear icon → Select "GNOME on Xorg" or "X11"
```

### 2. Grant Permanent Permission (Recommended)

Unfortunately, GNOME doesn't currently offer a "remember this choice" option for the RemoteDesktop portal. However, you can:

#### For ydotool specifically:
```bash
# Ensure ydotoold daemon is running with proper permissions
sudo usermod -a -G input $USER
systemctl --user enable ydotool
systemctl --user start ydotool
```

### 3. Use Alternative Input Methods

#### Clipboard Method (No Popup)
Instead of simulating keystrokes, copy to clipboard:
```bash
# In push2type script, replace the paste_text function:
echo -n "$text" | wl-copy  # For Wayland
echo -n "$text" | xclip -selection clipboard  # For X11
```
Then manually paste with Ctrl+V.

#### D-Bus Method (Future)
Some applications are moving to D-Bus interfaces that don't trigger security prompts. This requires application-specific integration.

### 4. Disable Portal Prompts (Not Recommended)

**Warning**: This reduces system security.

```bash
# Create override for xdg-desktop-portal
mkdir -p ~/.config/systemd/user/xdg-desktop-portal.service.d/
cat > ~/.config/systemd/user/xdg-desktop-portal.service.d/override.conf << EOF
[Service]
Environment="GTK_USE_PORTAL=0"
EOF

systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal
```

### 5. Use InputPlumber (Experimental)

InputPlumber is a newer input management system that may handle permissions differently:
```bash
# Installation varies by distro
# Check: https://github.com/Supreeeme/InputPlumber
```

## Fedora-Specific Considerations

Fedora defaults to Wayland since Fedora 25, making this issue more common. Fedora's security-focused approach means:
- SELinux may add additional restrictions
- Stricter default permissions on /dev/input devices
- More frequent portal usage

## Best Practice Recommendation

For push2type users on Fedora:
1. Accept the popup when it first appears
2. Consider using X11 session if you use push2type frequently
3. Or modify push2type to use clipboard method instead of key simulation

## Technical Background

The popup is triggered by:
- `org.freedesktop.portal.RemoteDesktop` D-Bus interface
- Specifically the `CreateSession` and `SelectDevices` methods
- GNOME Shell handles the UI through `gnome-shell/js/ui/remoteAccess.js`

Currently, there's no API to pre-authorize applications, though this is being discussed in:
- https://github.com/flatpak/xdg-desktop-portal/issues/649
- https://gitlab.gnome.org/GNOME/gnome-shell/-/issues/4284