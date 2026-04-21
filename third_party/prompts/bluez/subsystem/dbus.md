# D-Bus Subsystem Patterns

## When to Load
Load when patch touches:
- `gdbus/` directory - D-Bus convenience wrapper
- `src/dbus-common.c` - D-Bus connection setup
- Any code using `g_dbus_*` APIs
- D-Bus method handlers, signal emissions, property implementations
- Files with `DBusMessage`, `DBusConnection` usage

## Key Files
- `gdbus/gdbus.h` - Main D-Bus wrapper API
- `gdbus/object.c` - Object/interface registration
- `gdbus/client.c` - D-Bus client proxy
- `src/dbus-common.c` - BlueZ D-Bus connection management

## Interface Patterns

### DBUS-001: Interface Registration/Unregistration
**Risk**: Use-after-free, stale D-Bus objects

```c
/* Register interface with method/signal/property tables */
g_dbus_register_interface(conn, path, INTERFACE_NAME,
				methods, signals, properties,
				user_data, destroy);

/* MUST unregister before freeing user_data */
g_dbus_unregister_interface(conn, path, INTERFACE_NAME);
```

**Check**:
- [ ] Interface unregistered before backing data freed
- [ ] Destroy callback correctly frees user_data
- [ ] No method/property handlers called after unregistration
- [ ] Path string valid during entire registration lifetime

### DBUS-002: Method Handler Pattern
**Risk**: Memory leak, invalid reply

```c
static DBusMessage *method_handler(DBusConnection *conn,
					DBusMessage *msg, void *data)
{
	struct my_data *obj = data;

	/* Return reply synchronously */
	return g_dbus_create_reply(msg, DBUS_TYPE_INVALID);

	/* OR return NULL for async reply */
	obj->pending_msg = dbus_message_ref(msg);
	return NULL;
}
```

**Check**:
- [ ] Handler returns either a reply or NULL (never both)
- [ ] If returning NULL, message is ref'd for later reply
- [ ] Later reply sent with g_dbus_send_message() or g_dbus_send_reply()
- [ ] Pending messages replied or unrefd on cleanup

### DBUS-003: Property Implementation
**Risk**: Type mismatch, stale values

```c
static gboolean property_get(const GDBusPropertyTable *property,
				DBusMessageIter *iter, void *data)
{
	struct my_data *obj = data;
	const char *str = obj->name;

	dbus_message_iter_append_basic(iter, DBUS_TYPE_STRING, &str);
	return TRUE;
}
```

**Check**:
- [ ] Return type matches D-Bus signature in property table
- [ ] Data pointer still valid when property is read
- [ ] g_dbus_emit_property_changed() called when value changes
- [ ] Property exists check returns correct boolean

### DBUS-004: Signal Emission
**Risk**: Emitting on unregistered path

```c
g_dbus_emit_signal(conn, path, INTERFACE_NAME, "SignalName",
			DBUS_TYPE_STRING, &value,
			DBUS_TYPE_INVALID);
```

**Check**:
- [ ] Signal emitted only while interface is registered
- [ ] Signal arguments match declared signature
- [ ] PropertiesChanged emitted for property updates

### DBUS-005: Error Replies
**Risk**: Client timeout, missing error info

```c
return btd_error_invalid_args(msg);
return btd_error_not_supported(msg);
return btd_error_failed(msg, strerror(err));
```

**Check**:
- [ ] All error paths return an error reply
- [ ] Error messages are descriptive
- [ ] Async operations always eventually reply

## Client Proxy Patterns

### DBUS-006: D-Bus Client Lifetime
**Risk**: Use-after-free, stale proxy

```c
client = g_dbus_client_new(conn, service, path);
g_dbus_client_set_proxy_handlers(client, proxy_added,
					proxy_removed, property_changed,
					user_data);
```

**Check**:
- [ ] Client unrefd in cleanup
- [ ] proxy_removed handler cleans up proxy references
- [ ] user_data outlives client
- [ ] Property changes handled after proxy removal

## Quick Checks

- [ ] Every g_dbus_register_interface has matching unregister
- [ ] Method handlers return reply or NULL (with ref'd message)
- [ ] Pending async replies resolved on cleanup
- [ ] Properties emit changed signals
- [ ] No D-Bus operations after interface unregistration
- [ ] Error replies on all failure paths
