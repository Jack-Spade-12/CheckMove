# CheckMove

> **Copy it. Check it. Trust it.**
>
> An interactive Bash utility that uses `rsync` to copy files and folders, verify them with checksums, and automatically retry until the destination matches the source.

---

## Features

✅ Interactive file and folder selection

✅ Supports multiple source files and directories

✅ Configurable destination folder structure

✅ Required and optional path components

✅ Pre-flight validation before any changes are made

✅ Confirmation before creating missing folders

✅ Reliable `rsync` transfers

✅ Checksum verification after transfer

✅ Automatic retry on transfer or verification failure

✅ Drag-and-drop path support

✅ Full support for standard `rsync` trailing-slash behavior

---

## Requirements

- Bash
- rsync

### Ubuntu / Debian

```bash
sudo apt install rsync
```

### Fedora

```bash
sudo dnf install rsync
```

### Arch Linux

```bash
sudo pacman -S rsync
```

---

## Installation

Clone the repository:

```bash
git clone https://github.com/Jack-Spade-12/checkmove.git
cd checkmove
```

Make the script executable:

```bash
chmod +x checkmove.sh
```

Run it:

```bash
./checkmove.sh
```

---

## How It Works

1. Select one or more files and/or folders.
2. Build a destination path from configurable path segments.
3. Validate all source and destination paths.
4. Confirm any folders that will need to be created.
5. Review a transfer summary.
6. Copy files using `rsync`.
7. Verify the copy using checksum comparison.
8. Automatically retry if a transfer or verification fails.
9. Finish only when verification passes.

---

## Configuration

The destination path structure is defined by the `PATH_PARTS` array near the top of the script:

```bash
PATH_PARTS=(
    "DEFAULT_ROOT_DESTINATION="
    "YEAR="
    "CLIENT="
    "PROJECT="
    "FOLDER!="
)
```

### Rules

| Format | Behavior |
|----------|----------|
| `LABEL=value` | Uses the predefined value without prompting |
| `LABEL=` | Prompts the user; blank input skips the segment |
| `LABEL!=` | Prompts the user; input is required |

The first entry is always treated as the root destination and must be an absolute path or begin with `~`.

---

## Example Configuration

```bash
PATH_PARTS=(
    "DEFAULT_ROOT_DESTINATION=/mnt/archive"
    "YEAR="
    "CLIENT="
    "PROJECT="
    "FOLDER!="
)
```

User input:

```text
YEAR    = 2025
CLIENT  = Acme
PROJECT = Migration
FOLDER  = Photos
```

Destination produced:

```text
/mnt/archive/2025/Acme/Migration/Photos
```

### Customizing PATH_PARTS

You can freely add, remove, or reorder entries in the `PATH_PARTS` array to match your own folder structure.

For example:

```bash
PATH_PARTS=(
    "ROOT=/mnt/archive"
    "YEAR="
    "CLIENT="
    "PROJECT="
    "MEDIA_TYPE="
    "FOLDER!="
)
```

would produce a path like:

```text
/mnt/archive/2025/Acme/Migration/Photos/RAW
```

or you could simplify it to:

```bash
PATH_PARTS=(
    "ROOT=/mnt/archive"
    "FOLDER!="
)
```

which would produce:

```text
/mnt/archive/Photos
```

When adding new entries, follow the same format used by the existing examples:

```bash
"LABEL=value"   # Fixed value, no prompt
"LABEL="        # Prompted, optional
"LABEL!="       # Prompted, required
```

The script automatically processes the entries in the order they appear, building the destination path from top to bottom. Any entry can be added, removed, or reordered as needed.

---

## Entering Source Paths

### One Path Per Line

```text
/home/user/file.txt
```

### Paths With Spaces

```text
/home/user/My Folder/file.txt
```

If entered alone on a line, quoting is not required.

### Multiple Paths On One Line

Quoted:

```text
"/path/Folder One" "/path/Folder Two"
```

Escaped:

```text
/path/Folder\ One /path/Folder\ Two
```

### Home Directory Expansion

```text
~/Documents
```

---

## Folder Copy Behavior

CheckMove follows standard `rsync` semantics.

### Copy The Folder Itself

Source:

```text
/photos
```

Result:

```text
destination/photos
```

### Copy Only The Folder Contents

Source:

```text
/photos/
```

Result:

```text
destination/<contents of photos>
```

Trailing slashes matter.

---

## Validation

Before any files are copied, CheckMove:

- Validates every source path
- Builds the destination path
- Checks for missing destination folders
- Detects file/folder conflicts
- Displays a complete transfer summary
- Requests final confirmation

No changes are made until approval is given.

---

## Transfer Verification

Transfers are performed using:

```bash
rsync -avh --progress --partial
```

Verification is performed using:

```bash
rsync -avhc --dry-run
```

If verification detects differences between source and destination, the script automatically reruns the transfer and verifies again.

---

## Exit At Any Time

Typing:

```text
exit
```

at any prompt will immediately terminate the program.

---

## Safety Features

- No wildcard expansion (`*`, `?`)
- No environment variable expansion (`$HOME`, `$PWD`, etc.)
- Prevents destination path traversal (`..`)
- Detects destination file/folder conflicts
- Refuses to proceed with invalid source paths
- Creates directories only after final confirmation

---

## Example Session

```text
Files/Folders:
/home/user/photos
/home/user/documents

YEAR: 2025
CLIENT: ACME
PROJECT: Archive
FOLDER: Backup

Proceed? [y/n]
```

Final destination:

```text
/backup/2025/ACME/Archive/Backup
```

The data is copied, checksum verified, and the script exits only after a successful verification pass.

---

## Why CheckMove?

While `rsync` is already a powerful and reliable tool, CheckMove adds:

- Interactive destination construction
- Validation workflows
- User-friendly prompts
- Automatic retry handling
- Integrated checksum verification
- Safer archive and backup workflows

Ideal for:

- Photo archives
- Project backups
- Client deliverables
- Media migrations
- Long-running file transfers

---

## License

MIT License

Feel free to modify, redistribute, and adapt the script to fit your own backup, archive, and migration workflows.
