-- RandNet Keyboard Scanner Module
-- Converts MiSTer PS/2 keyboard input to N64 RandNet keyboard protocol
-- https://sites.google.com/site/consoleprotocols/home/nintendo-joy-bus-documentation/n64-specific/randnet-keyboard
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity keyboard_scanner is
   port (
      clk            : in  std_logic;
      reset          : in  std_logic;
      
      -- MiSTer ps2_key bus: [10]=toggle, [9]=pressed, [8]=extended, [7:0]=scan code
      ps2_key        : in  std_logic_vector(10 downto 0);
      
      key1_pos       : out std_logic_vector(15 downto 0) := (others => '0');
      key2_pos       : out std_logic_vector(15 downto 0) := (others => '0');
      key3_pos       : out std_logic_vector(15 downto 0) := (others => '0');
      kb_status      : out std_logic_vector(7 downto 0)  := (others => '0')
   );
end entity;

architecture arch of keyboard_scanner is

   signal ps2_key_toggle_last : std_logic := '0';
   
   -- Key tracking
   type key_array_t is array (0 to 15) of std_logic_vector(8 downto 0);
   signal pressed_keys    : key_array_t := (others => (others => '0'));
   signal num_keys        : unsigned(4 downto 0) := (others => '0');
   signal home_down_s     : std_logic := '0';
   signal key_error_s     : std_logic := '0';
   
   -- Key matrix lookup table with RandNet keyboard matrix positions
   type matrix_lookup_t is array (0 to 511) of std_logic_vector(15 downto 0);
   
   constant KEY_MATRIX : matrix_lookup_t := (
      --------------------------------------------------------------------------
      -- Non-extended keys (E0=0): index 0x000..0x0FF
      --------------------------------------------------------------------------
      16#076# => x"0A08",  -- Escape

      -- Function keys
      16#005# => x"0B01",  -- F1
      16#006# => x"0A01",  -- F2
      16#004# => x"0B08",  -- F3
      16#00C# => x"0A07",  -- F4
      16#003# => x"0B07",  -- F5
      16#00B# => x"0A02",  -- F6
      16#083# => x"0B02",  -- F7
      16#00A# => x"0A03",  -- F8
      16#001# => x"0B03",  -- F9
      16#009# => x"0A04",  -- F10
      16#078# => x"0203",  -- F11
      16#007# => x"0B06",  -- F12

      -- Lock keys
      16#077# => x"0A05",  -- Num Lock
      16#07E# => x"0208",  -- Scroll Lock -> Japanese Key below Caps Lock LED
      16#058# => x"0F05",  -- Caps Lock

      -- Tilde (grave/~ key)
      16#00E# => x"0D05",  -- ~ -> Japanese Key above Tab

      -- Number row
      16#016# => x"0C05",  -- 1
      16#01E# => x"0505",  -- 2
      16#026# => x"0605",  -- 3
      16#025# => x"0705",  -- 4
      16#02E# => x"0805",  -- 5
      16#036# => x"0905",  -- 6
      16#03D# => x"0906",  -- 7
      16#03E# => x"0806",  -- 8
      16#046# => x"0706",  -- 9
      16#045# => x"0606",  -- 0

      16#07B# => x"0506",  -- Keypad minus (-)
      16#055# => x"0C06",  -- '=' key -> '^' position

      -- Backspace / Tab / Enter / Space
      16#066# => x"0D06",  -- Backspace
      16#00D# => x"0D01",  -- Tab
      16#05A# => x"0D04",  -- Enter
      16#029# => x"0602",  -- Space

      -- Letters
      16#015# => x"0C01",  -- Q
      16#01D# => x"0501",  -- W
      16#024# => x"0601",  -- E
      16#02D# => x"0701",  -- R
      16#02C# => x"0801",  -- T
      16#035# => x"0901",  -- Y
      16#03C# => x"0904",  -- U
      16#043# => x"0804",  -- I
      16#044# => x"0704",  -- O
      16#04D# => x"0604",  -- P

      16#01C# => x"0D07",  -- A
      16#01B# => x"0C07",  -- S
      16#023# => x"0507",  -- D
      16#02B# => x"0607",  -- F
      16#034# => x"0707",  -- G
      16#033# => x"0807",  -- H
      16#03B# => x"0907",  -- J
      16#042# => x"0903",  -- K
      16#04B# => x"0803",  -- L

      16#01A# => x"0D08",  -- Z
      16#022# => x"0C08",  -- X
      16#021# => x"0508",  -- C
      16#02A# => x"0608",  -- V
      16#032# => x"0708",  -- B
      16#031# => x"0808",  -- N
      16#03A# => x"0908",  -- M

      -- Punctuation / symbols
      16#052# => x"0504",  -- Quote '
      16#054# => x"0C04",  -- Left brace [
      16#05B# => x"0406",  -- Right brace ]
      16#04C# => x"1105",  -- Semicolon Pipes
      16#041# => x"0902",  -- Comma <
      16#049# => x"0802",  -- Period >
      16#04A# => x"0702",  -- Slash ?

      -- Long dash
      16#04E# => x"1004",  -- '-' (Long dash)

      -- Numpad plus/asterisk
      16#079# => x"0703",  -- Keypad +
      16#07C# => x"0603",  -- Keypad *

      -- Shifts / Ctrl / Alt / Opt
      16#012# => x"0E01",  -- Left Shift
      16#059# => x"0E06",  -- Right Shift
      16#014# => x"1107",  -- Left Ctrl
      16#011# => x"1008",  -- Left Alt
      16#01F# => x"0F07",  -- Opt (fallback if a keyboard emits non-E0 here)

      -- Japanese keys via keypad 1/2/3 in the reference mapping
      16#069# => x"1002",  -- Keypad 1 -> Japanese 'alphanumeric key'
      16#072# => x"0E02",  -- Keypad 2 -> Japanese 'kana'
      16#07A# => x"1006",  -- Keypad 3 -> Japanese Character

      --------------------------------------------------------------------------
      -- Extended keys (E0=1): index 0x100..0x1FF (i.e., 0x100 + scancode)
      --------------------------------------------------------------------------

      16#17C# => x"0B05",  -- PrintScreen -> Japanese Key below Numlock LED
      16#17D# => x"0207",  -- Page Up -> Japanese Key below Power LED

      -- Arrow keys (E0-prefixed)
      16#175# => x"0204",  -- Up
      16#16B# => x"0205",  -- Left
      16#172# => x"0305",  -- Down
      16#174# => x"0405",  -- Right

      -- End
      16#169# => x"0206",  -- End

      -- Right-side modifiers (map to same RandNet positions)
      16#114# => x"1107",  -- Right Ctrl -> Ctrl
      16#111# => x"1008",  -- Right Alt  -> Alt
      16#11F# => x"0F07",  -- Windows/Opt (common E0 1F)

      others => x"0000"
   );

begin

   -- Pack status byte: bit4=key_error_s, bit0=home_down_s
   kb_status <= "000" & key_error_s & "000" & home_down_s;

   -- Key press/release tracking (from ps2_key bus)
   process(clk)
      variable pk       : key_array_t;
      variable nk       : unsigned(4 downto 0);
      variable key_id   : std_logic_vector(8 downto 0);
      variable mapped   : std_logic_vector(15 downto 0);
      variable found_i  : integer range -1 to 15;
   begin
      if rising_edge(clk) then
         if reset = '1' then
            pressed_keys        <= (others => (others => '0'));
            num_keys            <= (others => '0');
            ps2_key_toggle_last <= ps2_key(10);
            home_down_s         <= '0';
         else
            pk := pressed_keys;
            nk := num_keys;
            
            if ps2_key(10) /= ps2_key_toggle_last then
               ps2_key_toggle_last <= ps2_key(10);
               
               -- Home on PS/2 Set-2 is typically E0 6C (MiSTer reports extended flag + scancode).
               if (ps2_key(8) = '1') and (ps2_key(7 downto 0) = x"6C") then
                  home_down_s <= ps2_key(9);  -- 1=make, 0=break
               end if;

               -- build 9-bit id: {E0, scancode}
               key_id := ps2_key(8) & ps2_key(7 downto 0);
               mapped := KEY_MATRIX(to_integer(unsigned(key_id)));

               -- Only consider keys that have a mapping for the 3-key report
               if mapped /= x"0000" then

                  if ps2_key(9) = '0' then
                     -- BREAK: remove key_id if present
                     found_i := -1;
                     for i in 0 to 15 loop
                        if pk(i) = key_id then
                           found_i := i;
                           exit;
                        end if;
                     end loop;

                     if found_i /= -1 then
                        for j in 0 to 14 loop
                           if j >= found_i then
                              pk(j) := pk(j + 1);
                           end if;
                        end loop;
                        pk(15) := (others => '0');

                        if nk > 0 then
                           nk := nk - 1;
                        end if;
                     end if;

                  else
                     -- MAKE: add key_id if not already present
                     found_i := -1;
                     for i in 0 to 15 loop
                        if pk(i) = key_id then
                           found_i := i;
                           exit;
                        end if;
                     end loop;

                     if found_i = -1 then
                        if nk < to_unsigned(16, nk'length) then
                           pk(to_integer(nk)) := key_id;
                           nk := nk + 1;
                        end if;
                     end if;
                  end if;

               end if;
            end if;
            
            pressed_keys <= pk;
            num_keys     <= nk;
         end if;
      end if;
   end process;

   -- Output key positions to gamepad module + set key_error_s
   process(clk)
      variable matrix_pos : std_logic_vector(15 downto 0);
   begin
      if rising_edge(clk) then
      
         if reset = '1' then
            key1_pos    <= (others => '0');
            key2_pos    <= (others => '0');
            key3_pos    <= (others => '0');
            key_error_s <= '0';
         else
            if num_keys >= to_unsigned(4, num_keys'length) then
               key_error_s <= '1';
               -- When error, no key data is sent (per protocol spec)
               key1_pos  <= (others => '0');
               key2_pos  <= (others => '0');
               key3_pos  <= (others => '0');
            else
               key_error_s <= '0';
               
               -- First key
               if num_keys >= to_unsigned(1, num_keys'length) then
                  matrix_pos := KEY_MATRIX(to_integer(unsigned(pressed_keys(0))));
                  key1_pos <= matrix_pos;
               else
                  key1_pos <= (others => '0');
               end if;
               
               -- Second key
               if num_keys >= to_unsigned(2, num_keys'length) then
                  matrix_pos := KEY_MATRIX(to_integer(unsigned(pressed_keys(1))));
                  key2_pos <= matrix_pos;
               else
                  key2_pos <= (others => '0');
               end if;
               
               -- Third key
               if num_keys >= to_unsigned(3, num_keys'length) then
                  matrix_pos := KEY_MATRIX(to_integer(unsigned(pressed_keys(2))));
                  key3_pos <= matrix_pos;
               else
                  key3_pos <= (others => '0');
               end if;
            end if;
         end if;
      end if;
   end process;

end architecture;
