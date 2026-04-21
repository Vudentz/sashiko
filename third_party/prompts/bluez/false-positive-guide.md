# False Positive Elimination Guide

## Purpose
This guide helps eliminate false positives before reporting regressions.
Apply these checks to every potential issue found.

## Core Principle
**Never report a bug you cannot prove with concrete code paths.**

## Verification Checks

### CHECK 1: Can the Code Path Actually Execute?

Before reporting an issue:

1. **Trace the call path** from entry point to problematic code
2. **Identify all conditions** that must be true to reach it
3. **Verify conditions are possible** in real usage

**False Positive Example**:
```c
/* Reported: NULL dereference of dev */
void process_device(struct btd_device *dev) {
        if (!dev)
                return;
        /* ... lots of code ... */
        use(dev->adapter);  /* dev CANNOT be NULL here! */
}
```

### CHECK 2: Are Prerequisites Validated Elsewhere?

BlueZ often validates at API boundaries, not at every use.

**Check**:
- Does the public API validate this input?
- Is this internal code that assumes valid input?
- Do callers guarantee non-NULL?

**False Positive Example**:
```c
/* Internal function - caller guarantees non-NULL */
static void adapter_setup(struct btd_adapter *adapter) {
        /* No NULL check needed - all callers verify adapter */
        setup_mgmt(adapter->mgmt);
}
```

### CHECK 3: new0() and util_malloc() Never Return NULL

**CRITICAL**: BlueZ's `new0()` and `util_malloc()` abort on OOM.
They NEVER return NULL. Do not report missing NULL checks after these.

**False Positive Example**:
```c
/* NOT A BUG - new0 aborts on failure */
data = new0(struct my_data, 1);
data->field = value;  /* Always safe - new0 never returns NULL */
```

**Real Issue Example**:
```c
/* IS A BUG - raw malloc can return NULL */
data = malloc(size);
data->field = value;  /* NULL dereference possible! */
```

### CHECK 4: Queue Functions Handle NULL Gracefully

All `queue_*` functions handle NULL queue arguments gracefully:
- `queue_push_tail(NULL, ...)` returns false
- `queue_find(NULL, ...)` returns NULL
- `queue_foreach(NULL, ...)` is a no-op
- `queue_destroy(NULL, ...)` is a no-op

Do not report NULL queue dereferences when using the queue API.

### CHECK 5: Does Error Handling Actually Matter?

Some error paths are intentionally best-effort:

```c
/* Intentional - cleanup is best-effort */
queue_remove(pending, data);  /* OK if not found */
```

### CHECK 6: Is the Callback Lifetime Actually Violated?

Before reporting callback-after-free:
1. Check if the callback is unregistered before the object is freed
2. Check if there's a disconnect handler that cancels pending operations
3. Check if the destroy notifier frees the user_data

**Common safe pattern**:
```c
static void my_remove(struct btd_device *device) {
        struct my_data *data = btd_device_get_data(device);

        /* Unregister callback BEFORE freeing data */
        bt_att_unregister(data->att, data->notify_id);
        free(data);
}
```

### CHECK 7: Is This a Test/Debug Path?

Test code has different standards:
- Memory leaks acceptable in test programs (tools/*-tester)
- Test assertions firing on bad input are expected
- Emulator code may have intentional simplifications
- Python test scripts (test/) have very different standards

### CHECK 8: D-Bus Interface Lifecycle

D-Bus interface registration/unregistration often follows object lifecycle:

```c
/* probe: register D-Bus interface */
g_dbus_register_interface(...);

/* remove: unregister before freeing */
g_dbus_unregister_interface(...);
```

Check that unregistration happens in the remove/disconnect/cleanup path
before reporting stale D-Bus objects.

### CHECK 9: Bluetooth Protocol Compliance

Before reporting protocol violations:
- Check the Bluetooth Core Specification for the correct behavior
- Some "violations" are intentional workarounds for broken devices
- Interoperability quirks are common and documented in comments

### CHECK 10: Mainloop Variant Awareness

Code in `src/shared/` is compiled for three mainloop variants.
The `struct io` abstraction hides the differences. Don't report
mainloop-specific issues unless they affect the specific compilation
target relevant to the patch.

## Elimination Process

For each potential issue:

1. [ ] Can I show the exact code path that triggers this?
2. [ ] Have I verified the path is actually reachable?
3. [ ] Is this truly a bug, not a defensive programming request?
4. [ ] Have I checked for validation elsewhere in the call chain?
5. [ ] Is this production code, not test/debug?
6. [ ] Have I verified new0()/util_malloc() vs raw malloc()?

**If any answer is NO or UNCERTAIN**, do not report the issue.

## TASK POSITIVE.1 Verification Checklist

Complete each verification step below and produce the required output.
Do not skip steps. Do not claim completion without producing the output.

Before reporting ANY regression, verify:

1. **Can I prove this path executes?**
   - Find calling code that reaches here
     - Output: quote the call chain with locations
   - Check for impossible conditions blocking the path
     - Output: list conditions checked and their evaluation
   - Verify not in dead code or disabled features
     - Output: build config option or "always compiled"

2. **Is the bad behavior structurally possible?**
   - Prove the code path exists and the triggering conditions are not
     structurally impossible
     - Output: step-by-step execution path with function names and locations
   - Prove the failure mode is concrete (crash, leak, corruption), not just
     "increases risk"
     - Output: the specific failure mode and triggering condition

3. **Did I check the full context?**
   - Examine calling functions (2-3 levels up)
     - Output: list each caller checked
   - Check initialization and cleanup paths
     - Output: init/cleanup functions examined
   - Verify BlueZ conventions
     - Output: conventions found and whether code follows them

4. **Is this actually wrong?**
   - Check if intentional design choice
     - Output: quote commit message or comment if explains intent
   - Check if documented limitation
     - Output: quote documentation if found
   - Verify not test code
     - Output: "daemon code" or "test code - severity adjusted"

5. **Did I check the commit message?**
   - Read the entire commit message
     - Output: quote any text explaining this behavior
   - Read surrounding code comments
     - Output: quote relevant comments

6. **Did I hallucinate a problem that doesn't actually exist?**
   - Verify the bug report matches the actual code
     - Output: quote the exact code snippet from the file
   - Reread the file and confirm code matches your analysis
     - Output: file and verbatim code

7. **Debate yourself**
   - Pretend you are the author. Try to prove the review incorrect.
     - Output: strongest argument against reporting this bug
   - Now pretend you're the reviewer. Address the author's arguments.
     - Output: code evidence refuting the author, or "likely false positive"

## Special Cases

### Test Code
- Memory leaks in test programs -> Usually OK
- File descriptor leaks in tests -> Usually OK
- Unless it crashes/hangs the test framework -> Report it

### Emulator Code
- Simplifications in emulator -> Usually OK unless they cause test failures
- Virtual controller quirks -> Intentional for testing edge cases

### Plugin/Profile Code
- Missing features -> Not a regression (it's new code)
- Partial implementation -> Check commit message for scope

## Final Filter

Before adding to report:
1. **Do I have proof, not just suspicion?** [ yes / no ]
2. **Would an experienced BlueZ developer see this as a real issue?** [ yes / no ]
3. **Is this worth the maintainer's time?** [ yes / no ]
4. **Am I suggesting defensive programming, or reporting a concrete bug?** [ yes / no ]

If any answer is no, investigate further or discard.
