# Push2Type Tests

This directory contains BATS (Bash Automated Testing System) tests for the push2type project.

## Structure

- `test_helper.bash` - Common test helper functions and utilities
- `test_push2type.bats` - Tests for the main push2type script
- `test_setup.bats` - Tests for the setup.sh installation script

## Running Tests

### Prerequisites

Install BATS:
```bash
# Clone BATS
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local

# Or use package manager
sudo dnf install bats           # Fedora/RHEL
sudo apt install bats          # Ubuntu/Debian
```

### Run All Tests

```bash
# From project root
bats test/

# Or run specific test files
bats test/test_push2type.bats
bats test/test_setup.bats
```

### Run Tests Verbosely

```bash
bats -t test/
```

## Test Categories

### Push2Type Script Tests (`test_push2type.bats`)

- **Help and Usage**: Command-line argument parsing and help text
- **Dependency Checks**: Validation of required system dependencies
- **Configuration**: Environment variables and config file handling
- **Test Mode**: Audio recording and transcription testing functionality
- **Error Handling**: Graceful handling of missing dependencies and invalid configs

### Setup Script Tests (`test_setup.bats`)

- **Distribution Detection**: Automatic detection of Fedora/RHEL vs Ubuntu/Debian
- **Dependency Installation**: Package installation via dnf/apt-get
- **Keyd Installation**: Building and configuring keyd for key remapping
- **User Configuration**: Adding user to input group, API key setup
- **Audio Testing**: Recording and playback validation
- **Service Installation**: Optional systemd service setup

## Test Design Principles

### No Mocks Where Possible

Tests focus on real functionality rather than mocking:
- Uses actual command-line argument parsing
- Tests real dependency checking logic
- Validates actual file creation and permissions
- Uses timeout to prevent hanging on interactive operations

### Fake External Dependencies

For system-level operations that require privileges or external services:
- Creates fake `sudo` that executes commands without privilege escalation
- Implements fake package managers (`dnf`, `apt-get`) that simulate installation
- Uses fake `systemctl` for service management testing
- Creates minimal fake audio files for testing audio processing

### Isolated Test Environment

Each test runs in isolation:
- Creates temporary directories under `$BATS_TMPDIR`
- Overrides `$HOME` and config directories for testing
- Cleans up all test artifacts after each test
- Uses custom `$PATH` to control which tools are available

## Helper Functions

### Test Environment
- `setup_test_env()` - Creates isolated test environment
- `cleanup_test_env()` - Removes all test artifacts
- `create_test_api_key()` - Creates test API key configuration

### File Operations
- `create_test_audio_file()` - Generates minimal WAV files for testing
- `assert_file_exists()` - Validates file creation
- `create_test_keyd_config()` - Creates test keyd configuration

### Assertions
- `assert_success()` - Validates command succeeded (exit 0)
- `assert_failure()` - Validates command failed (non-zero exit)
- `assert_output_contains()` - Checks for expected text in output

### Conditional Testing
- `skip_if_missing()` - Skips tests when dependencies unavailable
- `skip_if_unsupported_platform()` - Skips non-Linux tests

## Test Data

Tests create minimal test data:
- **Audio files**: Simple WAV headers with silent audio data
- **Config files**: Basic API key and environment configurations
- **System configs**: Minimal keyd configurations for testing

## Continuous Integration

Tests are designed to run in CI environments:
- No root privileges required
- No real hardware dependencies (audio, keyboard)
- No network access required
- Fast execution (most tests complete in seconds)

## Troubleshooting

### Common Issues

**Tests hang**: Usually caused by interactive prompts. Use `timeout` wrapper or provide input via stdin.

**Permission errors**: Ensure test environment is properly isolated and fake `sudo` is working.

**Missing dependencies**: Use `skip_if_missing` for optional dependencies.

### Debug Mode

Run with verbose output:
```bash
bats -t test/test_setup.bats
```

Check test environment:
```bash
# Add to test for debugging
echo "TEST_DIR: $TEST_DIR" >&3
echo "PATH: $PATH" >&3
ls -la "$TEST_DIR" >&3
```

## Adding New Tests

1. **Identify functionality**: What specific behavior needs testing?
2. **Choose test file**: Add to existing file or create new one
3. **Setup test environment**: Use helper functions for isolation
4. **Write test**: Focus on real behavior, avoid mocking when possible
5. **Add assertions**: Validate both success and error cases
6. **Test edge cases**: Empty input, missing files, invalid configurations

Follow the existing patterns for consistency and maintainability.