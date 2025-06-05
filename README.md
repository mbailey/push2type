# Push2Type

Simple push-to-talk voice transcription for Linux. Hold CapsLock to record, release to transcribe and paste text anywhere.

## Features

- 🎤 **CapsLock as push-to-talk** - Hold to record, release to transcribe
- 🔤 **Accurate transcription** - Uses OpenAI Whisper API
- 📝 **Auto-paste** - Text appears where you're typing
- 💾 **Save recordings** - Audio and text files with timestamps
- 🖥️ **Works everywhere** - X11 and Wayland support
- ⚡ **Simple & reliable** - Pure bash, no complex dependencies

## Quick Start

1. **Install dependencies:**

   ```bash
   # Fedora/RHEL
   sudo dnf install alsa-utils evtest jq curl

   # Ubuntu/Debian
   sudo apt install alsa-utils evtest jq curl
   ```

2. **Run setup:**

   ```bash
   ./setup.sh
   ```

3. **Set your API key:**

   ```bash
   export OPENAI_API_KEY='your-openai-api-key'
   ```

4. **Start the daemon:**

   ```bash
   # Run directly
   ./push2type

   # Or as systemd service (if installed during setup)
   systemctl --user start push2type
   ```

5. **Use it:**
   - Hold **CapsLock** to record
   - Release **CapsLock** to transcribe and paste

## How It Works

1. **keyd** remaps CapsLock to F24 system-wide
2. **evtest** monitors F24 key events
3. **arecord** captures audio while key is held
4. **OpenAI Whisper** transcribes the audio
5. **ydotool/xdotool** pastes text into active application

## Files

- `push2type` - Complete daemon (CapsLock monitoring, recording, transcription)
- `setup.sh` - Installation script  
- `config/dot-config/systemd/user/push2type.service` - systemd service file

## Requirements

- Linux with ALSA audio
- OpenAI API key
- User in `input` group (setup script handles this)

## Troubleshooting

### CapsLock not working

```bash
# Check if keyd is running
sudo systemctl status keyd

# Test key mapping
sudo keyd monitor  # Press CapsLock, should show 'f24'
```

### No audio recording

```bash
# Test microphone
arecord -f cd -t wav test.wav

# List audio devices
arecord -l
```

### Find keyboard device

The daemon automatically detects the keyd virtual keyboard. If issues persist, check:

```bash
# Verify keyd is running
sudo systemctl status keyd

# List input devices  
ls -la /dev/input/event*
```

### Audio files location

Recordings are saved to `~/push2type_recordings/`

## Configuration

### Custom API endpoint

```bash
export OPENAI_BASE_URL='http://localhost:8080'  # For local Whisper
```

### Manual keyboard device

```bash
export KEYBOARD_DEVICE='/dev/input/event18'
./push2type
```

### Systemd service management

```bash
# User service commands
systemctl --user start push2type     # Start service
systemctl --user stop push2type      # Stop service
systemctl --user status push2type    # Check status
systemctl --user enable push2type    # Auto-start on login
systemctl --user disable push2type   # Disable auto-start

# View logs
journalctl --user -u push2type -f
```

## License

MIT

## Contributing

PRs welcome! This project values simplicity and reliability over features.

