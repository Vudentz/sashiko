# Monitor (btmon) Subsystem Patterns

## When to Load
Load when patch touches:
- `monitor/` directory
- btmon packet decoding/display
- Protocol analyzers (ATT, L2CAP, SDP, AVCTP, AVDTP, etc.)

## Key Files
- `monitor/main.c` - btmon entry point
- `monitor/packet.c` - Main packet decoding dispatch
- `monitor/bt.h` - HCI definitions
- `monitor/l2cap.c` - L2CAP decoding
- `monitor/att.c` - ATT/GATT decoding
- `monitor/avctp.c` - AVCTP decoding
- `monitor/avdtp.c` - AVDTP decoding
- `monitor/sdp.c` - SDP decoding

## Monitor Patterns

### MON-001: Packet Parsing Safety
**Risk**: Buffer overread, crash on malformed packets

btmon processes untrusted data from HCI captures.

```c
/* CORRECT - validate before reading */
if (size < sizeof(struct bt_hci_evt_hdr))
	return;
```

**Check**:
- [ ] Every packet parser validates minimum size
- [ ] Variable-length fields checked before access
- [ ] Nested protocol parsing (L2CAP inside HCI) validates inner length
- [ ] String fields bounded and null-terminated

### MON-002: Display/Print Safety
**Risk**: Format string issues, truncation

**Check**:
- [ ] printf-style functions use correct format specifiers
- [ ] Buffer sizes adequate for formatted output
- [ ] UTF-8 strings validated before display

### MON-003: Protocol State Tracking
**Risk**: Incorrect decoding due to stale state

btmon tracks connection state to decode higher-layer protocols.

**Check**:
- [ ] Connection handle lookups handle unknown handles
- [ ] Protocol multiplexing (CID/PSM) correctly resolved
- [ ] State cleaned up on disconnect events

## Quick Checks

- [ ] All packet parsers validate size before reading
- [ ] No unbounded string reads from packet data
- [ ] Connection state tracked correctly
- [ ] Display formatting handles all edge cases
