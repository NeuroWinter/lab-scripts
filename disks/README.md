# POS Disk Forensics Scripts

A collection of bash scripts for imaging and analysis of disks recovered from e-waste POS and other machines.

## Scripts

| Script | Purpose | Requires root |
|--------|---------|---------------|
| `image_and_hash.sh` | Create image with ddrescue + hash verification | Yes |
| `hash_one_image.sh` | Generate SHA256/MD5 for existing image | No |
| `triage_image.sh` | Quick triage report (hex, strings, signatures) | Optional (for blkid/fdisk) |

## Installation

```bash
git clone https://github.com/neurowinter/lab-scripts.git
cd lab-scripts/disks
chmod +x *.sh lib/*.sh
```

### Dependencies

**Required:**
- `ddrescue` (gddrescue)
- `pv` (pipe viewer)
- `hexdump` (bsdmainutils)

**Optional:**
- `ent` (entropy analysis for triage)
- `blkid`
- `fdisk` (partition info for triage I have found these super useful!)

On Debian/Ubuntu:
```bash
sudo apt install gddrescue pv bsdmainutils ent
```

## Configuration

All scripts use environment variables for paths. Defaults are set for my setup but can be overridden:

```bash
export POS_IMG_DIR=/path/to/images       # Default: /media/neuro/data/POS-IMAGES
export POS_TEMP_DIR=/path/to/temp        # Default: /tmp/pos-temp
```

## Typical Workflow

### 1. Image a drive

```bash
# Connect drive (e.g., appears as /dev/sdc)
# lsblk -o NAME,SIZE,MODEL,SERIAL helps me find where it's mounted
sudo ./image_and_hash.sh /dev/sdc DRV-01
```

This will:
- Set drive read-only - software write-blocking
- Image with ddrescue to temp location (You will need to make sure you have enough space locally!)
- Copy to destination while computing SHA256/MD5
- Verify hashes
- Save ddrescue log

### 2. Triage the image

```bash
./triage_image.sh /media/neuro/data/POS-IMAGES/DRV-01.img
```

Creates `DRV-01.triage.txt` with:
- File type and partition info
- Hex dumps at key offsets
- String samples
- Filesystem signature detection
- Entropy analysis if `ent` is installed


## Hash creation

To hash an existing image (e.g., after transfer):

```bash
./hash_one_image.sh /path/to/DRV-01.img
```

To regenerate existing hashes:

```bash
./hash_one_image.sh /path/to/DRV-01.img --force
```

## Notes

- **Write blocking**: These scripts use software write-blocking (`blockdev --setro`). For proper forensic work, consider using a hardware write blocker.
- **Naming convention**: I use `DRV-XX` format (e.g., DRV-01, DRV-02) but any name works.
