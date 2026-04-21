# Mesh Subsystem Patterns

## When to Load
Load when patch touches:
- `mesh/` directory
- bluetooth-meshd daemon
- Mesh provisioning, configuration, or network operations

## Key Files
- `mesh/mesh.c` - Main mesh daemon
- `mesh/node.c` - Mesh node management
- `mesh/net.c` - Mesh network layer
- `mesh/model.c` - Mesh model implementation
- `mesh/prov.c` - Provisioning
- `mesh/crypto.c` - Mesh cryptography
- `mesh/mesh-io-generic.c` - Generic mesh IO (HCI)
- `mesh/mesh-config-json.c` - JSON configuration storage

## Mesh Patterns

### MESH-001: ELL-Based Architecture
**Risk**: Mixing GLib and ELL APIs

The mesh daemon uses **ELL (Embedded Linux Library)**, NOT GLib.
Do not confuse with the main bluetoothd which uses GLib.

**Check**:
- [ ] No GLib calls in mesh/ code
- [ ] Uses l_queue, l_dbus, l_io (not g_queue, gdbus, etc.)
- [ ] ELL memory functions (l_new, l_free) used consistently

### MESH-002: Cryptographic Operations
**Risk**: Key exposure, incorrect encryption

Mesh uses AES-CCM, AES-CMAC, and ECDH for security.

**Check**:
- [ ] Keys zeroed after use (memset or explicit_bzero)
- [ ] Nonce values unique per message
- [ ] Application and network key indices correct
- [ ] IV Index handled correctly (rollover)

### MESH-003: Provisioning Security
**Risk**: Key compromise, unauthorized provisioning

**Check**:
- [ ] OOB (Out-of-Band) data validated
- [ ] Provisioning PDU lengths validated
- [ ] Session keys properly derived and destroyed
- [ ] Provisioning state machine followed

### MESH-004: JSON Configuration
**Risk**: Data corruption, parse errors

Mesh configuration stored in JSON files via json-c library.

**Check**:
- [ ] JSON parsing errors handled gracefully
- [ ] File writes atomic (write to temp, rename)
- [ ] Missing fields handled with defaults
- [ ] Node configuration saved after state changes

## Quick Checks

- [ ] No GLib/gdbus usage in mesh/ (ELL only)
- [ ] Cryptographic keys properly managed
- [ ] JSON configuration writes are safe
- [ ] Provisioning state machine complete
- [ ] Network PDU size validated
