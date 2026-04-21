# BlueZ Review Prompts

AI-assisted code review prompts for the BlueZ Bluetooth protocol stack.

## Usage

Use with sashiko's `--prompts` flag:

```bash
sashiko-review --prompts third_party/prompts/bluez [other args]
```

Or in the GitHub Action:

```yaml
prompts_path: third_party/prompts/bluez
```

## File Structure

```
bluez/
├── README.md                 # This file
├── technical-patterns.md     # Core patterns (always loaded)
├── review-core.md            # Main review protocol
├── debugging.md              # Debugging protocol
├── false-positive-guide.md   # False positive checklist
├── inline-template.md        # Report template
├── severity.md               # Severity level definitions
├── subsystem/                # Subsystem-specific guides
│   ├── subsystem.md          # Index for Phase 0 selection
│   ├── gatt.md               # ATT/GATT protocol
│   ├── dbus.md               # D-Bus interface patterns
│   ├── audio.md              # Classic audio (A2DP, AVRCP)
│   ├── le-audio.md           # LE Audio (BAP, BASS, VCP, etc.)
│   ├── mesh.md               # Bluetooth Mesh daemon
│   ├── mgmt.md               # Kernel MGMT interface
│   ├── monitor.md            # btmon packet monitor
│   ├── emulator.md           # HCI emulation and testing
│   ├── core.md               # Core daemon (adapter, device)
│   └── client.md             # bluetoothctl CLI
├── patterns/                 # Detailed pattern explanations
│   ├── QUEUE-001.md          # Queue data structure patterns
│   ├── DBUS-001.md           # D-Bus registration patterns
│   └── BTIO-001.md           # Bluetooth IO patterns
├── scripts/                  # Setup scripts (placeholder)
├── skills/                   # Skill definitions (placeholder)
└── slash-commands/           # Slash command definitions (placeholder)
```

## Covered Subsystems

- **Core daemon** - adapter, device, plugin, agent, storage management
- **GATT/ATT** - Attribute Protocol transport and Generic Attribute Profile
- **D-Bus** - BlueZ's GLib-based D-Bus wrapper (gdbus/)
- **Classic Audio** - A2DP, AVRCP, media transport
- **LE Audio** - BAP, BASS, VCP, MCP, CSIP, TMAP, GMAP, ASHA
- **Mesh** - Bluetooth Mesh daemon (ELL-based, NOT GLib)
- **MGMT** - Kernel management interface
- **Monitor** - btmon HCI packet analyzer
- **Emulator** - Virtual Bluetooth controller and test framework
- **Client** - bluetoothctl interactive CLI

## Key Differences from Kernel Prompts

- BlueZ is userspace C code, not kernel code
- No kernel-specific constructs (RCU, spinlocks, kref, etc.)
- Uses GLib mainloop (or ELL for mesh)
- D-Bus for IPC instead of syscalls/ioctls
- `new0()` / `util_malloc()` abort on OOM (never return NULL)
- No Signed-off-by lines (BlueZ convention)
- Follows kernel coding style but with BlueZ-specific rules (M1-M12)
- Mailing list: linux-bluetooth@vger.kernel.org
- Patch prefix: [PATCH BlueZ]
