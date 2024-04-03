library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity RDRAMRegs is
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

architecture arch of RDRAMRegs is

   signal addr      : std_logic_vector(5 downto 0);
   signal wren_a    : std_logic;
   signal q_b       : std_logic_vector(31 downto 0);
   
   signal read_next : std_logic := '0';
   signal read_ram  : std_logic := '0';
   signal read_xor  : std_logic := '0';

begin 

   addr   <= std_logic_vector(bus_addr(14 downto 13)) & std_logic_vector(bus_addr(5 downto 2));

   wren_a <= '1' when (bus_write = '1' and bus_addr(9 downto 0) <= 16#24#) else '0';

   iREGRAM: entity mem.dpram
   generic map 
   ( 
      addr_width  => 6,
      data_width  => 32
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => addr,
      data_a      => bus_dataWrite,
      wren_a      => wren_a,
      
      clock_b     => clk1x,
      address_b   => addr,
      data_b      => 32x"0",
      wren_b      => '0',
      q_b         => q_b
   );  


   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         read_next    <= '0';
      
         if (reset = '1') then
            
            bus_done     <= '0';
            
         elsif (ce = '1') then
         
            bus_done     <= '0';
            bus_dataRead <= (others => '0');

            -- bus read
            if (bus_read = '1') then
               read_next <= '1';
               read_ram  <= '0';
               read_xor  <= '0';
               if (bus_addr(9 downto 0) <= 16#24#) then
                  read_ram <= '1';
               end if;
               if (bus_addr(9 downto 0) = 16#C#) then
                  read_xor <= '1';
               end if;
            end if;
            
            if (read_next = '1') then
               bus_done <= '1';
               if (read_xor = '1') then
                  bus_dataRead <= q_b xor x"C0C0C0C0";
               elsif (read_ram = '1') then
                  bus_dataRead <= q_b;
               end if;
            end if;
            
            -- bus write
            if (bus_write = '1') then
               bus_done <= '1';
            end if;

         end if;
      end if;
   end process;

end architecture;





