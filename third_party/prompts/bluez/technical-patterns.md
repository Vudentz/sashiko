# BlueZ Technical Deep-dive Patterns

## Core Instructions

- Trace full execution flow, gather additional context from the call chain
- IMPORTANT: never make assumptions based on return types, checks, or comments -
  explicitly verify the code is correct by tracing concrete execution paths
- IMPORTANT: never skip any steps just because you found a bug in previous step
- Never report errors without checking if the error is impossible in the call path

## Project Overview

BlueZ is the official Linux Bluetooth protocol stack. It provides:
- `bluetoothd` - the core daemon (src/, profiles/, plugins/)
- `bluetoothctl` - interactive CLI client (client/)
- `btmon` - HCI packet monitor (monitor/)
- `bluetooth-meshd` - mesh daemon (mesh/)
- Emulator and test tools (emulator/, tools/, unit/, test/)

BlueZ follows the **Linux kernel coding style** (checkpatch.pl --no-tree),
with additional project-specific rules documented in doc/coding-style.rst.
BlueZ does **NOT** use Signed-off-by lines.

## Coding Style

**Indentation**: Tabs (8-space width), 80-column limit.

**Blank Lines (M1)**: Required before and after if/while/do/for statements,
unless nested and not preceded by an expression. Exception: error checking
immediately after a function call.

```c
/* CORRECT - error check immediately after call */
err = stat(filename, &st);
if (err || !S_ISDIR(st.st_mode))
	return;

/* CORRECT - blank line before if */
a = 1;

if (b) {
}
```

**Multi-line Comments (M2)**: Start from the second line.
```c
/*
 * first line comment
 * last line comment
 */
```

**Line Wrapping (M4)**: Indent continuations as far right as possible
without exceeding 80 columns. Do NOT align with body indentation.
```c
/* CORRECT */
void btd_adapter_register_pin_cb(struct btd_adapter *adapter,
						btd_adapter_pin_cb_t cb)

/* WRONG - aligned with body */
void btd_adapter_register_pin_cb(struct btd_adapter *adapter,
	btd_adapter_pin_cb_t cb)
```

**Type Casting (M5)**: Space between type and variable: `(int *) b` not `(int *)b`

**Initialization (M6)**: Don't initialize variables unnecessarily.

**Include Guards (M8)**: Internal headers must NOT use include guards.

**Enums (M9)**: Lowercase type name, CAPS values prefixed by type name.
```c
enum animal_type {
	ANIMAL_TYPE_FOUR_LEGS =		4,
	ANIMAL_TYPE_EIGHT_LEGS =	8,
};
```

**Switch on Enum (M10)**: Must list ALL enum values even with default.

**sizeof (M11)**: Always use parentheses: `sizeof(*stuff)` not `sizeof *stuff`

**void Parameters (M12)**: Functions with no parameters must use `void`.

**Early Return (O1)**: Prefer early return/break/continue over deep nesting.

## Memory Management

**Allocation Macros**:
```c
new0(type, count)    /* calloc-like, zero-initialized, aborts on OOM */
newa(type, count)    /* alloca-based, stack allocation */
malloc0(n)           /* calloc(1, n) */
util_malloc(size)    /* malloc that aborts on OOM */
util_memdup(src, n)  /* memdup that aborts on OOM */
```

**CRITICAL**: `new0()` and `util_malloc()` call `abort()` on allocation
failure. They never return NULL. Code using these macros does NOT need
NULL checks after allocation.

**Manual Allocation**: When using raw `malloc()`/`calloc()`, NULL checks
ARE required.

**Ownership Model**: BlueZ uses explicit ownership. When data is stored
in a queue or passed to a callback, ownership transfer must be clear:
- If a queue takes ownership, it needs a destroy callback
- If a function takes ownership of a pointer, the caller must not free it
- Reference counting is manual (see queue.c ref_count pattern)

## Data Structures

**Queue** (`src/shared/queue.c`):
- Reference-counted linked list
- `queue_new()` / `queue_destroy(queue, destroy_func)`
- `queue_push_tail()` / `queue_push_head()` / `queue_pop_head()`
- `queue_find(queue, match_func, match_data)`
- `queue_remove()` / `queue_remove_if()` / `queue_remove_all()`
- `queue_foreach(queue, func, user_data)` - holds ref during iteration
- Destroy function is called for each element on queue_destroy/queue_remove_all
- NULL queue arguments are handled gracefully (return NULL/false/0)

**Queue Iteration Safety**: `queue_foreach` takes a reference on the queue
during iteration. This means elements can be removed during iteration
without crashing, but the iteration itself may skip elements or see stale data.

## Byte Order

BlueZ defines endian conversion macros in `src/shared/util.h`:
```c
le16_to_cpu(val)  cpu_to_le16(val)
le32_to_cpu(val)  cpu_to_le32(val)
le64_to_cpu(val)  cpu_to_le64(val)
be16_to_cpu(val)  cpu_to_be16(val)
```

**Unaligned Access**:
```c
get_unaligned(ptr)        /* Safe unaligned read */
put_unaligned(val, ptr)   /* Safe unaligned write */
```

**Pointer/Integer Casts**:
```c
PTR_TO_UINT(p)  UINT_TO_PTR(u)
PTR_TO_INT(p)   INT_TO_PTR(u)
```

## Error Handling

**Return Conventions**:
- Functions returning pointers: NULL on error
- Functions returning bool: false on error
- Functions returning int: negative errno on error, 0 or positive on success
- Callback registration: returns unsigned int ID (0 = failure)

**Error Logging**:
- `error()` - error messages
- `warn()` - warnings
- `info()` - informational
- `DBG()` / `util_debug()` - debug messages
- Debug output uses `util_debug_func_t` callback pattern

**NULL Tolerance**: Most BlueZ functions check for NULL at entry and
return gracefully (NULL, false, 0). This is a project convention, not
a bug. Do not report missing NULL checks when the function already
handles NULL.

## D-Bus Integration

BlueZ uses its own GLib-based D-Bus wrapper (`gdbus/`):
- `g_dbus_register_interface()` - register object with method/signal/property tables
- `g_dbus_emit_signal()` - emit D-Bus signal
- `g_dbus_emit_property_changed()` - emit PropertiesChanged
- `g_dbus_send_reply()` / `g_dbus_send_error()` - send replies

**D-Bus Message Lifetime**: Data extracted from D-Bus messages is valid
only while the message exists. Copy strings if needed beyond the callback.

**D-Bus Method Handlers**: Return `DBusMessage *` - either a reply or
error message. Returning NULL means the reply will be sent later (async).

## Mainloop Variants

BlueZ has THREE mainloop backends:
- **GLib** (`src/shared/io-glib.c`) - used by bluetoothd
- **Custom mainloop** (`src/shared/io-mainloop.c`) - used by some tools
- **ELL** (`src/shared/io-ell.c`) - used by mesh daemon

`src/shared/` is compiled three times as `libshared-glib`, `libshared-mainloop`,
`libshared-ell`. Code in `src/shared/` must be mainloop-agnostic using the
`struct io` abstraction.

## Bluetooth Protocol Patterns

**HCI/MGMT Interface** (`src/shared/mgmt.c`):
- All adapter control goes through the kernel MGMT interface
- Asynchronous: send command, register callback for response
- `mgmt_send()` returns request ID, 0 on failure
- `mgmt_register()` for event notifications

**ATT/GATT** (`src/shared/att.c`, `gatt-client.c`, `gatt-server.c`):
- ATT is the transport layer for GATT
- `bt_att_send()` - send ATT PDU with response callback
- GATT operations are asynchronous with completion callbacks
- Service/characteristic discovery uses iterative patterns

**Callback Lifetime**: When registering callbacks with user_data:
- The user_data must remain valid until the callback is unregistered
- Use destroy callbacks to clean up user_data when unregistering
- `bt_att_register_disconnect()`, `mgmt_register()` etc. return IDs
  for later unregistration

## Plugin Architecture

Plugins are loaded by `bluetoothd` and registered via:
```c
static struct btd_profile my_profile = {
	.name		= "my-profile",
	.connect	= my_connect,
	.disconnect	= my_disconnect,
	.device_probe	= my_probe,
	.device_remove	= my_remove,
};

static int my_init(void)
{
	btd_profile_register(&my_profile);
	return 0;
}

static void my_exit(void)
{
	btd_profile_unregister(&my_profile);
}

BLUETOOTH_PLUGIN_DEFINE(my_plugin, VERSION, ..., my_init, my_exit)
```

**Probe/Remove Symmetry**: Every resource allocated in `device_probe` must
be freed in `device_remove`. Every `connect` must have a matching `disconnect`.

## File Descriptor Handling

- Use `O_CLOEXEC` on all file descriptor creation (following kernel convention)
- Socket creation: use `SOCK_CLOEXEC`
- BlueZ uses Bluetooth sockets (AF_BLUETOOTH) for HCI, L2CAP, RFCOMM, SCO, ISO

## Testing

**Test Framework** (`src/shared/tester.c`):
- `tester_init()` / `tester_run()` / `tester_teardown_complete()`
- Tests register with `tester_add()` or `tester_add_full()`
- `tester_test_passed()` / `tester_test_failed()`

**Emulator** (`emulator/`):
- `hciemu_new()` creates virtual Bluetooth controller
- `btdev` implements virtual controller responses
- `bthost` implements virtual remote host
- Used for testing without real hardware

## Control Flow

**goto Usage**: Only for cleanup, only forward jumps.

**Infinite Loops**: Use `for (;;)` not `while (1)`.
