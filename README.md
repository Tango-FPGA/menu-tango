# menu-tango -- the Tango launcher

**Version 2026-11-13** (date code `20261113`)

menu-tango is the **launcher** of the Tango FPGA system for the **Sipeed Tang Console 138K**: the FPGA core the Tango
firmware loads from the SD card at power-on, as MiSTer loads its menu core. Its picture is the Tango test pattern; over
it the firmware draws the launcher's pages (the Cores browser, System Settings, Define joystick buttons, About) on the
framework's on-screen-menu overlay, and loads the core you pick.

The launcher is a core like any other Tango core: it is built on the framework
[sys-tango](https://github.com/Tango-FPGA/sys-tango), which this repository includes as a git submodule at `sys/`. The
BL616 firmware that loads it and runs its pages is [firmware-tango](https://github.com/Tango-FPGA/firmware-tango), and
[console-template-tango](https://github.com/Tango-FPGA/console-template-tango) is the example core.

## Contents

- [What you need](#what-you-need)
- [Installing](#installing)
- [What the launcher core does](#what-the-launcher-core-does)
- [Building from source](#building-from-source)
- [Layout](#layout)
- [Attributions](#attributions)
- [Licence](#licence)

## What you need

- A **Sipeed Tang Console 138K** (the GW5AST-138 FPGA). The launcher uses the board's DDR3 for its frame buffers.
- **firmware-tango** in the board's BL616 (its README, "Installing"): the firmware loads the launcher from the card and
  draws every page of it.
- A **FAT32 SD card** in MiSTer's layout (firmware-tango's README, "The SD card"), with the cores you want to start.

## Installing

The launcher bitstream is in this repository's **`releases/`** folder, one file per release named
`menu_<YYYYMMDD>.bin` (this version: `releases/menu_20261113.bin`). Take the latest (the newest date) and copy it
to the root of the SD card as **`/menu.bin`**. At power-on the firmware loads `/menu.fs` if the card has one, else
`/menu.bin`: remove an old `/menu.fs`, or the firmware keeps loading that.

The firmware starts from the SD card only while no PC is connected to the board's **MCU** USB-C port (with a PC there,
the BL616 stays the PC's USB debugger): power the board from its other USB-C port or a power supply.

`menu.bin` is a raw bitstream (the `.bin` the firmware streams into the FPGA over JTAG); `fpga/build/build_menu_vproc.sh`
makes it from the Gowin `.fs` with `sys/build_tools/fs2bin.py`. Its menu string (CONF_STR) begins `MENU`, which is how
the firmware knows it is the launcher, and ends `V,v260928`.

## What the launcher core does

- **Its picture:** the Tango test pattern (`fpga/rtl/tango_test_pattern.v`: a gradient, grids, two rings, colour bars,
  a sweep line; per-pixel logic, no frame buffer, no ROM), computed on a 720p beam and sent to the scaler as a native
  **640 x 360** frame, which the framework's scaler (ascal) shows at 1280 x 720.
- **The standard set of the framework** (sys-tango README, "Build options"): `TANGO_VIDEO_ASCAL` (the scaler), its
  frame buffers in the **DDR3** (`TANGO_VIDEO_DDR3`), the framework's Video page entries (`TANGO_VIDEO_OPTS`: Aspect
  ratio, Scale, Scanlines) and MiSTer's video and audio processing (`TANGO_VIDEO_PROC`), so the firmware's video
  processing settings apply to the launcher as to any core.
- **Everything else is the framework's:** the BL616 link, the on-screen-menu overlay the firmware draws the pages on,
  the USB-A pad and keyboard ports, the HDMI output (720p, 48 kHz audio; the launcher's audio is silent).
- No options of its own and no file downloads (`fpga/rtl/tango_core_menu.v`).

## Building from source

You need, on Linux (x86-64):

- **Gowin EDA** (the IDE with `gw_sh`), V1.9.11.03, with a licence for the GW5AST-138 and its DDR3 Memory Interface
  IP. The framework's `build_core.sh` runs it headless from `$GOWIN_HOME/IDE` (default `~/gowin`) and takes Gowin's
  `PLL_INIT` and the DDR3 IP from that installation (sys-tango README, "Building").
- **Python 3** (the build tools).
- **systemd** user scopes for `tango_capped.sh`, which runs the build in a memory-capped cgroup. A 138K build needs a
  few GB of memory; run one build at a time.

Get the sources with the framework:

    git clone https://github.com/Tango-FPGA/menu-tango.git
    cd menu-tango
    git submodule update --init          # sys/ = sys-tango, at the commit this release was built with

Build the launcher:

    fpga/build/build_menu_vproc.sh

It runs the framework's `sys/board/console138k/build_core.sh` with the launcher's options, then the STA gate
(`sys/build_tools/sta_gate.py`: no setup or hold violation, every clock at or above its constraint, a worst setup
slack of at least +0.10 ns, logic and block RAM at most 98%; never use a build whose gate failed), and archives the result in `$TANGO_ARCHIVE` (default `bitstreams/` in the checkout) as
`tango_menu_ascal138_<YYYYMMDD-HHMM>_g<commit>_vproc_ddr3.{fs,bin,txt}` (`..._STA-FAIL` when the gate failed; the
`.txt` holds the gate's report and the resource use). Copy the `.bin` to the card as `/menu.bin`. The Gowin project
is in `fpga/build/out/tango_menu_ascal138/`.

Optional, for testing without the firmware (over JTAG): `TANGO_PRESET_STATUS=<32 hex digits>` (the option word at
power-up) and `TANGO_VPROC_PRESET="<settings>"` (a compiled-in filter / gamma / mask load, from MiSTer's filter files
in `TANGO_FILTERS_ROOT`); the argument of the script
is a tag added to the archive name. Both are the framework's options (sys-tango README, "Build options").

## Layout

| Path | What |
|---|---|
| `releases/` | the launcher bitstreams, `menu_<YYYYMMDD>.bin`, one per release (copy the latest to the card as `/menu.bin`) |
| `fpga/rtl/tango_core_menu.v` | the launcher core (module `tango_core`, the framework's core interface) |
| `fpga/rtl/tango_test_pattern.v` | its picture |
| `fpga/build/build_menu_vproc.sh` | the card build |
| `sys/` | the framework, [sys-tango](https://github.com/Tango-FPGA/sys-tango) (git submodule) |

## Attributions

| Component | Where | Author | Licence |
|---|---|---|---|
| **sys-tango**, the framework | `sys/` (submodule) | the Tango authors, with third-party parts | MIT, except the files derived from MiSTer (GNU GPL) and the third-party parts listed in its own `NOTICE` |

**Following MiSTer and FPGA Companion:** the menu string format (CONF_STR, which begins `MENU` as the CONF_STR of
MiSTer's menu core does) and the core interface are MiSTer's; the link is the SPI format of
[FPGA Companion](https://github.com/MiSTle-Dev/FPGA-Companion). `NOTICE` lists the MiSTer text in the launcher's files.

## Licence

**MIT** (`LICENSE`), `Copyright (c) 2026 the Tango authors`, for the launcher's own code, as each source file's
`SPDX-License-Identifier: MIT` header says (`NOTICE`: the MiSTer text it carries).

The framework in `sys/` is sys-tango's, under its own `LICENSE` and `NOTICE`.

**The bitstream (`releases/menu_<YYYYMMDD>.bin`, on the card as `menu.bin`):** the launcher's build includes
sys-tango's `tango_video_geo.v`, `tango_shmask.v` and `tango_audio_filter.v`, which are under the GNU General Public
License, version 2 or (at your option) any later version (derived from MiSTer; sys-tango's `NOTICE`). `menu.bin` is therefore a combined work distributed under the terms of
GPL-2.0-or-later; its source is this repository at the release's commit, with sys-tango at `sys/` (the commit the
submodule points at).
`PLL_INIT` and the DDR3 Memory Interface IP, which the build takes from the Gowin installation, keep Gowin's terms.

The BL616 firmware, [firmware-tango](https://github.com/Tango-FPGA/firmware-tango), is GPL-3.0-or-later and released
separately.
