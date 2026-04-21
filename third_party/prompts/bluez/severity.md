# Severity Levels

When identifying issues, you must assign a severity level to each finding.
Treat this task seriously. Don't unnecessarily raise the priority;
critical issues must be truly critical, high issues must be very damaging.
Use Medium as default and lower/raise depending on the analysis.

## Critical
- **Definition**: Issues that cause data loss, memory corruption, or security vulnerabilities.
- **Question to ask**: Is it actually better for the daemon/system to crash rather than keep working? If yes, it's critical.
- **Examples**:
    - Security vulnerability in pairing/bonding/encryption
    - Buffer overflow in protocol parsing (ATT, L2CAP, SDP, MGMT)
    - Use-after-free or double-free in daemon code
    - Memory corruption affecting all Bluetooth on the system
    - Unauthorized access to devices or services
    - Remote code execution via Bluetooth

## High
- **Definition**: Serious issues that can crash the daemon or make Bluetooth fully unusable.
- **Question to ask**: Can the daemon crash or Bluetooth become totally unusable? If yes, high.
- **Examples**:
    - Daemon crash (bluetoothd segfault)
    - Logic errors leading to incorrect pairing/connection behavior
    - Resource leaks (memory, file descriptors) in long-running daemon
    - D-Bus interface breakage affecting all Bluetooth clients
    - Incorrect GATT/ATT behavior breaking profile functionality
    - Connection state machine errors

## Medium
- **Definition**: Recoverable issues or non-critical regressions.
- **Examples**:
    - Memory leaks on cold/error paths
    - Incorrect D-Bus property values
    - Non-conformant but functional protocol behavior
    - Incorrect statistics or monitoring output
    - Missing error logging
    - Issues in test tools (btmon, tester programs)

## Low
- **Definition**: Naming, style, and coding style issues.
- **Question to ask**: Is there any visible real-life effect? If no, it's low.
- **Examples**:
    - Coding style violations (M1-M12 rules)
    - Typos in comments or log messages
    - Formatting issues
    - Unnecessary variable initialization (M6 violation)
    - Missing documentation
    - Suboptimal but correct code patterns
