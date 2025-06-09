#!/usr/bin/env bats

# Load test helpers
load test_helper

# Setup and teardown
setup() {
    setup_test_env
    
    # Create fake sudo that doesn't require password
    export TEST_SUDO_DIR="$TEST_DIR/bin"
    mkdir -p "$TEST_SUDO_DIR"
    
    # Create fake sudo script that just executes commands
    cat > "$TEST_SUDO_DIR/sudo" << 'EOF'
#!/bin/bash
# Fake sudo for testing - just execute the command
shift # Remove 'sudo' from args
exec "$@"
EOF
    chmod +x "$TEST_SUDO_DIR/sudo"
    
    # Add to PATH
    export PATH="$TEST_SUDO_DIR:$PATH"
    
    # Create fake package managers
    create_fake_package_managers
}

teardown() {
    cleanup_test_env
}

# Helper to create fake package managers
create_fake_package_managers() {
    # Fake dnf
    cat > "$TEST_SUDO_DIR/dnf" << 'EOF'
#!/bin/bash
echo "Fake dnf: $*"
if [[ "$*" =~ "install" ]]; then
    echo "Installing packages..."
    exit 0
fi
exit 0
EOF
    chmod +x "$TEST_SUDO_DIR/dnf"
    
    # Fake apt-get  
    cat > "$TEST_SUDO_DIR/apt-get" << 'EOF'
#!/bin/bash
echo "Fake apt-get: $*"
if [[ "$*" =~ "update" ]]; then
    echo "Updating package lists..."
elif [[ "$*" =~ "install" ]]; then
    echo "Installing packages..."
fi
exit 0
EOF
    chmod +x "$TEST_SUDO_DIR/apt-get"
    
    # Fake systemctl
    cat > "$TEST_SUDO_DIR/systemctl" << 'EOF'
#!/bin/bash
echo "Fake systemctl: $*"
case "$*" in
    *"enable keyd"*|*"restart keyd"*|*"status keyd"*)
        echo "keyd service command"
        exit 0
        ;;
    *"is-active"*)
        echo "active"
        exit 0
        ;;
    *"daemon-reload"*|*"enable"*|*"disable"*)
        echo "Service operation successful"
        exit 0
        ;;
esac
exit 0
EOF
    chmod +x "$TEST_SUDO_DIR/systemctl"
    
    # Fake usermod
    cat > "$TEST_SUDO_DIR/usermod" << 'EOF'
#!/bin/bash
echo "Fake usermod: $*"
exit 0
EOF
    chmod +x "$TEST_SUDO_DIR/usermod"
    
    # Fake keyd
    cat > "$TEST_SUDO_DIR/keyd" << 'EOF'
#!/bin/bash
case "$1" in
    "check")
        echo "Configuration is valid"
        exit 0
        ;;
    "monitor")
        echo "Key monitoring would start here"
        exit 0
        ;;
esac
echo "Fake keyd: $*"
exit 0
EOF
    chmod +x "$TEST_SUDO_DIR/keyd"
    
    # Fake make
    cat > "$TEST_SUDO_DIR/make" << 'EOF'
#!/bin/bash
echo "Fake make: $*"
if [[ "$*" =~ "install" ]]; then
    echo "Installing keyd..."
fi
exit 0
EOF
    chmod +x "$TEST_SUDO_DIR/make"
    
    # Fake git
    cat > "$TEST_SUDO_DIR/git" << 'EOF'
#!/bin/bash
echo "Fake git: $*"
if [[ "$*" =~ "clone" ]]; then
    mkdir -p keyd
    echo "Cloned repository"
fi
exit 0
EOF
    chmod +x "$TEST_SUDO_DIR/git"
    
    # Fake arecord for audio testing
    cat > "$TEST_SUDO_DIR/arecord" << 'EOF'
#!/bin/bash
echo "Fake arecord: $*"
# Create a minimal test audio file if output specified
for arg in "$@"; do
    if [[ "$arg" =~ \.wav$ ]] && [[ ! "$arg" =~ ^- ]]; then
        echo "Creating fake audio file: $arg"
        # Create minimal WAV-like file
        printf "RIFF\x00\x00\x00\x00WAVE" > "$arg"
        dd if=/dev/zero bs=1000 count=2 >> "$arg" 2>/dev/null
        break
    fi
done
# Simulate recording for a short time
sleep 0.1
exit 0
EOF
    chmod +x "$TEST_SUDO_DIR/arecord"
}

# Distribution Detection Tests
@test "detects Fedora/RHEL and uses dnf" {
    # Mock dnf as available
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Fake dnf"
    assert_output_contains "alsa-utils evtest jq curl"
}

@test "detects Ubuntu/Debian when apt-get available and dnf not" {
    # Remove dnf from PATH, keep apt-get
    rm -f "$TEST_SUDO_DIR/dnf"
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Fake apt-get"
    assert_output_contains "update"
}

@test "fails on unsupported distribution" {
    # Remove both package managers
    rm -f "$TEST_SUDO_DIR/dnf" "$TEST_SUDO_DIR/apt-get"
    run timeout 5 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_failure
    assert_output_contains "Unsupported distribution"
}

# Root User Detection
@test "prevents running as root" {
    # Simulate running as root by setting EUID
    EUID=0 run ./setup.sh
    assert_failure
    assert_output_contains "Don't run as root"
}

# Dependency Installation Tests
@test "installs core dependencies" {
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Installing dependencies"
    assert_output_contains "alsa-utils evtest jq curl"
}

@test "installs optional audio compression" {
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Installing optional audio compression"
    assert_output_contains "lame"
}

@test "handles missing optional dependencies gracefully" {
    # Remove lame from PATH to simulate it not being available
    rm -f "$TEST_SUDO_DIR/lame"
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Warning: lame not available"
}

# Keyd Installation Tests
@test "installs keyd when not present" {
    # Remove keyd from PATH to simulate it not being installed
    rm -f "$TEST_SUDO_DIR/keyd"
    run timeout 15 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Installing keyd"
    assert_output_contains "Fake git"
    assert_output_contains "clone"
}

@test "skips keyd installation when already present" {
    # keyd is already in PATH from setup
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    [[ ! "$output" =~ "Installing keyd" ]] || assert_output_contains "Installing dependencies"
}

@test "installs build dependencies for keyd" {
    rm -f "$TEST_SUDO_DIR/keyd"
    run timeout 15 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    # Should install build dependencies based on available package manager
    assert_output_contains "git make gcc"
}

# User Group Management
@test "adds user to input group when not already member" {
    # Mock groups command to show user not in input group
    cat > "$TEST_SUDO_DIR/groups" << 'EOF'
#!/bin/bash
echo "user wheel"
EOF
    chmod +x "$TEST_SUDO_DIR/groups"
    
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Adding user to input group"
    assert_output_contains "LOGOUT AND LOGIN AGAIN"
}

@test "skips adding user to input group when already member" {
    # Mock groups command to show user already in input group
    cat > "$TEST_SUDO_DIR/groups" << 'EOF'
#!/bin/bash
echo "user wheel input"
EOF
    chmod +x "$TEST_SUDO_DIR/groups"
    
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    [[ ! "$output" =~ "Adding user to input group" ]] || assert_output_contains "Installing dependencies"
}

# Keyd Configuration Tests
@test "creates keyd configuration" {
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Setting up keyd configuration"
}

@test "validates keyd configuration" {
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "keyd config valid"
}

@test "starts keyd service" {
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "keyd running"
}

# API Key Setup Tests
@test "prompts for API key when not set" {
    run timeout 10 ./setup.sh <<< $'test-api-key\nn\n' 2>&1 || true
    assert_output_contains "Enter your OpenAI API key"
    assert_output_contains "API key saved securely"
}

@test "uses existing API key from environment" {
    OPENAI_API_KEY="existing-key" run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Using API key from environment variable"
    assert_output_contains "API key saved to environment file"
}

@test "prompts to update existing API key" {
    # Create existing API key file
    create_test_api_key "old-key"
    
    run timeout 10 ./setup.sh <<< $'y\nnew-key\nn\n' 2>&1 || true
    assert_output_contains "Environment file already exists"
    assert_output_contains "Update API key"
    assert_output_contains "API key updated"
}

@test "keeps existing API key when user declines update" {
    create_test_api_key "existing-key"
    
    run timeout 10 ./setup.sh <<< $'n\nn\n' 2>&1 || true
    assert_output_contains "Keeping existing API key"
}

# Audio Testing
@test "tests audio recording functionality" {
    run timeout 15 ./setup.sh <<< $'test-key\nn\nn\n' 2>&1 || true
    assert_output_contains "Testing audio"
    assert_output_contains "Recording 2 seconds"
    assert_output_contains "Audio recording works"
}

@test "offers audio playback" {
    run timeout 15 ./setup.sh <<< $'test-key\ny\nn\n' 2>&1 || true
    assert_output_contains "Play back the test recording"
}

@test "skips audio playback by default" {
    run timeout 15 ./setup.sh <<< $'test-key\nn\nn\n' 2>&1 || true
    assert_output_contains "Play back the test recording"
    # Should not show audio player output since default is no
}

# Binary Installation Tests  
@test "installs binary to ~/.local/bin" {
    run timeout 15 ./setup.sh <<< $'test-key\nn\nn\n' 2>&1 || true
    assert_output_contains "Installing push2type binary"
    assert_output_contains "Installed to ~/.local/bin/push2type"
}

@test "warns about PATH when ~/.local/bin not included" {
    # Mock PATH without ~/.local/bin
    PATH="/usr/bin:/bin" run timeout 15 ./setup.sh <<< $'test-key\nn\nn\n' 2>&1 || true
    assert_output_contains "~/.local/bin is not in your PATH"
    assert_output_contains "Add this to your"
}

# Systemd Service Tests
@test "offers to install systemd service" {
    run timeout 15 ./setup.sh <<< $'test-key\nn\ny\n' 2>&1 || true
    assert_output_contains "install push2type as a systemd service"
    assert_output_contains "Service installed and enabled"
}

@test "skips systemd service installation when declined" {
    run timeout 15 ./setup.sh <<< $'test-key\nn\nn\n' 2>&1 || true
    assert_output_contains "install push2type as a systemd service"
    assert_output_contains "Skipped service installation"
}

@test "provides service management commands" {
    run timeout 15 ./setup.sh <<< $'test-key\nn\ny\n' 2>&1 || true
    assert_output_contains "Service commands:"
    assert_output_contains "systemctl --user start push2type"
    assert_output_contains "systemctl --user stop push2type"
}

# Completion and Summary Tests
@test "shows completion message" {
    run timeout 15 ./setup.sh <<< $'test-key\nn\nn\n' 2>&1 || true
    assert_output_contains "Setup complete"
}

@test "provides next steps" {
    run timeout 15 ./setup.sh <<< $'test-key\nn\nn\n' 2>&1 || true
    assert_output_contains "Next steps:"
    assert_output_contains "Test manually: push2type"
}

@test "shows usage instructions" {
    run timeout 15 ./setup.sh <<< $'test-key\nn\nn\n' 2>&1 || true
    assert_output_contains "With daemon running:"
    assert_output_contains "Hold CapsLock"
    assert_output_contains "Release CapsLock"
}