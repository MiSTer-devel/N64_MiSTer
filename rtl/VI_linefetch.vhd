library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pVI.all;

entity VI_linefetch is
   port 
   (
      clk1x              : in  std_logic;
      clk2x              : in  std_logic;
      reset              : in  std_logic;
      
      error_linefetch    : out std_logic := '0';
      
      VI_DIRECTFBMODE    : in  std_logic;
      
      VI_CTRL_TYPE       : in unsigned(1 downto 0);
      VI_CTRL_SERRATE    : in std_logic;
      VI_ORIGIN          : in unsigned(23 downto 0);
      VI_WIDTH           : in unsigned(11 downto 0);
      VI_X_SCALE_FACTOR  : in unsigned(11 downto 0);
      VI_Y_SCALE_FACTOR  : in unsigned(11 downto 0);
      VI_Y_SCALE_OFFSET  : in unsigned(11 downto 0);
      
      newFrame           : in  std_logic;
      fetch              : in  std_logic;
      interlacedField    : in  std_logic;
      video_blockVIFB    : in  std_logic;
      
      addr9_offset       : out taddr9offset := (others => 0);
      startProc          : out std_logic := '0';
      procPtr            : out std_logic_vector(2 downto 0) := (others => '0');
      procDone           : in  std_logic;
      
      outprocIdle        : in  std_logic := '0';
      startOut           : out std_logic := '0';
      fracYout           : out unsigned(4 downto 0);
      FetchLineCount     : out unsigned(9 downto 0) := (others => '0');
      
      rdram_request      : out std_logic := '0';
      rdram_rnw          : out std_logic := '0'; 
      rdram_address      : out unsigned(27 downto 0):= (others => '0');
      rdram_burstcount   : out unsigned(9 downto 0):= (others => '0');
      rdram_granted      : in  std_logic;
      rdram_done         : in  std_logic;
      ddr3_DOUT_READY    : in  std_logic;
      rdram_store        : out std_logic_vector(2 downto 0) := (others => '0');
      rdram_storeAddr    : out unsigned(8 downto 0) := (others => '0');
      
      sdram_request      : out std_logic := '0';
      sdram_rnw          : out std_logic := '0'; 
      sdram_address      : out unsigned(26 downto 0):= (others => '0');
      sdram_burstcount   : out unsigned(7 downto 0):= (others => '0');
      sdram_granted      : in  std_logic;
      sdram_done         : in  std_logic;
      sdram_valid        : in  std_logic;
      rdram9_store       : out std_logic_vector(2 downto 0) := (others => '0');
      rdram9_storeAddr   : out unsigned(5 downto 0) := (others => '0')
   );
end entity;

architecture arch of VI_linefetch is

   type tstate is
   (
      IDLE,
      REQUESTLINE,
      WAITDONE,
      WAITPROC,
      WAITOUT
   );
   signal state            : tstate := IDLE;
   
   signal ram_offset       : signed(24 downto 0) := (others => '0');
   signal rdram_finished   : std_logic := '0';
   signal rdram9_finished  : std_logic := '0';

   signal lineInPtr        : std_logic_vector(2 downto 0) := (others => '0');
   signal lineInFetched    : unsigned(2 downto 0) := (others => '0');   
   signal lineProcCnt      : std_logic := '0';
   signal lineCount        : unsigned(9 downto 0) := (others => '0');
   
   signal line_prefetch    : integer range 0 to 8;   
   signal lineWidth        : unsigned(13 downto 0);
   signal y_accu_new       : unsigned(19 downto 0);
   signal y_accu           : unsigned(19 downto 0) := (others => '0');
   signal y_diff           : unsigned(9 downto 0);
   
   signal out_wait         : integer range 0 to 15 := 0;
   
begin 
   
   line_prefetch <= 8 when (VI_CTRL_TYPE = "11") else 4;
   
   lineWidth     <= VI_WIDTH & "00" when (VI_CTRL_TYPE = "11") else '0' & VI_WIDTH & '0';
  
   y_accu_new    <= y_accu + VI_Y_SCALE_FACTOR; 
   
   y_diff        <= y_accu_new(y_accu_new'left downto 10) - y_accu(y_accu'left downto 10);
   
   rdram_rnw <= '1';
   sdram_rnw <= '1';
   
   sdram_address <= 7x"0" & rdram_address(22 downto 5) & "00";
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         rdram_request <= '0';
         sdram_request <= '0';
         startProc     <= '0';
         startOut      <= '0';
         
         error_linefetch <= '0';
         if (state /= IDLE and (fetch = '1' or newFrame = '1')) then
            error_linefetch <= '1';
         end if;
         
         if (VI_CTRL_TYPE = "10") then
            if (VI_X_SCALE_FACTOR > x"200") then -- hack for 320/640 pixel width
               rdram_burstcount <= 10x"B0";
            else
               rdram_burstcount <= 10x"60";
            end if;
         elsif (VI_CTRL_TYPE = "11") then
            if (VI_X_SCALE_FACTOR > x"200") then -- hack for 320/640 pixel width
               rdram_burstcount <= 10x"150";
            else
               rdram_burstcount <= 10x"B0";
            end if;
         end if;
         
         if (VI_X_SCALE_FACTOR > x"200") then -- hack for 320/640 pixel width
            sdram_burstcount <= 8x"30";
         else
            sdram_burstcount <= 8x"18";
         end if; 
         
         if (reset = '1') then
         
            state         <= IDLE;
            lineInFetched <= "111";
         
         else
         
            case (state) is
            
               when IDLE =>
                  if (newFrame = '1') then
                     FetchLineCount <= lineCount;
                     lineCount      <= (others => '0');
                     if (VI_DIRECTFBMODE = '1') then
                        ram_offset    <= (others => '0');
                        lineInFetched <= "011";
                        lineProcCnt   <= '0';
                        if (VI_CTRL_SERRATE = '1' and interlacedField = '1' and video_blockVIFB = '0') then
                           ram_offset <= to_signed(0, ram_offset'length) - to_integer(lineWidth);
                        end if;
                     else
                        ram_offset    <= to_signed(0, ram_offset'length) - to_integer(lineWidth) - line_prefetch;
                        lineInFetched <= "000";
                        lineProcCnt   <= '1';
                        state         <= REQUESTLINE;
                     end if;
                     lineInPtr     <= "001";
                     y_accu        <= 8x"0" & VI_Y_SCALE_OFFSET;
                  end if;
                  if (fetch = '1') then
                     y_accu <= y_accu_new; 
                     if (y_diff > 0) then
                        state <= REQUESTLINE;
                        if (y_diff > 1 or (VI_DIRECTFBMODE = '1' and video_blockVIFB = '0' and VI_CTRL_SERRATE = '1' and VI_Y_SCALE_FACTOR <= 16#400#)) then
                           lineProcCnt <= '1';
                        end if;
                     else
                        out_wait <= 15;
                        state    <= WAITOUT;
                     end if;
                  end if;
                  
               when REQUESTLINE =>
                  state           <= WAITDONE;
                  rdram_address   <= to_unsigned(to_integer("0000" & VI_ORIGIN) + to_integer(ram_offset), rdram_address'length);
                  ram_offset      <= ram_offset + to_integer(lineWidth);
                  rdram_finished  <= '1';
                  rdram9_finished <= '1';
                  
                  if (VI_CTRL_TYPE = "10") then
                     rdram_request    <= '1';
                     sdram_request    <= '1';
                     rdram_finished   <= '0';
                     rdram9_finished  <= '0';
                  elsif (VI_CTRL_TYPE = "11") then
                     rdram_request    <= '1';
                     rdram_finished   <= '0';
                  end if;
                 
               when WAITDONE  => 
                  if (rdram_done = '1') then
                     rdram_finished <= '1';
                  end if;                  
                  if (sdram_done = '1') then
                     rdram9_finished <= '1';
                  end if;
                             
                  if (lineInPtr(0) = '1') then addr9_offset(0) <= to_integer(rdram_address(4 downto 1) - 2); end if;
                  if (lineInPtr(1) = '1') then addr9_offset(1) <= to_integer(rdram_address(4 downto 1) - 2); end if;
                  if (lineInPtr(2) = '1') then addr9_offset(2) <= to_integer(rdram_address(4 downto 1) - 2); end if;
                  
                  if ((rdram_done = '1' or rdram_finished = '1') and (sdram_done = '1' or rdram9_finished = '1')) then
                     state          <= IDLE;
                     lineCount      <= lineCount + 1;
                     lineInPtr      <= lineInPtr(1 downto 0) & lineInPtr(2);   
                     lineInFetched  <= lineInFetched(1 downto 0) & '1';    
                     if (lineInFetched(1 downto 0) = "11") then
                        startProc   <= '1';
                        procPtr     <= lineInPtr;
                        lineProcCnt <= '0';
                        if (lineProcCnt = '1') then
                           state <= WAITPROC;
                        else
                           out_wait <= 15;
                           state    <= WAITOUT;
                        end if;
                     else
                        state <= REQUESTLINE;
                     end if;
                  end if;
            
               when WAITPROC =>
                  if (procDone = '1') then
                     state <= REQUESTLINE;
                  end if;
                  
               when WAITOUT =>
                  if (out_wait > 0) then
                     out_wait <= out_wait - 1;
                  elsif (outprocIdle = '1') then
                     state    <= IDLE;
                     startOut <= '1';
                     fracYout <= y_accu(9 downto 5);
                  end if;
            
            end case;
            
         end if;
   
      end if;
   end process;
   
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         if (rdram_granted = '1') then
            rdram_store       <= lineInPtr;
            rdram_storeAddr   <= (others => '0');
         end if;
         
          if (ddr3_DOUT_READY = '1') then
             rdram_storeAddr <= rdram_storeAddr + 1;
          end if;
          
          if (rdram_done = '1') then
            rdram_store  <= "000";
          end if;

      end if;
   end process;
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (sdram_granted = '1') then
            rdram9_store       <= lineInPtr;
            rdram9_storeAddr   <= (others => '0');
         end if;
         
          if (sdram_valid = '1') then
             rdram9_storeAddr <= rdram9_storeAddr + 1;
          end if;
          
          if (sdram_done = '1') then
            rdram9_store  <= "000";
          end if;

      end if;
   end process;
   
   
end architecture;





