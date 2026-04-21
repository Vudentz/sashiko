# D-Bus Registration Patterns

## When to Load
Load when patch registers or unregisters D-Bus interfaces.

## Patterns

### DBUS-001: Interface Registration Lifecycle
**Risk**: Use-after-free, stale D-Bus objects

Every `g_dbus_register_interface()` must have a matching
`g_dbus_unregister_interface()` in the cleanup path.

```c
/* Registration in probe/init */
if (!g_dbus_register_interface(conn, path, INTERFACE,
				methods, signals, properties,
				data, destroy_func))
	return -EIO;

/* Unregistration in remove/cleanup - BEFORE freeing data */
g_dbus_unregister_interface(conn, path, INTERFACE);
/* Now safe to free data (or let destroy_func handle it) */
```

**Check**:
- [ ] Every register has matching unregister
- [ ] Unregister called BEFORE backing data freed
- [ ] destroy_func (6th arg) properly frees user_data if set
- [ ] If destroy_func is NULL, caller frees data after unregister
- [ ] Path string remains valid for entire lifetime

### DBUS-002: Async Method Reply
**Risk**: Client timeout, memory leak

When a method handler returns NULL (async):
```c
static DBusMessage *method_handler(DBusConnection *conn,
					DBusMessage *msg, void *data)
{
	obj->pending = dbus_message_ref(msg);
	start_async_operation(obj);
	return NULL;  /* Will reply later */
}

/* Later, in async completion: */
reply = g_dbus_create_reply(obj->pending, ...);
g_dbus_send_message(conn, reply);
dbus_message_unref(obj->pending);
obj->pending = NULL;
```

**Check**:
- [ ] Message ref'd when returning NULL
- [ ] Async reply always sent (even on error/cleanup)
- [ ] Pending message unrefd after reply sent
- [ ] Object cleanup replies with error if pending message exists
