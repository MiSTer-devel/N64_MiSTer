library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;    

entity VI_sqrt is
   port 
   (
      clk               : in  std_logic;
      start             : in  std_logic;
      val_in            : in  unsigned(13 downto 0);
      val_out           : out unsigned(7 downto 0) := (others => '0')
   );
end entity;

architecture arch of VI_sqrt is
   
   signal stage_result  : unsigned(6 downto 0) := (others => '0');
   signal stage1_result : unsigned(6 downto 0) := (others => '0');
   
   signal stage1_op     : unsigned(13 downto 0) := (others => '0');
   signal stage2_op     : unsigned(13 downto 0) := (others => '0');
   signal stage3_op     : unsigned(13 downto 0) := (others => '0');
   signal stage4_op     : unsigned(13 downto 0) := (others => '0');
   signal stage5_op     : unsigned(13 downto 0) := (others => '0');
   signal stage6_op     : unsigned(13 downto 0) := (others => '0');
   
   constant stage1_one  : unsigned(13 downto 0) := "01000000000000";
   constant stage2_one  : unsigned(12 downto 0) := "0010000000000";
   constant stage3_one  : unsigned(11 downto 0) := "000100000000";
   constant stage4_one  : unsigned(10 downto 0) := "00001000000";
   constant stage5_one  : unsigned( 9 downto 0) := "0000010000";
   constant stage6_one  : unsigned( 8 downto 0) := "000000100";
   constant stage7_one  : unsigned( 7 downto 0) := "00000001";
   
   signal stage1_res    : unsigned(12 downto 0);
   signal stage2_res    : unsigned(11 downto 0);
   signal stage3_res    : unsigned(10 downto 0);
   signal stage4_res    : unsigned( 9 downto 0);
   signal stage5_res    : unsigned( 8 downto 0);
   signal stage6_res    : unsigned( 7 downto 0);
   
begin 

   val_out <= stage1_result & '0';
   
   -- stage 1 - 14 bits -> 12 bits
   process (all)
      variable var_or : unsigned(13 downto 0); 
   begin
      var_or     := stage1_one;
      if (val_in >= var_or) then
         stage1_op       <= val_in - var_or;
         stage_result(6) <= '1';
      else
         stage1_op       <= val_in;
         stage_result(6) <= '0';
      end if;
   end process;

   -- stage 2 - 12 bits -> 10 bits
   stage1_res <= stage_result(6) & 12x"0";
   process (all)
      variable var_or : unsigned(12 downto 0); 
   begin
      var_or := stage1_res or stage2_one;
      if (stage1_op >= var_or) then
         stage2_op       <= stage1_op - var_or;
         stage_result(5) <= '1';
      else
         stage2_op       <= stage1_op;
         stage_result(5) <= '0';
      end if;
   end process;

   -- stage 3 - 10 bits -> 8 bits
   --stage2_res <= stage_result(6 downto 5) & 10x"0";
   --process (all)
   --   variable var_or : unsigned(11 downto 0); 
   --begin
   --   var_or := stage2_res or stage3_one;
   --   if (stage2_op >= var_or) then
   --      stage3_op       <= stage2_op - var_or;
   --      stage_result(4) <= '1';
   --   else
   --      stage3_op       <= stage2_op;
   --      stage_result(4) <= '0';
   --   end if;
   --end process;
   
   -- stage 3 - 10 bits -> 8 bits  -> do clocked here to split up logic to be done in 1 clock cycle
   stage2_res <= stage_result(6 downto 5) & 10x"0";
   process (clk)
      variable var_or : unsigned(11 downto 0); 
   begin
      if rising_edge(clk) then
         var_or := stage2_res or stage3_one;
         if (stage2_op >= var_or) then
            stage3_op       <= stage2_op - var_or;
            stage1_result(4) <= '1';
         else
            stage3_op       <= stage2_op;
            stage1_result(4) <= '0';
         end if;
         stage1_result(6 downto 5) <= stage_result(6 downto 5);    
      end if;
   end process;
   
   -- stage 4 - 8 bits -> 6 bits
   stage3_res <= stage1_result(6 downto 4) & 8x"0";
   process (all)
      variable var_or : unsigned(10 downto 0); 
   begin
      var_or := stage3_res or stage4_one;
      if (stage3_op >= var_or) then
         stage4_op        <= stage3_op - var_or;
         stage1_result(3) <= '1';
      else
         stage4_op        <= stage3_op;
         stage1_result(3) <= '0';
      end if;
   end process;
   
   -- stage 5 - 6 bits -> 4 bits
   stage4_res <= stage1_result(6 downto 3) & 6x"0";
   process (all)
      variable var_or : unsigned(9 downto 0); 
   begin
      var_or := stage4_res or stage5_one;
      if (stage4_op >= var_or) then
         stage5_op        <= stage4_op - var_or;
         stage1_result(2) <= '1';
      else
         stage5_op        <= stage4_op;
         stage1_result(2) <= '0';
      end if;
   end process;
   
   -- stage 6 - 4 bits -> 2 bits
   stage5_res <= stage1_result(6 downto 2) & 4x"0";
   process (all)
      variable var_or : unsigned(8 downto 0); 
   begin
      var_or := stage5_res or stage6_one;
      if (stage5_op >= var_or) then
         stage6_op        <= stage5_op - var_or;
         stage1_result(1) <= '1';
      else
         stage6_op        <= stage5_op;
         stage1_result(1) <= '0';
      end if;
   end process;
   
   -- stage 7 - 2 bits -> 0 bits
   stage6_res <= stage1_result(6 downto 1) & 2x"0";
   process (all)
      variable var_or : unsigned(7 downto 0); 
   begin
      var_or := stage6_res or stage7_one;
      if (stage6_op >= var_or) then
         stage1_result(0) <= '1';
      else
         stage1_result(0) <= '0';
      end if;
   end process;

end architecture;
