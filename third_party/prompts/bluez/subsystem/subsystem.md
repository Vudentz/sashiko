# BlueZ Subsystem Guide Index

This file lists all available subsystem-specific review guides.
During Phase 0, the AI selects which guides are relevant to the patch
being reviewed.

## Available Guides

- **gatt.md** - ATT/GATT protocol implementation (src/shared/att.*, src/shared/gatt-*.*, src/gatt-client.c, src/gatt-database.c). Covers PDU buffer management, request/response lifecycle, service discovery, notification registration, and gatt_db attribute operations.

- **dbus.md** - D-Bus interface patterns (gdbus/, src/dbus-common.c, g_dbus_* APIs). Covers interface registration/unregistration lifecycle, method handlers, property implementation, signal emission, error replies, and client proxy management.

- **audio.md** - Classic audio profiles (profiles/audio/, A2DP, AVRCP, media, transport, player). Covers media transport FD lifecycle, A2DP endpoint registration, and AVRCP state management.

- **le-audio.md** - LE Audio profiles (src/shared/bap.*, src/shared/bass.*, src/shared/vcp.*, src/shared/mcp.*, src/shared/csip.*, src/shared/tmap.*, src/shared/gmap.*, src/shared/asha.*). Covers BAP stream state machine, ISO data path, LC3 codec configuration, and broadcast source/sink lifecycle.

- **mesh.md** - Bluetooth Mesh daemon (mesh/ directory). Covers ELL-based architecture (NOT GLib), cryptographic operations, provisioning security, and JSON configuration storage.

- **mgmt.md** - Kernel management interface (src/shared/mgmt.*, src/adapter.c, lib/mgmt.h). Covers MGMT command send/response, event registration, packed data structures, and adapter index management.

- **monitor.md** - HCI packet monitor btmon (monitor/ directory). Covers packet parsing safety for untrusted data, display formatting, and protocol state tracking.

- **emulator.md** - HCI emulation and test framework (emulator/, src/shared/tester.c). Covers btdev command handling, bthost protocol implementation, and test framework usage.

- **core.md** - Core daemon components (src/adapter.*, src/device.*, src/plugin.*, src/agent.*, src/storage.*). Covers adapter lifecycle, device lifecycle, plugin registration, agent interaction, and storage operations.

- **client.md** - bluetoothctl CLI (client/ directory). Covers D-Bus proxy usage, command input handling, and interactive shell patterns.
