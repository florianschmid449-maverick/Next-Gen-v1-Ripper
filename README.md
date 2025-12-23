# 📀 NextGen Blu-ray/DVD Ripper

**NextGen Ripper** is a high-performance, bash-based automation tool designed for archiving optical media (DVDs and Blu-rays). It features a professional terminal dashboard, automatic file splitting for large media, multi-part tracking, and comprehensive logging.

It is designed to run in a loop: **Insert Disc ➔ Rip ➔ Eject ➔ Repeat.**

## 🚀 Key Features

* **Real-Time Dashboard:** visualizing progress, current write speed (MB/s), and ETA for every part of the rip.
* **Smart Splitting:** Automatically detects discs larger than 4GB (standard Blu-rays) and splits them into 4GB chunks (compatible with FAT32 file transfers).
* **Automated Workflow:** Auto-detects optical drives, rips the content, logs the data, and ejects the disc upon completion.
* **Resilience:** Includes a retry mechanism (up to 3 attempts) for difficult-to-read sectors.
* **Data Integrity:** Generates SHA256 checksums for every ripped part to ensure file integrity.
* **Master Logging:** Maintains a `csv` database of all rips, including timestamps, file sizes, and checksums.
* **Safety Checks:** Verifies available disk space before starting to prevent incomplete rips.

## 🛠 Dependencies

This script requires a Linux environment (Ubuntu/Debian recommended) with the following packages installed:

* `pv` (Pipe Viewer) - For monitoring data progress.
* `gddrescue` (GNU ddrescue) - For robust data copying.
* `tput` (ncurses) - For dashboard visualization.

### Install Dependencies (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install pv gddrescue

```

## 📥 Installation

1. Clone this repository or download the script.
2. Make the script executable:

```bash
chmod +x nextgen.sh

```

## 🖥️ Usage

1. Open your terminal.
2. Run the script:

```bash
./nextgen.sh

```

3. **Insert a DVD or Blu-ray.** The script will automatically:
* Detect the drive (`/dev/sr0`, etc.).
* Check for disk space.
* Begin ripping to your **Desktop**.
* Display the real-time dashboard.
* Eject the disc when finished.


4. Insert the next disc to continue the batch, or press `Ctrl+C` to stop.

## 📂 Output & Logging

### File Storage

By default, files are saved to:
`$HOME/Desktop/`

* **Standard DVDs:** Saved as single `.iso` files.
* **Blu-rays (>25GB):** Split into parts (e.g., `_part1`, `_part2`) to manage large file sizes and filesystem limits.

### Naming Convention

Files are named using a timestamp to avoid overwrites:
`disc_rip_YYYYMMDD_HHMMSS.iso`

### Master Log

A CSV log is maintained at `$HOME/Desktop/disc_rip_master_log.csv` containing:

* Timestamp
* Filename
* Size (Bytes)
* SHA256 Checksums
* Number of parts

## ⚙️ Configuration

You can customize variables at the top of the `nextgen.sh` file:

```bash
DESKTOP="$HOME/Desktop"          # Output directory
SPLIT_SIZE=$((4*1024*1024*1024)) # Size to split files (Default: 4GB)
MAX_RETRIES=3                    # Number of retries on read failure

```

## ⚠️ Disclaimer

This tool is intended for **personal archiving and backup purposes only** of media you legally own. Please check your local laws regarding copyright and format shifting before using this software.
