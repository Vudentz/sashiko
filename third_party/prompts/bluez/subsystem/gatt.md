# GATT/ATT Subsystem Patterns

## When to Load
Load when patch touches:
- `src/shared/att.c`, `src/shared/att.h` - ATT transport
- `src/shared/gatt-client.c`, `src/shared/gatt-server.c` - GATT implementation
- `src/shared/gatt-db.c`, `src/shared/gatt-db.h` - GATT database
- `src/gatt-client.c`, `src/gatt-database.c` - D-Bus GATT wrappers
- Any code using `bt_att_*`, `bt_gatt_client_*`, `bt_gatt_server_*` APIs

## Key Files
- `src/shared/att.c` - ATT protocol transport layer
- `src/shared/att-types.h` - ATT opcode and error definitions
- `src/shared/gatt-client.c` - GATT client (discovery, read, write, notify)
- `src/shared/gatt-server.c` - GATT server (handle requests)
- `src/shared/gatt-db.c` - In-memory GATT attribute database
- `src/shared/gatt-helpers.c` - GATT discovery helper functions

## ATT Patterns

### GATT-001: ATT PDU Buffer Management
**Risk**: Buffer overflow, out-of-bounds read

ATT PDUs have a maximum size of MTU. All PDU construction and parsing
must validate lengths.

```c
/* CORRECT - validate before reading */
if (length < sizeof(struct bt_att_pdu_header))
	return;

/* CORRECT - check remaining length before parsing TLV */
if (pdu_len - offset < entry_len)
	return;
```

**Check**:
- [ ] PDU length validated before parsing
- [ ] Attribute values validated against MTU
- [ ] Variable-length fields have bounds checks

### GATT-002: ATT Request/Response Lifecycle
**Risk**: Use-after-free, callback-after-disconnect

```c
/* Send ATT request with callback */
id = bt_att_send(att, opcode, pdu, pdu_len, callback, user_data, destroy);
```

**Check**:
- [ ] Return value (id) checked for 0 (failure)
- [ ] user_data valid until callback fires or request cancelled
- [ ] destroy callback frees user_data properly
- [ ] Pending requests cancelled on disconnect

### GATT-003: GATT Client Discovery
**Risk**: Incomplete discovery, stale handles

Discovery is multi-phase: services -> characteristics -> descriptors.

**Check**:
- [ ] Discovery completion callback handles partial results
- [ ] Handle ranges validated (start_handle <= end_handle)
- [ ] Handles don't overlap between services

### GATT-004: GATT Notification/Indication Registration
**Risk**: Callback-after-free

```c
id = bt_gatt_client_register_notify(client, handle, callback,
						notify, user_data, destroy);
```

**Check**:
- [ ] Registration ID stored for later unregistration
- [ ] Unregistered in cleanup/disconnect path
- [ ] user_data outlives the registration

## Database Patterns

### GATT-005: gatt_db Attribute Operations
**Risk**: Use-after-free, stale references

```c
attr = gatt_db_get_attribute(db, handle);
/* attr is valid only while db contains it */
```

**Check**:
- [ ] Attribute pointer not used after service removal
- [ ] Database modifications don't invalidate held references
- [ ] Handle lookups check for NULL return

### GATT-006: Service Registration/Removal
**Risk**: Stale handles, notification to dead clients

**Check**:
- [ ] Service removed callbacks notify connected clients
- [ ] CCC (Client Characteristic Configuration) cleaned up
- [ ] Active notifications stopped before service removal

## Quick Checks

- [ ] All PDU lengths validated before parsing
- [ ] ATT request callbacks handle disconnect
- [ ] GATT client cleanup unregisters all notifications
- [ ] Database attribute references not held across modifications
- [ ] Byte order correct for all multi-byte values (le16_to_cpu)
- [ ] MTU respected for all PDU construction
