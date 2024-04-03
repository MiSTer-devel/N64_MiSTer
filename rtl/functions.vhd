library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     
use ieee.math_real.all;   

package pFunctions is

   function byteswap64(inval : std_logic_vector(63 downto 0)) return std_logic_vector;
   function byteswap32(inval : unsigned(31 downto 0)) return unsigned;
   function byteswap32(inval : std_logic_vector(31 downto 0)) return std_logic_vector;
   function byteswap16(inval : unsigned(15 downto 0)) return unsigned;
   function byteswap16(inval : std_logic_vector(15 downto 0)) return std_logic_vector;

   -- synthesis translate_off
   function to_string_len(inval : integer; inlength: integer) return string;
   -- synthesis translate_on

end package;

package body pFunctions is

   function byteswap64(inval : std_logic_vector(63 downto 0)) return std_logic_vector is
   begin
      return inval(7 downto 0) & inval(15 downto 8) & inval(23 downto 16) & inval(31 downto 24) & inval(39 downto 32) & inval(47 downto 40) & inval(55 downto 48) & inval(63 downto 56);
   end function byteswap64;

   function byteswap32(inval : unsigned(31 downto 0)) return unsigned is
   begin
      return inval(7 downto 0) & inval(15 downto 8) & inval(23 downto 16) & inval(31 downto 24);
   end function byteswap32;   
   
   function byteswap32(inval : std_logic_vector(31 downto 0)) return std_logic_vector is
   begin
      return inval(7 downto 0) & inval(15 downto 8) & inval(23 downto 16) & inval(31 downto 24);
   end function byteswap32;

   function byteswap16(inval : unsigned(15 downto 0)) return unsigned is
   begin
      return inval(7 downto 0) & inval(15 downto 8);
   end function byteswap16;   
   
   function byteswap16(inval : std_logic_vector(15 downto 0)) return std_logic_vector is
   begin
      return inval(7 downto 0) & inval(15 downto 8);
   end function byteswap16;
   
   -- synthesis translate_off
   function to_string_len(inval : integer; inlength: integer) return string is
      variable to_return : string(1 to inlength);
      variable digits : integer;
      variable lowpos : integer;
   begin
      if (inval < 10) then
         digits := 1;
      else
         digits := integer(ceil(log10(real(inval + 1))));
      end if;
      for i in 1 to inlength - digits loop
         to_return(i) := ' ';
      end loop;
      if (digits > inlength) then
         return to_return;
      end if;
      lowpos := inlength - digits + 1;
      if (lowpos < 1) then 
         lowpos := 1;
      end if;
      to_return(lowpos to inlength) := to_string(inval);
      return to_return;
   end function to_string_len;
   -- synthesis translate_on

end pFunctions;



