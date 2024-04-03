library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity statemanager is
   generic
   (
      Softmap_SaveState_ADDR   : integer
   );
   port 
   (
      clk                 : in    std_logic; 
      ce                  : in    std_logic; 
      reset               : in    std_logic;

      savestate_number    : in    integer;
      save                : in    std_logic;  
      load                : in    std_logic;
      
      request_savestate   : out   std_logic := '0';
      request_loadstate   : out   std_logic := '0';
      request_address     : out   integer := 0;
      request_busy        : in    std_logic
   );
end entity;

architecture arch of statemanager is

   constant SAVESTATESIZE : integer := 16#1000000#; -- 4194304 Dwords = 16384 kbyte

   signal save_1         : std_logic := '0';
   signal load_1         : std_logic := '0';
   signal save_buffer    : std_logic := '0';
   signal load_buffer    : std_logic := '0';

begin 
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         request_savestate <= '0';
         request_loadstate <= '0';
 
         save_1 <= save; 
         if (save = '1' and save_1 = '0') then
            save_buffer <= '1';
         end if;
         
         load_1 <= load;
         if (load = '1' and load_1 = '0') then
            load_buffer <= '1';
         end if;
         
         if (reset = '0' and request_busy = '0') then
            
            if (save_buffer = '1') then
               request_address   <= Softmap_SaveState_ADDR + (savestate_number * SAVESTATESIZE);
               request_savestate <= '1';
               save_buffer       <= '0';
            elsif (load_buffer = '1') then
               request_address   <= Softmap_SaveState_ADDR + (savestate_number * SAVESTATESIZE);
               request_loadstate <= '1';
               load_buffer       <= '0';
            end if;
            
         end if;

      end if;
   end process;
  

end architecture;





