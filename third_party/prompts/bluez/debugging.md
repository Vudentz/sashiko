# BlueZ Debugging Protocol

## Overview

This protocol guides systematic debugging of BlueZ crashes, assertions,
and unexpected behavior.

## Pre-Debug Setup

1. ALWAYS load `technical-patterns.md` first
2. Identify the component that crashed
3. Load component-specific context files

## Component Identification

Identify the failing component from the crash/log:

| Component | Binary/Context | Files to Load |
|-----------|----------------|---------------|
| Daemon | bluetoothd | `subsystem/core.md` |
| GATT | ATT/GATT operations | `subsystem/gatt.md` |
| Audio | A2DP/AVRCP/BAP | `subsystem/audio.md`, `subsystem/le-audio.md` |
| Mesh | bluetooth-meshd | `subsystem/mesh.md` |
| Monitor | btmon | `subsystem/monitor.md` |
| CLI | bluetoothctl | `subsystem/client.md` |
| Emulator | btvirt/hciemu | `subsystem/emulator.md` |

## Debug Tasks

### DEBUG.1: Crash Information Extraction

From the crash report, extract:
- Faulting address/instruction
- Stack trace (all frames)
- Signal type (SIGSEGV, SIGABRT, etc.)
- BlueZ version and configuration

### DEBUG.2: Stack Trace Analysis

For each frame in the stack trace:
1. Identify the function name and source file
2. Look up the function implementation
3. Identify the failing line if possible
4. Note relevant local variables and state

### DEBUG.3: Root Cause Hypothesis

Based on the crash type, form hypotheses:

**SIGSEGV (Segmentation Fault)**:
- NULL pointer dereference (common: freed object accessed via callback)
- Use-after-free (common: queue element freed during iteration)
- Invalid pointer from protocol parsing (unchecked buffer bounds)

**SIGABRT (Abort)**:
- OOM in new0()/util_malloc() (these abort on failure)
- assert() failure
- GLib assertion failure (g_assert, g_return_if_fail)

### DEBUG.4: Common BlueZ Crash Patterns

**Pattern: Callback After Disconnect**
```
Symptoms: SIGSEGV in a GATT/ATT callback
Check: Was the callback unregistered in disconnect handler?
Check: Was bt_att_unregister() called before freeing data?
Check: Did the disconnect race with the callback?
```

**Pattern: Queue Element Use-After-Free**
```
Symptoms: SIGSEGV accessing queue element data
Check: Was element removed from queue while iterating?
Check: Was destroy callback called on removal?
Check: Was queue_foreach used (ref-counted iteration)?
```

**Pattern: D-Bus Use-After-Free**
```
Symptoms: SIGSEGV in D-Bus method handler
Check: Was g_dbus_unregister_interface called before freeing backing data?
Check: Was pending D-Bus message replied before object destruction?
```

**Pattern: Protocol Parsing Overflow**
```
Symptoms: SIGSEGV at offset from buffer start
Check: Was PDU length validated against MTU?
Check: Were TLV lengths validated before reading data?
Check: Was buffer bounds checking present?
```

### DEBUG.5: Resource State Analysis

Check resource states leading to crash:
- Were queues properly destroyed with correct destroy callbacks?
- Were D-Bus interfaces unregistered before object free?
- Were MGMT/ATT/L2CAP handlers unregistered?
- Were file descriptors closed?

## Quick Checks

- [ ] Was the callback unregistered before the object was freed?
- [ ] Was queue iteration safe (using queue_foreach with ref)?
- [ ] Was protocol data validated for length before parsing?
- [ ] Was D-Bus interface lifecycle correct?
- [ ] Was the disconnect/remove handler called before free?
