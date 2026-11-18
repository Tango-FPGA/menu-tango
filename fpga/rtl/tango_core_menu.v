// SPDX-License-Identifier: MIT
// Copyright (c) 2026 the Tango authors
//==============================================================================
// tango_core (menu core) -- the launcher, MiSTer's menu.rbf.  Everything but its picture -- link, overlay, pads -- is
// the framework (sys/).  Its CONF_STR names it MENU, which makes the BL616 firmware treat it as the launcher (MiSTer's
// menu core: "MENU;UART31250,MIDI;" ... "V,v<date>" -- the UART entry dropped).  No options, no downloads.
//
// A scaler core built the same way as every other core: it
// builds with the standard set (TANGO_VIDEO_ASCAL + TANGO_VIDEO_OPTS + TANGO_VIDEO_PROC, fpga/build/build_menu_vproc.sh;
// sys/README.md "Build options") and its CONF_STR has the framework's Video entries.  As MiSTer's menu
// core (the scaler shows its native picture; video_init loads MiSTer.ini's processing defaults for "MENU"), the
// launcher's picture goes through ascal and the firmware's video processing.  There is no other video path: a build
// without TANGO_VIDEO_ASCAL stops at elaboration (module TANGO_LAUNCHER_IS_A_SCALER_CORE does not exist).
//
// The picture: the Tango test pattern (tango_test_pattern; its spec: tango_test_pattern.v's header), computed
// on a 720p beam of the core's own (CLK_PIX, hdmi.sv's numbering: x 0..1649, y 0..749, 60.0 Hz) and sent to the scaler
// as a NATIVE 640 x 360 frame: the pixels with even x and even y (the reference model's test_pattern_native).  ascal scales
// it x2 back to 1280 x 720 (16:9, Aspect ratio Original); 1-px lines of the pattern become 2 px.  640 x 360 x 24 bits at
// 60 Hz is ~41.5 MB/s written into the frame buffers (the SDRAM's port C; the DDR3 in the card build), as much read back.
// Native timing (MiSTer's emu video ports; sys/tango_core_ports.vh RULE): CE_PIXEL is high for one clock per native
// pixel -- the clock after the beam's even x of an even line -- 825 per native line, blanking included, so it keeps
// pulsing through the blanking; VGA_* are registered at those clocks only (they change only at CE_PIXEL clocks, as
// MiSTer's video_mixer does).  Native line: 640 active + 185 blanking (HS at 695 .. 714); native frame: 360 active +
// 15 blanking lines (VS on native lines 362 .. 364).  The odd beam lines carry no native pixel (no CE_PIXEL).
//==============================================================================
// BUILD_DATE: "v<yymmdd>" from the build script (sys/board/console138k/build_core.sh, TANGO_BUILD_DATE), the CONF_STR's
// V tag as in every Tango core; a bench that defines none gets "sim".
`ifndef BUILD_DATE
`define BUILD_DATE "sim"
`endif
`default_nettype none
module tango_core (
    `include "tango_core_ports.vh"
);
    localparam CONF_STR = {
        "MENU;;",
        `TANGO_VIDEO_CONF,                  // the framework's Aspect ratio, Scale, Scanlines (the launcher UI shows no page)
        "V,",`BUILD_DATE
    };
    tango_conf_rom #(.CONF_STR(CONF_STR)) u_conf (.clk(CLK_PIX), .addr(conf_addr), .q(conf_char));
`ifndef TANGO_VIDEO_ASCAL
    TANGO_LAUNCHER_IS_A_SCALER_CORE build_it_with_tango_video_ascal ();   // header: no other video path
`else
    assign CLK_SYS = CLK_PIX;
    assign AUDIO_L = 16'd0;  assign AUDIO_R = 16'd0;
`ifdef TANGO_CORE_AUDIO_MIX
    assign AUDIO_MIX = 2'd0;
`endif
    assign status_menumask = 16'd0;
    assign ioctl_wait = 1'b0;

    // ---- the core's own 720p beam, and the pattern on it
    reg  [11:0] bx = 12'd0;  reg [10:0] by = 11'd0;
    always @(posedge CLK_PIX)
        if (RESET) begin bx <= 12'd0; by <= 11'd0; end
        else if (bx == 12'd1649) begin bx <= 12'd0; by <= (by == 11'd749) ? 11'd0 : by + 11'd1; end
        else bx <= bx + 12'd1;
    wire [23:0] tp;                         // the pattern for (bx, by) of the previous clock = (px, py) below
    tango_test_pattern u_tp (.clk(CLK_PIX), .rst(RESET), .cx(bx), .cy(by), .rgb(tp));
    reg  [11:0] px = 12'd0;  reg [10:0] py = 11'd0;
    always @(posedge CLK_PIX) begin px <= bx; py <= by; end

    // ---- the native 640 x 360 frame (header): the pixel (px, py) with px and py even, registered with its sync
    wire        nat   = !px[0] && !py[0];
    reg         ce_q  = 1'b0;
    reg  [23:0] rgb_q = 24'd0;
    reg         de_q  = 1'b0, hs_q = 1'b0, vs_q = 1'b0;
    always @(posedge CLK_PIX) begin
        ce_q <= nat;
        if (nat) begin
            rgb_q <= tp;
            de_q  <= (px < 12'd1280) && (py < 11'd720);
            hs_q  <= (px >= 12'd1390) && (px < 12'd1430);
            vs_q  <= (py >= 11'd724) && (py < 11'd730);
        end
    end
    assign CLK_VIDEO       = CLK_PIX;
    assign CE_PIXEL        = ce_q;
    assign VGA_R = rgb_q[23:16];  assign VGA_G = rgb_q[15:8];  assign VGA_B = rgb_q[7:0];
    assign VGA_DE          = de_q;
    assign VGA_HS          = hs_q;
    assign VGA_VS          = vs_q;
    assign VGA_SL          = 2'd0;          // the framework's Scanlines (TANGO_VIDEO_OPTS)
    assign VIDEO_ARX       = 13'd16;        // the native shape: 16:9, the framework's Aspect ratio "Original"
    assign VIDEO_ARY       = 13'd9;
    assign HDMI_FREEZE     = 1'b0;
    assign VIDEO_SCALE     = 3'd0;          // the framework's Scale (TANGO_VIDEO_OPTS)
    assign VIDEO_CROP_SIZE = 12'd0;
    assign VIDEO_CROP_OFF  = 5'd0;
`endif
endmodule
`default_nettype wire
