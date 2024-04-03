library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pFunctions.all;

entity savemem is
   port 
   (
      clk                  : in  std_logic;
      reset                : in  std_logic;
      
      SAVETYPE             : in  std_logic_vector(2 downto 0); -- 0 -> None, 1 -> EEPROM4, 2 -> EEPROM16, 3 -> SRAM32, 4 -> SRAM96, 5 -> Flash
      CONTROLLERPAK        : in  std_logic;
      TRANSFERPAK          : in  std_logic;
      
      save                 : in  std_logic;
      load                 : in  std_logic;
      
      mounted              : in  std_logic;
      anyChange            : in  std_logic;
      
      changePending        : out std_logic;
      save_ongoing         : out std_logic := '0';
      
      eeprom_addr          : out std_logic_vector(8 downto 0) := (others => '0');
      eeprom_wren          : out std_logic := '0';
      eeprom_in            : out std_logic_vector(31 downto 0) := (others => '0');
      eeprom_out           : in  std_logic_vector(31 downto 0);
      
      sdram_request        : out std_logic := '0';
      sdram_rnw            : out std_logic := '0'; 
      sdram_address        : out unsigned(26 downto 0):= (others => '0');
      sdram_burstcount     : out unsigned(7 downto 0):= (others => '0');
      sdram_writeMask      : out std_logic_vector(3 downto 0) := (others => '0'); 
      sdram_dataWrite      : out std_logic_vector(31 downto 0) := (others => '0');
      sdram_done           : in  std_logic;
      sdram_dataRead       : in  std_logic_vector(31 downto 0);

      save_rd              : out std_logic := '0';
      save_wr              : out std_logic := '0';
      save_lba             : out std_logic_vector(8 downto 0);
      save_ack             : in  std_logic;
      save_write           : in  std_logic;
      save_addr            : in  std_logic_vector(7 downto 0);
      save_dataIn          : in  std_logic_vector(15 downto 0);
      save_dataOut         : out std_logic_vector(15 downto 0)
   );
end entity;

architecture arch of savemem is
   
   signal DOSAVE     : std_logic;
   signal MAXBLOCK   : integer range 0 to 255; 
   
   type tState is
   (
      IDLE,
      
      LOAD_REQREAD,
      LOAD_WAITACKSTART,
      LOAD_WAITACKDONE,
      LOAD_READDATA,
      LOAD_REQWRITE,
      LOAD_WAITACK,
      
      SAVE_REQDATA,
      SAVE_WAITEEPROM,
      SAVE_READEEPROM,
      SAVE_WAITSDRAM,
      SAVE_READDATA,
      SAVE_REQWRITE,
      SAVE_WAITACKSTART,
      SAVE_WAITACKDONE
   );
   signal state         : tState := IDLE;
  
   signal loadLatched   : std_logic := '0';
   signal saveLatched   : std_logic := '0';
  
   signal anyChangeBuf  : std_logic := '0';
     
   signal blockCnt      : unsigned(8 downto 0);   
  
   signal is_CPAK       : std_logic := '0';
  
   -- memory
   signal mem_addrA     : std_logic_vector(6 downto 0) := (others => '0');
   signal mem_DataInA   : std_logic_vector(31 downto 0);
   signal mem_wrenA     : std_logic := '0';
   signal mem_DataOutA  : std_logic_vector(31 downto 0);

begin 

   DOSAVE <= '1' when (SAVETYPE = "001" or SAVETYPE = "010" or SAVETYPE = "011" or SAVETYPE = "100" or SAVETYPE = "101" or CONTROLLERPAK = '1' or TRANSFERPAK = '1') else '0';
   
   MAXBLOCK <=   0 when (SAVETYPE = "001") else -- EEPROM4
                 3 when (SAVETYPE = "010") else -- EEPROM16
                63 when (SAVETYPE = "011") else -- SRAM32
               191 when (SAVETYPE = "100") else -- SRAM96
               255 when (SAVETYPE = "101") else -- FLASH
                 0; -- unused
   

   changePending <= anyChangeBuf;
  
   sdram_burstcount <= x"01";
   sdram_writeMask  <= x"F";
  
   process (clk)
   begin
      if rising_edge(clk) then
      
         mem_wrenA      <= '0';  
         eeprom_wren    <= '0';  
         sdram_request  <= '0';  
         
         if (save_ack = '1') then
            save_rd <= '0';
            save_wr <= '0';
         end if;

         if (load = '1') then loadLatched <= DOSAVE; end if;
         if (save = '1') then saveLatched <= DOSAVE; end if;

         if (anyChange = '1') then anyChangeBuf <= '1'; end if;

         if (reset = '1') then
         
            state          <= IDLE;
            save_rd        <= '0';
            save_wr        <= '0';            
            save_ongoing   <= '0';

         else
         
            case (state) is
               when IDLE => 
                  blockCnt  <= (others => '0');
                  mem_addrA <= (others => '0');
                  save_lba  <= (others => '0');
                  is_CPAK   <= '0';
                  if (SAVETYPE = "000") then
                     is_CPAK <= '1';
                  end if;
                  if (loadLatched = '1' and mounted = '1') then
                     state        <= LOAD_REQREAD;
                     anyChangeBuf <= '0';
                  elsif (saveLatched = '1') then
                     if (anyChangeBuf = '1') then
                        state          <= SAVE_REQDATA;
                        anyChangeBuf   <= '0';
                        save_ongoing <= '1';
                     end if;
                     saveLatched  <= '0';
                  end if;
               
               -- loading
               when LOAD_REQREAD =>
                  state <= LOAD_WAITACKSTART;
                  save_rd  <= '1';
                  
               when LOAD_WAITACKSTART =>
                  if (save_ack = '1') then
                     state    <= LOAD_WAITACKDONE;
                     save_lba <= std_logic_vector(unsigned(save_lba) + 1);
                  end if;
                  
               when LOAD_WAITACKDONE =>
                  mem_addrA <= (others => '0');
                  if (save_ack = '0') then
                     state <= LOAD_READDATA;
                  end if;
               
               when LOAD_READDATA =>
                  state <= LOAD_REQWRITE;
            
               when LOAD_REQWRITE =>
                  state        <= LOAD_WAITACK;
                  if (is_CPAK = '1') then
                     sdram_request   <= '1';
                     sdram_rnw       <= '0';
                     sdram_address   <= resize(blockCnt(7 downto 0) & unsigned(mem_addrA & "00"), 27) + to_unsigned(16#500000#, 27);
                     sdram_dataWrite <= byteswap32(mem_DataOutA);
                  elsif (SAVETYPE = "001" or SAVETYPE = "010") then
                     eeprom_addr <= std_logic_vector(blockCnt(1 downto 0)) & mem_addrA;
                     eeprom_in   <= mem_DataOutA;
                     eeprom_wren <= '1';
                  elsif (SAVETYPE = "011" or SAVETYPE = "100" or SAVETYPE = "101") then
                     sdram_request   <= '1';
                     sdram_rnw       <= '0';
                     sdram_address   <= resize(blockCnt(7 downto 0) & unsigned(mem_addrA & "00"), 27) + to_unsigned(16#400000#, 27);
                     sdram_dataWrite <= byteswap32(mem_DataOutA);
                  end if;
                  
               when LOAD_WAITACK =>
                  if ((is_CPAK = '0' and (SAVETYPE = "001" or SAVETYPE = "010")) or (sdram_done = '1' and (SAVETYPE = "011" or SAVETYPE = "100" or SAVETYPE = "101" or is_CPAK = '1'))) then
                     if (unsigned(mem_addrA) = 127) then
                        if ((is_CPAK = '1' and blockCnt = 255) or (is_CPAK = '0' and blockCnt = MAXBLOCK)) then
                           if (is_CPAK = '1' or (CONTROLLERPAK = '0' and TRANSFERPAK = '0')) then
                              state        <= IDLE;
                              loadLatched  <= '0';
                           else
                              blockCnt  <= (others => '0');
                              mem_addrA <= (others => '0');
                              is_CPAK   <= '1';
                              state     <= LOAD_REQREAD;
                           end if;
                        else
                           blockCnt <= blockCnt + 1;
                           state    <= LOAD_REQREAD;
                        end if;
                     else
                        mem_addrA <= std_logic_vector(unsigned(mem_addrA) + 1);
                        state     <= LOAD_READDATA;
                     end if;
                  end if;
                  
               -- saving
               when SAVE_REQDATA =>
                  if (is_CPAK = '1') then
                     sdram_request   <= '1';
                     sdram_rnw       <= '1';
                     sdram_address   <= resize(blockCnt(7 downto 0) & unsigned(mem_addrA & "00"), 27) + to_unsigned(16#500000#, 27);
                     state           <= SAVE_WAITSDRAM;
                  elsif (SAVETYPE = "001" or SAVETYPE = "010") then
                     eeprom_addr <= std_logic_vector(blockCnt(1 downto 0)) & mem_addrA;
                     state       <= SAVE_WAITEEPROM;
                  elsif (SAVETYPE = "011" or SAVETYPE = "100" or SAVETYPE = "101") then
                     sdram_request   <= '1';
                     sdram_rnw       <= '1';
                     sdram_address   <= resize(blockCnt(7 downto 0) & unsigned(mem_addrA & "00"), 27) + to_unsigned(16#400000#, 27);
                     state           <= SAVE_WAITSDRAM;
                  end if;
               
               when SAVE_WAITEEPROM =>
                  state        <= SAVE_READEEPROM;
                  
               when SAVE_READEEPROM =>
                  state        <= SAVE_READDATA;
                  mem_wrenA    <= '1';
                  mem_DataInA  <= eeprom_out; 
                  
               when SAVE_WAITSDRAM =>
                  if (sdram_done = '1') then
                     state        <= SAVE_READDATA;
                     mem_wrenA    <= '1';
                     mem_DataInA  <= byteswap32(sdram_dataRead); 
                  end if;
                  
               when SAVE_READDATA =>
                  if (unsigned(mem_addrA) = 127) then
                     state <= SAVE_REQWRITE;
                  else
                     mem_addrA <= std_logic_vector(unsigned(mem_addrA) + 1);
                     state     <= SAVE_REQDATA;
                  end if;
                  
               when SAVE_REQWRITE =>
                  state <= SAVE_WAITACKSTART;
                  save_wr  <= '1';
                 
               when SAVE_WAITACKSTART =>
                  if (save_ack = '1') then 
                     state    <= SAVE_WAITACKDONE;
                     save_lba <= std_logic_vector(unsigned(save_lba) + 1);
                  end if;
                  
               when SAVE_WAITACKDONE =>
                  mem_addrA <= (others => '0');
                  if (save_ack = '0') then 
                     if ((is_CPAK = '1' and blockCnt = 255) or (is_CPAK = '0' and blockCnt = MAXBLOCK)) then
                        if (is_CPAK = '1' or (CONTROLLERPAK = '0' and TRANSFERPAK = '0')) then
                           state          <= IDLE;
                           save_ongoing   <= '0';
                        else
                           blockCnt  <= (others => '0');
                           mem_addrA <= (others => '0');
                           is_CPAK   <= '1';
                           state     <= SAVE_REQDATA;
                        end if;
                     else
                        blockCnt <= blockCnt + 1;
                        state    <= SAVE_REQDATA;
                     end if;
                  end if;
              
            end case;
            
         end if;
         
      end if;
   end process;
   
   iramSectorBuffer: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 7,
      data_width_a  => 32,
      addr_width_b  => 8,
      data_width_b  => 16
   )
   port map
   (
      clock_a     => clk,
      address_a   => mem_addrA,
      data_a      => mem_DataInA,
      wren_a      => mem_wrenA,
      q_a         => mem_DataOutA,
      
      clock_b     => clk,
      address_b   => save_addr,                    
      data_b      => save_dataIn,                  
      wren_b      => (save_write and save_ack),
      q_b         => save_dataOut
   );
   
end architecture;





