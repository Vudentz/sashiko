# LE Audio Subsystem Patterns

## When to Load
Load when patch touches:
- `src/shared/bap.c`, `src/shared/bap.h` - Basic Audio Profile
- `src/shared/bass.c` - Broadcast Audio Scan Service
- `src/shared/vcp.c` - Volume Control Profile
- `src/shared/mcp.c` - Media Control Profile
- `src/shared/micp.c` - Microphone Control Profile
- `src/shared/csip.c` - Coordinated Set Identification Profile
- `src/shared/tmap.c` - Telephony and Media Audio Profile
- `src/shared/gmap.c` - Gaming Audio Profile
- `src/shared/asha.c` - Audio Streaming for Hearing Aid
- `profiles/audio/bap.c` - BAP D-Bus integration

## Key Patterns

### LEAUDIO-001: BAP Stream State Machine
**Risk**: Invalid state transitions, resource leaks

BAP streams follow a strict state machine:
IDLE -> CONFIG -> QoS -> ENABLING -> STREAMING -> DISABLING -> RELEASING

**Check**:
- [ ] State transitions follow the BAP specification
- [ ] Resources allocated in CONFIG freed in RELEASING
- [ ] No operations on streams in invalid states
- [ ] CIG/CIS (Connected Isochronous Group/Stream) lifecycle correct

### LEAUDIO-002: ISO Data Path
**Risk**: Data path leak, incorrect configuration

ISO (Isochronous) channels carry audio data for LE Audio.

**Check**:
- [ ] ISO socket created with correct parameters
- [ ] Data path setup matches codec configuration
- [ ] Data path torn down before CIS disconnect
- [ ] QoS parameters validated against capabilities

### LEAUDIO-003: Codec Configuration
**Risk**: Invalid codec settings, interop failures

LC3 codec configuration uses LTV (Length-Type-Value) format.

**Check**:
- [ ] LTV parsing validates length before reading value
- [ ] Codec capabilities checked before configuration
- [ ] Sampling frequency, frame duration, octets per frame validated
- [ ] Channel allocation consistent with ASE count

### LEAUDIO-004: Broadcast Source/Sink
**Risk**: Stale BIG/BIS handles, sync loss handling

**Check**:
- [ ] BIG (Broadcast Isochronous Group) created/terminated correctly
- [ ] PA (Periodic Advertising) sync lifecycle managed
- [ ] BASS receive state updates sent to clients
- [ ] Encryption (Broadcast Code) handled correctly

## Quick Checks

- [ ] BAP stream state machine followed
- [ ] ISO socket parameters match codec config
- [ ] LTV parsing has bounds checks
- [ ] Broadcast lifecycle complete (create -> stream -> terminate)
- [ ] All LE Audio cleanup unregisters GATT notifications
