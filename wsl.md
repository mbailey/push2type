# Push2Type on WSL (Windows Subsystem for Linux)

## Problem

Push2Type doesn't work out-of-the-box on WSL because:

1. **Hardware access limitation**: WSL doesn't have direct access to physical keyboard hardware
2. **Key event interception**: Physical CapsLock presses are handled by Windows first, before reaching the Linux kernel
3. **keyd limitations**: While keyd runs successfully in WSL and can create a virtual keyboard, it cannot intercept the physical CapsLock key

## Diagnosis

When running on WSL:
- `keyd` service starts successfully and creates `/dev/input/event0` (keyd virtual keyboard)
- `push2type` finds the virtual keyboard device correctly
- Audio recording and transcription work fine
- But CapsLock presses never reach the Linux system to trigger recording

## Solutions

### Option 1: AutoHotkey (Recommended)

Use AutoHotkey on the Windows side to remap CapsLock to F24:

1. Download and install AutoHotkey from https://www.autohotkey.com/
2. Create a script file `push2type.ahk`:
   ```autohotkey
   CapsLock::F24
   ```
3. Run the script to activate the remapping
4. F24 events should now reach WSL and trigger push2type

### Option 2: Windows Registry Modification

Disable CapsLock in Windows entirely (requires reboot):

1. Run PowerShell as Administrator
2. Execute:
   ```powershell
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -PropertyType Binary -Value ([byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x00,0x00,0x3a,0x00,0x00,0x00,0x00,0x00))
   ```
3. Reboot Windows
4. Use a different key for push2type trigger

### Option 3: Alternative Trigger Key

Modify push2type to use a different key that WSL can detect:

1. Find a key that reaches WSL (test with `evtest`)
2. Update keyd configuration to map that key to F24
3. Modify the push2type script if needed

### Option 4: Native Windows Solution

Consider using a Windows-native voice transcription tool instead:
- Windows Speech Recognition
- Third-party tools like Dragon NaturallySpeaking
- Custom PowerShell script with Windows Speech API

## Testing

To verify if key events reach WSL:
```bash
# Monitor for any key events
sudo evtest /dev/input/event0

# Check if keyd is running
sudo systemctl status keyd

# Test push2type audio/transcription
push2type test
```

## Limitations

- WSL's hardware access is inherently limited
- Some input devices may not be accessible from WSL
- Performance may be slower than native Linux installation