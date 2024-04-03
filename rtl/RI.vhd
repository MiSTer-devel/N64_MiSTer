library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity RI is
   port 
   (
      clk1x            : in  std_logic;
      ce               : in  std_logic;
      reset            : in  std_logic;
      
      bus_addr         : in  unsigned(19 downto 0); 
      bus_dataWrite    : in  std_logic_vector(31 downto 0);
      bus_read         : in  std_logic;
      bus_write        : in  std_logic;
      bus_dataRead     : out std_logic_vector(31 downto 0) := (others => '0');
      bus_done         : out std_logic := '0'
   );
end entity;

architecture arch of RI is

   signal RI_MODE          : unsigned(31 downto 0); -- 0x04700000 (RW): [1:0] operating mode [2] stop T active [3] stop R active
   signal RI_CONFIG        : unsigned(31 downto 0); -- 0x04700004 (RW): [5:0] current control input [6] current control enable
   signal RI_CURRENT_LOAD  : unsigned(31 downto 0); -- 0x04700008 (W): [] any write updates current control register
   signal RI_SELECT        : unsigned(31 downto 0); -- 0x0470000C (RW): [2:0] receive select [2:0] transmit select
   signal RI_REFRESH       : unsigned(31 downto 0); -- 0x04700010 (RW): [7:0] clean refresh delay [15:8] dirty refresh delay [16] refresh bank [17] refresh enable [18] refresh optimize
   signal RI_LATENCY       : unsigned(31 downto 0); -- 0x04700014 (RW): [3:0] DMA latency/overlap
   signal RI_RERROR        : unsigned(31 downto 0); -- 0x04700018 (R): [0] nack error [1] ack error
   signal RI_WERROR        : unsigned(31 downto 0); -- 0x0470001C (W): [] any write clears all error bits

begin 

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
            
            bus_done             <= '0';
            
            RI_MODE              <= (others => '0');
            RI_CONFIG            <= (others => '0');
            RI_CURRENT_LOAD      <= (others => '0');
            RI_SELECT            <= x"00000014";
            RI_REFRESH           <= x"00063634";
            RI_LATENCY           <= (others => '0');
            RI_RERROR            <= (others => '0');
            RI_WERROR            <= (others => '0');
            
         elsif (ce = '1') then
         
            bus_done     <= '0';
            bus_dataRead <= (others => '0');

            -- bus read
            if (bus_read = '1') then
               bus_done <= '1';
               case (bus_addr(19 downto 2) & "00") is   
                  when x"00000" => bus_dataRead <= std_logic_vector(RI_MODE        );                  
                  when x"00004" => bus_dataRead <= std_logic_vector(RI_CONFIG      );                  
                  when x"00008" => bus_dataRead <= std_logic_vector(RI_CURRENT_LOAD);                  
                  when x"0000C" => bus_dataRead <= std_logic_vector(RI_SELECT      );                  
                  when x"00010" => bus_dataRead <= std_logic_vector(RI_REFRESH     );                  
                  when x"00014" => bus_dataRead <= std_logic_vector(RI_LATENCY     );                  
                  when x"00018" => bus_dataRead <= std_logic_vector(RI_RERROR      );                  
                  when x"0001c" => bus_dataRead <= std_logic_vector(RI_WERROR      );      
                  when others   => null;                   
               end case;
            end if;
            
            -- bus write
            if (bus_write = '1') then
               bus_done <= '1';
               
               case (bus_addr(19 downto 2) & "00") is
                  when x"00000" => RI_MODE         <= unsigned(bus_dataWrite);
                  when x"00004" => RI_CONFIG       <= unsigned(bus_dataWrite);
                  when x"00008" => RI_CURRENT_LOAD <= unsigned(bus_dataWrite);
                  when x"0000C" => RI_SELECT       <= unsigned(bus_dataWrite);
                  when x"00010" => RI_REFRESH      <= unsigned(bus_dataWrite);
                  when x"00014" => RI_LATENCY      <= unsigned(bus_dataWrite);
                  when x"00018" => RI_RERROR       <= unsigned(bus_dataWrite);
                  when x"0001c" => RI_WERROR       <= unsigned(bus_dataWrite);
                  when others   => null;                  
               end case;
               
            end if;

         end if;
      end if;
   end process;

end architecture;





