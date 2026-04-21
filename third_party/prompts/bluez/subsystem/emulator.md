# Emulator Subsystem Patterns

## When to Load
Load when patch touches:
- `emulator/` directory
- `emulator/btdev.c` - virtual Bluetooth controller
- `emulator/bthost.c` - virtual remote host
- `emulator/hciemu.c` - HCI emulation framework
- `src/shared/tester.c` - test framework

## Key Files
- `emulator/btdev.c` - Virtual controller (command processing, event generation)
- `emulator/bthost.c` - Virtual remote host (L2CAP, ATT, SMP)
- `emulator/hciemu.c` - Manages btdev+bthost pairs
- `emulator/vhci.c` - Virtual HCI transport
- `src/shared/tester.c` - Test harness

## Emulator Patterns

### EMU-001: btdev Command Handling
**Risk**: Incorrect event generation, spec violations

btdev processes HCI commands and generates events:

```c
static void cmd_handler(struct btdev *btdev, uint16_t opcode,
				const void *data, uint8_t len)
```

**Check**:
- [ ] Command parameter length validated
- [ ] Event generated matches expected response
- [ ] Status codes correct per HCI specification
- [ ] Command complete vs command status used correctly

### EMU-002: bthost Protocol Implementation
**Risk**: Incorrect pairing, connection behavior

bthost implements the remote side of protocols for testing.

**Check**:
- [ ] L2CAP signaling correct (connect req/rsp, config)
- [ ] SMP pairing follows specification flow
- [ ] ATT responses match request types

### EMU-003: Test Framework Usage
**Risk**: Test leaks, incomplete cleanup

```c
tester_add("Test Name", test_data, setup, test_func, teardown);
```

**Check**:
- [ ] teardown frees all test resources
- [ ] tester_test_passed/failed called on all paths
- [ ] tester_teardown_complete called in teardown
- [ ] Test timeouts set appropriately

## Quick Checks

- [ ] HCI command handlers validate parameter length
- [ ] Events match HCI specification
- [ ] Test teardown complete on all paths
- [ ] Emulator cleanup frees all allocated resources
