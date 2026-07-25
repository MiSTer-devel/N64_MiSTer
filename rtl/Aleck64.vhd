library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Aleck64 arcade daughterboard support.
--
-- The standard Aleck64 board adds an 8 MiB SDRAM window and memory-mapped
-- JAMMA/DIP inputs to the N64 hardware.  Seta's E90 variant (Magical Tetris)
-- also has a small display-list RAM and palette RAM.  The E90 renderer below
-- follows the currently documented MAME behaviour: each enabled list entry
-- draws one 8x8, palette-shaded puzzle block over the N64 video output.
entity Aleck64 is
   port
   (
      clk1x          : in  std_logic;
      clkvid         : in  std_logic;
      reset          : in  std_logic;

      enabled        : in  std_logic;
      e90_enabled    : in  std_logic;
      input_profile  : in  std_logic_vector(1 downto 0);
      dips           : in  std_logic_vector(15 downto 0);
      joy1           : in  std_logic_vector(31 downto 0);
      joy2           : in  std_logic_vector(31 downto 0);

      at24_nv_addr      : in  std_logic_vector(5 downto 0);
      at24_nv_data_in   : in  std_logic_vector(15 downto 0);
      at24_nv_wren      : in  std_logic;
      at24_nv_data_out  : out std_logic_vector(15 downto 0);
      at24_nv_changed   : out std_logic;

      bus_addr       : in  unsigned(31 downto 0);
      bus_dataWrite  : in  std_logic_vector(31 downto 0);
      bus_writeMask  : in  std_logic_vector(3 downto 0);
      bus_read       : in  std_logic;
      bus_write      : in  std_logic;
      bus_dataRead   : out std_logic_vector(31 downto 0) := (others => '0');
      bus_done       : out std_logic := '0';

      video_hsync_i  : in  std_logic;
      video_vsync_i  : in  std_logic;
      video_hblank_i : in  std_logic;
      video_vblank_i : in  std_logic;
      video_ce_i     : in  std_logic;
      video_r_i      : in  std_logic_vector(7 downto 0);
      video_g_i      : in  std_logic_vector(7 downto 0);
      video_b_i      : in  std_logic_vector(7 downto 0);

      video_hsync_o  : out std_logic := '0';
      video_vsync_o  : out std_logic := '0';
      video_hblank_o : out std_logic := '1';
      video_vblank_o : out std_logic := '1';
      video_ce_o     : out std_logic := '0';
      video_r_o      : out std_logic_vector(7 downto 0) := (others => '0');
      video_g_o      : out std_logic_vector(7 downto 0) := (others => '0');
      video_b_o      : out std_logic_vector(7 downto 0) := (others => '0')
   );
end entity;

architecture arch of Aleck64 is

   constant ADDR_INPUT_BASE : unsigned(31 downto 0) := x"C0800000";
   constant ADDR_INPUT_END  : unsigned(31 downto 0) := x"C0801000";
   constant ADDR_VRAM_BASE  : unsigned(31 downto 0) := x"D0000000";
   constant ADDR_VRAM_END   : unsigned(31 downto 0) := x"D0001000";
   constant ADDR_PAL_BASE   : unsigned(31 downto 0) := x"D0010000";
   constant ADDR_PAL_END    : unsigned(31 downto 0) := x"D0011000";
   constant ADDR_PROT_BASE  : unsigned(31 downto 0) := x"D0030000";
   constant ADDR_PROT_END   : unsigned(31 downto 0) := x"D0030020";

   type tPalTable is array(0 to 63) of integer range 0 to 15;
   constant PAL_TABLE : tPalTable :=
   (
      8,6,6,6,6,5,4,3,
      9,7,5,6,4,1,1,4,
      9,8,6,5,1,1,1,5,
      9,8,7,5,1,1,4,6,
      9,8,7,6,5,5,6,6,
      9,8,6,7,7,6,5,6,
      9,8,8,8,8,8,7,6,
      8,9,9,9,9,9,9,8
   );

   type tRenderState is
   (
      RENDER_IDLE,
      RENDER_PREV_ADDR,
      RENDER_PREV_WAIT,
      RENDER_PREV_CAPTURE,
      RENDER_PREV_CLEAR,
      RENDER_ATTR_ADDR,
      RENDER_ATTR_WAIT,
      RENDER_ATTR_CAPTURE,
      RENDER_POS_WAIT,
      RENDER_POS_CAPTURE,
      RENDER_DRAW,
      RENDER_PAL_WAIT,
      RENDER_PAL_WRITE
   );

   signal render_state    : tRenderState := RENDER_IDLE;
   signal render_entry    : integer range 0 to 511 := 0;
   signal render_x        : integer range 0 to 7 := 0;
   signal render_y        : integer range 0 to 7 := 0;
   signal render_playfield: std_logic := '0';
   signal render_attr     : std_logic_vector(15 downto 0) := (others => '0');
   signal render_pos      : std_logic_vector(31 downto 0) := (others => '0');
   signal prev_pos        : std_logic_vector(31 downto 0) := (others => '0');
   signal prev_valid      : std_logic := '0';
   signal render_pal_low  : std_logic := '0';

   signal vram_addr_a     : std_logic_vector(9 downto 0);
   signal vram_addr_b     : std_logic_vector(9 downto 0) := (others => '0');
   signal vram_data_a     : std_logic_vector(31 downto 0);
   signal vram_data_b     : std_logic_vector(31 downto 0);
   signal vram_wren_a     : std_logic;

   signal palette_addr_a  : std_logic_vector(9 downto 0);
   signal palette_addr_b  : std_logic_vector(9 downto 0) := (others => '0');
   signal palette_data_a  : std_logic_vector(31 downto 0);
   signal palette_data_b  : std_logic_vector(31 downto 0);
   signal palette_wren_a  : std_logic;

   signal prev_addr_write : std_logic_vector(8 downto 0) := (others => '0');
   signal prev_data_write : std_logic_vector(24 downto 0) := (others => '0');
   signal prev_write      : std_logic := '0';
   signal prev_addr_read  : std_logic_vector(8 downto 0) := (others => '0');
   signal prev_data_read  : std_logic_vector(24 downto 0);

   -- 320x256 E90 overlay.  A 16-bit framebuffer uses the core's established
   -- altsyncram primitive at its exact 81,920-pixel depth.  Each
   -- entry holds foreground/low-priority and RGB555.  Bit 15 marks normal E90
   -- foreground; bit 14 with bit 15 clear marks the keyed playfield backdrop.
   -- Previous display-list positions are
   -- cleared before the current list is redrawn so moved objects cannot leave
   -- stale pixels, without spending vertical blank erasing the whole screen.
   signal fb_addr_write   : std_logic_vector(16 downto 0) := (others => '0');
   signal fb_data_write   : std_logic_vector(15 downto 0) := (others => '0');
   signal fb_byteena_write: std_logic_vector(1 downto 0) := (others => '0');
   signal fb_write        : std_logic := '0';
   signal fb_addr_read    : std_logic_vector(16 downto 0) := (others => '0');
   signal fb_data_read    : std_logic_vector(15 downto 0);

   signal pixel_x         : integer range 0 to 639 := 0;
   signal pixel_y         : integer range 0 to 255 := 0;
   signal hblank_last     : std_logic := '1';
   signal vblank_last     : std_logic := '1';
   signal first_line      : std_logic := '1';

   signal r_delay1        : std_logic_vector(7 downto 0) := (others => '0');
   signal r_delay2        : std_logic_vector(7 downto 0) := (others => '0');
   signal g_delay1        : std_logic_vector(7 downto 0) := (others => '0');
   signal g_delay2        : std_logic_vector(7 downto 0) := (others => '0');
   signal b_delay1        : std_logic_vector(7 downto 0) := (others => '0');
   signal b_delay2        : std_logic_vector(7 downto 0) := (others => '0');
   signal hsync_delay     : std_logic_vector(1 downto 0) := (others => '0');
   signal vsync_delay     : std_logic_vector(1 downto 0) := (others => '0');
   signal hblank_delay    : std_logic_vector(1 downto 0) := (others => '1');
   signal vblank_delay    : std_logic_vector(1 downto 0) := (others => '1');
   signal ce_delay        : std_logic_vector(1 downto 0) := (others => '0');

   signal e90_in0         : std_logic_vector(31 downto 0);
   signal e90_in1         : std_logic_vector(31 downto 0);
   signal direct_in0      : std_logic_vector(31 downto 0);
   signal direct_in1      : std_logic_vector(31 downto 0);
   signal pif_in1         : std_logic_vector(31 downto 0);
   signal mahjong_in      : std_logic_vector(31 downto 0);
   signal mahjong_in0     : std_logic_vector(31 downto 0);
   signal mahjong_in1     : std_logic_vector(31 downto 0);
   signal input_select    : std_logic_vector(31 downto 0) := (others => '0');

   signal e90_i2c_scl     : std_logic := '0';
   signal e90_i2c_sda_out : std_logic := '0';
   signal e90_i2c_sda_oe  : std_logic := '1';
   signal e90_i2c_sda_in  : std_logic;

   function expand5(value : std_logic_vector(4 downto 0)) return std_logic_vector is
   begin
      return value & value(4 downto 2);
   end function;

   -- Tile 0x0400 with attribute 0x0060 is E90's empty playfield cell.  It is
   -- not disabled despite attribute bit 5 being set.  The real board renders
   -- the same eight-pixel vertical intensity pattern in every cell.
   function e90_playfield_level(pixel : integer) return std_logic_vector is
   begin
      case pixel is
         when 0      => return "00100";
         when 1      => return "00010";
         when 5      => return "00010";
         when 6      => return "00100";
         when 7      => return "01000";
         when others => return "00000";
      end case;
   end function;

begin

   iAT24C01 : entity work.AT24C01
   port map
   (
      clk             => clk1x,
      reset           => reset,
      nv_addr         => at24_nv_addr,
      nv_data_in      => at24_nv_data_in,
      nv_wren         => at24_nv_wren,
      nv_data_out     => at24_nv_data_out,
      scl             => e90_i2c_scl,
      sda_out         => e90_i2c_sda_out,
      sda_oe          => e90_i2c_sda_oe,
      sda_in          => e90_i2c_sda_in,
      changed         => at24_nv_changed
   );

   vram_addr_a    <= std_logic_vector(bus_addr(11 downto 2));
   palette_addr_a <= std_logic_vector(bus_addr(11 downto 2));
   vram_wren_a    <= bus_write when (enabled = '1' and e90_enabled = '1' and
                                     bus_addr >= ADDR_VRAM_BASE and bus_addr < ADDR_VRAM_END) else '0';
   palette_wren_a <= bus_write when (enabled = '1' and e90_enabled = '1' and
                                     bus_addr >= ADDR_PAL_BASE and bus_addr < ADDR_PAL_END) else '0';

   iE90VRAM : entity work.dpram_dif_be
   generic map
   (
      addr_width_a    => 10,
      data_width_a    => 32,
      addr_width_b    => 10,
      data_width_b    => 32,
      width_byteena_a => 4,
      width_byteena_b => 4
   )
   port map
   (
      clock_a   => clk1x,
      address_a => vram_addr_a,
      data_a    => bus_dataWrite,
      byteena_a => bus_writeMask,
      wren_a    => vram_wren_a,
      q_a       => vram_data_a,
      clock_b   => clkvid,
      address_b => vram_addr_b,
      data_b    => (others => '0'),
      byteena_b => "0000",
      wren_b    => '0',
      q_b       => vram_data_b
   );

   iE90Palette : entity work.dpram_dif_be
   generic map
   (
      addr_width_a    => 10,
      data_width_a    => 32,
      addr_width_b    => 10,
      data_width_b    => 32,
      width_byteena_a => 4,
      width_byteena_b => 4
   )
   port map
   (
      clock_a   => clk1x,
      address_a => palette_addr_a,
      data_a    => bus_dataWrite,
      byteena_a => bus_writeMask,
      wren_a    => palette_wren_a,
      q_a       => palette_data_a,
      clock_b   => clkvid,
      address_b => palette_addr_b,
      data_b    => (others => '0'),
      byteena_b => "0000",
      wren_b    => '0',
      q_b       => palette_data_b
   );

   iE90FrameBuffer : entity work.dpram_dif_be
   generic map
   (
      addr_width_a => 17,
      data_width_a => 16,
      addr_width_b => 17,
      data_width_b => 16,
      numwords_a => 81920,
      numwords_b => 81920,
      width_byteena_a => 2,
      width_byteena_b => 2
   )
   port map
   (
      clock_a   => clkvid,
      address_a => fb_addr_write,
      data_a    => fb_data_write,
      byteena_a => fb_byteena_write,
      wren_a    => fb_write,
      q_a       => open,
      clock_b   => clkvid,
      address_b => fb_addr_read,
      data_b    => (others => '0'),
      byteena_b => "00",
      wren_b    => '0',
      q_b       => fb_data_read
   );

   -- Snapshot of the previous 512 E90 records.  A separate read and write
   -- port lets the renderer erase the old list, then replace it with the
   -- current list without exposing a partially cleared full-screen buffer.
   iE90PreviousList : entity work.dpram
   generic map
   (
      addr_width => 9,
      data_width => 25
   )
   port map
   (
      clock_a   => clkvid,
      address_a => prev_addr_write,
      data_a    => prev_data_write,
      wren_a    => prev_write,
      q_a       => open,
      clock_b   => clkvid,
      address_b => prev_addr_read,
      data_b    => (others => '0'),
      wren_b    => '0',
      q_b       => prev_data_read
   );

   -- Magical Tetris and later Aleck64 boards use active-low JAMMA controls.
   -- E90 puts start/coin/service/test in different slots from the standard
   -- board, so build both register layouts from the same MiSTer inputs.
   process(all)
      variable e90_0  : std_logic_vector(31 downto 0);
      variable e90_1  : std_logic_vector(31 downto 0);
      variable dir0   : std_logic_vector(31 downto 0);
      variable dir1   : std_logic_vector(31 downto 0);
      variable pif1   : std_logic_vector(31 downto 0);
      variable mj     : std_logic_vector(31 downto 0);
      variable mj0    : std_logic_vector(31 downto 0);
      variable mj1    : std_logic_vector(31 downto 0);
   begin
      e90_0  := (others => '1');
      e90_1  := (others => '1');
      dir0   := dips & x"FFFF";
      dir1   := (others => '1');
      pif1   := (others => '1');
      mj     := (others => '1');
      mj0    := dips & x"FFFF";
      mj1    := (others => '1');

      e90_0(0)  := not joy1(3); -- P1 up
      e90_0(1)  := not joy1(2); -- P1 down
      e90_0(2)  := not joy1(1); -- P1 left
      e90_0(3)  := not joy1(0); -- P1 right
      e90_0(4)  := not joy1(4); -- P1 button 1
      e90_0(5)  := not joy1(5); -- P1 button 2
      e90_0(7)  := not joy1(6); -- P1 start
      e90_0(8)  := not joy2(3); -- P2 up
      e90_0(9)  := not joy2(2); -- P2 down
      e90_0(10) := not joy2(1); -- P2 left
      e90_0(11) := not joy2(0); -- P2 right
      e90_0(12) := not joy2(4); -- P2 button 1
      e90_0(13) := not joy2(5); -- P2 button 2
      e90_0(15) := not joy2(6); -- P2 start

      e90_1(0) := not joy1(7); -- coin 1
      e90_1(1) := not joy2(7); -- coin 2
      e90_1(4) := not joy1(8); -- service
      e90_1(5) := not joy1(9); -- test

      -- Standard direct/JAMMA layout used by Tower & Shaft, Kurukuru Fever,
      -- Hanabi de Doon and Vivid Dolls when its Controls DIP selects JAMMA.
      -- Slots 4..10 are B1/B2/B3/start/coin/service/test.
      dir0(0)  := not joy1(3); -- P1 up
      dir0(1)  := not joy1(2); -- P1 down
      dir0(2)  := not joy1(1); -- P1 left
      dir0(3)  := not joy1(0); -- P1 right
      dir0(4)  := not joy1(4); -- P1 button 1
      dir0(5)  := not joy1(5); -- P1 button 2
      dir0(6)  := not joy1(6); -- P1 button 3
      dir0(8)  := not joy2(3); -- P2 up
      dir0(9)  := not joy2(2); -- P2 down
      dir0(10) := not joy2(1); -- P2 left
      dir0(11) := not joy2(0); -- P2 right
      dir0(12) := not joy2(4); -- P2 button 1
      dir0(13) := not joy2(5); -- P2 button 2
      dir0(14) := not joy2(6); -- P2 button 3

      dir1(16) := not joy1(7);  -- start 1
      dir1(17) := not joy2(7);  -- start 2
      dir1(18) := not joy1(8);  -- coin 1
      dir1(19) := not joy2(8);  -- coin 2
      dir1(20) := not joy1(9);  -- service
      dir1(21) := not joy1(10); -- test

      -- PIF titles retain every N64 pad button. Arcade controls use MiSTer
      -- button slots 15..17, beyond the N64 pad packet.
      pif1(18) := not joy1(15); -- coin 1
      pif1(19) := not joy2(15); -- coin 2
      pif1(20) := not joy1(16); -- service
      pif1(21) := not joy1(17); -- test

      -- Mahjong panel: D-pad supplies A-D and button slots 4..19 supply
      -- E-N, Kan, Pon, Chi, Reach, Ron and Start respectively.
      mj(9)  := not joy1(0);  -- A
      mj(17) := not joy1(1);  -- B
      mj(1)  := not joy1(2);  -- C
      mj(25) := not joy1(3);  -- D
      mj(10) := not joy1(4);  -- E
      mj(18) := not joy1(5);  -- F
      mj(2)  := not joy1(6);  -- G
      mj(26) := not joy1(7);  -- H
      mj(11) := not joy1(8);  -- I
      mj(19) := not joy1(9);  -- J
      mj(3)  := not joy1(10); -- K
      mj(27) := not joy1(11); -- L
      mj(12) := not joy1(12); -- M
      mj(20) := not joy1(13); -- N
      mj(13) := not joy1(14); -- Kan
      mj(28) := not joy1(15); -- Pon
      mj(4)  := not joy1(16); -- Chi
      mj(21) := not joy1(17); -- Reach
      mj(5)  := not joy1(18); -- Ron
      mj(8)  := not joy1(19); -- Start

      -- The 20 panel controls occupy bits 0..19. MiSTer's extended joystick
      -- packet provides dedicated cabinet inputs above them; retain the old
      -- Start+Pon/Chi/Reach chords as convenient alternate mappings.
      mj1(18) := not (joy1(20) or (joy1(19) and joy1(15))); -- coin
      mj1(20) := not (joy1(21) or (joy1(19) and joy1(16))); -- service
      -- Either the physical/OSD Test DIP, dedicated button or chord can test.
      mj0(23) := dips(7) and not (joy1(22) or (joy1(19) and joy1(17)));

      e90_in0      <= e90_0;
      e90_in1      <= e90_1;
      direct_in0   <= dir0;
      direct_in1   <= dir1;
      pif_in1      <= pif1;
      mahjong_in   <= mj;
      mahjong_in0  <= mj0;
      mahjong_in1  <= mj1;
   end process;

   process(clk1x)
   begin
      if rising_edge(clk1x) then
         bus_done     <= '0';
         bus_dataRead <= (others => '0');

         if reset = '1' then
            input_select <= (others => '0');
            e90_i2c_scl     <= '0';
            e90_i2c_sda_out <= '0';
            e90_i2c_sda_oe  <= '1';
         elsif enabled = '1' and (bus_read = '1' or bus_write = '1') then
            bus_done <= '1';

            if bus_addr >= ADDR_INPUT_BASE and bus_addr < ADDR_INPUT_END then
               if e90_enabled = '1' and bus_write = '1' then
                  -- The CPU presents these as sub-word accesses to E90 word
                  -- registers. Decode the byte enables, not unaligned address
                  -- bits, so cached/uncached and write-buffer paths agree.
                  case to_integer(bus_addr(11 downto 2)) is
                     when 3 =>
                        if bus_writeMask(2) = '1' then
                           if bus_dataWrite = x"00000000" then
                              e90_i2c_scl <= '0';
                           else
                              e90_i2c_scl <= '1';
                           end if;
                        end if;
                        if bus_writeMask(0) = '1' then
                           if bus_dataWrite = x"00000000" then
                              e90_i2c_sda_out <= '0';
                           else
                              e90_i2c_sda_out <= '1';
                           end if;
                        end if;
                     when 28 =>
                        if bus_writeMask(3 downto 2) /= "00" then
                           if bus_dataWrite = x"00000000" then
                              e90_i2c_sda_oe <= '0';
                           else
                              e90_i2c_sda_oe <= '1';
                           end if;
                        end if;
                     when others => null;
                  end case;
               end if;

               case to_integer(bus_addr(11 downto 2)) is
                  when 0 =>
                     if e90_enabled = '1' then
                        bus_dataRead <= e90_in0;
                     elsif input_profile = "01" or
                           (input_profile = "11" and dips(4) = '0') then
                        bus_dataRead <= direct_in0;
                     elsif input_profile = "10" then
                        bus_dataRead <= mahjong_in0;
                     else
                        bus_dataRead <= dips & x"FFFF";
                     end if;
                  when 1 =>
                     if e90_enabled = '1' then
                        bus_dataRead <= e90_in1;
                     elsif input_profile = "01" or
                           (input_profile = "11" and dips(4) = '0') then
                        bus_dataRead <= direct_in1;
                     elsif input_profile = "10" then
                        bus_dataRead <= mahjong_in1;
                     else
                        bus_dataRead <= pif_in1;
                     end if;
                  when 2 =>
                     if bus_write = '1' then
                        input_select <= bus_dataWrite;
                     end if;
                     if e90_enabled = '1' then
                        bus_dataRead <= (others => '0');
                        -- Mirror the one-bit input in each byte lane. The CPU
                        -- selects register $09 using its original load address.
                        bus_dataRead(24) <= e90_i2c_sda_in;
                        bus_dataRead(16) <= e90_i2c_sda_in;
                        bus_dataRead(8)  <= e90_i2c_sda_in;
                        bus_dataRead(0)  <= e90_i2c_sda_in;
                     elsif input_profile /= "10" then
                        bus_dataRead <= (others => '0');
                     else
                        case input_select(15 downto 8) is
                           when x"01" => bus_dataRead <= mahjong_in;
                           when x"02" => bus_dataRead <= mahjong_in(23 downto 0) & x"00";
                           when x"04" => bus_dataRead <= mahjong_in(15 downto 0) & x"0000";
                           when x"08" => bus_dataRead <= x"00" & mahjong_in(31 downto 8);
                           when others => bus_dataRead <= (others => '0');
                        end case;
                     end if;
                  when others => null;
               end case;

            elsif e90_enabled = '1' and bus_addr >= ADDR_VRAM_BASE and bus_addr < ADDR_VRAM_END then
               bus_dataRead <= vram_data_a;
            elsif e90_enabled = '1' and bus_addr >= ADDR_PAL_BASE and bus_addr < ADDR_PAL_END then
               bus_dataRead <= palette_data_a;
            elsif e90_enabled = '1' and bus_addr >= ADDR_PROT_BASE and bus_addr < ADDR_PROT_END then
               -- E90 status bit 0x800 is ready/active-low in the available
               -- documentation.  Returning zero is the known-good response.
               bus_dataRead <= (others => '0');
            end if;
         end if;
      end if;
   end process;

   -- Rebuild the compact E90 display list once per frame.  Palette lookup is
   -- performed here so scanout needs only one RAM read and remains aligned
   -- with the N64 VI pixel stream.
   process(clkvid)
      variable xpos      : integer;
      variable ypos      : integer;
      variable palbank   : integer;
      variable palindex  : integer;
      variable raw_color : std_logic_vector(15 downto 0);
   begin
      if rising_edge(clkvid) then
         fb_write <= '0';
         fb_byteena_write <= (others => '0');
         prev_write <= '0';
         vblank_last <= video_vblank_i;

         if reset = '1' then
            render_state <= RENDER_IDLE;
            prev_valid   <= '0';
         elsif e90_enabled = '0' then
            render_state <= RENDER_IDLE;
         else
            if video_vblank_i = '1' and vblank_last = '0' then
               render_entry <= 0;
               if prev_valid = '1' then
                  render_state <= RENDER_PREV_ADDR;
               else
                  render_state <= RENDER_ATTR_ADDR;
               end if;
            end if;

            case render_state is
               when RENDER_IDLE => null;

               when RENDER_PREV_ADDR =>
                  prev_addr_read <= std_logic_vector(to_unsigned(render_entry, 9));
                  render_state   <= RENDER_PREV_WAIT;

               when RENDER_PREV_WAIT =>
                  render_state <= RENDER_PREV_CAPTURE;

               when RENDER_PREV_CAPTURE =>
                  prev_pos  <= prev_data_read(23 downto 8) & x"00" & prev_data_read(7 downto 0);
                  render_x  <= 0;
                  render_y  <= 0;
                  if prev_data_read(24) = '0' then
                     render_state <= RENDER_PREV_CLEAR;
                  elsif render_entry = 511 then
                     render_entry <= 0;
                     render_state <= RENDER_ATTR_ADDR;
                  else
                     render_entry <= render_entry + 1;
                     render_state <= RENDER_PREV_ADDR;
                  end if;

               when RENDER_PREV_CLEAR =>
                  xpos := to_integer(shift_right(signed(prev_pos(31 downto 16)), 1)) + render_x + 4;
                  ypos := to_integer(unsigned(prev_pos(7 downto 0))) + render_y + 7;

                  if xpos >= 0 and xpos < 320 and ypos >= 0 and ypos < 256 then
                     fb_addr_write <= std_logic_vector(to_unsigned((ypos * 320) + xpos, 17));
                     fb_data_write <= (others => '0');
                     fb_byteena_write <= "11";
                     fb_write <= '1';
                  end if;

                  if render_x = 7 then
                     render_x <= 0;
                     if render_y = 7 then
                        render_y <= 0;
                        if render_entry = 511 then
                           render_entry <= 0;
                           render_state <= RENDER_ATTR_ADDR;
                        else
                           render_entry <= render_entry + 1;
                           render_state <= RENDER_PREV_ADDR;
                        end if;
                     else
                        render_y <= render_y + 1;
                     end if;
                  else
                     render_x <= render_x + 1;
                  end if;

               when RENDER_ATTR_ADDR =>
                  vram_addr_b  <= std_logic_vector(to_unsigned(render_entry * 2, 10));
                  render_state <= RENDER_ATTR_WAIT;

               when RENDER_ATTR_WAIT =>
                  render_state <= RENDER_ATTR_CAPTURE;

               when RENDER_ATTR_CAPTURE =>
                  render_attr  <= vram_data_b(15 downto 0);
                  if vram_data_b = x"04000060" then
                     render_playfield <= '1';
                  else
                     render_playfield <= '0';
                  end if;
                  vram_addr_b  <= std_logic_vector(to_unsigned((render_entry * 2) + 1, 10));
                  render_state <= RENDER_POS_WAIT;

               when RENDER_POS_WAIT =>
                  render_state <= RENDER_POS_CAPTURE;

               when RENDER_POS_CAPTURE =>
                  render_pos <= vram_data_b;
                  render_x   <= 0;
                  render_y   <= 0;
                  prev_addr_write <= std_logic_vector(to_unsigned(render_entry, 9));
                  -- Clearing only consumes X (31..16) and Y (7..0).
                  if render_attr(5) = '0' or render_playfield = '1' then
                     prev_data_write <= '0' & vram_data_b(31 downto 16) &
                                        vram_data_b(7 downto 0);
                  else
                     prev_data_write <= '1' & vram_data_b(31 downto 16) &
                                        vram_data_b(7 downto 0);
                  end if;
                  prev_write      <= '1';
                  if render_attr(5) = '1' and render_playfield = '0' then
                     if render_entry = 511 then
                        prev_valid   <= '1';
                        render_state <= RENDER_IDLE;
                     else
                        render_entry <= render_entry + 1;
                        render_state <= RENDER_ATTR_ADDR;
                     end if;
                  else
                     render_state <= RENDER_DRAW;
                  end if;

               when RENDER_DRAW =>
                  xpos := to_integer(shift_right(signed(render_pos(31 downto 16)), 1)) + render_x + 4;
                  ypos := to_integer(unsigned(render_pos(7 downto 0))) + render_y + 7;

                  if render_playfield = '1' then
                     if xpos >= 0 and xpos < 320 and ypos >= 0 and ypos < 256 then
                        fb_addr_write   <= std_logic_vector(to_unsigned((ypos * 320) + xpos, 17));
                        -- Bit 14 is a low-priority marker.  Keeping bit 15
                        -- clear distinguishes these cells from pieces without
                        -- increasing the framebuffer width.
                        fb_data_write    <= "01" & "000000000" &
                                            e90_playfield_level(render_x);
                        fb_byteena_write <= "11";
                        fb_write         <= '1';
                     end if;

                     if render_x = 7 then
                        render_x <= 0;
                        if render_y = 7 then
                           render_y <= 0;
                           if render_entry = 511 then
                              prev_valid   <= '1';
                              render_state <= RENDER_IDLE;
                           else
                              render_entry <= render_entry + 1;
                              render_state <= RENDER_ATTR_ADDR;
                           end if;
                        else
                           render_y <= render_y + 1;
                        end if;
                     else
                        render_x <= render_x + 1;
                     end if;
                  else
                     palbank := to_integer(unsigned(render_attr(2 downto 1)));
                     if render_pos(15 downto 8) = x"BC" then
                        palbank := palbank + 32;
                     end if;
                     palbank  := palbank + (to_integer(unsigned(render_attr(7 downto 6))) * 4);
                     palindex := (palbank * 16) + PAL_TABLE((render_y * 8) + render_x);

                     if xpos >= 0 and xpos < 320 and ypos >= 0 and ypos < 256 then
                        fb_addr_write  <= std_logic_vector(to_unsigned((ypos * 320) + xpos, 17));
                        palette_addr_b <= std_logic_vector(to_unsigned(palindex / 2, 10));
                        if (palindex mod 2) = 0 then
                           render_pal_low <= '0';
                        else
                           render_pal_low <= '1';
                        end if;
                        render_state <= RENDER_PAL_WAIT;
                     else
                        if render_x = 7 then
                           render_x <= 0;
                           if render_y = 7 then
                              render_y <= 0;
                              if render_entry = 511 then
                                 prev_valid   <= '1';
                                 render_state <= RENDER_IDLE;
                              else
                                 render_entry <= render_entry + 1;
                                 render_state <= RENDER_ATTR_ADDR;
                              end if;
                           else
                              render_y <= render_y + 1;
                           end if;
                        else
                           render_x <= render_x + 1;
                        end if;
                     end if;
                  end if;

               when RENDER_PAL_WAIT =>
                  render_state <= RENDER_PAL_WRITE;

               when RENDER_PAL_WRITE =>
                  if render_pal_low = '0' then
                     raw_color := palette_data_b(31 downto 16);
                  else
                     raw_color := palette_data_b(15 downto 0);
                  end if;
                  fb_data_write    <= '1' & raw_color(14 downto 0);
                  fb_byteena_write <= "11";
                  fb_write      <= '1';

                  if render_x = 7 then
                     render_x <= 0;
                     if render_y = 7 then
                        render_y <= 0;
                        if render_entry = 511 then
                           prev_valid   <= '1';
                           render_state <= RENDER_IDLE;
                        else
                           render_entry <= render_entry + 1;
                           render_state <= RENDER_ATTR_ADDR;
                        end if;
                     else
                        render_y <= render_y + 1;
                        render_state <= RENDER_DRAW;
                     end if;
                  else
                     render_x <= render_x + 1;
                     render_state <= RENDER_DRAW;
                  end if;
            end case;
         end if;
      end if;
   end process;

   -- Track the 640-pixel VI scanout.  E90 coordinates are 320 pixels wide,
   -- so each overlay pixel is repeated horizontally once.
   process(clkvid)
      variable raw_color : std_logic_vector(14 downto 0);
   begin
      if rising_edge(clkvid) then
         hblank_last <= video_hblank_i;

         if reset = '1' then
            pixel_x    <= 0;
            pixel_y    <= 0;
            first_line <= '1';
         else
            if video_vblank_i = '1' then
               first_line <= '1';
            end if;

            if hblank_last = '1' and video_hblank_i = '0' and video_vblank_i = '0' then
               pixel_x <= 0;
               if first_line = '1' then
                  pixel_y    <= 0;
                  first_line <= '0';
               elsif pixel_y < 255 then
                  pixel_y <= pixel_y + 1;
               end if;
            elsif video_ce_i = '1' and video_hblank_i = '0' and pixel_x < 639 then
               pixel_x <= pixel_x + 1;
            end if;
         end if;

         fb_addr_read <= std_logic_vector(to_unsigned((pixel_y * 320) + (pixel_x / 2), 17));

         r_delay1 <= video_r_i;
         r_delay2 <= r_delay1;
         g_delay1 <= video_g_i;
         g_delay2 <= g_delay1;
         b_delay1 <= video_b_i;
         b_delay2 <= b_delay1;
         hsync_delay  <= hsync_delay(0)  & video_hsync_i;
         vsync_delay  <= vsync_delay(0)  & video_vsync_i;
         hblank_delay <= hblank_delay(0) & video_hblank_i;
         vblank_delay <= vblank_delay(0) & video_vblank_i;
         ce_delay     <= ce_delay(0)     & video_ce_i;

         raw_color := fb_data_read(14 downto 0);

         video_r_o <= r_delay2;
         video_g_o <= g_delay2;
         video_b_o <= b_delay2;
         if e90_enabled = '1' then
            if fb_data_read(15) = '1' then
               video_r_o <= expand5(raw_color(4 downto 0));
               video_g_o <= expand5(raw_color(9 downto 5));
               video_b_o <= expand5(raw_color(14 downto 10));
            elsif fb_data_read(14) = '1' and
                  r_delay2 = x"00" and g_delay2 = x"00" and b_delay2 = x"00" then
               -- The N64 black playfield is the transparent key for E90's
               -- banded backdrop.  Non-black VI graphics retain priority,
               -- including the animation drawn when a round is won.
               video_r_o <= expand5(raw_color(4 downto 0));
               video_g_o <= expand5(raw_color(4 downto 0));
               video_b_o <= expand5(raw_color(4 downto 0));
            end if;
         end if;

         video_hsync_o  <= hsync_delay(1);
         video_vsync_o  <= vsync_delay(1);
         video_hblank_o <= hblank_delay(1);
         video_vblank_o <= vblank_delay(1);
         video_ce_o     <= ce_delay(1);
      end if;
   end process;

end architecture;
