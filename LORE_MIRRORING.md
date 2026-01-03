# Mirroring lore.kernel.org Archives

Sashiko supports an "Offline/Test Mode" that reads from local git clones of mailing list archives. This is useful for development, testing, and bulk import of historical data without stressing the live NNTP servers.

## Prerequisites

- `git` installed on your system.
- Sufficient disk space (LKML archives can be tens of gigabytes).

## Finding the Git URL

`lore.kernel.org` uses [public-inbox](https://public-inbox.org/), which exposes mailing lists as git repositories.

1.  Go to [lore.kernel.org](https://lore.kernel.org/).
2.  Navigate to the list you are interested in (e.g., `LKML`).
3.  Look for the "mirror" instructions at the bottom or top of the page.

For LKML (Linux Kernel Mailing List), the base URL is:
`https://lore.kernel.org/lkml/`

## Cloning the Archive

`public-inbox` repositories are often split into "epochs" (e.g., `0.git`, `1.git`, `2.git`...) to keep repository sizes manageable. However, for many lists, you can clone the unified view or specific epochs.

### Simple Clone (Most recent epoch)

If you only need recent history (e.g., for testing current ingestion), you can clone the main endpoint or the latest epoch. Sashiko's `ingestor.rs` uses the `0.git` endpoint by default.

```bash
# Example for LKML (check lore for exact paths)
# We use --bare as Sashiko treats these as bare repositories.
mkdir -p archives
cd archives
git clone --bare --depth=1000 https://lore.kernel.org/lkml/0.git archives/lkml/0.git
```

*Note: `lore` often suggests using `grokmirror` for full mirrors. The `0.git` endpoint typically refers to the first epoch, but for some lists, it might be the only one. Sashiko currently hardcodes `0.git` for bootstrapping.*

### Automatic Bootstrapping

Sashiko's ingestor (`src/ingestor.rs`) includes logic to automatically bootstrap these repositories if they are missing. It performs a shallow bare clone of the `0.git` endpoint.

### Using Grokmirror (Recommended for Full Mirrors)

For a robust, continuously updated mirror of the entire history, the kernel infrastructure team recommends `grokmirror`.

1.  Install `grokmirror`:
    ```bash
    pip install grokmirror
    ```

2.  Configure it to track specific lists. Create a `grokmirror.conf` (example):
    ```ini
    [core]
    toplevel = /path/to/sashiko/archives
    log = /path/to/sashiko/grokmirror.log

    [remote]
    site = https://lore.kernel.org
    manifest = https://lore.kernel.org/manifest.js.gz
    ```

3.  Run the pull command:
    ```bash
    grok-pull -c grokmirror.conf
    ```

## Sashiko Directory Structure

Sashiko expects archives to be placed in the `archives/` directory at the project root.

```text
sashiko/
├── archives/
│   ├── lkml/
│   │   ├── 0.git/
│   │   ├── 1.git/
│   │   └── ...
│   └── netdev/
│       └── ...
└── ...
```

When running Sashiko in offline mode, point it to these directories.

## Helper Script

We plan to add a helper script in `scripts/mirror_lore.sh` to automate this process.

*(See `TODO.md` for status on automated tools)*
