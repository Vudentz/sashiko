# Audio Subsystem Patterns

## When to Load
Load when patch touches:
- `profiles/audio/` directory
- A2DP, AVRCP, media, transport, player code
- `src/shared/a2dp-codecs.h` - codec definitions

## Key Files
- `profiles/audio/a2dp.c` - A2DP sink/source implementation
- `profiles/audio/avrcp.c` - AVRCP controller/target
- `profiles/audio/transport.c` - Media transport (file descriptors)
- `profiles/audio/media.c` - Media API (endpoints, players)
- `profiles/audio/player.c` - Media player tracking

## Audio Patterns

### AUDIO-001: Media Transport Lifecycle
**Risk**: File descriptor leak, use-after-free

Media transports manage audio data file descriptors:
```c
/* Transport acquired: FD handed to client */
transport_acquire(transport, &fd, &imtu, &omtu);

/* Transport released: FD closed */
transport_release(transport);
```

**Check**:
- [ ] FD properly closed on release
- [ ] Transport state machine transitions are valid
- [ ] No audio operations on released transport
- [ ] Client disconnection triggers release

### AUDIO-002: A2DP Endpoint Registration
**Risk**: Stale endpoints, codec mismatch

**Check**:
- [ ] Endpoint capabilities match codec configuration
- [ ] Endpoint unregistered on adapter removal
- [ ] SEP (Stream End Point) lifecycle matches connection

### AUDIO-003: AVRCP State Management
**Risk**: Stale player state, incorrect notifications

**Check**:
- [ ] Player state updated on track/status changes
- [ ] Change notifications sent to registered controllers
- [ ] Browsed player cleanup on disconnect

## Quick Checks

- [ ] Transport FDs closed on all cleanup paths
- [ ] Codec configurations validated
- [ ] Media endpoints registered/unregistered symmetrically
- [ ] Player state consistent across AVRCP notifications
