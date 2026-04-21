# Bluetooth IO (btio) Patterns

## When to Load
Load when patch touches btio/ or uses bt_io_* functions for
L2CAP/RFCOMM socket operations.

## Patterns

### BTIO-001: Socket Creation and Connection
**Risk**: FD leak, incorrect socket options

```c
io = bt_io_connect(callback, user_data, destroy,
			&err,
			BT_IO_OPT_SOURCE_BDADDR, &src,
			BT_IO_OPT_DEST_BDADDR, &dst,
			BT_IO_OPT_PSM, psm,
			BT_IO_OPT_SEC_LEVEL, BT_IO_SEC_MEDIUM,
			BT_IO_OPT_INVALID);
```

**Check**:
- [ ] Option list terminated with BT_IO_OPT_INVALID
- [ ] Error (GError) checked after call
- [ ] GIOChannel properly unrefd on cleanup
- [ ] Callback handles connection failure
- [ ] destroy callback frees user_data

### BTIO-002: Listen Socket
**Risk**: Accept callback issues, FD leak

```c
io = bt_io_listen(connect_cb, NULL, user_data, destroy,
			&err,
			BT_IO_OPT_SOURCE_BDADDR, &src,
			BT_IO_OPT_PSM, psm,
			BT_IO_OPT_INVALID);
```

**Check**:
- [ ] connect_cb handles new connections correctly
- [ ] Listening socket cleaned up on adapter removal
- [ ] Accepted connections tracked for cleanup

### BTIO-003: Socket Options
**Risk**: Security bypass, incorrect behavior

**Check**:
- [ ] Security level appropriate for the profile
- [ ] MTU settings correct for the protocol
- [ ] Source/destination addresses correct
- [ ] PSM/CID values match specification
