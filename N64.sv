//============================================================================
//  N64 for MiSTer
//  Copyright (C) 2023 Robert Peip
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
   output         HDMI_FREEZE,
   output         HDMI_BLACKOUT,
   output         HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[8:7];

assign LED_USER  = cartN64_download | cartGB_download | aleckExtra_download | bk_pending;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign VGA_SCALER= 0;

assign ADC_BUS  = 'Z;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign FB_BASE    = video_FB_base;
assign FB_EN      = video_FB_en;
assign FB_FORMAT  = 5'b00110;
assign FB_WIDTH   = {2'd0, video_FB_sizeX};
assign FB_HEIGHT  = {2'd0, video_FB_sizeY};
assign FB_STRIDE  = 14'd4096;
assign FB_FORCE_BLANK = 0;

///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire clk_1x;
wire clk_93;
wire clk_2x;
wire clk_vid;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_1x),
	.outclk_1(clk_93),
	.outclk_2(clk_2x),
	.outclk_3(SDRAM_CLK),
   .locked(pll_locked)
);

pll2 pll2
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),
   .reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;

wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg_small pll_cfg_small
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin : cfg_block
	reg pald = 0, pald2 = 0;
	reg [2:0] state = 0;

	pald  <= status[79];
	pald2 <= pald;

	cfg_write <= 0;
	if(pald2 != pald) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			3: begin
					cfg_address <= 7;
					cfg_data <= pald2 ? 4024384270 : 3274482981;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

wire reset_or = RESET | buttons[1] | status[0];

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6          7         8         9
// 01234567890123456789012345678901 23456789012345678901234567890123 45678901234567890123456789012345
// todo
// 

`include "build_id.v"
parameter CONF_STR = {
	"Aleck64;SS3C000000:1000000;",
   "H2FS1,N64z64n64v64,Load,32000000;",
   "H2F2,GBCGB ,Load GB-Transfer;",
   "H2-;",
   "H2C,Cheats;",
   "H2O[103],Cheats Enabled,Yes,No;",
   "H2-;",
	"R[40],Reload Backup RAM;",
	"R[41],Save Backup RAM;",
	"O[42],Autosave,On,Off;",
   //"-;",
	//"O[46],Savestates to SDCard,On,Off;",
	//"O[3],Autoincrement Slot,Off,On;",
	//"O[39:38],Savestate Slot,1,2,3,4;",
	//"RH,Save state (Alt-F1);",
	//"RI,Restore state (F1);",
	"-;",
   "H2O[51:49],Pad 1 Type,N64Pad,None,ControllerPak,RumblePak,SNAC,TransferPak;",
   "H2O[54:52],Pad 2 Type,N64Pad,None,ControllerPak,RumblePak,SNAC;",
   "H2O[57:55],Pad 3 Type,N64Pad,None,ControllerPak,RumblePak,SNAC;",
   "H2O[60:58],Pad 4 Type,N64Pad,None,ControllerPak,RumblePak,SNAC;",
   "H2O[92],Swap Analog<->DPAD,Off,On;",
   "H2O[86:84],Mouse for P1,Off,Buttons ABZ,Buttons ZAB,Buttons ZBA;",
   "H2O[62:61],Dual Controller,Off,P1->P2,P1->P3;",
   "H2O[63],Analog Stick Swap,Off,On;",
	"DIP;",
	"-;",
   
   "P1,Video & Audio;",
   "P1O[8:7],Stereo Mix,None,25%,50%,100%;",
   "P1O[82],Fixed Video Blanks,On,Off;",
   "D0P1O[45:44],Crop Vertical,None,8,12;",
   "P1O[48:47],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
   "P1-;",
   "H3P1O[105],Video Out,Original(VI),Clean HDMI;",
   "D1P1O[104],VI Colorbits,Original(21),24;",
   "D1P1O[32],VI Bilinear,Original,Off;",
   "D1P1O[89],VI Deblur,Original,On;",
   "D1P1O[33],VI Gamma,Original,Off;",
   "D1P1O[88:87],VI Dedither,Original,Off,Force;",
   "D1P1O[35],VI Antialias,Original,Off;",
   "D1P1O[36],VI Divot,Original,Off;",
   "D1P1O[37],VI Noisedither,Original,Off;",
   "P1-;",
   "P1O[30],Texture Filter,Original,Off;",
   "P1O[31],Dithering,Original,Off;",
   "P1O[34],LOD Textures,Original,Off;",
   "P1-;",
   "P1O[2],Error Overlay,Off,On;",
   "P1O[28],FPS Overlay,Off,On;",
   
   "H2P2,System settings;",
	"H2P2-;",
   "H2P2-,From N64-database;",
	"H2P2O[64],Auto Detect,On,Off;",
   "H2P2O[90],Patch games,Yes(Auto),Off;",
   "H2P2O[70],RAM size,8MByte,4MByte;",
   "H2P2O[80:79],System Type,NTSC,PAL;",
	"H2P2O[68:65],CIC,6101,6102,7101,7102,6103,7103,6105,7105,6106,7106,8303,8401,5167,DDUS,5101;",
   "H2P2O[81],Auto Setup Pak Type,On,Off;",
   "H2P2O[71],ControllerPak,Off,On;",
   "H2P2O[72],RumblePak,Off,On;",
   "H2P2O[73],TransferPak,Off,On;",
   "H2P2O[74],RTC,Off,On;",
   "H2P2O[77:75],Save Type,None,EEPROM4,EEPROM16,SRAM32,SRAM96,Flash;",
   
   "H2P3,Debug settings;",
   "H2P3O[83],Fast RAM access,Off,On;",
   "H2P3O[106],Fast ROM access,Off,On;",
   "H2P3O[93],Instr Cache,On,Off;",
   "H2P3O[43],Data Cache,On,Off;",
   "H2P3O[100],Data Cache from TLB,On,Off;",
   "H2P3O[29],Data FORCE WB,Off,On;",
   "H2P3O[99],DTLB Mini Cache,On,Off;",
   //"H2P3O[97:94],iTLB Random Miss,Off,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15;",
   "H2P3O[27:24],Cache Delay,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15;",
   "H2P3O[23:20],DDR3 Delay,0,16,24,32,40,48,56,64,72,80,88,96,104,112;",
   "H2P3O[98],RDRAM Calib Waittime,On,Off;",
   "H2P3O[11],Write Bit 9,On,Off;",
   "H2P3O[12],Read Bit 9,On,Off;",
   "H2P3O[13],Wait Bit 9,On,Off;",
   "H2P3O[14],Write Z,On,Off;",
   "H2P3O[15],Read Z,On,Off;",
   "H2P3O[1],Swap Interlaced,Off,On;",
   "H2P3O[101],AI processing,On,Off;",
   "H2P3O[102],AI IRQ,On,Off;",
   "H2P3O[91],SNAC Compare,Off,On;",
   "-;",
   
	"R0,Reset;",
   "J1,A,B,Start,L,R,Z,C Up,C Right,C Down,C Left,Softreset;",
	"jn,A,B,Start,L,R,Z,C Up,C Right,C Down,C Left;",
	"I,",
	"Load=DPAD Up|Save=Down|Slot=L+R,",
	"Active Slot 1,",
	"Active Slot 2,",
	"Active Slot 3,",
	"Active Slot 4,",
	"Save to state 1,",
	"Restore state 1,",
	"Save to state 2,",
	"Restore state 2,",
	"Save to state 3,",
	"Restore state 3,",
	"Save to state 4,",
	"Restore state 4;",
	"V,v",`BUILD_DATE
};

wire  [1:0] buttons;
wire [127:0] status;
wire        forced_scandoubler;

wire [31:0] joy;
wire [31:0] joy_unmod;
wire [31:0] joy2;
wire [31:0] joy2_unmod;
wire [31:0] joy3;
wire [31:0] joy4;

wire [15:0] joystick_analog_l0;
wire [15:0] joystick_analog_l1;
wire [15:0] joystick_analog_l2;
wire [15:0] joystick_analog_l3;

wire [24:0] mouse;

wire [10:0] ps2_key;

wire        fixed_blanks_off = status[82];
wire        clean_hdmi;
wire        video_FB_en;

wire [127:0] status_in = {status[127:40],ss_slot,status[37:0]};

wire DIRECT_VIDEO;

wire        ioctl_download;
wire        ioctl_upload;
reg         ioctl_download_1;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wr;
wire  [7:0] ioctl_index;
reg         ioctl_wait = 0;

// MRA index 3 contains the Aleck64 machine descriptor:
// bit 0 = Aleck64 mode, bit 1 = E90 custom video, bit 2 = 8 MiB N64 RDRAM.
// bits 4:3 = input profile: 0 PIF gamepads, 1 direct JAMMA, 2 mahjong,
// 3 Vivid Dolls (PIF/JAMMA selected by DIP SW2 #5).
// bit 5 = force the disconnected D-pad signature required by Eleven Beat.
// bit 6 = BK4D-NUS 4-kbit EEPROM, persisted through MRA NVRAM index 4.
reg  [7:0] aleck_config = 0;
reg [15:0] aleck_dips = 16'hFFFF;
wire       aleck_mode = aleck_config[0];
wire       aleck_e90  = aleck_config[1];
wire [1:0] aleck_input = aleck_config[4:3];
wire       aleck_disconnected_dpad = aleck_mode && aleck_config[5];
wire       aleck_eeprom = aleck_mode && aleck_config[6];
// E90 draws its puzzle-piece layer after the VI pixel stream. Direct
// framebuffer output bypasses that compositor, so keep Clean HDMI unavailable
// only on E90 while exposing it for standard Aleck64 boards.
assign     clean_hdmi = status[105] && !aleck_e90;
wire [15:0] status_menumask = {12'd0, aleck_e90, aleck_mode, clean_hdmi, fixed_blanks_off};

reg  [8:0]  aleck_eeprom_addr = 0;
reg  [31:0] aleck_eeprom_data_in = 0;
wire [31:0] aleck_eeprom_data_out;
reg         aleck_eeprom_wren = 0;
reg         aleck_eeprom_init = 0;
reg         aleck_eeprom_loaded = 0;
wire        aleck_eeprom_change;
reg  [5:0]  aleck_at24_addr = 0;
reg  [15:0] aleck_at24_data_in = 0;
wire [15:0] aleck_at24_data_out;
reg         aleck_at24_wren = 0;
wire        aleck_at24_change;
reg         aleck_at24_nvram_valid = 0;
reg  [19:0] aleck_eeprom_save_delay = 0;
reg         aleck_eeprom_upload_req = 0;
wire [26:0] aleck_at24_ioctl_offset = ioctl_addr - 27'd514;
wire [15:0] aleck_eeprom_upload_data = (ioctl_addr < 27'd512) ?
   (ioctl_addr[1] ? aleck_eeprom_data_out[31:16] : aleck_eeprom_data_out[15:0]) :
   ((ioctl_addr == 27'd512) ? 16'h24A5 : aleck_at24_data_out);

always @(posedge clk_1x) begin
	// MRA downloads occur while the core is held in RESET.  These descriptor
	// registers therefore use their FPGA power-up values and must remain
	// writable throughout reset; clearing them here would erase the selected
	// Aleck64 machine before the CPU is released.
	if(ioctl_wr) begin
		if(ioctl_index == 8'd3 && !ioctl_addr[26:1]) aleck_config <= ioctl_dout[7:0];
		if(ioctl_index == 8'hFE && !ioctl_addr[26:1]) aleck_dips <= ioctl_dout;
	end
end

// The MRA loader replays the combined NVRAM file on index 4. Pack its first
// 512 bytes into the PIF EEPROM's 32-bit maintenance port; Magical Tetris's
// tagged AT24 extension follows it. The loaded flag is deliberately not
// reset: MRA data arrives while the core reset is asserted.
always @(posedge clk_1x) begin
	aleck_eeprom_wren <= 0;
	aleck_eeprom_init <= 0;
	aleck_at24_wren <= 0;
	if(ioctl_wr && ioctl_index == 8'd3 && !ioctl_addr[26:1]) begin
		// A new MRA must not inherit the previous title's contents when no
		// NVRAM file exists. Start the PIF erase while the remaining ROMs load.
		aleck_eeprom_init <= 1;
		aleck_eeprom_loaded <= 0;
		aleck_at24_nvram_valid <= 0;
		aleck_eeprom_save_delay <= 0;
	end
	if(ioctl_wr && ioctl_index == 8'd4 && ioctl_addr < 27'd512) begin
		// Assert this on the low half so the following high-half write can
		// immediately take ownership of the PIF EEPROM maintenance port.
		aleck_eeprom_loaded <= 1;
		aleck_eeprom_addr <= ioctl_addr[10:2];
		if(!ioctl_addr[1]) begin
			aleck_eeprom_data_in[15:0] <= ioctl_dout;
		end else begin
			aleck_eeprom_data_in[31:16] <= ioctl_dout;
			aleck_eeprom_wren <= 1;
		end
	end else if(ioctl_wr && ioctl_index == 8'd4 && aleck_e90 && ioctl_addr == 27'd512) begin
		// A header distinguishes the extended format from an older 512-byte
		// save that Main may zero-pad to the MRA's new length.
		aleck_at24_nvram_valid <= (ioctl_dout == 16'h24A5);
	end else if(ioctl_wr && ioctl_index == 8'd4 && aleck_e90 &&
	            ioctl_addr >= 27'd514 && ioctl_addr < 27'd642) begin
		aleck_at24_addr <= aleck_at24_ioctl_offset[6:1];
		aleck_at24_data_in <= ioctl_dout;
		aleck_at24_wren <= aleck_at24_nvram_valid;
	end else if(ioctl_wr && ioctl_index == 8'd5 && aleck_e90 && ioctl_addr < 27'd128) begin
		// Factory contents dumped from the E90 board. A persistent index-4
		// image, when present, is streamed later and overrides this seed.
		aleck_at24_addr <= ioctl_addr[6:1];
		aleck_at24_data_in <= ioctl_dout;
		aleck_at24_wren <= 1;
	end else if(ioctl_upload && ioctl_index == 8'd4) begin
		if(ioctl_addr < 27'd512) aleck_eeprom_addr <= ioctl_addr[10:2];
		else if(ioctl_addr >= 27'd514) aleck_at24_addr <= aleck_at24_ioctl_offset[6:1];
	end

	// Wait until the complete eight-byte PIF write has settled, then ask the
	// arcade framework to save the MRA NVRAM file.
	aleck_eeprom_upload_req <= 0;
	if(aleck_eeprom && (aleck_eeprom_change || (aleck_e90 && aleck_at24_change))) begin
		aleck_eeprom_save_delay <= 20'd1000000;
	end else if(aleck_eeprom_save_delay != 0) begin
		aleck_eeprom_save_delay <= aleck_eeprom_save_delay - 1'd1;
		if(aleck_eeprom_save_delay == 1) aleck_eeprom_upload_req <= 1;
	end
end

reg [7:0] info_index;
reg info_req;

wire  [8:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [31:0] img_size;

wire [3:0] rumble;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
(
	.clk_sys(clk_1x),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

   .ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),
	.ioctl_upload_req(aleck_eeprom_upload_req),
	.ioctl_upload_index(8'd4),
	.ioctl_din(aleck_eeprom_upload_data),

	.joystick_0(joy_unmod),
	.joystick_1(joy2_unmod),
	.joystick_2(joy3),
	.joystick_3(joy4),
	.ps2_key(ps2_key),

	.status(status),
	.status_in(status_in),
	//.status_set(statusUpdate),
	.status_set(0),
	.status_menumask(status_menumask),
	.info_req(info_req),
	.info(info_index),
   
   .joystick_l_analog_0(joystick_analog_l0), 
   .joystick_l_analog_1(joystick_analog_l1),
   .joystick_l_analog_2(joystick_analog_l2),
   .joystick_l_analog_3(joystick_analog_l3),
   
   .joystick_0_rumble(rumble[0] ? 16'hFFFF : 16'h0000),
   .joystick_1_rumble(rumble[1] ? 16'hFFFF : 16'h0000),
   .joystick_2_rumble(rumble[2] ? 16'hFFFF : 16'h0000),
   .joystick_3_rumble(rumble[3] ? 16'hFFFF : 16'h0000),
   
   .ps2_mouse(mouse),
   
   .sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),
   
   .direct_video(DIRECT_VIDEO)
);

////////////////////////////  MAME keyboard controls  /////////////////////////

// MiSTer PS/2 event bus: [10] toggles for each event, [9] is make/break,
// [8] marks an E0-prefixed scan code and [7:0] contains the Set 2 code.
// Keep semantic key state here, then adapt it to each Aleck64 input profile.
reg [3:0] key_p1_dir = 0;
reg [3:0] key_p2_dir = 0;
reg [3:0] key_p1_btn = 0;
reg [3:0] key_p2_btn = 0;
reg [1:0] key_start = 0;
reg [1:0] key_coin = 0;
reg       key_service = 0;
reg       key_test = 0;
reg [22:0] key_mahjong = 0;
reg       old_ps2_toggle = 0;

wire key_pressed = ps2_key[9];
wire [8:0] key_code = ps2_key[8:0];

always @(posedge clk_1x) begin
	old_ps2_toggle <= ps2_key[10];

	if(reset_or || !aleck_mode) begin
		key_p1_dir  <= 0;
		key_p2_dir  <= 0;
		key_p1_btn  <= 0;
		key_p2_btn  <= 0;
		key_start   <= 0;
		key_coin    <= 0;
		key_service <= 0;
		key_test    <= 0;
		key_mahjong <= 0;
	end else if(old_ps2_toggle != ps2_key[10]) begin
		if(aleck_input == 2) begin
			// MAME's default mahjong panel bindings. The Aleck64 panel
			// exposes A-D on its direction slots and E-Ron on buttons.
			case(key_code)
				9'h01C: key_mahjong[ 0] <= key_pressed; // A
				9'h032: key_mahjong[ 1] <= key_pressed; // B
				9'h021: key_mahjong[ 2] <= key_pressed; // C
				9'h023: key_mahjong[ 3] <= key_pressed; // D
				9'h024: key_mahjong[ 4] <= key_pressed; // E
				9'h02B: key_mahjong[ 5] <= key_pressed; // F
				9'h034: key_mahjong[ 6] <= key_pressed; // G
				9'h033: key_mahjong[ 7] <= key_pressed; // H
				9'h043: key_mahjong[ 8] <= key_pressed; // I
				9'h03B: key_mahjong[ 9] <= key_pressed; // J
				9'h042: key_mahjong[10] <= key_pressed; // K
				9'h04B: key_mahjong[11] <= key_pressed; // L
				9'h03A: key_mahjong[12] <= key_pressed; // M
				9'h031: key_mahjong[13] <= key_pressed; // N
				9'h014: key_mahjong[14] <= key_pressed; // Kan   (left Ctrl)
				9'h011: key_mahjong[15] <= key_pressed; // Pon   (left Alt)
				9'h029: key_mahjong[16] <= key_pressed; // Chi   (Space)
				9'h012: key_mahjong[17] <= key_pressed; // Reach (left Shift)
				9'h01A: key_mahjong[18] <= key_pressed; // Ron   (Z)
				9'h016: key_mahjong[19] <= key_pressed; // Start (1)
				9'h02E: key_mahjong[20] <= key_pressed; // Coin  (5)
				9'h046: key_mahjong[21] <= key_pressed; // Service (9)
				9'h006: key_mahjong[22] <= key_pressed; // Test/service mode (F2)
				default: ;
			endcase
		end else begin
			case(key_code)
				9'h175: key_p1_dir[3] <= key_pressed; // P1 Up
				9'h172: key_p1_dir[2] <= key_pressed; // P1 Down
				9'h16B: key_p1_dir[1] <= key_pressed; // P1 Left
				9'h174: key_p1_dir[0] <= key_pressed; // P1 Right
				9'h014: key_p1_btn[0] <= key_pressed; // P1 Button 1 (left Ctrl)
				9'h011: key_p1_btn[1] <= key_pressed; // P1 Button 2 (left Alt)
				9'h029: key_p1_btn[2] <= key_pressed; // P1 Button 3 (Space)
				9'h012: key_p1_btn[3] <= key_pressed; // P1 Button 4 (left Shift)

				9'h02D: key_p2_dir[3] <= key_pressed; // P2 Up    (R)
				9'h02B: key_p2_dir[2] <= key_pressed; // P2 Down  (F)
				9'h023: key_p2_dir[1] <= key_pressed; // P2 Left  (D)
				9'h034: key_p2_dir[0] <= key_pressed; // P2 Right (G)
				9'h01C: key_p2_btn[0] <= key_pressed; // P2 Button 1 (A)
				9'h01B: key_p2_btn[1] <= key_pressed; // P2 Button 2 (S)
				9'h015: key_p2_btn[2] <= key_pressed; // P2 Button 3 (Q)
				9'h01D: key_p2_btn[3] <= key_pressed; // P2 Button 4 (W)

				9'h016: key_start[0] <= key_pressed; // P1 Start (1)
				9'h01E: key_start[1] <= key_pressed; // P2 Start (2)
				9'h02E: key_coin[0]  <= key_pressed; // Coin 1 (5)
				9'h036: key_coin[1]  <= key_pressed; // Coin 2 (6)
				9'h046: key_service  <= key_pressed; // Service 1 (9)
				9'h006: key_test     <= key_pressed; // Test/service mode (F2)
				default: ;
			endcase
		end
	end
end

wire aleck_direct_keyboard = (aleck_input == 1) ||
	                         ((aleck_input == 3) && !aleck_dips[4]);
wire aleck_pif_keyboard = !aleck_e90 && ((aleck_input == 0) ||
	                     ((aleck_input == 3) && aleck_dips[4]));

reg [31:0] keyboard_joy1;
reg [31:0] keyboard_joy2;
always @* begin
	keyboard_joy1 = 0;
	keyboard_joy2 = 0;

	if(aleck_mode) begin
		if(aleck_input == 2) begin
			keyboard_joy1[22:0] = key_mahjong;
		end else if(aleck_e90) begin
			keyboard_joy1[3:0] = key_p1_dir;
			keyboard_joy2[3:0] = key_p2_dir;
			keyboard_joy1[5:4] = key_p1_btn[1:0];
			keyboard_joy2[5:4] = key_p2_btn[1:0];
			keyboard_joy1[6] = key_start[0];
			keyboard_joy2[6] = key_start[1];
			keyboard_joy1[7] = key_coin[0];
			keyboard_joy2[7] = key_coin[1];
			keyboard_joy1[8] = key_service;
			keyboard_joy1[9] = key_test;
		end else if(aleck_direct_keyboard) begin
			keyboard_joy1[3:0] = key_p1_dir;
			keyboard_joy2[3:0] = key_p2_dir;
			keyboard_joy1[6:4] = key_p1_btn[2:0];
			keyboard_joy2[6:4] = key_p2_btn[2:0];
			keyboard_joy1[7] = key_start[0];
			keyboard_joy2[7] = key_start[1];
			keyboard_joy1[8] = key_coin[0];
			keyboard_joy2[8] = key_coin[1];
			keyboard_joy1[9] = key_service;
			keyboard_joy1[10] = key_test;
		end else begin
			// PIF games retain the N64 button layout. MAME buttons 3/4
			// correspond to the MRA's logical C/D controls at R/C-Right.
			keyboard_joy1[5:4] = key_p1_btn[1:0];
			keyboard_joy2[5:4] = key_p2_btn[1:0];
			keyboard_joy1[8] = key_p1_btn[2];
			keyboard_joy2[8] = key_p2_btn[2];
			keyboard_joy1[11] = key_p1_btn[3];
			keyboard_joy2[11] = key_p2_btn[3];
			keyboard_joy1[6] = key_start[0];
			keyboard_joy2[6] = key_start[1];
			keyboard_joy1[15] = key_coin[0];
			keyboard_joy2[15] = key_coin[1];
			keyboard_joy1[16] = key_service;
			keyboard_joy1[17] = key_test;
		end
	end
end

assign joy  = joy_unmod  | keyboard_joy1;
assign joy2 = joy2_unmod | keyboard_joy2;

// Aleck64 PIF titles use the N64 analog stick for their MAME directions.
// A keyboard direction overrides that axis while held; opposing keys center it.
wire [7:0] key_p1_analog_h = (key_p1_dir[0] == key_p1_dir[1]) ? 8'h00 :
	                         (key_p1_dir[0] ? 8'h55 : 8'hAB);
wire [7:0] key_p1_analog_v = (key_p1_dir[2] == key_p1_dir[3]) ? 8'h00 :
	                         (key_p1_dir[2] ? 8'h55 : 8'hAB);
wire [7:0] key_p2_analog_h = (key_p2_dir[0] == key_p2_dir[1]) ? 8'h00 :
	                         (key_p2_dir[0] ? 8'h55 : 8'hAB);
wire [7:0] key_p2_analog_v = (key_p2_dir[2] == key_p2_dir[3]) ? 8'h00 :
	                         (key_p2_dir[2] ? 8'h55 : 8'hAB);
wire [7:0] pad_0_analog_h = (aleck_mode && aleck_pif_keyboard && |key_p1_dir[1:0]) ? key_p1_analog_h : joystick_analog_l0[7:0];
wire [7:0] pad_0_analog_v = (aleck_mode && aleck_pif_keyboard && |key_p1_dir[3:2]) ? key_p1_analog_v : joystick_analog_l0[15:8];
wire [7:0] pad_1_analog_h = (aleck_mode && aleck_pif_keyboard && |key_p2_dir[1:0]) ? key_p2_analog_h : joystick_analog_l1[7:0];
wire [7:0] pad_1_analog_v = (aleck_mode && aleck_pif_keyboard && |key_p2_dir[3:2]) ? key_p2_analog_v : joystick_analog_l1[15:8];

////////////////////////////  PIFROM download  ///////////////////////////////////

reg  [9:0] pifrom_wraddress;
reg [31:0] pifrom_wrdata;   
reg        pifrom_wren;   
reg        pifrom_download;


always @(posedge clk_1x) begin

   pifrom_download   <= ioctl_download & (ioctl_index[5:0] == 0);

	pifrom_wren <= 0;
	if(pifrom_download) begin
      if (ioctl_wr) begin
         if(~ioctl_addr[1]) begin
            pifrom_wrdata[31:24] <= ioctl_dout[7:0];
            pifrom_wrdata[23:16] <= ioctl_dout[15:8];
            pifrom_wraddress    <= {ioctl_index[6], ioctl_addr[10:2]};                                  
         end else begin
            pifrom_wrdata[15:8] <= ioctl_dout[7:0];
            pifrom_wrdata[7:0]  <= ioctl_dout[15:8];
            pifrom_wren          <= 1;
         end
      end
	end
   
end

////////////////////////////  ROM download  ///////////////////////////////////

reg [26:0] romcopy_size;
reg        romcopy_start = 0;

reg [26:0] ramdownload_wraddr;
reg [31:0] ramdownload_wrdata;
reg        ramdownload_wr;
wire       ramdownload_ready;
reg        cartN64_download;
reg        cartGB_download;
reg        aleckExtra_download;
reg        cart_loaded = 0;

localparam CARTN64_START = 16777216;
localparam CARTGB_START  = 8388608;

always @(posedge clk_1x) begin

   cartN64_download     <= ioctl_download & (ioctl_index[5:0] == 1);
   cartGB_download      <= ioctl_download & (ioctl_index[5:0] == 2) & ~aleck_mode;
   aleckExtra_download  <= ioctl_download & (ioctl_index[5:0] == 2) & aleck_mode;
   
   ioctl_download_1 <= ioctl_download;

   romcopy_start <= 0;
   if (~ioctl_download && ioctl_download_1 && ioctl_index[5:0] == 1) begin
      romcopy_size    <= ioctl_addr;
      romcopy_start   <= 1;
   end

	ramdownload_wr <= 0;
	if(cartN64_download) begin
      cart_loaded <= 1;
	end else if(cartGB_download) begin
      if (ioctl_wr) begin
         if(~ioctl_addr[1]) begin
            ramdownload_wrdata[15:0] <= ioctl_dout;
            ramdownload_wraddr       <= ioctl_addr[26:0] + CARTGB_START[26:0];                                  
         end else begin
            ramdownload_wrdata[31:16] <= ioctl_dout;
            ramdownload_wr            <= 1;
            ioctl_wait                <= 1;
         end
      end
      if(ramdownload_ready) ioctl_wait <= 0;
   end else begin 
      ioctl_wait <= 0;
	end
   
end

// Pop OSD menu if no rom has been loaded automatically
assign BUTTONS[0] = osd_btn;
assign BUTTONS[1] = 0;

reg osd_btn = 0;
always @(posedge clk_1x) begin : osd_block
	integer timeout = 0;

	if(!RESET) begin
		osd_btn <= 0;
		if(timeout < 150000000) begin
			timeout <= timeout + 1;
			if (timeout > 140000000)
				osd_btn <= ~cart_loaded;
		end
	end
end

////////////////////////////  SDRAM  ///////////////////////////////////

wire        sdram_ena;
wire        sdram_rnw;
wire [26:0] sdram_Adr;
wire  [3:0] sdram_be;
wire [31:0] sdram_dataWrite;
wire        sdram_done;  
wire        sdram_reqprocessed;  
wire [31:0] sdram_dataRead;

sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_1x),

	.ch1_addr(sdram_Adr),
	.ch1_din(sdram_dataWrite),
	.ch1_dout(sdram_dataRead),
	.ch1_req(sdram_ena),
	.ch1_rnw(sdram_rnw),
	.ch1_be(sdram_be),
	.ch1_ready(sdram_done),
	.ch1_reqprocessed(sdram_reqprocessed),

	.ch2_addr (ramdownload_wraddr),
	.ch2_din  (ramdownload_wrdata),
	.ch2_dout (),
	.ch2_req  (ramdownload_wr),
	.ch2_rnw  (1'b0),
	.ch2_ready(ramdownload_ready),

	.ch3_addr(27'b0),
	.ch3_din(16'b0),
	.ch3_dout(),
	.ch3_req(1'b0),
	.ch3_rnw(1'b1),
	.ch3_ready()
);

///////////////////////////  SAVESTATE  /////////////////////////////////

wire [1:0] ss_slot;
wire [7:0] ss_info;
wire ss_save, ss_load, ss_info_req;
wire statusUpdate;

savestate_ui savestate_ui
(
	.clk            (clk_1x        ),
	.ps2_key        (ps2_key[10:0] ),
	.allow_ss       (cart_loaded   ),
	//.joySS          (joy_unmod[14] ),
	.joySS          (0             ),
	.joyRight       (joy_unmod[0]  ),
	.joyLeft        (joy_unmod[1]  ),
	.joyDown        (joy_unmod[2]  ),
	.joyUp          (joy_unmod[3]  ),
	.joyRewind      (0             ),
	.rewindEnable   (0             ), 
	.status_slot    (status[39:38] ),
	.autoincslot    (status[3]     ),
	.OSD_saveload   (status[18:17] ),
	.ss_save        (ss_save       ),
	.ss_load        (ss_load       ),
	.ss_info_req    (info_req      ),
	.ss_info        (info_index    ),
	.statusUpdate   (statusUpdate  ),
	.selected_slot  (ss_slot       )
);
defparam savestate_ui.INFO_TIMEOUT_BITS = 25;

///////////////////////// SAVE/LOAD  /////////////////////////////

wire  bk_pending;

wire bk_load     = status[40] | (cartN64_download & img_mounted);
wire bk_save     = status[41] | (OSD_STATUS & ~OSD_STATUS_1 & ~status[42]);

reg use_img;
reg OSD_STATUS_1 = 0;

always @(posedge clk_1x) begin
	reg old_downloading;
   
   OSD_STATUS_1 <= OSD_STATUS;

	old_downloading <= cartN64_download;
	if(~old_downloading & cartN64_download) use_img <= 0;

	if(img_mounted && img_size && !img_readonly) begin
		use_img <= 1;
	end
end

////////////////////////////  SYSTEM  ///////////////////////////////////

wire HBlank;
wire VBlank;
wire Interlaced;
wire [31:0] video_FB_base;
wire [9:0] video_FB_sizeX;
wire [9:0] video_FB_sizeY;
wire video_blockVIFB;
wire video_ce;

assign DDRAM_CLK = clk_2x;
//assign DDRAM_CLK = clk_1x;

n64top 
#(
   .use2Xclock(1'b1)
)
n64top
(
   .clk1x(clk_1x),          
   .clk93(clk_93),          
   //.clk93(clk_1x),          
   .clk2x(clk_2x),          
   //.clk2x(clk_1x),          
   .clkvid(clk_vid),
   .reset(reset_or),
   .softreset((aleck_mode && aleck_input == 2'b10) ? 1'b0 : joy[14]),
   .pause(OSD_STATUS),
   .errorCodesOn(status[2]),
   .fpscountOn(status[28]),
   
   .ISPAL(aleck_mode ? 1'b0 : status[79]),
   .FIXEDBLANKS(~fixed_blanks_off && ~clean_hdmi),
   
   .CROPVERTICAL(status[45:44]),
   .VI_BILINEAROFF(status[32]),
   .VI_DEBLUR(status[89]),
   .VI_GAMMAOFF(status[33]),
   .VI_DEDITHEROFF(status[87]),
   .VI_DEDITHERFORCE(status[88]),
   .VI_AAOFF(status[35]),
   .VI_DIVOTOFF(status[36]),
   .VI_NOISEOFF(status[37]),
   .VI_7BITPERCOLOR(~status[104]),
   .VI_DIRECTFBMODE(clean_hdmi),
   
   .CICTYPE(aleck_mode ? 4'd14 : status[68:65]),
   .RAMSIZE8(aleck_mode ? aleck_config[2] : ~status[70]),
   .FASTRAM(status[83]),
   .FASTROM(status[106]),
   .ALECK64(aleck_mode),
   .ALECK_E90(aleck_e90),
   .ALECK_DIPS(aleck_dips),
   .ALECK_INPUT(aleck_input),
   .ALECK_JOY1(joy),
   .ALECK_JOY2(joy2),
   .ALECK_EEPROM_ADDR(aleck_eeprom_addr),
   .ALECK_EEPROM_WREN(aleck_eeprom_wren),
   .ALECK_EEPROM_DATA_IN(aleck_eeprom_data_in),
   .ALECK_EEPROM_DATA_OUT(aleck_eeprom_data_out),
   .ALECK_EEPROM_INIT(aleck_eeprom_init),
   .ALECK_EEPROM_LOADED(aleck_eeprom_loaded),
   .ALECK_EEPROM_CHANGE(aleck_eeprom_change),
   .ALECK_AT24_ADDR(aleck_at24_addr),
   .ALECK_AT24_WREN(aleck_at24_wren),
   .ALECK_AT24_DATA_IN(aleck_at24_data_in),
   .ALECK_AT24_DATA_OUT(aleck_at24_data_out),
   .ALECK_AT24_CHANGE(aleck_at24_change),
   .INSTRCACHEON(~status[93]),
   .DATACACHEON(~status[43]),
   .DATACACHESLOW(status[27:24]),
   .DATACACHEFORCEWEB(status[29]),
   .DATACACHETLBON(~status[100]),
   //.RANDOMMISS(status[97:94]),
   .RANDOMMISS(4'd0),
   .DISABLE_BOOTCOUNT(status[98]),
   .DISABLE_DTLBMINI(status[99]), 
   .DDR3SLOW(status[23:20]),
   .DISABLEFILTER(status[30]),
   .DISABLEDITHER(status[31]),
   .DISABLELOD(status[34]),
   
   .write9(!status[11]), 
   .read9(!status[12]),  
   .wait9(!status[13]), 
   .writeZ(!status[14]),
   .readZ(!status[15]),
   
   // savestates              
   .increaseSSHeaderCount (!status[46]),
   .save_state            (0), //(ss_save),
   .load_state            (ss_load),
   .savestate_number      (ss_slot),
   .state_loaded          (),
   
   // PIFROM download port
   .pifrom_wraddress  (pifrom_wraddress),
   .pifrom_wrdata     (pifrom_wrdata   ),
   .pifrom_wren       (pifrom_wren     ),
                      
   // RDRAM           
   .ddr3_BUSY         (DDRAM_BUSY      ),
   .ddr3_BURSTCNT     (DDRAM_BURSTCNT  ),
   .ddr3_ADDR         (DDRAM_ADDR      ),
   .ddr3_DOUT         (DDRAM_DOUT      ),
   .ddr3_DOUT_READY   (DDRAM_DOUT_READY),
   .ddr3_RD           (DDRAM_RD        ),
   .ddr3_DIN          (DDRAM_DIN       ),
   .ddr3_BE           (DDRAM_BE        ),
   .ddr3_WE           (DDRAM_WE        ),
                      
   // ROM+SRAM+FLASH  
   .cartAvailable     (cart_loaded       ),
   .romcopy_start     (romcopy_start     ),
   .romcopy_size      (romcopy_size      ),
   
   .sdram_ena         (sdram_ena         ),
   .sdram_rnw         (sdram_rnw         ),
   .sdram_Adr         (sdram_Adr         ),
   .sdram_be          (sdram_be          ),
   .sdram_dataWrite   (sdram_dataWrite   ),
   .sdram_reqprocessed(sdram_reqprocessed),
   .sdram_done        (sdram_done        ),
   .sdram_dataRead    (sdram_dataRead    ),
      
   // pad
   .PADTYPE0         (aleck_mode ? (aleck_e90 ? 3'b001 : 3'b000) : status[51:49]),
   .PADTYPE1         (aleck_mode ? (aleck_e90 ? 3'b001 : 3'b000) : status[54:52]),
   .PADTYPE2         (status[57:55]),
   .PADTYPE3         (status[60:58]),
   .MOUSETYPE        (status[86:84]),
   .PADDPADSWAP      (status[92]),
   .rumble           (rumble),
   .pad_A            ({joy4[ 4],joy3[ 4],joy2[ 4],joy[ 4]}),
   .pad_B            ({joy4[ 5],joy3[ 5],joy2[ 5],joy[ 5]}),
   .pad_Z            ({status[61]? joy3[11] : status[62]? joy2[11] : joy4[ 9],status[62]? joy[11] : joy3[ 9],status[61] ? joy[ 11] :joy2[ 9],joy[ 9]}),
   .pad_START        ({joy4[ 6],joy3[ 6],joy2[ 6],joy[ 6]}),
   .pad_DPAD_UP      ({joy4[ 3],joy3[ 3],aleck_disconnected_dpad ? 1'b1 : joy2[3],aleck_disconnected_dpad ? 1'b1 : joy[3]}),
   .pad_DPAD_DOWN    ({joy4[ 2],joy3[ 2],aleck_disconnected_dpad ? 1'b1 : joy2[2],aleck_disconnected_dpad ? 1'b1 : joy[2]}),
   .pad_DPAD_LEFT    ({joy4[ 1],joy3[ 1],aleck_disconnected_dpad ? 1'b1 : joy2[1],aleck_disconnected_dpad ? 1'b1 : joy[1]}),
   .pad_DPAD_RIGHT   ({joy4[ 0],joy3[ 0],aleck_disconnected_dpad ? 1'b1 : joy2[0],aleck_disconnected_dpad ? 1'b1 : joy[0]}),
   .pad_L            ({joy4[ 7],joy3[ 7],joy2[ 7],joy[ 7]}),
   .pad_R            ({joy4[ 8],joy3[ 8],joy2[ 8],joy[ 8]}),
   .pad_C_UP         ({joy4[10],joy3[10],joy2[10],joy[10]}),
   .pad_C_DOWN       ({joy4[12],joy3[12],joy2[12],joy[12]}),
   .pad_C_LEFT       ({joy4[13],joy3[13],joy2[13],joy[13]}),
   .pad_C_RIGHT      ({joy4[11],joy3[11],joy2[11],joy[11]}),
   .pad_0_analog_h   (pad_0_analog_h),
   .pad_0_analog_v   (pad_0_analog_v),
   .pad_1_analog_h   (pad_1_analog_h),
   .pad_1_analog_v   (pad_1_analog_v),
   .pad_2_analog_h   (joystick_analog_l2[7:0]),
   .pad_2_analog_v   (joystick_analog_l2[15:8]),
   .pad_3_analog_h   (joystick_analog_l3[7:0]),
   .pad_3_analog_v   (joystick_analog_l3[15:8]),
   .MouseEvent(mouse[24]),
   .MouseLeft(mouse[0]),
   .MouseRight(mouse[1]),
   .MouseMiddle(mouse[2]),
   .MouseX({mouse[4],mouse[15:8]}),
   .MouseY({mouse[5],mouse[23:16]}),
 
    // snac  
   .PIFCOMPARE             (status[91]),
   .snac                   (snac),
   .command_startSNAC      (command_start),
   .command_padindexSNAC   (command_padindex),
   .command_sendCntSNAC    (command_sendCnt),
   .command_receiveCntSNAC (command_receiveCnt),
   .toPad_enaSNAC          (toPad_ena),
   .toPad_dataSNAC         (toPad_data),
   .toPad_readySNAC        (toPad_ready),
   .toPIF_enaSNAC          (toPIF_ena),
   .toPIF_timeoutSNAC      (toPIF_timeout),
   .toPIF_dataSNAC         (toPIF_data),
	
   // audio
   .DISABLE_AI       (status[101]),
   .DISABLE_AI_IRQ   (status[102]),
   .sound_out_left   (AUDIO_L),
   .sound_out_right  (AUDIO_R),  
   
   // Saves
   .SAVETYPE         (aleck_mode ? (aleck_eeprom ? 3'b001 : 3'b000) : status[77:75]),
   .CONTROLLERPAK    (status[71]),
   .TRANSFERPAK      (status[73]),
   
   .save             (bk_save),
   .load             (bk_load),
   .mounted          (use_img),
   .changePending    (bk_pending),
   .save_ongoing     (),
   .save_rd          (sd_rd),
   .save_wr          (sd_wr),
   .save_lba         (sd_lba),
   .save_ack         (sd_ack), 
   .save_write       (sd_buff_wr),
   .save_addr        (sd_buff_addr),
   .save_dataIn      (sd_buff_dout),
   .save_dataOut     (sd_buff_din),
   
   // video out   
   .video_hsync      (VGA_HS),
   .video_vsync      (VGA_VS),
   .video_hblank     (HBlank),
   .video_vblank     (VBlank),
   .video_ce         (video_ce),
   .video_interlace  (Interlaced),
   .video_r          (VGA_R),
   .video_g          (VGA_G),
   .video_b          (VGA_B),
   
   .video_FB_en      (video_FB_en),
   .video_FB_base    (video_FB_base),
   .video_FB_sizeX   (video_FB_sizeX),
   .video_FB_sizeY   (video_FB_sizeY)
);

assign CLK_VIDEO = clk_vid;
assign VGA_DE = ~(HBlank | VBlank);
assign VGA_F1 = clean_hdmi ? 1'b0 : Interlaced ^ status[1];
assign VGA_SL = 0;
assign VGA_DISABLE = 0;

assign CE_PIXEL = video_ce;
   
reg [11:0] ARCoreX = 12'd4;
reg [11:0] ARCoreY = 12'd3;
   
always @(posedge clk_1x) begin
   if (fixed_blanks_off || clean_hdmi) begin // fixed blanks off
      ARCoreX <= 12'd4;
      ARCoreY <= 12'd3;
   end else begin
      if (status[79]) begin // PAL
         case(status[45:44]) // crop
            2'b00 : begin ARCoreX <= 12'd512 ; ARCoreY <= 12'd387 ; end
            2'b01 : begin ARCoreX <= 12'd1024; ARCoreY <= 12'd731 ; end
            2'b10 : begin ARCoreX <= 12'd2048; ARCoreY <= 12'd1419; end
         endcase;
      end else begin // NTSC
         case(status[45:44]) // crop
            2'b00 : begin ARCoreX <= 12'd512 ; ARCoreY <= 12'd381 ; end
            2'b01 : begin ARCoreX <= 12'd1280; ARCoreY <= 12'd889 ; end
            2'b10 : begin ARCoreX <= 12'd2560; ARCoreY <= 12'd1714; end
         endcase;
      end
   end
end
   
wire [1:0] ar = status[48:47];
assign VIDEO_ARX = (!ar) ? ARCoreX : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ARCoreY : 12'd0;

////////////////////////////  SNAC  ///////////////////////////////////

wire snac;
wire dataIn;
wire dataOut;
wire command_start;
wire [1:0]command_padindex;
wire [5:0]command_sendCnt;
wire [5:0]command_receiveCnt;
wire toPad_ena;
wire [7:0]toPad_data;
wire toPad_ready;
wire toPIF_timeout;
wire toPIF_ena;
wire [7:0]toPIF_data;

//d-  io[1] pad1
//d+  io[0] pad2
//rx- io[5] pad3
//rx+ io[4] pad4

always @(posedge clk_1x) begin
	if (snac) begin
		case (command_padindex)
			2'd0: begin//port1
				USER_OUT[1] <= dataOut;
				dataIn <= USER_IN[1];
			end
			2'd1: begin//port2
				USER_OUT[0] <= dataOut;
				dataIn <= USER_IN[0];
			end
			2'd2: begin//port3
				USER_OUT[5] <= dataOut;
				dataIn <= USER_IN[5];
			end
			2'd3: begin//port4
				USER_OUT[4] <= dataOut;
				dataIn <= USER_IN[4];
			end
		endcase
		USER_OUT[2] <= 1'b1;
		USER_OUT[3] <= 1'b1;
		USER_OUT[6] <= 1'b1;
	end else begin
		USER_OUT <= '1;
	end
end

N64_SNAC N64_SNAC_inst
(
	.reset(reset_or),
	.clk_1x(clk_1x) ,	// input clk1x 62.5mhz
	.output1(dataOut) ,
	.input1(dataIn),
	.start(command_start),
	.dataOut(toPIF_data),
	.cmdData(toPad_data),
	.byteRec(toPIF_ena),
	.ready(toPad_ready),
	.toPad_ena(toPad_ena),
	.timeout(toPIF_timeout),
	.receiveCnt(command_receiveCnt),
	.sendCnt(command_sendCnt)
);

endmodule
