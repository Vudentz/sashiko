# Client (bluetoothctl) Subsystem Patterns

## When to Load
Load when patch touches:
- `client/` directory
- bluetoothctl commands and interaction

## Key Files
- `client/main.c` - bluetoothctl entry point and command dispatch
- `client/admin.c` - Admin policy commands
- `client/advertising.c` - LE advertising commands
- `client/gatt.c` - GATT commands
- `client/player.c` - Media player commands
- `client/transport.c` - Media transport commands

## Client Patterns

### CLIENT-001: D-Bus Proxy Usage
**Risk**: Stale proxy, use-after-free

bluetoothctl uses GDBusProxy to interact with bluetoothd:

**Check**:
- [ ] Proxy validity checked before use
- [ ] Proxy removed handler cleans up references
- [ ] No proxy operations after removal notification

### CLIENT-002: Command Input Handling
**Risk**: Buffer overflow, format string

**Check**:
- [ ] User input properly validated
- [ ] String arguments bounds-checked
- [ ] Format strings not constructed from user input

### CLIENT-003: Interactive Shell
**Risk**: Readline callback issues

**Check**:
- [ ] Completion functions handle partial/empty input
- [ ] Shell state consistent across commands
- [ ] Async command results displayed correctly

## Quick Checks

- [ ] D-Bus proxy checked for validity
- [ ] User input validated
- [ ] Async results properly handled
