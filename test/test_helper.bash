#!/usr/bin/env bash
# BATS test helper functions for push2type

# Setup test environment
setup_test_env() {
    export TEST_DIR="$BATS_TMPDIR/push2type_test"
    export TEST_RECORDINGS_DIR="$TEST_DIR/recordings"
    export TEST_CONFIG_DIR="$TEST_DIR/.config/push2type"
    
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_RECORDINGS_DIR" 
    mkdir -p "$TEST_CONFIG_DIR"
    
    # Override default directories for testing
    export RECORDINGS_DIR="$TEST_RECORDINGS_DIR"
    export HOME="$TEST_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# Create a test API key file
create_test_api_key() {
    local api_key="${1:-test-api-key-12345}"
    echo "OPENAI_API_KEY=$api_key" > "$TEST_CONFIG_DIR/environment"
    chmod 600 "$TEST_CONFIG_DIR/environment"
}

# Create a test audio file
create_test_audio_file() {
    local filename="${1:-test.wav}"
    local duration="${2:-1}"
    
    # Create a minimal WAV file with silence
    # WAV header for 1-second 44100Hz mono 16-bit
    if command -v dd >/dev/null; then
        # Create a simple WAV file with header
        {
            # RIFF header
            printf "RIFF"
            printf "\x24\x08\x00\x00"  # File size - 8
            printf "WAVE"
            
            # fmt chunk
            printf "fmt "
            printf "\x10\x00\x00\x00"  # fmt chunk size
            printf "\x01\x00"          # PCM format
            printf "\x01\x00"          # mono
            printf "\x44\xAC\x00\x00"  # 44100 Hz
            printf "\x88\x58\x01\x00"  # byte rate
            printf "\x02\x00"          # block align
            printf "\x10\x00"          # bits per sample
            
            # data chunk
            printf "data"
            printf "\x00\x08\x00\x00"  # data size
            
            # Silent audio data (2048 bytes of zeros for ~46ms at 44100Hz)
            dd if=/dev/zero bs=2048 count=1 2>/dev/null
        } > "$TEST_RECORDINGS_DIR/$filename"
    fi
}

# Check if file exists and has expected content
assert_file_exists() {
    local file="$1"
    [ -f "$file" ] || {
        echo "Expected file does not exist: $file"
        return 1
    }
}

# Check if string contains expected pattern
assert_output_contains() {
    local expected="$1"
    [[ "$output" =~ $expected ]] || {
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    }
}

# Check if command succeeded
assert_success() {
    [ "$status" -eq 0 ] || {
        echo "Expected command to succeed (exit 0), got exit $status"
        echo "Output: $output"
        return 1
    }
}

# Check if command failed
assert_failure() {
    [ "$status" -ne 0 ] || {
        echo "Expected command to fail (non-zero exit), got exit $status"
        echo "Output: $output"
        return 1
    }
}

# Skip test if dependency is missing
skip_if_missing() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null; then
        skip "$cmd not available"
    fi
}

# Skip test if not on supported platform
skip_if_unsupported_platform() {
    case "$(uname -s)" in
        Linux) return 0 ;;
        *) skip "Test only supported on Linux" ;;
    esac
}

# Create minimal keyd config for testing
create_test_keyd_config() {
    local config_dir="$TEST_DIR/etc/keyd"
    mkdir -p "$config_dir"
    cat > "$config_dir/default.conf" << 'EOF'
[ids]
*

[main]
capslock = f24
EOF
}