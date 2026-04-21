# Queue Data Structure Patterns

## When to Load
Load when patch touches queue operations: `queue_new`, `queue_destroy`,
`queue_push_*`, `queue_pop_*`, `queue_find`, `queue_remove*`, `queue_foreach`.

## Patterns

### QUEUE-001: Queue Ownership and Destroy Callbacks
**Risk**: Memory leak, double-free

When creating a queue that holds allocated data:
```c
queue = queue_new();

/* Adding data */
data = new0(struct my_data, 1);
queue_push_tail(queue, data);

/* Destroying - MUST pass destroy func to free elements */
queue_destroy(queue, free);
```

**Check**:
- [ ] queue_destroy called with appropriate destroy function
- [ ] Destroy function matches allocation (free for new0/malloc, custom for complex types)
- [ ] No manual iteration to free + queue_destroy(queue, NULL) pattern (use destroy callback instead)
- [ ] queue_remove_all with destroy callback used for selective cleanup

### QUEUE-002: Queue Iteration Safety
**Risk**: Use-after-free during iteration

`queue_foreach` holds a ref during iteration, but elements can still be
removed by the callback:

```c
queue_foreach(queue, process_and_maybe_remove, queue);
```

**Check**:
- [ ] If callback removes elements, remaining iteration may skip items
- [ ] For removal during iteration, prefer queue_remove_all with match function
- [ ] Don't free the queue itself inside a queue_foreach callback

### QUEUE-003: Queue Find and Remove Patterns
**Risk**: Stale pointer, missing cleanup

```c
data = queue_find(queue, match_func, match_data);
/* data is still in the queue - don't free it! */

data = queue_remove_if(queue, match_func, match_data);
/* data is removed from queue - caller must free it */
```

**Check**:
- [ ] queue_find result not freed (still owned by queue)
- [ ] queue_remove_if result freed by caller (removed from queue)
- [ ] match_func correctly identifies the target element
- [ ] NULL return handled (element not found)
