# Aleck64 arcade platform for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

This branch is a special version for Aleck64 support.
In case you are searching for the normal N64 core, please go here:
https://github.com/MiSTer-devel/N64_MiSTer

## Hardware Requirements
SDRAM of any size is required.

## Aleck64 arcade games

This branch can start Aleck64 games from MAME-format ZIP sets through MRA
files.  The MRA selects the arcade hardware before loading the PIF, auxiliary
board ROM, and N64 program ROM.  Aleck64 mode adds:

- the 8 MiB board SDRAM window at `0xC0000000`;
- JAMMA controls, coins, service/test inputs, and MRA DIP-switch data at
  `0xC0800000`;
- the Seta E90 display-list, palette, and protection windows used by Magical
  Tetris Challenge;
- the board's BK4D-NUS 4-kbit PIF EEPROM, persisted as 512-byte MRA NVRAM;
- CIC 5101, NTSC, and per-board 4/8 MiB RDRAM selection without changing the
  normal N64 path.

The `mra` directory contains one MRA for every game set in MAME 0.287,
including the `srmvsa` clone:

| MAME set | Game | Input/hardware status |
| --- | --- | --- |
| `11beat` | Eleven Beat | Standard PIF gamepads |
| `mtetrisc` | Magical Tetris Challenge | E90 direct JAMMA implementation |
| `starsldr` | Star Soldier: Vanishing Earth | Standard PIF gamepads |
| `srmvs`, `srmvsa` | Super Real Mahjong VS | Multiplexed INMJ mahjong panel |
| `vivdolls` | Vivid Dolls | Standard PIF gamepads by default |
| `mayjin3` | Mayjinsen 3 | Generic PIF gamepad definition |
| `twrshaft` | Tower & Shaft | Direct JAMMA inputs |
| `hipai`, `hipai2` | Hi Pai Paradise 1/2 | Multiplexed INMJ mahjong panel |
| `kurufev` | Kurukuru Fever | Direct JAMMA inputs |
| `doncdoon` | Hanabi de Doon! | Direct JAMMA inputs |

To install an MRA:

1. Build this core, rename the resulting RBF with an `Aleck64_` prefix, and put
   it in `_Arcade/cores`.
2. Copy the desired files from `mra` into `_Arcade`.
3. Put the corresponding unmodified MAME ZIP and the parent BIOS
   `aleck64.zip` in `games/mame`.

Each MRA performs MAME's per-file 16-bit program-ROM word swap, concatenates
split program images in MAME order, and applies the Aleck64 protection patch
while assembling the download; no extracted or converted ROM is needed. The
E90 puzzle-piece overlay extends the reference MAME implementation with the
tile `0x0400` playfield-background mode. The BK4D-NUS PIF EEPROM is restored
when the MRA starts and is saved after a game
write when the OSD is next opened; **Save Settings** also writes it explicitly.
Magical Tetris's separate 128-byte S2D board memory is initialized from the
MAME `at24c01.u34` dump and appended to the same persistent NVRAM file. Existing
512-byte Magical Tetris saves are accepted and upgraded on the next save. The
core emulates the E90 board's S2D serial GPIO protocol; the program ROM remains
unmodified apart from the standard Aleck64 protection bypass.

The direct-JAMMA MRAs expose the game's action buttons followed by Start,
Coin, Service, and Test. Mahjong MRAs use the D-pad for Mahjong A-D and the 16
panel buttons for E-N, Kan, Pon, Chi, Reach, Ron, and Start. Dedicated Coin,
Service, and Test controls use the extended joystick packet. Start+Pon,
Start+Chi, and Start+Reach remain available as alternate cabinet-input chords.

Aleck64 mode also supports MAME's default keyboard controls. Player 1 uses the
arrow keys, left Ctrl/Alt, Space, and left Shift; Player 2 uses R/F/D/G and
A/S/Q/W. The 1/2 keys start players, 5/6 insert coins, 9 is Service 1, and F2
enters the test/service mode. PIF games translate keyboard directions to the
N64 analog stick. Mahjong games use MAME's panel defaults: A-N, left Ctrl for
Kan, left Alt for Pon, Space for Chi, left Shift for Reach, and Z for Ron.

Games with physical DIP banks expose their MAME-defined settings through the
standard MiSTer **DIP Switches** OSD entry. Vivid Dolls' Controls switch selects
between its PIF joystick and JAMMA input wiring. Magical Tetris has no physical
game DIP table; its operator configuration is changed in the test menu and
stored in the emulated S2D EEPROM instead.

Standard Aleck64 boards support both the original VI video path and Clean HDMI
direct-framebuffer output. Clean HDMI is intentionally unavailable on the E90
Magical Tetris board because it would bypass the board's separately composited
puzzle-piece layer.
