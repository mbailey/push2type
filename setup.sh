#!/bin/bash
# Simple setup script for push2type with CapsLock hotkey

# set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Push2Type Simple Setup${NC}"
echo "====================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  echo -e "${RED}Don't run as root!${NC}"
  exit 1
fi

# 1. Install dependencies
echo -e "\n${YELLOW}Installing dependencies...${NC}"

# Detect distro
if command -v dnf >/dev/null; then
  # Fedora/RHEL
  sudo dnf install -y alsa-utils evtest jq curl
  # Optional: Install audio compression for faster uploads
  echo -e "\n${YELLOW}Installing optional audio compression (recommended)...${NC}"
  sudo dnf install -y lame || echo "Warning: lame not available - uploads will be slower"
elif command -v apt-get >/dev/null; then
  # Ubuntu/Debian
  sudo apt-get update
  sudo apt-get install -y alsa-utils evtest jq curl
  # Optional: Install audio compression for faster uploads
  echo -e "\n${YELLOW}Installing optional audio compression (recommended)...${NC}"
  sudo apt-get install -y lame || echo "Warning: lame not available - uploads will be slower"
else
  echo -e "${RED}Unsupported distribution. Please install manually: alsa-utils evtest jq curl lame${NC}"
  exit 1
fi

# 2. Install keyd if not present
if ! command -v keyd >/dev/null; then
  echo -e "\n${YELLOW}Installing keyd...${NC}"

  # Install build deps
  if command -v dnf >/dev/null; then
    sudo dnf install -y git make gcc kernel-headers
  elif command -v apt-get >/dev/null; then
    sudo apt-get install -y git make gcc linux-headers-$(uname -r)
  fi

  # Build and install keyd
  cd /tmp
  git clone https://github.com/rvaiya/keyd.git
  cd keyd
  make
  sudo make install
  sudo systemctl enable keyd
  cd - >/dev/null
  rm -rf /tmp/keyd
fi

# 3. Add user to input group
if ! groups | grep -q '\binput\b'; then
  echo -e "\n${YELLOW}Adding user to input group...${NC}"
  sudo usermod -a -G input "$USER"
  echo -e "${RED}You need to logout and login again!${NC}"
  NEED_RELOGIN=true
fi

# 4. Setup keyd config
echo -e "\n${YELLOW}Setting up keyd configuration...${NC}"
sudo mkdir -p /etc/keyd

cat <<'EOF' | sudo tee /etc/keyd/default.conf
# keyd configuration for push2type
[ids]
*

[main]
capslock = f24
EOF

echo "" | sudo tee -a /etc/keyd/default.conf >/dev/null

# Test and start keyd
if keyd check; then
  echo -e "${GREEN}✓ keyd config valid${NC}"
  sudo systemctl restart keyd
  if systemctl is-active --quiet keyd; then
    echo -e "${GREEN}✓ keyd running${NC}"
  else
    echo -e "${RED}✗ keyd failed to start${NC}"
    sudo journalctl -u keyd -n 10
    exit 1
  fi
else
  echo -e "${RED}✗ keyd config invalid${NC}"
  exit 1
fi

# 5. Setup API key
echo -e "\n${YELLOW}OpenAI API Key Setup${NC}"
mkdir -p ~/.config/push2type

if [[ -f ~/.config/push2type/environment ]]; then
  echo "Environment file already exists: ~/.config/push2type/environment"
  echo -n "Update API key? [y/N] "
  read -r update_key
  if [[ ! "$update_key" =~ ^[Yy]$ ]]; then
    echo "Keeping existing API key"
  else
    echo -n "Enter your OpenAI API key: "
    read -r -s api_key
    echo
    echo "OPENAI_API_KEY=$api_key" >~/.config/push2type/environment
    chmod 600 ~/.config/push2type/environment
    echo -e "${GREEN}✓ API key updated${NC}"
  fi
else
  if [[ -n "$OPENAI_API_KEY" ]]; then
    echo "Using API key from environment variable"
    echo "OPENAI_API_KEY=$OPENAI_API_KEY" >~/.config/push2type/environment
    chmod 600 ~/.config/push2type/environment
    echo -e "${GREEN}✓ API key saved to environment file${NC}"
  else
    echo -n "Enter your OpenAI API key: "
    read -r -s api_key
    echo
    if [[ -n "$api_key" ]]; then
      echo "OPENAI_API_KEY=$api_key" >~/.config/push2type/environment
      chmod 600 ~/.config/push2type/environment
      echo -e "${GREEN}✓ API key saved securely${NC}"
    else
      echo -e "${RED}No API key provided${NC}"
      echo "You can set it later by running:"
      echo "echo 'OPENAI_API_KEY=your-key' > ~/.config/push2type/environment"
      echo "chmod 600 ~/.config/push2type/environment"
    fi
  fi
fi

# 6. Test audio
echo -e "\n${YELLOW}Testing audio...${NC}"
echo "Recording 2 seconds of test audio..."

arecord -D default -f S16_LE -r 44100 -c 1 -t wav /tmp/audio_test.wav &
RECORD_PID=$!
sleep 2
kill $RECORD_PID 2>/dev/null
wait $RECORD_PID 2>/dev/null

if [[ -f /tmp/audio_test.wav ]]; then
  FILE_SIZE=$(stat -c%s /tmp/audio_test.wav)
  if [[ $FILE_SIZE -gt 1000 ]]; then
    echo -e "${GREEN}✓ Audio recording works (${FILE_SIZE} bytes)${NC}"
    
    # Offer to play back the recording
    echo -n "Play back the test recording? [y/N] "
    read -r play_audio
    if [[ "$play_audio" =~ ^[Yy]$ ]]; then
      # Try different audio players
      if command -v aplay >/dev/null; then
        aplay /tmp/audio_test.wav 2>/dev/null
      elif command -v mpv >/dev/null; then
        mpv --no-video /tmp/audio_test.wav 2>/dev/null
      elif command -v ffplay >/dev/null; then
        ffplay -nodisp -autoexit /tmp/audio_test.wav 2>/dev/null
      elif command -v paplay >/dev/null; then
        paplay /tmp/audio_test.wav 2>/dev/null
      else
        echo "No audio player found. Test file saved at: /tmp/audio_test.wav"
      fi
    fi
  else
    echo -e "${RED}✗ Audio file too small - check microphone${NC}"
  fi
else
  echo -e "${RED}✗ Audio recording failed${NC}"
fi

# 7. Install binary
echo -e "\n${YELLOW}Installing push2type binary...${NC}"

# Make executable
chmod +x push2type

# Install to ~/.local/bin (XDG standard for user binaries)
mkdir -p "$HOME/.local/bin"

# Create symlink (allows easy updates from git repo)
ln -sf "$PWD/push2type" "$HOME/.local/bin/push2type"

echo -e "${GREEN}✓ Installed to ~/.local/bin/push2type${NC}"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo -e "${YELLOW}Note: ~/.local/bin is not in your PATH${NC}"
  echo "Add this to your ~/.bashrc or ~/.bash_profile:"
  echo 'export PATH="$HOME/.local/bin:$PATH"'
fi

# 8. Optional systemd service setup
echo -e "\n${YELLOW}Systemd service setup (optional)${NC}"
echo "Do you want to install push2type as a systemd service?"
echo "This will start automatically on login and run in background."
echo -n "Install service? [y/N] "
read -r install_service

if [[ "$install_service" =~ ^[Yy]$ ]]; then
  # Create user service directory
  mkdir -p ~/.config/systemd/user

  # Copy service file with correct paths
  SERVICE_FILE="$HOME/.config/systemd/user/push2type.service"
  cp push2type.service "$SERVICE_FILE"

  # Replace %h with actual home directory in service file
  sed -i "s|%h|$HOME|g" "$SERVICE_FILE"
  sed -i "s|%i|$USER|g" "$SERVICE_FILE"

  # Reload and enable service
  systemctl --user daemon-reload
  systemctl --user enable push2type.service

  echo -e "${GREEN}✓ Service installed and enabled${NC}"
  echo "Service will start automatically on next login"
  echo
  echo "Service commands:"
  echo "  Start:   systemctl --user start push2type"
  echo "  Stop:    systemctl --user stop push2type"
  echo "  Status:  systemctl --user status push2type"
  echo "  Logs:    journalctl --user -u push2type -f"
else
  echo "Skipped service installation"
fi

echo -e "\n${GREEN}Setup complete!${NC}"
echo
echo "Next steps:"
if [[ "$NEED_RELOGIN" == "true" ]]; then
  echo -e "1. ${RED}LOGOUT AND LOGIN AGAIN${NC} (for input group)"
fi
echo "2. Verify API key is set: cat ~/.config/push2type/environment"
echo "3. Test manually: push2type"

if [[ "$install_service" =~ ^[Yy]$ ]]; then
  echo "4. Start service: systemctl --user start push2type"
  echo "   Or logout/login to start automatically"
else
  echo "4. Run daemon: push2type"
fi

echo
echo "With daemon running:"
echo "- Hold CapsLock = start recording"
echo "- Release CapsLock = stop, transcribe, paste"
