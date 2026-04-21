# BlueZ Patch Review Protocol

## Overview

This protocol guides systematic review of BlueZ patches for correctness,
style compliance, and potential regressions.

## Pre-Review Setup

Before beginning review:
1. ALWAYS load `technical-patterns.md` first
2. Load subsystem-specific files based on changed code (see triggers below)
3. Load pattern files when specific patterns are detected

## Review Tasks

### TASK 0: Identify Changed Functions

Use available tools to identify all functions modified by the patch:
- For git commits: examine the diff
- List each modified function with its file location

### TASK 1: Subsystem Context Loading

Load subsystem files based on code locations and patterns:

| Trigger | File to Load |
|---------|--------------|
| `src/shared/gatt-*`, `src/shared/att.*`, ATT/GATT operations | `subsystem/gatt.md` |
| `gdbus/`, `g_dbus_*`, D-Bus method/signal/property tables | `subsystem/dbus.md` |
| `profiles/audio/`, A2DP, AVRCP, media, transport | `subsystem/audio.md` |
| `mesh/`, bluetooth-meshd, provisioning | `subsystem/mesh.md` |
| `src/shared/mgmt.*`, MGMT commands/events | `subsystem/mgmt.md` |
| `monitor/`, btmon, packet decoding | `subsystem/monitor.md` |
| `emulator/`, btdev, bthost, hciemu | `subsystem/emulator.md` |
| `src/shared/bap.*`, `src/shared/bass.*`, LE Audio | `subsystem/le-audio.md` |
| `client/`, bluetoothctl | `subsystem/client.md` |
| `src/adapter.*`, `src/device.*`, core daemon | `subsystem/core.md` |

### TASK 2: Pattern Detection

When you encounter these patterns, load the corresponding pattern file:

| Pattern | File |
|---------|------|
| `queue_*` operations, data structure management | `patterns/QUEUE-001.md` |
| `g_dbus_*` interface registration, D-Bus handlers | `patterns/DBUS-001.md` |
| `bt_io_*`, L2CAP/RFCOMM socket operations | `patterns/BTIO-001.md` |

### TASK 3: Per-Function Analysis

For each modified function, analyze:

**3.1 Error Handling**
- Are all error paths handled correctly?
- Are errors propagated properly (NULL, false, negative errno)?
- Is cleanup performed on error paths (free, unregister, disconnect)?
- Are error messages logged appropriately?

**3.2 Resource Management**
- Are all allocated resources freed on all paths?
- Are file descriptors closed on error paths?
- Is queue ownership clear (who calls queue_destroy with what destroy func)?
- Are callbacks unregistered before freeing associated data?
- Is probe/remove symmetry maintained for plugins and profiles?

**3.3 Callback Safety**
- Does user_data outlive the callback registration?
- Are destroy notifiers set for callback registrations?
- Are callback IDs stored for later unregistration?
- Is there a risk of callbacks firing after the object is freed?

**3.4 D-Bus Safety**
- Are D-Bus interfaces unregistered before freeing backing data?
- Are message reply pointers valid (not accessing freed message data)?
- Are async replies handled correctly (method returns NULL)?
- Are PropertiesChanged signals emitted when state changes?

**3.5 Protocol Correctness**
- Do ATT/GATT operations follow the Bluetooth specification?
- Are PDU sizes validated against MTU?
- Are opcodes and status codes used correctly?
- Is byte order handled properly (le16_to_cpu, cpu_to_le16)?

**3.6 Style Compliance**
- Does the code follow BlueZ coding style (doc/coding-style.rst)?
- Blank lines before/after control flow (M1)?
- Line wrapping indented far right, not aligned (M4)?
- Space in casts (M5)?
- No unnecessary initialization (M6)?
- No include guards in internal headers (M8)?
- All enum values in switch (M10)?
- sizeof with parentheses (M11)?
- void in empty parameter lists (M12)?

### TASK 4: Integration Analysis

**4.1 Caller Impact**
- How do callers use this function?
- Could the changes break existing callers?
- Are API contracts preserved?

**4.2 Thread Safety**
- BlueZ is primarily single-threaded (event loop based)
- But some code runs in different contexts (timers, IO callbacks)
- Verify no re-entrancy issues in callback chains

**4.3 Backward Compatibility**
- Do D-Bus API changes break existing clients?
- Are new properties/methods backward compatible?
- Are protocol changes compliant with the Bluetooth specification?

## Severity Classification

When reporting issues:

**CRITICAL**: Security vulnerabilities, crashes, data corruption
- Use-after-free, double-free, buffer overflow
- Missing bounds checks on protocol data
- Crashes in daemon code (affects all Bluetooth on system)
- Security bypass in pairing/bonding

**HIGH**: Functional bugs, resource leaks
- Memory leaks in long-running daemon
- Incorrect GATT/ATT/L2CAP behavior
- Connection handling errors
- Callback-after-free patterns

**MEDIUM**: Recoverable issues, non-critical regressions
- Leaks in error paths (cold paths)
- Incorrect D-Bus property values
- Non-conformant but functional protocol behavior
- Missing error logging

**LOW**: Style, cosmetic, suggestions
- Coding style violations
- Typos in comments
- Suboptimal but correct code patterns
- Missing documentation

## Output Format

When issues are found, generate the review report using `inline-template.md`.

## False Positive Check

Before reporting any issue:
1. Consult `false-positive-guide.md`
2. Verify the issue can actually occur in practice
3. Trace the execution path to confirm
