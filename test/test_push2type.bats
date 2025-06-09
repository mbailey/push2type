#!/usr/bin/env bats

# Load test helpers
load test_helper

# Setup and teardown
setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

# Help and Usage Tests
@test "displays help with --help flag" {
    run ./push2type --help
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "OPTIONS:"
    assert_output_contains "-d, --daemon"
    assert_output_contains "test"
}

@test "displays help with -h flag" {
    run ./push2type -h
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "OPTIONS:"
}

@test "displays help with help argument" {
    run ./push2type help
    assert_success
    assert_output_contains "Usage:"
}

@test "shows usage for invalid arguments" {
    run ./push2type --invalid-option
    assert_failure
    assert_output_contains "Usage:"
    assert_output_contains "Use"
    assert_output_contains "--help"
}

# Dependency Check Tests
@test "fails gracefully when dependencies are missing" {
    # Test with PATH that doesn't include required tools
    PATH="/usr/bin" run ./push2type test
    assert_failure
    assert_output_contains "Missing dependencies"
}

@test "detects missing API key" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    # Run without API key
    run ./push2type test
    assert_failure
    assert_output_contains "OPENAI_API_KEY"
}

# Configuration Tests
@test "loads API key from environment file" {
    skip_if_missing "arecord"
    skip_if_missing "curl" 
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key "test-key-from-file"
    
    # Should load API key from file and not complain about missing key
    run timeout 2 ./push2type test 2>&1 || true
    # Should not contain the "OPENAI_API_KEY environment variable not set" error
    [[ ! "$output" =~ "OPENAI_API_KEY environment variable not set" ]]
}

@test "respects custom recordings directory" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq" 
    skip_if_missing "evtest"
    
    create_test_api_key
    custom_dir="$TEST_DIR/custom_recordings"
    
    RECORDINGS_DIR="$custom_dir" run timeout 2 ./push2type test 2>&1 || true
    
    # Should create the custom directory
    [ -d "$custom_dir" ]
}

@test "respects custom minimum hold time" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    MIN_HOLD_TIME="0.5" run timeout 2 ./push2type test 2>&1 || true
    
    # Should mention the custom hold time in output
    assert_output_contains "0.5"
}

# Test Mode Tests  
@test "test mode validates dependencies" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    run timeout 5 ./push2type test 2>&1 || true
    
    assert_output_contains "Dependencies check passed"
    assert_output_contains "API key configured"
    assert_output_contains "Recordings directory"
}

@test "test mode creates recordings directory" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    run timeout 5 ./push2type test 2>&1 || true
    
    # Should create recordings directory
    assert_file_exists "$TEST_RECORDINGS_DIR"
}

@test "test mode attempts audio recording" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    run timeout 10 ./push2type test 2>&1 || true
    
    assert_output_contains "Testing audio recording"
    assert_output_contains "Recording 2 seconds"
}

# Audio Processing Tests
@test "creates recordings directory on startup" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    # Remove recordings dir to test creation
    rm -rf "$TEST_RECORDINGS_DIR"
    
    run timeout 2 ./push2type test 2>&1 || true
    
    assert_file_exists "$TEST_RECORDINGS_DIR"
}

# Configuration Validation Tests
@test "validates audio device configuration" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    # Test with invalid audio device
    AUDIO_DEVICE="nonexistent" run timeout 5 ./push2type test 2>&1 || true
    
    # Should still attempt to use the specified device
    # (arecord will fail, but script should try)
    assert_output_contains "Testing audio recording"
}

@test "handles missing keyboard device gracefully" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    # Test with non-existent keyboard device
    KEYBOARD_DEVICE="/dev/input/event999" run timeout 2 ./push2type 2>&1 || true
    
    assert_output_contains "Cannot read"
}

# Environment Variable Tests
@test "recognizes OPENAI_BASE_URL configuration" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    # Set custom API endpoint
    OPENAI_BASE_URL="http://localhost:8080" run timeout 2 ./push2type test 2>&1 || true
    
    # Script should run without complaining about missing API key
    [[ ! "$output" =~ "OPENAI_API_KEY environment variable not set" ]]
}

@test "handles audio compression settings" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    # Test with compression disabled
    COMPRESS_AUDIO="false" run timeout 2 ./push2type test 2>&1 || true
    
    # Should not warn about missing compression tools
    [[ ! "$output" =~ "No audio compression available" ]] || assert_output_contains "Testing audio recording"
}

# Error Handling Tests
@test "handles missing audio tools gracefully" {
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    # Remove arecord from PATH
    PATH="/usr/bin:/bin" run ./push2type test
    assert_failure
    assert_output_contains "Missing dependencies"
    assert_output_contains "alsa-utils"
}

@test "daemon mode requires valid environment" {
    skip_if_missing "arecord"
    skip_if_missing "curl"
    skip_if_missing "jq"
    skip_if_missing "evtest"
    
    create_test_api_key
    
    # Test daemon mode (should timeout since we can't provide real keyboard input)
    run timeout 2 ./push2type --daemon 2>&1 || true
    
    # Should start monitoring or complain about keyboard access
    assert_output_contains "Looking for keyd virtual keyboard" || assert_output_contains "Cannot read"
}