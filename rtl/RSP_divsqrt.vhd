library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   

library mem;
use work.pFunctions.all;
use work.pRSP.all;

entity RSP_divsqrt is
   port 
   (
      clk1x                 : in  std_logic;
      
      CalcNew               : in  std_logic;
      CalcType              : in  VECTOR_CALCTYPE;
      CalcValue             : in  std_logic_vector(15 downto 0);
      
      writebackEna          : out std_logic := '0';
      writebackData         : out std_logic_vector(15 downto 0) := (others => '0')
   );
end entity;

architecture arch of RSP_divsqrt is
         
   -- stage 3   
   signal inputData     : signed(31 downto 0);
   signal inputXOR      : signed(31 downto 0);
   signal inputAdjust   : signed(31 downto 0);
   signal clz_result    : unsigned(4 downto 0);
   signal shifted       : signed(31 downto 0);
   signal index_rom     : unsigned(9 downto 0);

   -- regs
   signal DivDP         : std_logic := '0';
   signal DivIn         : signed(15 downto 0) := (others => '0');
   signal DivOut        : signed(15 downto 0) := (others => '0');
   signal mask          : std_logic := '0';
   
   signal outshift      : integer range 0 to 31 := 0;
   
   type toutputSelect is
   (
      OUTPUT_DIVZERO,
      OUTPUT_DIVMIN,
      OUTPUT_CALC,
      OUTPUT_HI
   );
   signal outputSelect : toutputSelect;
   
   -- stage 4 
   signal div_romdata   : signed(15 downto 0);
   signal div_expand    : signed(31 downto 0); 
   signal div_shifted   : signed(31 downto 0); 
   signal div_masked    : signed(31 downto 0); 
   
   
  
begin 

 
--##############################################################
--############################### stage 3
--##############################################################
   
   inputData <= resize(signed(CalcValue), 32) when (CalcType = VCALC_VRCP or CalcType = VCALC_VSRQ or DivDP = '0') else
                DivIn & signed(CalcValue);
 
   inputXOR <= inputData xor (0 to 31 => inputData(31));
 
   inputAdjust <= inputXOR + 1 when (inputData > -32768 and inputData(31) = '1') else
                  inputXOR;
   
   process (all)
   begin
   
      clz_result <= (others => '0');
      for i in 0 to 31 loop
         if (inputAdjust(i) = '1') then
            clz_result <= to_unsigned(31 - i, 5);
         end if;
      end loop;
      
   end process;
   
   shifted <= inputAdjust sll to_integer(clz_result);
   
   index_rom <= '1' & (not clz_result(0)) & unsigned(shifted(30 downto 23)) when (CalcType = VCALC_VSRQ or CalcType = VCALC_VSRQL) else
                '0' & unsigned(shifted(30 downto 22));
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         writebackEna   <= '0';
         mask           <= inputData(31);
         
         if (CalcType = VCALC_VRCP or CalcType = VCALC_VRCPL) then
            outshift    <= 31 - to_integer(clz_result);
         else
            outshift    <= (31 - to_integer(clz_result)) / 2;
         end if;
      
         if (CalcNew = '1') then
         
            case (CalcType) is
         
               when VCALC_VRCP | VCALC_VRCPL | VCALC_VSRQ | VCALC_VSRQL =>
                  writebackEna     <= '1';
                  DivDP            <= '0';
                  if (inputAdjust = 0) then
                     outputSelect <= OUTPUT_DIVZERO;
                  elsif (inputData = -32768) then
                     outputSelect <= OUTPUT_DIVMIN;
                  else
                     outputSelect <= OUTPUT_CALC;
                  end if;

               when VCALC_VRCPH | VCALC_VRSQH =>
                  writebackEna     <= '1';
                  DivDP            <= '1';
                  DivIn            <= signed(CalcValue);
                  outputSelect     <= OUTPUT_HI;

               when others => null;
         
            end case;
         
         end if;
         
      end if; -- clock
   end process;
   
   iRSP_divtable : entity work.RSP_divtable
   port map
   (
      clk1x     => clk1x,
      address   => index_rom,
      data      => div_romdata
   );

--##############################################################
--############################### stage 4
--##############################################################
   
   div_expand  <= "01" & div_romdata & 14x"0";
   div_shifted <= shift_right(div_expand, outshift);
   div_masked  <= div_shifted xor (0 to 31 => mask);
   
   process (all)
   begin
      
      case (outputSelect) is
      
         when OUTPUT_DIVZERO => 
            writebackData <= x"FFFF";
         
         when OUTPUT_DIVMIN  => writebackData <= (others => '0');
            writebackData <= x"0000";
         
         when OUTPUT_CALC =>
            writebackData <= std_logic_vector(div_masked(15 downto 0));
            
         when OUTPUT_HI =>
            writebackData <= std_logic_vector(DivOut);
            
      end case; 
      
   end process;
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (writebackEna = '1') then
      
            case (outputSelect) is
            
               when OUTPUT_DIVZERO => 
                  DivOut        <= x"7FFF";
               
               when OUTPUT_DIVMIN  =>
                  DivOut        <= x"FFFF";
               
               when OUTPUT_CALC =>
                  DivOut <= div_masked(31 downto 16);
   
               when others => null;
   
            end case; 
            
         end if;
         
      end if; -- clock
   end process;
   
   
   

end architecture;





