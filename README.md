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

1. **Run setup:**

   ```bash
   # Clone and run
   git clone https://github.com/mbailey/push2type.git
   cd push2type
   ./setup.sh
   ```

   Or run directly:
   ```bash
   curl -sSL https://raw.githubusercontent.com/mbailey/push2type/master/setup.sh | bash
   ```

   This will install all required dependencies and configure your system.

2. **API key configuration:**

   The setup script will prompt for your OpenAI API key and save it to `~/.config/push2type/environment`.
   
   If you need to update it later:
   ```bash
   echo "OPENAI_API_KEY=your-openai-api-key" > ~/.config/push2type/environment
   chmod 600 ~/.config/push2type/environment
   ```

3. **Start the daemon:**

   ```bash
   # As systemd service (recommended)
   systemctl --user start push2type

   # Or run directly
   push2type
   ```

4. **Use it:**
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
- `push2type.service` - systemd service file

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

## Auto-start on Login

To have push2type start automatically when you log in:

```bash
# Enable and start the service
systemctl --user enable --now push2type

# Verify it's running
systemctl --user status push2type
```

To disable auto-start:
```bash
systemctl --user disable push2type
```

## Configuration

### Custom API endpoint

```bash
export OPENAI_BASE_URL='http://localhost:8080'  # For local Whisper
```

### Manual keyboard device

```bash
export KEYBOARD_DEVICE='/dev/input/event18'
push2type
```

### Systemd service management

```bash
# User service commands
systemctl --user start push2type     # Start service
systemctl --user stop push2type      # Stop service
systemctl --user status push2type    # Check status
systemctl --user restart push2type   # Restart service

# View logs
journalctl --user -u push2type -f
```

## Uninstalling

To remove push2type from your system:

```bash
# Stop and disable the service (if installed)
systemctl --user stop push2type
systemctl --user disable push2type

# Remove files
rm -f ~/.local/bin/push2type
rm -f ~/.config/systemd/user/push2type.service
rm -rf ~/.config/push2type
rm -rf ~/push2type_recordings

# Remove keyd configuration
sudo rm -f /etc/keyd/default.conf
sudo systemctl restart keyd

# Remove user from input group (optional)
sudo gpasswd -d $USER input
```

## License

MIT

## Contributing

PRs welcome! This project values simplicity and reliability over features.

