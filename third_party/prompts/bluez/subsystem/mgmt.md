# MGMT Interface Patterns

## When to Load
Load when patch touches:
- `src/shared/mgmt.c`, `src/shared/mgmt.h` - MGMT client
- `src/adapter.c` - adapter management (heavy MGMT user)
- `lib/mgmt.h` - MGMT command/event definitions
- Any code using `mgmt_send()`, `mgmt_register()`

## Key Files
- `src/shared/mgmt.c` - Kernel management interface client
- `lib/mgmt.h` - MGMT protocol definitions (commands, events, structures)
- `src/adapter.c` - Primary consumer of MGMT interface

## MGMT Patterns

### MGMT-001: Command Send/Response
**Risk**: Callback-after-free, unhandled responses

```c
id = mgmt_send(mgmt, opcode, index, length, param,
			callback, user_data, destroy);
if (!id) {
	/* Send failed */
}
```

**Check**:
- [ ] Return value checked (0 = failure)
- [ ] user_data valid until callback or destroy
- [ ] destroy callback frees user_data
- [ ] Response callback handles all status codes

### MGMT-002: Event Registration
**Risk**: Stale handlers, missed events

```c
id = mgmt_register(mgmt, event_code, index,
			callback, user_data, destroy);
```

**Check**:
- [ ] Registration ID stored for cleanup
- [ ] Unregistered in adapter/device removal
- [ ] Handler checks adapter index matches
- [ ] Event data length validated before parsing

### MGMT-003: MGMT Data Structures
**Risk**: Buffer overflow, incorrect packing

MGMT structures are packed and use fixed sizes:
```c
struct mgmt_cp_set_powered {
	uint8_t val;
} __attribute__((packed));
```

**Check**:
- [ ] Command parameter structure size matches length argument
- [ ] Event data cast to correct structure type
- [ ] Variable-length event data has bounds checks
- [ ] Byte order correct (MGMT uses little-endian)

### MGMT-004: Adapter Index Management
**Risk**: Operating on wrong adapter

**Check**:
- [ ] Correct adapter index used in all MGMT calls
- [ ] MGMT_INDEX_NONE used for non-adapter commands
- [ ] Index checked in event handlers (could be for different adapter)

## Quick Checks

- [ ] All mgmt_send calls check return value
- [ ] All mgmt_register calls store ID for cleanup
- [ ] MGMT event data length validated
- [ ] Correct adapter index in all operations
- [ ] Command parameter structures correctly packed
