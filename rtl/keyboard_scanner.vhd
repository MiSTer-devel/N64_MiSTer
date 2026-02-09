-- RandNet Keyboard Scanner Module
-- Converts PS/2 keyboard input to N64 RandNet keyboard protocol
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
      
      -- Output to gamepad module
      key1_pos       : out std_logic_vector(15 downto 0) := (others => '0');
      key2_pos       : out std_logic_vector(15 downto 0) := (others => '0');
      key3_pos       : out std_logic_vector(15 downto 0) := (others => '0');
      key_error      : out std_logic := '0'
   );
end entity;

architecture arch of keyboard_scanner is

   signal ps2_key_toggle_last : std_logic := '0';
   
   -- Key tracking
   type key_array_t is array (0 to 15) of std_logic_vector(7 downto 0);
   signal pressed_keys    : key_array_t := (others => (others => '0'));
   signal num_keys        : unsigned(3 downto 0) := (others => '0');
   
   -- Key matrix lookup table with RandNet keyboard matrix positions
   type matrix_lookup_t is array (0 to 255) of std_logic_vector(15 downto 0);
   
   constant KEY_MATRIX : matrix_lookup_t := (
      -- Letter keys (PS/2 Set 2 scan codes -> N64 RandNet matrix positions)
      16#1C# => x"0D07",  -- A
      16#32# => x"0602",  -- B
      16#21# => x"0C02",  -- C
      16#23# => x"0507",  -- D
      16#24# => x"0601",  -- E
      16#2B# => x"0607",  -- F
      16#34# => x"0707",  -- G
      16#33# => x"0807",  -- H
      16#43# => x"0804",  -- I
      16#3B# => x"0907",  -- J
      16#42# => x"0908",  -- K
      16#4B# => x"0808",  -- L
      16#3A# => x"0802",  -- M
      16#31# => x"0702",  -- N
      16#44# => x"0704",  -- O
      16#4D# => x"0604",  -- P
      16#15# => x"0C01",  -- Q
      16#2D# => x"0701",  -- R
      16#1B# => x"0C07",  -- S
      16#2C# => x"0801",  -- T
      16#3C# => x"0904",  -- U
      16#2A# => x"0502",  -- V
      16#1D# => x"0501",  -- W
      16#22# => x"0D02",  -- X
      16#35# => x"0901",  -- Y
      16#1A# => x"0E01",  -- Z
      
      -- Number keys (top row)
      16#45# => x"0606",  -- 0
      16#16# => x"0C05",  -- 1
      16#1E# => x"0505",  -- 2
      16#26# => x"0605",  -- 3
      16#25# => x"0705",  -- 4
      16#2E# => x"0805",  -- 5
      16#36# => x"0905",  -- 6
      16#3D# => x"0906",  -- 7
      16#3E# => x"0806",  -- 8
      16#46# => x"0706",  -- 9
      
      -- Special keys
      16#5A# => x"0D04",  -- Enter
      16#76# => x"0A08",  -- Escape
      16#66# => x"0D06",  -- Backspace
      16#0D# => x"0D01",  -- Tab
      16#29# => x"0603",  -- Space
      16#12# => x"0F01",  -- Left Shift
      16#59# => x"0F04",  -- Right Shift
      16#14# => x"0E06",  -- Ctrl (Left Ctrl)
      16#11# => x"0E04",  -- Alt (Left Alt)
      16#58# => x"0F05",  -- Caps Lock
      
      -- Punctuation and symbols
      16#4E# => x"0506",  -- - (minus/hyphen after 0)
      16#55# => x"0C06",  -- = (equals, shown as ^ in doc)
      16#54# => x"0504",  -- [ (shown as apostrophe in doc)
      16#5B# => x"0C04",  -- ] (shown as left brace {)
      16#5D# => x"0406",  -- \ (shown as right brace })
      16#4C# => x"0708",  -- ; (semicolon)
      16#52# => x"0608",  -- ' (apostrophe, shown as colon :)
      16#0E# => x"0506",  -- ` (grave accent, mapped to - after zero position)
      16#41# => x"0902",  -- , (comma)
      16#49# => x"0903",  -- . (period)
      16#4A# => x"0803",  -- / (slash)
      
      -- Function keys
      16#05# => x"0B01",  -- F1
      16#06# => x"0A01",  -- F2
      16#04# => x"0B08",  -- F3
      16#0C# => x"0A07",  -- F4
      16#03# => x"0B07",  -- F5
      16#0B# => x"0A02",  -- F6
      16#83# => x"0B02",  -- F7
      16#0A# => x"0A03",  -- F8
      16#01# => x"0B03",  -- F9
      16#09# => x"0A04",  -- F10
      16#78# => x"0203",  -- F11
      16#07# => x"0B06",  -- F12
      
      -- Lock keys
      16#77# => x"0A05",  -- Num Lock
      
      -- Navigation cluster (these are extended codes with E0 prefix)
      -- Will need special handling in the state machine
      16#6C# => x"0B04",  -- Home (E0 6C)
      16#69# => x"0A06",  -- End (E0 69)
      16#75# => x"0205",  -- Up Arrow (E0 75)
      16#72# => x"0206",  -- Down Arrow (E0 72)
      16#6B# => x"0204",  -- Left Arrow (E0 6B)
      16#74# => x"0201",  -- Right Arrow (E0 74)
      
      -- Additional right-side keys (extended)
      -- Note: Some of these might need remapping based on your PS/2 keyboard
      16#1F# => x"0E02",  -- Left Windows/Opt (E0 1F) -> Opt
      
      -- Default for unmapped keys
      others => x"0000"
   );

begin

   -- Key press/release tracking (from ps2_key bus)
   process(clk)
      variable key_found : boolean;
      variable ps2_code_v : std_logic_vector(7 downto 0);
      variable is_release : boolean;
   begin
      if rising_edge(clk) then
      
         if reset = '1' then
            pressed_keys <= (others => (others => '0'));
            num_keys     <= (others => '0');
            ps2_key_toggle_last <= ps2_key(10);
            
         else
            if ps2_key(10) /= ps2_key_toggle_last then
               ps2_key_toggle_last <= ps2_key(10);
               ps2_code_v := ps2_key(7 downto 0);
               is_release := (ps2_key(9) = '0');

               if is_release then
                  -- Remove key from pressed list
                  key_found := false;
                  for i in 0 to 15 loop
                     if pressed_keys(i) = ps2_code_v then
                        -- Shift remaining keys down
                        for j in i to 14 loop
                           pressed_keys(j) <= pressed_keys(j + 1);
                        end loop;
                        pressed_keys(15) <= (others => '0');
                        if num_keys > 0 then
                           num_keys <= num_keys - 1;
                        end if;
                        key_found := true;
                        exit;
                     end if;
                  end loop;
                  
               else
                  -- Add key to pressed list if not already there
                  key_found := false;
                  for i in 0 to 15 loop
                     if pressed_keys(i) = ps2_code_v then
                        key_found := true;
                        exit;
                     end if;
                  end loop;
                  
                  if not key_found then
                     if num_keys < 16 then
                        pressed_keys(to_integer(num_keys)) <= ps2_code_v;
                        num_keys <= num_keys + 1;
                     end if;
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process;

   -- Output key positions to gamepad module
   process(clk)
      variable matrix_pos : std_logic_vector(15 downto 0);
   begin
      if rising_edge(clk) then
      
         if reset = '1' then
            key1_pos   <= (others => '0');
            key2_pos   <= (others => '0');
            key3_pos   <= (others => '0');
            key_error  <= '0';
            
         else
            -- Check for error condition (4+ keys pressed)
            if num_keys >= 4 then
               key_error <= '1';
               -- When error, no key data is sent (per protocol spec)
               key1_pos  <= (others => '0');
               key2_pos  <= (others => '0');
               key3_pos  <= (others => '0');
            else
               key_error <= '0';
               
               -- First key
               if num_keys >= 1 then
                  matrix_pos := KEY_MATRIX(to_integer(unsigned(pressed_keys(0))));
                  key1_pos <= matrix_pos;
               else
                  key1_pos <= (others => '0');
               end if;
               
               -- Second key
               if num_keys >= 2 then
                  matrix_pos := KEY_MATRIX(to_integer(unsigned(pressed_keys(1))));
                  key2_pos <= matrix_pos;
               else
                  key2_pos <= (others => '0');
               end if;
               
               -- Third key
               if num_keys >= 3 then
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
