#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 the Tango authors
# build_menu_vproc.sh [tag] -- the launcher (/menu.bin, fpga/rtl/tango_core_menu.v) as a scaler core with the standard
# set (sys/README.md "Build options"): TANGO_VIDEO_ASCAL=1 TANGO_VIDEO_OPTS=1
# TANGO_VIDEO_PROC=1 (MiSTer's video and audio processing; it brings TANGO_AUDIO_FILTER), its native 640 x 360 frame:
# TANGO_VIDEO_ASCAL_MAXW=640, TANGO_VIDEO_ASCAL_MAXH=360.
# Optional build-time presets (sys/tango_cfg.vh; boards without the Tango firmware, e.g. JTAG tests):
#   TANGO_PRESET_STATUS=<32 hex digits>   the option word at power-up
#   TANGO_VPROC_PRESET="<vproc_preset.py settings>"   a compiled-in filter / gamma / mask load
#   [tag]  a name for the preset, added to the archive name
# TANGO_VIDEO_DDR3=1 (sys/README.md "The DDR3 path"): ascal's frames in the DDR3 (no tango_sdram, no
# SDRAM PLL); the archive gets _ddr3 after _vproc.
# Gate: sys/build_tools/sta_gate.py, every clock.
# Archive: $TANGO_ARCHIVE (default bitstreams/ of this checkout) tango_menu_ascal138_<stamp>_g<git>[-dirty]_vproc
# [_<tag>].{fs,bin,txt} (the .txt: the framework, the gate, resources); a failing gate is archived as ..._STA-FAIL.
# Never flashes anything.  A heavy job (several GB of memory, run through sys/build_tools/tango_capped.sh): one at a time.
set -eu
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
NAME=tango_menu_ascal138
TAG="${1:-}"
FILES="$ROOT/fpga/rtl/tango_core_menu.v $ROOT/fpga/rtl/tango_test_pattern.v"
START=$(mktemp); trap 'rm -f "$START"' EXIT
set +e
TANGO_NO_ARCHIVE=1 TANGO_VIDEO_ASCAL=1 TANGO_VIDEO_DDR3=1 TANGO_VIDEO_OPTS=1 TANGO_VIDEO_PROC=1 TANGO_VIDEO_ASCAL_MAXW=640 TANGO_VIDEO_ASCAL_MAXH=360 \
    TANGO_OUT=fpga/build/out "$ROOT/sys/board/console138k/build_core.sh" "$NAME" - $FILES
BC=$?
set -e
IMPL="$ROOT/fpga/build/out/$NAME/impl/pnr"
FS="$IMPL/$NAME.fs"
[ $BC -eq 0 ] && [ -f "$FS" ] && [ "$FS" -nt "$START" ] || { echo "NO FRESH BITSTREAM (build_core.sh exit $BC)"; exit 1; }
set +e; GATE=$(python3 "$ROOT/sys/build_tools/sta_gate.py" "$IMPL"); SG=$?; set -e   # TANGO_VIDEO_DDR3: no clk_sdram
echo "$GATE"
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)
DTAG=""; [ -n "$(git status --porcelain --untracked-files=no -- fpga/rtl fpga/build sys 2>/dev/null)" ] && DTAG="-dirty"
FSHA=$(git -C sys rev-parse --short=12 HEAD); FDIRTY=$(git -C sys status --porcelain --untracked-files=no | wc -l)
ARCH="${TANGO_ARCHIVE:-$ROOT/bitstreams}"; mkdir -p "$ARCH"
STAMP="$ARCH/${NAME}_$(date +%Y%m%d-%H%M)_g${SHA}${DTAG}_vproc_ddr3${TAG:+_$TAG}"; [ $SG -ne 0 ] && STAMP="${STAMP}_STA-FAIL"
cp "$FS" "$STAMP.fs" && cmp "$FS" "$STAMP.fs" && chmod 444 "$STAMP.fs"
python3 "$ROOT/sys/build_tools/fs2bin.py" "$STAMP.fs" "$STAMP.bin" && chmod 444 "$STAMP.bin"
{ echo "menu-tango launcher ASCAL + TANGO_VIDEO_PROC + TANGO_VIDEO_DDR3 $SHA$DTAG"; echo "framework: sys/ = sys-tango $FSHA (uncommitted files in sys/: $FDIRTY)"
  echo "TANGO_PRESET_STATUS=${TANGO_PRESET_STATUS:-}"; echo "TANGO_VPROC_PRESET=${TANGO_VPROC_PRESET:-}"
  echo; echo "$GATE"
  grep -E "^\s*(Logic|CLS|Register|BSRAM|DSP|PLL)\s*\|" "$IMPL/$NAME.rpt.txt" || true
  J="$ROOT/fpga/build/out/${NAME}_vproc_preset.json"; [ -n "${TANGO_VPROC_PRESET:-}" ] && [ -f "$J" ] && { echo; echo "preset tables:"; cat "$J"; }
} > "$STAMP.txt"
chmod 444 "$STAMP.txt"
sha256sum "$STAMP.fs" "$STAMP.bin"
ls -l "$STAMP".*
[ $SG -ne 0 ] && { echo "WARNING: STA GATE FAIL -- do NOT flash"; exit 1; }
exit 0
