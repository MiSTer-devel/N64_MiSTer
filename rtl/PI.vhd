library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;
use work.pFunctions.all;

entity PI is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      FASTROM              : in  std_logic;
      SAVETYPE             : in  std_logic_vector(2 downto 0); -- 0 -> None, 1 -> EEPROM4, 2 -> EEPROM16, 3 -> SRAM32, 4 -> SRAM96, 5 -> Flash
      fastDecay            : in  std_logic;
      cartAvailable        : in  std_logic;
      
      irq_out              : out std_logic := '0';
      
      error_PI             : out std_logic := '0';
      
      change_sram          : out std_logic := '0';
      change_flash         : out std_logic := '0';
      
      sdram_request        : out std_logic := '0';
      sdram_rnw            : out std_logic := '0'; 
      sdram_address        : out unsigned(26 downto 0):= (others => '0');
      sdram_burstcount     : out unsigned(7 downto 0):= (others => '0');
      sdram_writeMask      : out std_logic_vector(3 downto 0) := (others => '0'); 
      sdram_dataWrite      : out std_logic_vector(31 downto 0) := (others => '0');
      sdram_done           : in  std_logic;
      sdram_dataRead       : in  std_logic_vector(31 downto 0);
      
      rdram_request        : out std_logic := '0';
      rdram_rnw            : out std_logic := '0'; 
      rdram_address        : out unsigned(27 downto 0):= (others => '0');
      rdram_burstcount     : out unsigned(9 downto 0):= (others => '0');
      rdram_done           : in  std_logic;
      rdram_dataRead       : in  std_logic_vector(63 downto 0);
      
      PIfifo_Din           : out std_logic_vector(92 downto 0); -- 64bit data + 24 bit address + 8 byte enables
      PIfifo_Wr            : out std_logic;  
      PIfifo_nearfull      : in  std_logic;
      PIfifo_empty         : in  std_logic;
      
      bus_reg_addr         : in  unsigned(19 downto 0); 
      bus_reg_dataWrite    : in  std_logic_vector(31 downto 0);
      bus_reg_read         : in  std_logic;
      bus_reg_write        : in  std_logic;
      bus_reg_dataRead     : out std_logic_vector(31 downto 0) := (others => '0');
      bus_reg_done         : out std_logic := '0';
      
      bus_cart_addr        : in  unsigned(31 downto 0); 
      bus_cart_dataWrite   : in  std_logic_vector(31 downto 0);
      bus_cart_read        : in  std_logic;
      bus_cart_write       : in  std_logic;
      bus_cart_dataRead    : out std_logic_vector(31 downto 0) := (others => '0');
      bus_cart_done        : out std_logic := '0';
      
      SS_reset              : in  std_logic;
      SS_DataWrite          : in  std_logic_vector(63 downto 0);
      SS_Adr                : in  unsigned(2 downto 0);
      SS_wren               : in  std_logic;
      SS_rden               : in  std_logic;
      SS_DataRead           : out std_logic_vector(63 downto 0);
      SS_idle               : out std_logic
   );
end entity;

architecture arch of PI is

   signal PI_DRAM_ADDR           : unsigned(23 downto 0);  -- 0x04600000 PI DRAM address (RW) : [23:0] starting RDRAM address
   signal PI_CART_ADDR           : unsigned(31 downto 0);  -- 0x04600004 PI pbus (cartridge) address (RW) : [31:0] starting AD16 address
   signal PI_LEN                 : unsigned(24 downto 0);  -- 0x04600008/C PI read/write length (RW) : [23:0] read data length
   signal PI_WR_LEN              : unsigned( 6 downto 0);  -- 0x0460000C PI write length (RW) : [23:0] read data length
   signal PI_STATUS_DMAbusy      : std_logic;              -- 0x04600010 PI status (R) : [0] DMA busy [1] I/O busy [2] DMA error [3] Interrupt (DMA completed) (W) : [0] reset controller [1] clear intr
   signal PI_STATUS_IObusy       : std_logic;  
   signal PI_STATUS_DMAerror     : std_logic;  
   signal PI_STATUS_irq          : std_logic;  
   signal PI_BSD_DOM1_LAT        : unsigned(7 downto 0);   -- 0x04600014 PI dom1 latency (RW) : [7:0] domain 1 device latency
   signal PI_BSD_DOM1_PWD        : unsigned(7 downto 0);   -- 0x04600018 PI dom1 pulse width (RW) : [7:0] domain 1 device R / W strobe pulse width
   signal PI_BSD_DOM1_PGS        : unsigned(3 downto 0);   -- 0x0460001C PI dom1 page size(RW) : [3:0] domain 1 device page size
   signal PI_BSD_DOM1_RLS        : unsigned(1 downto 0);   -- 0x04600020 PI dom1 release (RW) : [1:0] domain 1 device R / W release duration
   signal PI_BSD_DOM2_LAT        : unsigned(7 downto 0);   -- 0x04600024 PI dom2 latency (RW) : [7:0] domain 2 device latency
   signal PI_BSD_DOM2_PWD        : unsigned(7 downto 0);   -- 0x04600028 PI dom2 pulse width (RW) : [7:0] domain 2 device R / W strobe pulse width
   signal PI_BSD_DOM2_PGS        : unsigned(3 downto 0);   -- 0x0460002C PI dom2 page size (RW) : [3:0] domain 2 device page size
   signal PI_BSD_DOM2_RLS        : unsigned(1 downto 0);   -- 0x04600030 PI dom2 release (RW) : [1:0] domain 2 device R / W release duration
   
   signal dmaIsWrite             : std_logic;
   signal first128               : std_logic;
   signal blocklength            : integer range 0 to 128;
   signal maxram                 : integer range -7 to 128;
   signal copycnt                : integer range 0 to 128;
   signal MaxBlockSize           : integer range 0 to 128;
   signal distEndOfRow           : integer range 0 to 2048;
   signal distEndOfRowSave       : integer range 0 to 2048;
   signal misAlignSave           : integer range 0 to 7;
      
   -- PI state machine  
   type tState is 
   (  
      IDLE, 
      READROM,
      READSRAM,
      WRITESRAM,
      WRITEFLASH,
      WAITFLASH,
      COPYDMABLOCK,
      DMA_READCART,
      DMA_READRDRAM,
      DMA_WAITRDRAM,
      DMA_WAITSDRAM
   ); 
   signal state                  : tState := IDLE;
   
   signal writtenData            : std_logic_vector(31 downto 0) := (others => '0');   
   signal writtenTime            : integer range 0 to 200 := 0; 

   signal bus_cart_read_latched  : std_logic := '0';  
   signal bus_cart_write_latched : std_logic := '0';  
   
   signal dma_isflashread        : std_logic := '0';

   signal PI_BSD_LAT             : unsigned(7 downto 0);
   signal PI_BSD_PWD             : unsigned(7 downto 0);
   signal PI_BSD_PGS             : unsigned(3 downto 0);
   signal PI_BSD_RLS             : unsigned(1 downto 0);
   signal rom_slow_sum           : unsigned(31 downto 0) := (others => '0');
   signal rom_slow_cnt           : unsigned(31 downto 0) := (others => '0');
   signal PI_DRAM_pagemask       : unsigned(17 downto 0);
   signal PI_DRAM_page           : unsigned(17 downto 0);
   signal PI_DRAM_valid          : std_logic := '0';

   -- Flash
   type tFlashState is 
   (  
      FLASHIDLE, 
      FLASHSTATUS,
      FLASHERASE,
      FLASHREAD,
      FLASHWRITE
   ); 
   signal flashState       : tFlashState := FLASHIDLE;
   signal flash_statusword : std_logic_vector(63 downto 0) := (others => '0');
   signal flash_offset     : unsigned(9 downto 0) := (others => '0');

   signal flash_addrA      : std_logic_vector(5 downto 0) := (others => '0');
   signal flash_DataInA    : std_logic_vector(15 downto 0) := (others => '0');
   signal flash_wrenA      : std_logic := '0';
   signal flash_addrB      : std_logic_vector(4 downto 0) := (others => '0');
   signal flash_DataOutB   : std_logic_vector(31 downto 0);

   -- savestates
   type t_ssarray is array(0 to 7) of std_logic_vector(63 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0'));     

begin 

   irq_out <= PI_STATUS_irq;
   
   rdram_burstcount <= 10x"01";
   sdram_burstcount <= x"01";
   
   distEndOfRow <= 16#800# - to_integer(PI_DRAM_ADDR(10 downto 0));

   PI_BSD_LAT <= PI_BSD_DOM2_LAT when (PI_CART_ADDR(28 downto 0) < 16#10000000#) else PI_BSD_DOM1_LAT;
   PI_BSD_PWD <= PI_BSD_DOM2_PWD when (PI_CART_ADDR(28 downto 0) < 16#10000000#) else PI_BSD_DOM1_PWD;
   PI_BSD_PGS <= PI_BSD_DOM2_PGS when (PI_CART_ADDR(28 downto 0) < 16#10000000#) else PI_BSD_DOM1_PGS;
   PI_BSD_RLS <= PI_BSD_DOM2_RLS when (PI_CART_ADDR(28 downto 0) < 16#10000000#) else PI_BSD_DOM1_RLS;

   PI_DRAM_pagemask <= 18x"3FFFC" when PI_BSD_PGS = 0  else
                       18x"3FFF8" when PI_BSD_PGS = 1  else
                       18x"3FFF0" when PI_BSD_PGS = 2  else
                       18x"3FFE0" when PI_BSD_PGS = 3  else
                       18x"3FFC0" when PI_BSD_PGS = 4  else
                       18x"3FF80" when PI_BSD_PGS = 5  else
                       18x"3FF00" when PI_BSD_PGS = 6  else
                       18x"3FE00" when PI_BSD_PGS = 7  else
                       18x"3FC00" when PI_BSD_PGS = 8  else
                       18x"3F800" when PI_BSD_PGS = 9  else
                       18x"3F000" when PI_BSD_PGS = 10 else
                       18x"3E000" when PI_BSD_PGS = 11 else
                       18x"3C000" when PI_BSD_PGS = 12 else
                       18x"38000" when PI_BSD_PGS = 13 else
                       18x"30000" when PI_BSD_PGS = 14 else
                       18x"20000";

   process (clk1x)
      variable blocklength_new : integer range 0 to 128;
      variable count_new       : unsigned(24 downto 0);
      variable writemask_new   : std_logic_vector(1 downto 0);
      variable dma_readData    : std_logic_vector(15 downto 0);
   begin
      if rising_edge(clk1x) then
      
         error_PI     <= '0';
         change_sram  <= '0';
         change_flash <= '0';
         flash_wrenA  <= '0';
         PIfifo_Wr    <= '0';
         
         if (PI_STATUS_DMAbusy = '1') then
            rom_slow_cnt <= rom_slow_cnt + 1;
         end if;
      
         if (reset = '1') then
            
            bus_reg_done            <= '0';

            PI_DRAM_ADDR            <= (others => '0');
            PI_CART_ADDR            <= (others => '0');
            PI_LEN                  <= (others => '0');
            PI_WR_LEN               <= (others => '0');
            PI_STATUS_DMAbusy       <= ss_in(0)(56); -- '0';
            PI_STATUS_IObusy        <= ss_in(0)(57); -- '0';
            PI_STATUS_DMAerror      <= ss_in(0)(58); -- '0';
            PI_STATUS_irq           <= ss_in(0)(59); -- '0';
            PI_BSD_DOM1_LAT         <= unsigned(ss_in(2)(7 downto 0));   --(others => '0');
            PI_BSD_DOM1_PWD         <= unsigned(ss_in(2)(15 downto 8));  --(others => '0');
            PI_BSD_DOM1_PGS         <= unsigned(ss_in(2)(19 downto 16)); --(others => '0');
            PI_BSD_DOM1_RLS         <= unsigned(ss_in(2)(21 downto 20)); --(others => '0');
            PI_BSD_DOM2_LAT         <= unsigned(ss_in(2)(29 downto 22)); --(others => '0');
            PI_BSD_DOM2_PWD         <= unsigned(ss_in(2)(37 downto 30)); --(others => '0');
            PI_BSD_DOM2_PGS         <= unsigned(ss_in(2)(41 downto 38)); --(others => '0');
            PI_BSD_DOM2_RLS         <= unsigned(ss_in(2)(43 downto 42)); --(others => '0');
               
            state                   <= IDLE;
               
            bus_cart_read_latched   <= '0';
            bus_cart_write_latched  <= '0';
            
            flashState              <= FLASHIDLE;
            flash_statusword        <= (others => '0');
            flash_offset            <= (others => '0');
 
         elsif (ce = '1') then
         
            bus_reg_done     <= '0';
            bus_reg_dataRead <= (others => '0');

            -- bus regs read
            if (bus_reg_read = '1') then
               bus_reg_done <= '1';
               case (bus_reg_addr(19 downto 2) & "00") is
                  when x"00000" => bus_reg_dataRead(23 downto 0) <= std_logic_vector(PI_DRAM_ADDR);    
                  when x"00004" => bus_reg_dataRead(31 downto 0) <= std_logic_vector(PI_CART_ADDR);    
                  when x"00008" => bus_reg_dataRead( 6 downto 0) <= (others => '1'); -- maybe different for reads < 8?   
                  when x"0000C" => bus_reg_dataRead( 6 downto 0) <= std_logic_vector(PI_WR_LEN);
                  when x"00010" => 
                     bus_reg_dataRead(0) <= PI_STATUS_DMAbusy;    
                     bus_reg_dataRead(1) <= PI_STATUS_IObusy;    
                     bus_reg_dataRead(2) <= PI_STATUS_DMAerror;    
                     bus_reg_dataRead(3) <= PI_STATUS_irq; 
                  when x"00014" => bus_reg_dataRead(7 downto 0) <= std_logic_vector(PI_BSD_DOM1_LAT);    
                  when x"00018" => bus_reg_dataRead(7 downto 0) <= std_logic_vector(PI_BSD_DOM1_PWD);    
                  when x"0001C" => bus_reg_dataRead(3 downto 0) <= std_logic_vector(PI_BSD_DOM1_PGS);    
                  when x"00020" => bus_reg_dataRead(1 downto 0) <= std_logic_vector(PI_BSD_DOM1_RLS);    
                  when x"00024" => bus_reg_dataRead(7 downto 0) <= std_logic_vector(PI_BSD_DOM2_LAT);    
                  when x"00028" => bus_reg_dataRead(7 downto 0) <= std_logic_vector(PI_BSD_DOM2_PWD);    
                  when x"0002C" => bus_reg_dataRead(3 downto 0) <= std_logic_vector(PI_BSD_DOM2_PGS);    
                  when x"00030" => bus_reg_dataRead(1 downto 0) <= std_logic_vector(PI_BSD_DOM2_RLS);  
                  when others   => null;                  
               end case;
            end if;

            -- bus regs write
            if (bus_reg_write = '1') then
               bus_reg_done <= '1';
               
               if ((bus_reg_addr(19 downto 2) & "00") = x"00010") then
                  if (bus_reg_dataWrite(1) = '1') then
                     PI_STATUS_irq <= '0';
                  end if;
                  if (bus_reg_dataWrite(0) = '1') then
                     PI_STATUS_DMAbusy  <= '0';
                     PI_STATUS_DMAerror <= '0';
                  end if;
                  
               --elsif (PI_STATUS_DMAbusy = '1' or PI_STATUS_IObusy = '1') then -- also check IObusy?
               elsif (PI_STATUS_DMAbusy = '1') then
                  PI_STATUS_DMAerror <= '1';
                  error_PI           <= '1';
               
               else
               
                  case (bus_reg_addr(19 downto 2) & "00") is
                     when x"00000" => PI_DRAM_ADDR <= unsigned(bus_reg_dataWrite(23 downto 1)) & '0';   
                     when x"00004" => PI_CART_ADDR <= unsigned(bus_reg_dataWrite(31 downto 1)) & '0';
                     
                     when x"00008" | x"0000C" => 
                        PI_STATUS_DMAbusy <= '1';
                        first128          <= '1';
                        PI_LEN            <= resize(unsigned(bus_reg_dataWrite(23 downto 0)), 25) + to_unsigned(1, 25);      
                        MaxBlockSize      <= 128;
                        PI_DRAM_valid     <= '0';
                        rom_slow_cnt      <= (others => '0');
                        rom_slow_sum      <= (others => '0');
                        if (bus_reg_addr(19 downto 2) & "00" = x"00008") then dmaIsWrite <= '0'; else dmaIsWrite <= '1'; end if;
                        
                     when x"00010" => null; --handled above
                     when x"00014" => PI_BSD_DOM1_LAT <= unsigned(bus_reg_dataWrite(7 downto 0));    
                     when x"00018" => PI_BSD_DOM1_PWD <= unsigned(bus_reg_dataWrite(7 downto 0));    
                     when x"0001C" => PI_BSD_DOM1_PGS <= unsigned(bus_reg_dataWrite(3 downto 0));    
                     when x"00020" => PI_BSD_DOM1_RLS <= unsigned(bus_reg_dataWrite(1 downto 0));    
                     when x"00024" => PI_BSD_DOM2_LAT <= unsigned(bus_reg_dataWrite(7 downto 0));    
                     when x"00028" => PI_BSD_DOM2_PWD <= unsigned(bus_reg_dataWrite(7 downto 0));    
                     when x"0002C" => PI_BSD_DOM2_PGS <= unsigned(bus_reg_dataWrite(3 downto 0));    
                     when x"00030" => PI_BSD_DOM2_RLS <= unsigned(bus_reg_dataWrite(1 downto 0));
                     when others   => null;
                  end case;
                  
               end if;
            end if;
            
            
            -- PI state machine
            bus_cart_done     <= '0';
            bus_cart_dataRead <= (others => '0');
            sdram_request     <= '0';
            rdram_request     <= '0';
            
            if (writtenTime > 0) then
               writtenTime <= writtenTime - 1;
            else
               PI_STATUS_IObusy <= '0';
            end if;
            
            if (bus_cart_read = '1') then
               bus_cart_read_latched <= '1';
            end if;            
            if (bus_cart_write = '1') then
               bus_cart_write_latched <= '1';
            end if;
            
            case (state) is
            
               when IDLE =>
               
                  flash_addrB  <= (others => '0');
                  
                  if (bus_cart_read_latched = '1') then
                     bus_cart_read_latched <= '0';
                     bus_cart_dataRead     <= std_logic_vector(bus_cart_addr(15 downto 0)) & std_logic_vector(bus_cart_addr(15 downto 0)); -- open bus is default
                     
                     if (bus_cart_addr(28 downto 0) < 16#08000000#) then -- DD
                        bus_cart_done <= '1';
                     elsif (bus_cart_addr(28 downto 0) < 16#10000000#) then -- SRAM+FLASH                          
                        if (SAVETYPE = "011" or SAVETYPE = "100") then
                           state         <= READSRAM;
                           sdram_request <= '1';
                           sdram_rnw     <= '1';
                           if (SAVETYPE = "011") then
                              sdram_address <= (11x"0" & bus_cart_addr(14 downto 2) & "00") + to_unsigned(16#400000#, 27);
                           else
                              sdram_address <= (9x"0" &  bus_cart_addr(16 downto 2) & "00") + to_unsigned(16#400000#, 27);
                           end if;
                        elsif (SAVETYPE = "101") then
                           bus_cart_done     <= '1';
                           if (bus_cart_addr(2) = '0') then
                              bus_cart_dataRead <= flash_statusword(63 downto 32);
                           else
                              bus_cart_dataRead <= flash_statusword(31 downto 0);
                           end if;
                        else 
                           bus_cart_done <= '1';
                        end if;
                     elsif (bus_cart_addr(28 downto 0) < 16#13FF0000# and cartAvailable = '1') then -- game rom
                        if (PI_STATUS_IObusy = '1') then
                           PI_STATUS_IObusy  <= '0';
                           bus_cart_dataRead <= writtenData;
                           bus_cart_done     <= '1';
                        else
                           state         <= READROM;
                           sdram_request <= '1';
                           sdram_rnw     <= '1';
                           if (bus_cart_addr(1) = '1') then
                              sdram_address <= (bus_cart_addr(25 downto 2) & "10") + to_unsigned(16#1000004#, 27);
                           else
                              sdram_address <= (bus_cart_addr(25 downto 2) & "00") + to_unsigned(16#1000000#, 27);
                           end if;
                        end if;
                     else
                        bus_cart_done <= '1';
                     end if;
                     
                  elsif (bus_cart_write_latched = '1') then
                  
                     bus_cart_write_latched <= '0';
                  
                     if (PI_STATUS_IObusy = '0') then 
                        PI_STATUS_IObusy  <= '1';
                        writtenData       <= bus_cart_dataWrite;
                        if (fastDecay = '1') then
                           writtenTime       <= 1;
                        else
                           writtenTime       <= 150;
                        end if;
                     end if;

                     if (bus_cart_addr(28 downto 0) < 16#08000000#) then -- DD
                        bus_cart_done <= '1';
                     elsif (bus_cart_addr(28 downto 0) < 16#10000000#) then -- SRAM+FLASH  
                        if (SAVETYPE = "011" or SAVETYPE = "100") then
                           change_sram      <= '1';
                           state            <= WRITESRAM;
                           sdram_request    <= '1';
                           sdram_rnw        <= '0';
                           sdram_dataWrite  <= byteswap32(bus_cart_dataWrite);
                           if (SAVETYPE = "011") then
                              sdram_address <= (11x"0" & bus_cart_addr(14 downto 2) & "00") + to_unsigned(16#400000#, 27);
                           else
                              sdram_address <= (9x"0" &  bus_cart_addr(16 downto 2) & "00") + to_unsigned(16#400000#, 27);
                           end if;
                        elsif (SAVETYPE = "101") then
                           bus_cart_done <= '1';
                           if (bus_cart_addr(26 downto 0) /= 0) then
                              case (bus_cart_dataWrite(31 downto 24)) is
                                 when x"4B" => -- set erase offset
                                    flash_offset <= unsigned(bus_cart_dataWrite(9 downto 0));
                                 
                                 when x"78" => -- erase
                                    flashState        <= FLASHERASE;
                                    flash_statusword  <= x"1111800800C2001D";
                                 
                                 when x"A5" => -- set write offset
                                    flash_offset <= unsigned(bus_cart_dataWrite(9 downto 0));
                                    flash_statusword  <= x"1111800400C2001D";
                                 
                                 when x"B4" => -- write
                                    flashState        <= FLASHWRITE;
                                 
                                 when x"D2" => -- execute
                                    if (flashState = FLASHERASE or flashState = FLASHWRITE) then
                                       bus_cart_done     <= '0';
                                       state             <= WRITEFLASH;
                                    end if;
                                 
                                 when x"E1" => -- status
                                    flashState        <= FLASHSTATUS;
                                    flash_statusword  <= x"1111800100C2001D";
                                 
                                 when x"F0" => -- read
                                    flashState        <= FLASHREAD;
                                    flash_statusword  <= x"11118004F000001D";
                                    
                                 when others => null;
                              end case;
                           end if;
                        else
                           bus_cart_done <= '1';
                        end if;
                     else
                        bus_cart_done <= '1';
                     end if;
                     
                  elsif (PI_STATUS_DMAbusy = '1') then
                     
                     if (PI_LEN > 0) then
                     
                        if (dmaIsWrite = '1') then
                        
                           state <= COPYDMABLOCK;
                           
                           blocklength_new := MaxBlockSize - to_integer(PI_DRAM_ADDR(2 downto 0));
                           if (distEndOfRow < blocklength_new) then
                              blocklength_new := distEndOfRow;
                           end if;
                           if (PI_LEN < blocklength_new) then
                              blocklength_new := to_integer(PI_LEN);
                           end if;
                           
                           maxram           <= blocklength_new - to_integer(PI_DRAM_ADDR(2 downto 0));
                           blocklength      <= blocklength_new;
                           copycnt          <= 0;
                           distEndOfRowSave <= distEndOfRow;
                           misAlignSave     <= to_integer(PI_DRAM_ADDR(2 downto 0));
                           rom_slow_sum     <= rom_slow_sum + 28;
                           
                        else 
                        
                           state <= DMA_READRDRAM;
                           
                           blocklength_new := 128;
                           if (PI_LEN < 128) then
                              blocklength_new := to_integer(PI_LEN);
                           end if;
                           count_new := PI_LEN - blocklength_new;
                           if (count_new(0) = '1') then 
                              count_new := count_new + 1;
                           end if;
                              
                           maxram       <= blocklength_new;
                           blocklength  <= blocklength_new;
                           PI_LEN       <= count_new;
                           copycnt      <= 0;
                           
                        end if;
                           
                     elsif (PIfifo_empty = '1' and (FASTROM = '1' or (rom_slow_cnt >= rom_slow_sum))) then
                        --if (rom_slow_cnt > (rom_slow_sum + 5)) then
                        --   error_PI           <= '1';
                        --end if;
                        PI_STATUS_irq     <= '1';
                        PI_STATUS_DMAbusy <= '0';
                     end if;
                     
                  end if;
            
               when READROM => 
                  if (sdram_done = '1') then
                     state             <= IDLE;
                     bus_cart_dataRead <= sdram_dataRead(7 downto 0) & sdram_dataRead(15 downto 8) & sdram_dataRead(23 downto 16) & sdram_dataRead(31 downto 24);
                     bus_cart_done     <= '1';
                  end if;
                  
               when READSRAM => 
                  if (sdram_done = '1') then
                     state             <= IDLE;
                     bus_cart_dataRead <= sdram_dataRead(7 downto 0) & sdram_dataRead(15 downto 8) & sdram_dataRead(23 downto 16) & sdram_dataRead(31 downto 24);
                     bus_cart_done     <= '1';
                  end if;               
                  
               when WRITESRAM => 
                  if (sdram_done = '1') then
                     state             <= IDLE;
                     bus_cart_done     <= '1';
                  end if;
                  
               when WRITEFLASH =>
                  state             <= WAITFLASH;
                  change_flash      <= '1';
                  flash_addrB       <= std_logic_vector(unsigned(flash_addrB) + 1);
                  sdram_request     <= '1';
                  sdram_rnw         <= '0';
                  sdram_writeMask   <= "1111";
                  sdram_address     <= (10x"0" & flash_offset & unsigned(flash_addrB) & "00") + to_unsigned(16#400000#, 27);
                  if (flashState = FLASHWRITE) then
                     sdram_dataWrite <= flash_DataOutB;
                  else
                     sdram_dataWrite <= (others => '1');
                  end if;

               when WAITFLASH =>
                  if (sdram_done = '1') then
                     if (flash_addrB = 5x"0") then
                        state           <= IDLE;
                        bus_cart_done   <= '1';
                     else
                        state           <= WRITEFLASH;
                     end if;
                  end if;
            
               when COPYDMABLOCK =>
                  if (copycnt < blocklength) then
                     state         <= DMA_READCART;
                     sdram_request <= '1';
                     sdram_rnw     <= '1';
                     
                     dma_isflashread <= '0';
                     
                     rom_slow_sum <= rom_slow_sum + to_integer(PI_BSD_PWD) + to_integer(PI_BSD_RLS) + 2;
                     
                     if (PI_CART_ADDR(28 downto 0) < 16#08000000#) then -- DD
                        report "DD DMA read not implemented" severity failure;
                        error_PI      <= '1';
                     elsif (PI_CART_ADDR(28 downto 0) < 16#10000000#) then -- SRAM+FLASH  
                        if (SAVETYPE = "011") then
                           sdram_address <= (11x"0" & PI_CART_ADDR(14 downto 1) & '0') + to_unsigned(16#400000#, 27);
                        else
                           sdram_address <= (9x"0" &  PI_CART_ADDR(16 downto 1) & '0') + to_unsigned(16#400000#, 27);
                        end if;
                        if (SAVETYPE = "101") then
                           dma_isflashread <= '1';
                        end if;  
                     elsif (PI_CART_ADDR(28 downto 0) < 16#13FF0000#) then -- game rom
                        sdram_address <= (PI_CART_ADDR(25 downto 1) & '0') + to_unsigned(16#1000000#, 27);
                     else
                        report "Openbus DMA read not implemented" severity failure;
                        error_PI      <= '1';
                     end if;
                  elsif (PIfifo_nearfull = '0') then
                     state        <= IDLE;
                     first128     <= '0';
                     PI_DRAM_ADDR <= PI_DRAM_ADDR + 7;
                     PI_DRAM_ADDR(2 downto 0) <= "000";
                     if (distEndOfRowSave < 8) then
                        MaxBlockSize <= 128 - misAlignSave;
                     else
                        MaxBlockSize <= 128;
                     end if;
                     if (blocklength > 8) then
                        PI_WR_LEN <= 7x"7F";
                     else
                        PI_WR_LEN <= to_unsigned(127 - misAlignSave, 7);
                     end if;
                  end if;
                  
               when DMA_READCART =>
                  if (sdram_done = '1') then
                  
                     state        <= COPYDMABLOCK;
                     PIfifo_Din(84 downto 64)   <= std_logic_vector(PI_DRAM_ADDR(23 downto 3));
                  
                     copycnt      <= copycnt + 2;
                     PI_CART_ADDR <= PI_CART_ADDR + 2;
                     if (PI_LEN > 2) then
                        PI_LEN    <= PI_LEN - 2;
                     else
                        PI_LEN    <= (others => '0');
                     end if;
                     
                     if (PI_DRAM_valid = '0' or ((PI_DRAM_ADDR(17 downto 0) and PI_DRAM_pagemask) /= (PI_DRAM_page and PI_DRAM_pagemask))) then
                        PI_DRAM_page  <= PI_DRAM_ADDR(17 downto 0);
                        rom_slow_sum  <= rom_slow_sum + to_integer(PI_BSD_LAT);
                        PI_DRAM_valid <= '1';
                     end if;
                     
                     writemask_new := "00";
                     if (copycnt < maxram) then
                        writemask_new(0) := '1';
                        writemask_new(1) := '1';
                     end if;
                     if (first128 = '1' and blocklength < 127 - misAlignSave) then
                        if (copycnt >= maxram - 1) then 
                           writemask_new(1) := '0';
                        end if;
                     end if;
                     
                     if (writemask_new(0) = '1') then
                        PIfifo_Wr   <= '1';
                     end if;
                     
                     if (writemask_new(1) = '1') then
                        PI_DRAM_ADDR <= PI_DRAM_ADDR + 2;
                     elsif (writemask_new(0) = '1') then
                        PI_DRAM_ADDR <= PI_DRAM_ADDR + 1;
                     end if;
                     
                     if (PI_DRAM_ADDR(0) = '1' and writemask_new /= "00") then
                        report "Unaligned PI DMA write" severity failure;  
                     end if;
                     
                     dma_readData := sdram_dataRead(15 downto 0);
                     
                     if (dma_isflashread = '1') then
                        if (flashState = FLASHSTATUS) then
                           case (PI_CART_ADDR(2 downto 1)) is
                              when "00" => dma_readData := byteswap16(flash_statusword(63 downto 48));
                              when "01" => dma_readData := byteswap16(flash_statusword(47 downto 32));
                              when "10" => dma_readData := byteswap16(flash_statusword(31 downto 16));
                              when "11" => dma_readData := byteswap16(flash_statusword(15 downto 0));
                              when others => null;
                           end case;
                        elsif (flashState /= FLASHREAD) then
                           dma_readData := (others => '0');
                        end if;
                     end if;
                     
                     case (PI_DRAM_ADDR(2 downto 1)) is
                        when "00" => PIfifo_Din(15 downto  0) <= dma_readData; PIfifo_Din(92 downto 85) <= "000000" & writemask_new;
                        when "01" => PIfifo_Din(31 downto 16) <= dma_readData; PIfifo_Din(92 downto 85) <= "0000" & writemask_new & "00";
                        when "10" => PIfifo_Din(47 downto 32) <= dma_readData; PIfifo_Din(92 downto 85) <= "00" & writemask_new & "0000";
                        when "11" => PIfifo_Din(63 downto 48) <= dma_readData; PIfifo_Din(92 downto 85) <= writemask_new & "000000";
                        when others => null;
                     end case;
                     
                  end if;
                  
               when DMA_READRDRAM =>
                  if (copycnt < blocklength) then
                     state            <= DMA_WAITRDRAM;
                     rdram_request   <= '1';
                     rdram_rnw       <= '1';
                     rdram_address   <= "0000" & PI_DRAM_ADDR(23 downto 3) & "000";
                  else
                     state <= IDLE;
                     PI_DRAM_ADDR <= PI_DRAM_ADDR + 7;
                     PI_DRAM_ADDR(2 downto 0) <= "000";
                     PI_CART_ADDR <= PI_CART_ADDR + 1;
                     PI_CART_ADDR(0) <= '0';
                  end if;

               when DMA_WAITRDRAM =>
                  if (rdram_done = '1') then
                  
                     sdram_dataWrite <= rdram_dataRead(15 downto  0) & rdram_dataRead(15 downto  0);
                     case (PI_DRAM_ADDR(2 downto 1)) is
                        when "00" => sdram_dataWrite <= rdram_dataRead(15 downto  0) & rdram_dataRead(15 downto  0); flash_DataInA <= rdram_dataRead(15 downto  0);
                        when "01" => sdram_dataWrite <= rdram_dataRead(31 downto 16) & rdram_dataRead(31 downto 16); flash_DataInA <= rdram_dataRead(31 downto 16);
                        when "10" => sdram_dataWrite <= rdram_dataRead(47 downto 32) & rdram_dataRead(47 downto 32); flash_DataInA <= rdram_dataRead(47 downto 32);
                        when "11" => sdram_dataWrite <= rdram_dataRead(63 downto 48) & rdram_dataRead(63 downto 48); flash_DataInA <= rdram_dataRead(63 downto 48);
                        when others => null;
                     end case;
                     
                     if (PI_CART_ADDR(1) = '1') then
                        sdram_writeMask  <= "1100";
                     else
                        sdram_writeMask  <= "0011";
                     end if;
                     
                     if (SAVETYPE = "011") then
                        sdram_address <= (11x"0" & PI_CART_ADDR(14 downto 2) & "00") + to_unsigned(16#400000#, 27);
                     else
                        sdram_address <= (9x"0" &  PI_CART_ADDR(16 downto 2) & "00") + to_unsigned(16#400000#, 27);
                     end if;
                     
                     flash_addrA <= std_logic_vector(PI_CART_ADDR(6 downto 1));
                     
                     state   <= DMA_READRDRAM;
                     copycnt <= copycnt + 2;
                     PI_DRAM_ADDR <= PI_DRAM_ADDR + 2;
                     PI_CART_ADDR <= PI_CART_ADDR + 2;
                        
                     if (PI_CART_ADDR(28 downto 0) < 16#08000000#) then -- DD
                        report "DD DMA write not implemented" severity failure;
                        error_PI      <= '1';
                     elsif (PI_CART_ADDR(28 downto 0) < 16#10000000#) then -- SRAM+FLASH  
                        if (SAVETYPE = "011" or SAVETYPE = "100") then
                           change_sram   <= '1';
                           state         <= DMA_WAITSDRAM;
                           sdram_request <= '1';
                           sdram_rnw     <= '0';
                        elsif (SAVETYPE = "101") then
                           flash_wrenA <= '1';
                        end if;
                     elsif (PI_CART_ADDR(28 downto 0) < 16#13FF0000#) then -- game rom
                        report "Cart DMA write not implemented" severity failure;
                        error_PI      <= '1';
                     else
                        report "Openbus DMA write not implemented" severity failure;
                        error_PI      <= '1';
                     end if;
                     
                     
                  end if;
                           
               when DMA_WAITSDRAM =>
                  if (sdram_done = '1') then
                     state <= DMA_READRDRAM;
                  end if;
                  
                  
            end case;

         end if;
      end if;
   end process;
   
   iflashpage: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 6,
      data_width_a  => 16,
      addr_width_b  => 5,
      data_width_b  => 32
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => flash_addrA,
      data_a      => flash_DataInA,
      wren_a      => flash_wrenA,
      q_a         => open,
      
      clock_b     => clk1x,
      address_b   => flash_addrB,
      data_b      => 32x"0",
      wren_b      => '0',
      q_b         => flash_DataOutB
   );
   
--##############################################################
--############################### savestates
--##############################################################

   SS_idle <= '1';

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 5 loop
               ss_in(i) <= (others => '0');
            end loop;
            
         elsif (SS_wren = '1') then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         if (SS_rden = '1') then
            SS_DataRead <= ss_out(to_integer(SS_Adr));
         end if;
      
      end if;
   end process;
   
      
--##############################################################
--############################### export
--##############################################################
   
   -- synthesis translate_off
   goutput : if 1 = 1 generate
      signal out_count        : unsigned(31 downto 0) := (others => '0');
      signal exportindex      : unsigned(15 downto 0);
   begin
   
      process
         file outfile           : text;
         variable f_status      : FILE_OPEN_STATUS;
         variable line_out      : line;
         variable stringbuffer  : string(1 to 31);
         
         variable exportaddress : unsigned(31 downto 0);
         variable exportdata    : unsigned(63 downto 0);
         variable out_count_new : unsigned(31 downto 0);
      begin
   
         file_open(f_status, outfile, "R:\\PI_n64_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\PI_n64_sim.txt", append_mode);
         
         while (true) loop
         
            if (reset = '1') then
               file_close(outfile);
               file_open(f_status, outfile, "R:\\PI_n64_sim.txt", write_mode);
               file_close(outfile);
               file_open(f_status, outfile, "R:\\PI_n64_sim.txt", append_mode);
               out_count <= (others => '0');
               exportindex <= (others => '0');
            end if;
            
            wait until rising_edge(clk1x);

            --if (rdram_request = '1' and rdram_rnw = '0') then
            --   
            --   exportaddress := x"0" & rdram_address;
            --   exportdata    := unsigned(rdram_dataWrite);
            --   
            --   out_count_new := out_count;
            --   for i in 0 to 7 loop
            --      if (rdram_writeMask(i) = '1') then
            --         write(line_out, to_hstring(exportindex));
            --         write(line_out, string'(" "));                    
            --         write(line_out, to_hstring(exportaddress));
            --         write(line_out, string'(" "));
            --         write(line_out, to_hstring(exportdata(7 downto 0)));
            --         writeline(outfile, line_out);
            --         out_count_new := out_count_new + 1;
            --      end if;
            --      
            --      exportdata := x"00" & exportdata(63 downto 8);
            --      exportaddress := exportaddress + 1;
            --   end loop;
            --   out_count <= out_count_new;
            --   
            --end if;
            
            if (state = IDLE and dmaIsWrite = '1' and PI_STATUS_DMAbusy = '1' and PI_LEN = 0) then
               file_close(outfile);
               file_open(f_status, outfile, "R:\\PI_n64_sim.txt", append_mode);
               exportindex <= exportindex + 1;
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;

   -- synthesis translate_on  

end architecture;





