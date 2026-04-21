# Core Daemon Patterns

## When to Load
Load when patch touches:
- `src/adapter.c`, `src/adapter.h` - Adapter management
- `src/device.c`, `src/device.h` - Device management
- `src/plugin.c`, `src/plugin.h` - Plugin infrastructure
- `src/main.c` - Daemon entry point
- `src/agent.c` - Pairing agent
- `src/storage.c` - Persistent storage
- `src/settings.c` - Configuration (main.conf)

## Key Files
- `src/adapter.c` - Adapter lifecycle, MGMT interaction, D-Bus interface
- `src/device.c` - Device lifecycle, connection management, D-Bus interface
- `src/plugin.c` - Plugin loading and registration
- `src/agent.c` - Pairing agent protocol
- `src/storage.c` - Key/device info persistence

## Core Patterns

### CORE-001: Adapter Lifecycle
**Risk**: Use-after-free, stale references

Adapters are created on MGMT index_added and removed on index_removed.

**Check**:
- [ ] All adapter references cleared on removal
- [ ] MGMT handlers unregistered on adapter removal
- [ ] D-Bus interface unregistered before adapter free
- [ ] Pending MGMT commands cancelled on removal
- [ ] Connected devices properly disconnected/cleaned

### CORE-002: Device Lifecycle
**Risk**: Callback-after-free, stale D-Bus objects

Devices persist across connections. Key lifecycle points:
- `device_create()` - allocate and register D-Bus
- `device_remove()` - unregister D-Bus and free
- `device_connect_le()` / `device_connect_profile()` - connect
- `device_request_disconnect()` - disconnect

**Check**:
- [ ] Profile probe/remove called symmetrically
- [ ] D-Bus interface unregistered before device free
- [ ] ATT/GATT cleanup on disconnect
- [ ] Pending operations cancelled on device removal
- [ ] Device not accessed after btd_device_unref drops to 0

### CORE-003: Plugin Registration
**Risk**: Missing cleanup, double registration

```c
static struct btd_profile profile = {
	.name		= "profile-name",
	.device_probe	= probe,
	.device_remove	= remove,
};
```

**Check**:
- [ ] btd_profile_register in init, btd_profile_unregister in exit
- [ ] probe allocates resources, remove frees them
- [ ] connect/disconnect properly paired
- [ ] accept callback handles incoming connections

### CORE-004: Agent Interaction
**Risk**: Pending agent request after device removal

**Check**:
- [ ] Agent requests cancelled on device removal
- [ ] Agent reply timeout handled
- [ ] No operations after agent unregistered

### CORE-005: Storage Operations
**Risk**: Data corruption, missing persistence

**Check**:
- [ ] Key information persisted after pairing
- [ ] Storage operations handle write failures
- [ ] Configuration reloaded correctly

## Quick Checks

- [ ] Adapter removal cleans up all resources
- [ ] Device removal unregisters D-Bus and cancels pending ops
- [ ] Profile probe/remove symmetric
- [ ] MGMT handlers registered/unregistered with adapter
- [ ] Storage writes handle errors
