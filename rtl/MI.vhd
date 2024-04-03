library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity MI is
   port 
   (
      clk1x            : in  std_logic;
      ce               : in  std_logic;
      reset            : in  std_logic;
      
      irq_in           : in  std_logic_vector(5 downto 0);
      irq_out          : out std_logic := '0';
      
      bus_addr         : in  unsigned(19 downto 0); 
      bus_dataWrite    : in  std_logic_vector(31 downto 0);
      bus_read         : in  std_logic;
      bus_write        : in  std_logic;
      bus_dataRead     : out std_logic_vector(31 downto 0) := (others => '0');
      bus_done         : out std_logic := '0';
      
      SS_reset         : in  std_logic;
      SS_DataWrite     : in  std_logic_vector(63 downto 0);
      SS_wren          : in  std_logic;
      SS_rden          : in  std_logic;
      SS_DataRead      : out std_logic_vector(63 downto 0);
      SS_idle          : out std_logic
   );
end entity;

architecture arch of MI is

   signal MI_MODE_initLength   : std_logic_vector(6 downto 0); -- 0x04300000 
   signal MI_MODE_initMode     : std_logic;
   signal MI_MODE_ebusTestMode : std_logic;
   signal MI_MODE_RDRAMreqMode : std_logic;
   signal MI_INTR_DP           : std_logic; -- special handling of DP irq, because it is cleared here in MI
   signal MI_INTR_MASK         : std_logic_vector(5 downto 0); -- 0x0430000C
   
   -- savestates
   signal ss_in  : std_logic_vector(63 downto 0) := (others => '0');  
   signal ss_out : std_logic_vector(63 downto 0) := (others => '0');    

begin 

   irq_out <= '1' when ((irq_in and MI_INTR_MASK) /= "000000") else 
              '1' when (MI_INTR_DP = '1' and MI_INTR_MASK(5) = '1') else
              '0';

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
            
            bus_done             <= '0';

            MI_MODE_initLength   <= ss_in(6 downto 0);
            MI_MODE_initMode     <= ss_in(7);
            MI_MODE_ebusTestMode <= ss_in(8);
            MI_MODE_RDRAMreqMode <= ss_in(9);
            MI_INTR_DP           <= ss_in(15);
            MI_INTR_MASK         <= ss_in(21 downto 16);
            
         elsif (ce = '1') then
         
            bus_done     <= '0';
            bus_dataRead <= (others => '0');

            -- bus read
            if (bus_read = '1') then
               bus_done <= '1';
               case (bus_addr(19 downto 2) & "00") is   
                  when x"00000" => 
                     bus_dataRead(6 downto 0) <= MI_MODE_initLength;   
                     bus_dataRead(7)          <= MI_MODE_initMode;   
                     bus_dataRead(8)          <= MI_MODE_ebusTestMode;   
                     bus_dataRead(9)          <= MI_MODE_RDRAMreqMode;   
                  
                  when x"00004" => bus_dataRead <= x"02020102"; -- 0x04300004 (R): [7:0] io [15:8] rac [23:16] rdp [31:24] rsp       
                  when x"00008" => -- 0x04300008 (R): [0] SP intr [1] SI intr [2] AI intr [3] VI intr [4] PI intr [5] DP intr
                     bus_dataRead(4 downto 0) <= irq_in(4 downto 0);
                     bus_dataRead(5)          <= irq_in(5) or MI_INTR_DP;
                     
                  when x"0000C" => bus_dataRead(5 downto 0) <= MI_INTR_MASK;  
                  when others   => null; 
               end case;
            end if;
            
            -- bus write
            if (bus_write = '1') then
               bus_done <= '1';
               
               case (bus_addr(19 downto 2) & "00") is   
                  when x"00000" =>
                     MI_MODE_initLength   <= bus_dataWrite(6 downto 0); 
                     if (bus_dataWrite( 7) = '1') then MI_MODE_initMode <= '0'; end if;
                     if (bus_dataWrite( 8) = '1') then MI_MODE_initMode <= '1'; end if;
                     if (bus_dataWrite( 9) = '1') then MI_MODE_ebusTestMode <= '0'; end if;
                     if (bus_dataWrite(10) = '1') then MI_MODE_ebusTestMode <= '1'; end if;
                     if (bus_dataWrite(11) = '1') then MI_INTR_DP <= '0'; end if;
                     if (bus_dataWrite(12) = '1') then MI_MODE_RDRAMreqMode <= '0'; end if;
                     if (bus_dataWrite(13) = '1') then MI_MODE_RDRAMreqMode <= '1'; end if;
                  
                  when x"0000C" => 
                     if (bus_dataWrite( 0) = '1') then MI_INTR_MASK(0) <= '0'; end if;
                     if (bus_dataWrite( 1) = '1') then MI_INTR_MASK(0) <= '1'; end if;
                     if (bus_dataWrite( 2) = '1') then MI_INTR_MASK(1) <= '0'; end if;
                     if (bus_dataWrite( 3) = '1') then MI_INTR_MASK(1) <= '1'; end if;
                     if (bus_dataWrite( 4) = '1') then MI_INTR_MASK(2) <= '0'; end if;
                     if (bus_dataWrite( 5) = '1') then MI_INTR_MASK(2) <= '1'; end if;
                     if (bus_dataWrite( 6) = '1') then MI_INTR_MASK(3) <= '0'; end if;
                     if (bus_dataWrite( 7) = '1') then MI_INTR_MASK(3) <= '1'; end if;
                     if (bus_dataWrite( 8) = '1') then MI_INTR_MASK(4) <= '0'; end if;
                     if (bus_dataWrite( 9) = '1') then MI_INTR_MASK(4) <= '1'; end if;
                     if (bus_dataWrite(10) = '1') then MI_INTR_MASK(5) <= '0'; end if;
                     if (bus_dataWrite(11) = '1') then MI_INTR_MASK(5) <= '1'; end if;
                  
                  when others   => null;                  
               end case;
               
            end if;
            
            if (irq_in(5) = '1') then
               MI_INTR_DP <= '1';
            end if;

         end if;
      end if;
   end process;
   
   --##############################################################
--############################### savestates
--##############################################################

   SS_idle <= '1';

   ss_out <= (others => '0');

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
            ss_in <= (others => '0');
         elsif (SS_wren = '1') then
            ss_in <= SS_DataWrite;
         end if;
         
         if (SS_rden = '1') then
            SS_DataRead <= ss_out;
         end if;
      
      end if;
   end process;

end architecture;





