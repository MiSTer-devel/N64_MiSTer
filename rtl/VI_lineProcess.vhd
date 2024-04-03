library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pVI.all;
use work.pFunctions.all;

entity VI_lineProcess is
   port 
   (
      clk1x              : in  std_logic;
      reset              : in  std_logic;
      
      VI_DIRECTFBMODE    : in  std_logic;
      
      VI_CTRL_TYPE       : in  unsigned(1 downto 0);
      VI_CTRL_AA_MODE    : in  unsigned(1 downto 0);
      VI_WIDTH           : in  unsigned(11 downto 0);
      
      newFrame           : in  std_logic;
      startProc          : in  std_logic;
      interlacedField    : in  std_logic;
      procDone           : out std_logic := '0';
      
      fetchAddr          : out unsigned(9 downto 0) := (others => '0');
      fetchdata          : in  tfetchArray;
      fetchAddr9         : out unsigned(9 downto 0) := (others => '0');
      fetchdata9         : in  tfetchArray9;
      
      proc_pixel         : out std_logic := '0';
      proc_border        : out std_logic := '0';
      proc_x             : out unsigned(9 downto 0) := (others => '0');        
      proc_y             : out unsigned(9 downto 0) := (others => '0');
      proc_pixel_Mid     : out tfetchelement := (others => (others => '0'));
      proc_pixels_AA     : out tfetcharray_AA := (others => (others => (others => '0')));
      proc_pixels_DD     : out tfetcharray_DD := (others => (others => (others => '0')));
      
      video_blockVIFB    : in  std_logic;
      line_x_min         : in  unsigned(9 downto 0);
      line_x_max         : in  unsigned(9 downto 0);
      VIFB_frameindex    : in  unsigned(1 downto 0);
      VIFBfifo_Din       : out std_logic_vector(87 downto 0); -- 64bit data + 24 bit address
      VIFBfifo_Wr        : out std_logic := '0'  
   );
end entity;

architecture arch of VI_lineProcess is

   type tstate is
   (
      IDLE,
      FETCH0,
      FETCH
   );
   signal state         : tstate := IDLE; 
   
   signal newFrame_1    : std_logic := '0';
   signal lineLength    : unsigned(9 downto 0) := (others => '0');        
   signal cnt_x         : unsigned(9 downto 0) := (others => '0');        
   signal cnt_y         : unsigned(9 downto 0) := (others => '0');
   
   signal firstword16   : std_logic := '0'; 
   signal fetchAddr_1   : unsigned(2 downto 0);
   signal prefetch      : integer range 0 to 5 := 0;     
   
   signal fetchshift0   : tfetchshift := (others => (others => (others => '0')));
   signal fetchshift1   : tfetchshift := (others => (others => (others => '0')));
   signal fetchshift2   : tfetchshift := (others => (others => (others => '0')));
   
   type tfetchelementArray is array(0 to 2) of tfetchelement;
   signal fetchArray    : tfetchelementArray;
   
   type tfetchdata16 is array(0 to 2) of unsigned(15 downto 0);
   signal fetchdata16   : tfetchdata16;
   
   signal lineEnd       : std_logic;
   
   signal fb_count      : std_logic := '0';

begin 
  
   process (all)
   begin
      for i in 0 to 2 loop
      
         if (firstword16 = '1') then
            fetchdata16(i) <= byteswap16(fetchdata(i)(15 downto 0));
         else 
            fetchdata16(i) <= byteswap16(fetchdata(i)(31 downto 16));
         end if;
      
         if (VI_CTRL_TYPE = "11") then
            fetchArray(i).r <= fetchdata(i)( 7 downto  0);
            fetchArray(i).g <= fetchdata(i)(15 downto  8);
            fetchArray(i).b <= fetchdata(i)(23 downto 16);
            fetchArray(i).c <= fetchdata(i)(31 downto 29);
         else
            fetchArray(i).r <= fetchdata16(i)(15 downto 11) & "000";
            fetchArray(i).g <= fetchdata16(i)(10 downto  6) & "000";
            fetchArray(i).b <= fetchdata16(i)( 5 downto  1) & "000";
            fetchArray(i).c <= fetchdata16(i)(0) & fetchdata9(i);
         end if;
         
         if (VI_CTRL_AA_MODE(1) = '1') then
            fetchArray(i).c <= "111";
         end if;
         
      end loop;
   end process;   
   
   proc_pixel_Mid    <= fetchshift1(2);
   
   proc_pixels_AA(0) <= fetchshift0(1);
   proc_pixels_AA(1) <= fetchshift0(3);
   proc_pixels_AA(2) <= fetchshift1(0);
   proc_pixels_AA(3) <= fetchshift1(4);
   proc_pixels_AA(4) <= fetchshift2(1);
   proc_pixels_AA(5) <= fetchshift2(3);
   
   proc_pixels_DD(0) <= fetchshift0(1);
   proc_pixels_DD(1) <= fetchshift0(2);
   proc_pixels_DD(2) <= fetchshift0(3);
   proc_pixels_DD(3) <= fetchshift1(1);
   proc_pixels_DD(4) <= fetchshift1(3);
   proc_pixels_DD(5) <= fetchshift2(1);
   proc_pixels_DD(6) <= fetchshift2(2);
   proc_pixels_DD(7) <= fetchshift2(3);
   
   lineLength <= to_unsigned(700, lineLength'length) when (VI_WIDTH > 700) else resize(VI_WIDTH + 1, lineLength'length);
   
   lineEnd <= '1' when (cnt_x > lineLength) else '0';
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         proc_pixel  <= '0';
         procDone    <= '0';
         VIFBfifo_Wr <= '0';
         newFrame_1  <= newFrame;
         
         if (reset = '1') then
         
            state <= IDLE;
         
         else
         
            case (state) is
            
               when IDLE =>
                  
                  if (newFrame = '1') then
                     cnt_y                      <= (others => '0');
                  end if;
                  if (newFrame_1 = '1') then
                     VIFBfifo_Din(87 downto 64) <= x"2" & std_logic_vector(VIFB_frameindex) & "00" & x"0000";
                     if (interlacedField = '1' and video_blockVIFB = '1') then
                        VIFBfifo_Din(81 downto 73) <= 9x"01";
                     end if;
                  end if;
                  if (startProc = '1') then
                     fetchAddr   <= (others => '0');
                     fetchAddr9  <= (others => '0');
                     firstword16 <= '1';
                     state       <= FETCH0;
                     cnt_x       <= (others => '0');  
                     proc_border <= '0';       
                     if (VI_DIRECTFBMODE = '1') then
                        prefetch <= 0;
                     else
                        prefetch <= 5;
                     end if;
                     VIFBfifo_Din(72 downto 64) <= 9x"00";  
                     if (cnt_y > 0) then
                        if (video_blockVIFB = '1') then
                           VIFBfifo_Din(81 downto 73) <= std_logic_vector(unsigned(VIFBfifo_Din(81 downto 73)) + 2);
                        else
                           VIFBfifo_Din(81 downto 73) <= std_logic_vector(unsigned(VIFBfifo_Din(81 downto 73)) + 1);
                        end if;
                     end if;
                     fb_count    <= '0';        
                  end if;
            
               when FETCH0 =>
                  state <= FETCH;
                  if (VI_CTRL_TYPE = "11" or firstword16 = '0') then
                     fetchAddr <= fetchAddr + 1;
                  end if;
                  fetchAddr9 <= fetchAddr9 + 1;
                  
               when FETCH =>
                  for i in 0 to 3 loop
                     fetchshift0(i) <= fetchshift0(i + 1);
                  end loop;
                  fetchshift0(4) <= fetchArray(0);
                  
                  for i in 0 to 3 loop
                     fetchshift1(i) <= fetchshift1(i + 1);
                  end loop;
                  fetchshift1(4) <= fetchArray(1);
                  
                  for i in 0 to 3 loop
                     fetchshift2(i) <= fetchshift2(i + 1);
                  end loop;
                  fetchshift2(4) <= fetchArray(2);
                  
                  if (prefetch > 0) then
                     prefetch <= prefetch - 1;
                  else
                     proc_pixel  <= '1';
                     proc_x      <= cnt_x;
                     proc_y      <= cnt_y;
                     
                     fb_count <= not fb_count;
                     VIFBfifo_Din(63 downto 56) <= x"00"; 
                     VIFBfifo_Din(55 downto 48) <= std_logic_vector(fetchArray(2).b); 
                     VIFBfifo_Din(47 downto 40) <= std_logic_vector(fetchArray(2).g); 
                     VIFBfifo_Din(39 downto 32) <= std_logic_vector(fetchArray(2).r); 
                     if (cnt_x < line_x_min or cnt_x >= line_x_max) then
                        VIFBfifo_Din(55 downto 32) <= (others => '0');
                     end if;
                     VIFBfifo_Din(31 downto 0) <= VIFBfifo_Din(63 downto 32);
                     if (VI_DIRECTFBMODE = '1' and fb_count = '1') then
                        VIFBfifo_Wr <= '1';
                     end if;
                     if (VIFBfifo_Wr = '1') then
                        VIFBfifo_Din(72 downto 64) <= std_logic_vector(unsigned(VIFBfifo_Din(72 downto 64)) + 1);
                     end if;
                     
                     cnt_x       <= cnt_x + 1;
                     if (lineEnd = '1') then
                        proc_border <= '1';
                        state     <= IDLE;
                        procDone  <= '1';
                        cnt_y     <= cnt_y + 1;
                     end if;
                  end if;
                  
                  firstword16 <= not firstword16;
                  if (VI_CTRL_TYPE = "11" or firstword16 = '1') then
                     fetchAddr <= fetchAddr + 1;
                  end if;
                  fetchAddr9 <= fetchAddr9 + 1;
            
            end case;
            
         end if;
   
      end if;
   end process;
   
end architecture;





