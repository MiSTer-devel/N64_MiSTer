library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pVI.all;

entity VI_filter_pen is
   port 
   (
      proc_pixels_AA   : in  tfetcharray_AA := (others => (others => (others => '0')));
      mid_color        : in  tcolor := (others => (others => '0'));
      penmin           : out tcolor := (others => (others => '0'));
      penmax           : out tcolor := (others => (others => '0'))
   );
end entity;

architecture arch of VI_filter_pen is

   type t_AAcolor is array(0 to 2) of tcolor;
   signal AA_sort_in1      : t_AAcolor := (others => (others => (others => '0')));
   signal AA_sort_in2      : t_AAcolor := (others => (others => (others => '0')));   
   signal AA_sort_out1     : t_AAcolor := (others => (others => (others => '0')));
   signal AA_sort_out2     : t_AAcolor := (others => (others => (others => '0')));
   
   signal penmin_sort      : tcolor;
   signal penmax_sort      : tcolor;
   
begin 

   -- penmin is searched as follows:
   -- 6 element array is split in 2x3 elements
   -- each 3 element array is then sorted using a decision tree
   -- compare lowest element of both arrays : smaller one is out
   -- compare against second element of the array when the smallest element was
   -- either this or the first element of the other array must be penmin
   -- same sorted arrays can be used to find penmax by comparing the largest elements in the same manner

   process(all)
   begin
      
      for i in 0 to 2 loop
         if (proc_pixels_AA(i).c = 7) then
            AA_sort_in1(i)(0) <= proc_pixels_AA(i).r;
            AA_sort_in1(i)(1) <= proc_pixels_AA(i).g;
            AA_sort_in1(i)(2) <= proc_pixels_AA(i).b;
         else
            AA_sort_in1(i)(0) <= mid_color(0);
            AA_sort_in1(i)(1) <= mid_color(1);
            AA_sort_in1(i)(2) <= mid_color(2);
         end if;
      end loop;
      
      for i in 0 to 2 loop
         if (proc_pixels_AA(i + 3).c = 7) then
            AA_sort_in2(i)(0) <= proc_pixels_AA(i + 3).r;
            AA_sort_in2(i)(1) <= proc_pixels_AA(i + 3).g;
            AA_sort_in2(i)(2) <= proc_pixels_AA(i + 3).b;
         else
            AA_sort_in2(i)(0) <= mid_color(0);
            AA_sort_in2(i)(1) <= mid_color(1);
            AA_sort_in2(i)(2) <= mid_color(2);
         end if;
      end loop;
   
   end process;
   
   process(all)
   begin
      for i in 0 to 2 loop
      
         AA_sort_out1(0)(i) <= AA_sort_in1(0)(i);
         AA_sort_out1(1)(i) <= AA_sort_in1(1)(i);
         AA_sort_out1(2)(i) <= AA_sort_in1(2)(i);
      
         if (AA_sort_in1(0)(i) < AA_sort_in1(1)(i)) then
            if (AA_sort_in1(1)(i) > AA_sort_in1(2)(i)) then
               if (AA_sort_in1(0)(i) < AA_sort_in1(2)(i)) then
                  AA_sort_out1(1)(i) <= AA_sort_in1(2)(i);
                  AA_sort_out1(2)(i) <= AA_sort_in1(1)(i); 
               else
                  AA_sort_out1(0)(i) <= AA_sort_in1(2)(i);
                  AA_sort_out1(1)(i) <= AA_sort_in1(0)(i);
                  AA_sort_out1(2)(i) <= AA_sort_in1(1)(i);
               end if;
            end if;
         else   
            if (AA_sort_in1(1)(i) < AA_sort_in1(2)(i)) then
               if (AA_sort_in1(0)(i) < AA_sort_in1(2)(i)) then
                  AA_sort_out1(0)(i) <= AA_sort_in1(1)(i);
                  AA_sort_out1(1)(i) <= AA_sort_in1(0)(i); 
               else
                  AA_sort_out1(0)(i) <= AA_sort_in1(1)(i);
                  AA_sort_out1(1)(i) <= AA_sort_in1(2)(i);
                  AA_sort_out1(2)(i) <= AA_sort_in1(0)(i);
               end if;
            else
               AA_sort_out1(0)(i) <= AA_sort_in1(2)(i);
               AA_sort_out1(2)(i) <= AA_sort_in1(0)(i); 
            end if;
         end if;
         
         AA_sort_out2(0)(i) <= AA_sort_in2(0)(i);
         AA_sort_out2(1)(i) <= AA_sort_in2(1)(i);
         AA_sort_out2(2)(i) <= AA_sort_in2(2)(i);
      
         if (AA_sort_in2(0)(i) < AA_sort_in2(1)(i)) then
            if (AA_sort_in2(1)(i) > AA_sort_in2(2)(i)) then
               if (AA_sort_in2(0)(i) < AA_sort_in2(2)(i)) then
                  AA_sort_out2(1)(i) <= AA_sort_in2(2)(i);
                  AA_sort_out2(2)(i) <= AA_sort_in2(1)(i); 
               else
                  AA_sort_out2(0)(i) <= AA_sort_in2(2)(i);
                  AA_sort_out2(1)(i) <= AA_sort_in2(0)(i);
                  AA_sort_out2(2)(i) <= AA_sort_in2(1)(i);
               end if;
            end if;
         else   
            if (AA_sort_in2(1)(i) < AA_sort_in2(2)(i)) then
               if (AA_sort_in2(0)(i) < AA_sort_in2(2)(i)) then
                  AA_sort_out2(0)(i) <= AA_sort_in2(1)(i);
                  AA_sort_out2(1)(i) <= AA_sort_in2(0)(i); 
               else
                  AA_sort_out2(0)(i) <= AA_sort_in2(1)(i);
                  AA_sort_out2(1)(i) <= AA_sort_in2(2)(i);
                  AA_sort_out2(2)(i) <= AA_sort_in2(0)(i);
               end if;
            else
               AA_sort_out2(0)(i) <= AA_sort_in2(2)(i);
               AA_sort_out2(2)(i) <= AA_sort_in2(0)(i); 
            end if;
         end if;

      end loop;
   end process;
   
   process(all)
   begin
      
      for i in 0 to 2 loop
      
         --int penmin = (first[0] < second[0]) ? min(first[1], second[0]) : min(first[0], second[1]);
         if (AA_sort_out1(0)(i) < AA_sort_out2(0)(i)) then
            if (AA_sort_out1(1)(i) < AA_sort_out2(0)(i)) then
               penmin_sort(i) <= AA_sort_out1(1)(i);
            else
               penmin_sort(i) <= AA_sort_out2(0)(i);
            end if;
         else
            if (AA_sort_out1(0)(i) < AA_sort_out2(1)(i)) then
               penmin_sort(i) <= AA_sort_out1(0)(i);
            else
               penmin_sort(i) <= AA_sort_out2(1)(i);
            end if;
         end if;
         
         -- int penmax = (first[2] > second[2]) ? max(first[1], second[2]) : max(first[2], second[1]);
         if (AA_sort_out1(2)(i) > AA_sort_out2(2)(i)) then
            if (AA_sort_out1(1)(i) > AA_sort_out2(2)(i)) then
               penmax_sort(i) <= AA_sort_out1(1)(i);
            else
               penmax_sort(i) <= AA_sort_out2(2)(i);
            end if;
         else
            if (AA_sort_out1(2)(i) > AA_sort_out2(1)(i)) then
               penmax_sort(i) <= AA_sort_out1(2)(i);
            else
               penmax_sort(i) <= AA_sort_out2(1)(i);
            end if;
         end if;
         
         -- penmin = std::min(center, penmin);
         if (penmin_sort(i) < mid_color(i)) then
            penmin(i) <= penmin_sort(i);
         else
            penmin(i) <= mid_color(i);
         end if;
         
         -- penmax = std::max(center, penmax);
         if (penmax_sort(i) > mid_color(i)) then
            penmax(i) <= penmax_sort(i);
         else
            penmax(i) <= mid_color(i);
         end if;
         
      end loop;
   
   end process;
   
   
end architecture;





