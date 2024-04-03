library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity pif_cic6105 is
   port 
   (
      clk1x                : in  std_logic;
      cic_input_first      : in  std_logic;
      cic_input_ena        : in  std_logic;
      cic_input_data       : in  std_logic_vector(3 downto 0);
      cic_output_done      : out std_logic := '0';
      cic_output_data      : out std_logic_vector(3 downto 0) := (others => '0')  
   );
end entity;

architecture arch of pif_cic6105 is

   type t_cic_lut is array(0 to 31) of unsigned(3 downto 0);
   constant cic_lut : t_cic_lut := 
   (
      x"4", x"7", x"A", x"7", x"E", x"5", x"E", x"1",
      x"C", x"F", x"8", x"F", x"6", x"3", x"6", x"9",
   	x"4", x"1", x"A", x"7", x"E", x"5", x"E", x"1",
      x"C", x"9", x"8", x"5", x"6", x"3", x"C", x"9"
   );

   type tState is
   (
      IDLE,
      NEXT_KEY_MOD
   );
   signal state : tState := IDLE;
   
   signal cic_key    : unsigned(3 downto 0) := (others => '0');
   signal cic_mod    : std_logic := '0';
   
   signal cic_result : unsigned(3 downto 0) := (others => '0');
   signal cic_mag    : unsigned(2 downto 0) := (others => '0');
   
begin 

   cic_output_data <= std_logic_vector(cic_result);

   process (clk1x)
      variable cic_calc : unsigned(5 downto 0);
   begin
      if rising_edge(clk1x) then
      
         cic_output_done <= '0';
      
         if (cic_input_first = '1') then
            cic_key <= x"B";
            cic_mod <= '0';
         end if;
         
         cic_calc   := cic_key + unsigned(cic_input_data) + (unsigned(cic_input_data) & "00");
      
         case (state) is
            
            when IDLE =>
               if (cic_input_ena = '1') then
                  state      <= NEXT_KEY_MOD;
                  cic_result <= cic_calc(3 downto 0);
                  if (cic_calc(3) = '1') then
                     cic_mag <= not cic_calc(2 downto 0);
                  else
                     cic_mag <= cic_calc(2 downto 0);
                  end if;
               end if;
            
            when NEXT_KEY_MOD =>
               state           <= IDLE;
               cic_output_done <= '1';
               cic_key         <= cic_lut(to_integer(cic_mod & cic_result));
               if ((cic_mag mod 3) = 1) then
                  cic_mod <= cic_result(3);
               else
                  cic_mod <= not cic_result(3);
               end if;
               if (cic_mod = '1' and (cic_result = x"1" or cic_result = x"9")) then
                  cic_mod <= '1';
               end if;
               if (cic_mod = '1' and (cic_result = x"B" or cic_result = x"E")) then
                  cic_mod <= '0';
               end if;
         
         end case;
         
         
      end if;
   end process;

end architecture;





