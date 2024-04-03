-----------------------------------------------------------------
--------------- DDR3Mux Package  --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pDDR3 is

   constant DDR3MUXCOUNT : integer := 8;
   
   constant DDR3MUX_RSP    : integer := 0;
   constant DDR3MUX_RDP    : integer := 1;
   constant DDR3MUX_SS     : integer := 2;
   constant DDR3MUX_PI     : integer := 3;
   constant DDR3MUX_SI     : integer := 4;
   constant DDR3MUX_MEMMUX : integer := 5;
   constant DDR3MUX_AI     : integer := 6;
   constant DDR3MUX_VI     : integer := 7;
   
   type tDDDR3Single     is array(0 to DDR3MUXCOUNT - 1) of std_logic;
   type tDDDR3ReqAddr    is array(0 to DDR3MUXCOUNT - 1) of unsigned(27 downto 0);
   type tDDDR3Burstcount is array(0 to DDR3MUXCOUNT - 1) of unsigned(9 downto 0);
   type tDDDR3BwriteMask is array(0 to DDR3MUXCOUNT - 1) of std_logic_vector(7 downto 0);
   type tDDDR3BwriteData is array(0 to DDR3MUXCOUNT - 1) of std_logic_vector(63 downto 0);
  
end package;

-----------------------------------------------------------------
--------------- DDR3Mux module    -------------------------------
-----------------------------------------------------------------

--   0..8   Mbyte = RDRAM
--   8..8   Mbyte = RMRAM read behind area 
--  16..32  Mbyte = VI FB mode area
--  32..96  Mbyte = N64 ROM fastload area 
-- 192..256 Mbyte = Savestates

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pDDR3.all;

entity DDR3Mux is
   generic
   (
      use2Xclock       : in  std_logic
   );
   port 
   (
      clk1x            : in  std_logic;
      clk2x            : in  std_logic;
      clk2xIndex       : in  std_logic;
      
      RAMSIZE8         : in  std_logic;
      slow_in          : in  std_logic_vector(3 downto 0); 
      
      error            : out std_logic;
      error_fifo       : out std_logic;
      error_outReq     : out std_logic;
      error_outRSP     : out std_logic;
      error_outRDP     : out std_logic;
      error_outRDPZ    : out std_logic;
      error_outPI      : out std_logic;

      ddr3_BUSY        : in  std_logic;                    
      ddr3_DOUT        : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY  : in  std_logic;
      ddr3_BURSTCNT    : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_ADDR        : out std_logic_vector(28 downto 0) := (others => '0');                       
      ddr3_DIN         : out std_logic_vector(63 downto 0) := (others => '0');
      ddr3_BE          : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_WE          : out std_logic := '0';
      ddr3_RD          : out std_logic := '0';
      
      rdram_request    : in  tDDDR3Single;
      rdram_rnw        : in  tDDDR3Single;    
      rdram_address    : in  tDDDR3ReqAddr;
      rdram_burstcount : in  tDDDR3Burstcount;  
      rdram_writeMask  : in  tDDDR3BwriteMask;  
      rdram_dataWrite  : in  tDDDR3BwriteData;
      rdram_granted    : out tDDDR3Single;
      rdram_granted2X  : out tDDDR3Single;
      rdram_done       : out tDDDR3Single;
      rdram_dataRead   : out std_logic_vector(63 downto 0);
      
      rspfifo_req      : in  std_logic;
      rspfifo_reset    : in  std_logic; 
      rspfifo_Din      : in  std_logic_vector(84 downto 0); -- 64bit data + 21 bit address
      rspfifo_Wr       : in  std_logic;  
      rspfifo_nearfull : out std_logic;  
      rspfifo_empty    : out std_logic;
      
      rdpfifo_Din      : in  std_logic_vector(91 downto 0); -- 64bit data + 20 bit address + 8 byte enables
      rdpfifo_Wr       : in  std_logic;  
      rdpfifo_nearfull : out std_logic;  
      rdpfifo_empty    : out std_logic;
      
      rdpfifoZ_Din     : in  std_logic_vector(91 downto 0); -- 64bit data + 20 bit address + 8 byte enables
      rdpfifoZ_Wr      : in  std_logic;  
      rdpfifoZ_nearfull: out std_logic;  
      rdpfifoZ_empty   : out std_logic;
      
      PIfifo_Din       : in  std_logic_vector(92 downto 0); -- 64bit data + 21 bit address + 8 byte enables
      PIfifo_Wr        : in  std_logic;  
      PIfifo_nearfull  : out std_logic;
      PIfifo_empty     : out std_logic;

      VIFBfifo_Din     : in  std_logic_vector(87 downto 0); -- 64bit data + 24 bit address
      VIFBfifo_Wr      : in  std_logic     
   );
end entity;

architecture arch of DDR3Mux is

   type tddr3State is
   (
      IDLE,
      WAITREAD,
      READAGAIN,
      WAITSLOW,
      RSPFIFO
   );
   signal ddr3State     : tddr3State := IDLE;
   
   signal readCount     : unsigned(7 downto 0);
   signal timeoutCount  : unsigned(12 downto 0);
   
   signal req_latched   : tDDDR3Single := (others => '0');
   signal lastIndex     : integer range 0 to DDR3MUXCOUNT - 1;
   signal remain        : unsigned(9 downto 0);
   signal lastReadReq   : std_logic;
   
   signal RAMSIZE8_2x   : std_logic;
   
   type tdone is array(0 to DDR3MUXCOUNT - 1) of std_logic_vector(1 downto 0);
   signal done    : tdone := (others => (others => '0'));
   signal granted : tdone := (others => (others => '0'));
   
   -- rsp fifo
   signal rspfifo_Dout     : std_logic_vector(84 downto 0);
   signal rspfifo_Rd       : std_logic := '0';      
   
   -- rdp fifo
   signal rdpfifo_Dout     : std_logic_vector(91 downto 0);
   signal rdpfifo_Rd       : std_logic := '0';     

   -- rdp fifo Z
   signal rdpfifoZ_Dout    : std_logic_vector(91 downto 0);
   signal rdpfifoZ_Rd      : std_logic := '0';      
   
   -- PI fifo 
   signal PIfifo_Dout      : std_logic_vector(92 downto 0);
   signal PIfifo_Rd        : std_logic := '0';     
   
   -- VI FB fifo
   signal VIFBfifo_Dout    : std_logic_vector(87 downto 0);
   signal VIFBfifo_Rd      : std_logic := '0';    
   signal VIFBfifo_empty   : std_logic := '0';    

   -- slow
   signal slow       : unsigned(3 downto 0) := (others => '0');
   signal slow_on    : std_logic := '0';
   signal slowcnt    : unsigned(10 downto 0) := (others => '0');

   -- clk1x transfer
   signal ddr3_DOUT_READY_1 : std_logic := '0';
   signal rdram_dataRead_2x : std_logic_vector(63 downto 0);

   signal clk1x_captureNext : std_logic := '0';

begin 

   ddr3_ADDR(28 downto 25) <= "0011";
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (ddr3State = WAITREAD) then
            clk1x_captureNext <= '1';
         end if;
         
         if (clk1x_captureNext = '1') then
            if (ddr3_DOUT_READY = '1') then
               rdram_dataRead    <= ddr3_DOUT;
               clk1x_captureNext <= '0';
            end if;
            if (ddr3_DOUT_READY_1 = '1') then
               rdram_dataRead    <= rdram_dataRead_2x;
               clk1x_captureNext <= '0';
            end if;
         end if;
      
      end if;
   end process;

   process (clk2x)
      variable activeRequest : std_logic;
      variable activeIndex   : integer range 0 to DDR3MUXCOUNT - 1;
   begin
      if rising_edge(clk2x) then
      
         error          <= '0';
         error_outReq   <= '0';
         error_outRSP   <= '0';
         error_outRDP   <= '0';
         error_outRDPZ  <= '0';
         error_outPI    <= '0';
         
         rspfifo_Rd  <= '0';
         rdpfifo_Rd  <= '0';
         rdpfifoZ_Rd <= '0';
         PIFifo_Rd   <= '0';
         VIFBfifo_Rd <= '0';
         
         ddr3_DOUT_READY_1 <= ddr3_DOUT_READY;
         
         RAMSIZE8_2x <= RAMSIZE8;
      
         if (ddr3_BUSY = '0') then
            ddr3_WE <= '0';
            ddr3_RD <= '0';
         end if;
         
         slow    <= unsigned(slow_in);
         slow_on <= '0';
         if (slow > 0) then
            slow_on <= '1';
         end if;
         
         if (slowcnt > 0) then
            slowcnt <= slowcnt - 1;
         end if;

         -- request handling
         activeRequest := '0';
         for i in 0 to DDR3MUXCOUNT - 1 loop
            if (rdram_request(i) = '1') then
               req_latched(i) <= '1';
            end if;
            
            if (req_latched(i) = '1') then
               activeRequest := '1';
               activeIndex   := i;
            end if;
            
            rdram_done(i) <= '0';
            done(i) <= '0' & done(i)(1);
            if (done(i) /= "00") then
               rdram_done(i) <= '1';
            end if;
            
            rdram_granted(i) <= '0';
            granted(i) <= '0' & granted(i)(1);
            if (granted(i) /= "00") then
               rdram_granted(i) <= '1';
            end if;
            rdram_granted2X(i) <= '0';
            
         end loop;

         -- main statemachine
         case (ddr3State) is
            when IDLE =>
               
               lastIndex    <= activeIndex;
               timeoutCount <= (others => '0');
            
               if (ddr3_BUSY = '0' or ddr3_WE = '0') then
               
                  if (rspfifo_req = '1') then
                  
                     ddr3State <= RSPFIFO;
                     
                  elsif (PIfifo_empty = '0' and PIfifo_Rd = '0') then
                  
                     PIfifo_Rd  <= '1';
                     ddr3_WE    <= '1';
                     ddr3_DIN   <= PIfifo_Dout(63 downto 0);      
                     ddr3_BE    <= PIfifo_Dout(92 downto 85);       
                     ddr3_ADDR(24 downto 0) <= "0000" & PIfifo_Dout(84 downto 64);
                     ddr3_BURSTCNT <= x"01";           
   
                     if ((RAMSIZE8_2x = '1' and PIfifo_Dout(84) = '1') or (RAMSIZE8_2x = '0' and PIfifo_Dout(84 downto 83) /= "00")) then
                        ddr3_WE      <= '0';
                        error_outPI  <= '1';
                     end if; 
                  
                  elsif (activeRequest = '1') then
                  
                     req_latched(activeIndex) <= '0';
                     ddr3_DIN                 <= rdram_dataWrite(activeIndex);
                     ddr3_BE                  <= rdram_writeMask(activeIndex);
                     ddr3_ADDR(24 downto 0)   <= std_logic_vector(rdram_address(activeIndex)(27 downto 3));
                     
                     slowcnt <= resize(slow & "000", 11) + rdram_burstcount(activeIndex);
                     
                     if (rdram_burstcount(activeIndex)(9 downto 8) = "00") then
                        ddr3_BURSTCNT  <= std_logic_vector(rdram_burstcount(activeIndex)(7 downto 0));
                        readCount      <= rdram_burstcount(activeIndex)(7 downto 0);
                        lastReadReq    <= '1';
                     else
                        ddr3_BURSTCNT  <= x"FF";
                        readCount      <= x"FF";
                        lastReadReq    <= '0';
                     end if;
                     
                     remain    <= rdram_burstcount(activeIndex) - 16#FF#;
   
                     if (rdram_rnw(activeIndex) = '1') then
                        ddr3State                     <= WAITREAD;
                        ddr3_RD                       <= '1';
                        granted(activeIndex)          <= use2Xclock & '1'; 
                        rdram_granted2X(activeIndex)  <= '1';
                     else
                        ddr3_WE                       <= '1';
                        done(activeIndex)             <= use2Xclock & '1'; 
                     end if;
                     
                     -- writing/reading behind ram
                     if ((RAMSIZE8_2x = '1' and rdram_address(activeIndex)(27 downto 23) > 0) or (RAMSIZE8_2x = '0' and rdram_address(activeIndex)(27 downto 22) > 0)) then
                        if (activeIndex /= DDR3MUX_SS) then
                           if (activeIndex /= DDR3MUX_VI) then -- VI reading cannot damage and request outside will happen, e.g. reading previous line with framebuffer at Address 0
                              error_outReq   <= '1';
                           end if;
                           if (rdram_rnw(activeIndex) = '1') then
                              ddr3_ADDR(24 downto 0) <= 25x"100000";
                           else
                              ddr3_WE <= '0';
                           end if;
                        end if;
                     end if;
                   
                  elsif (rdpfifo_empty = '0' and rdpfifo_Rd = '0') then
                  
                     rdpfifo_Rd <= '1';
                     ddr3_WE    <= '1';
                     ddr3_DIN   <= rdpfifo_Dout(63 downto 0);      
                     ddr3_BE    <= rdpfifo_Dout(91 downto 84);       
                     ddr3_ADDR(24 downto 0) <= "00000" & rdpfifo_Dout(83 downto 64);
                     ddr3_BURSTCNT <= x"01";
                     
                     if (RAMSIZE8_2x = '0' and rdpfifo_Dout(83) = '1') then
                        ddr3_WE        <= '0';
                        error_outRDP   <= '1';
                     end if;  
                     
                  elsif (rdpfifoZ_empty = '0' and rdpfifoZ_Rd = '0') then
                  
                     rdpfifoZ_Rd <= '1';
                     ddr3_WE     <= '1';
                     ddr3_DIN    <= rdpfifoZ_Dout(63 downto 0);      
                     ddr3_BE     <= rdpfifoZ_Dout(91 downto 84);       
                     ddr3_ADDR(24 downto 0) <= "00000" & rdpfifoZ_Dout(83 downto 64);
                     ddr3_BURSTCNT <= x"01";
                     
                     if (RAMSIZE8_2x = '0' and rdpfifo_Dout(83) = '1') then
                        ddr3_WE        <= '0';
                        error_outRDPZ  <= '1';
                     end if;  
                     
                  elsif (VIFBfifo_empty = '0' and VIFBfifo_Rd = '0') then
                  
                     VIFBfifo_Rd <= '1';
                     ddr3_WE     <= '1';
                     ddr3_DIN    <= VIFBfifo_Dout(63 downto 0);      
                     ddr3_BE     <= x"FF";       
                     ddr3_ADDR(24 downto 0) <= "0" & VIFBfifo_Dout(87 downto 64);
                     ddr3_BURSTCNT <= x"01";
                  
                  end if;   
                  
               end if;
                  
            when WAITREAD =>
               timeoutCount <= timeoutCount + 1;
               if (timeoutCount(timeoutCount'high) = '1') then
                  error <= '1';
               end if;
               if (ddr3_DOUT_READY = '1') then
                  rdram_dataRead_2x <= ddr3_DOUT;
                  timeoutCount      <= (others => '0');
                  readCount         <= readCount - 1;
                  if (readCount = 1) then
                     if (lastReadReq = '1') then
                        if (slow_on = '1') then
                           ddr3State       <= WAITSLOW;
                           if (slowcnt = 0) then
                              error <= '1';
                           end if;
                        else
                           ddr3State       <= IDLE;
                           done(lastIndex) <= use2Xclock & '1'; 
                        end if;
                     else
                        ddr3State       <= READAGAIN; 
                     end if;
                  end if;
               end if;
               
            when READAGAIN =>
               ddr3_ADDR(20 downto 0)   <= std_logic_vector(unsigned(ddr3_ADDR(20 downto 0)) + 16#FF#);
                  
               if (remain(9 downto 8) = "00") then
                  ddr3_BURSTCNT  <= std_logic_vector(remain(7 downto 0));
                  readCount      <= remain(7 downto 0);
                  lastReadReq    <= '1';
               else
                  ddr3_BURSTCNT  <= x"FF";
                  readCount      <= x"FF";
                  lastReadReq    <= '0';
               end if;
               
               ddr3State <= WAITREAD;
               ddr3_RD   <= '1';
               remain    <= remain - 16#FF#;
               
            when WAITSLOW =>
               if (slowcnt = 0) then
                  ddr3State       <= IDLE;
                  done(lastIndex) <= use2Xclock & '1';
               end if;
         
            when RSPFIFO =>
               if (rspfifo_req = '0') then
                  ddr3State <= IDLE;
               end if;
         
               if ((ddr3_BUSY = '0' or ddr3_WE = '0') and rspfifo_empty = '0' and rspfifo_Rd = '0') then
                  rspfifo_Rd <= '1';
                  ddr3_WE    <= '1';
                  ddr3_DIN   <= rspfifo_Dout(63 downto 0);      
                  ddr3_BE    <= (others => '1');       
                  ddr3_ADDR(24 downto 0) <= "0000" & rspfifo_Dout(84 downto 64);
                  ddr3_BURSTCNT <= x"01";           

                  if ((RAMSIZE8_2x = '1' and rspfifo_Dout(84) = '1') or (RAMSIZE8_2x = '0' and rspfifo_Dout(84 downto 83) /= "00")) then
                     ddr3_WE      <= '0';
                     error_outRSP <= '1';
                  end if;      
               end if;
         
         end case;

      end if;
   end process;
   
   
   iRSPFifo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 64,
      DATAWIDTH        => 64 + 21, -- 64bit data + 21 bit address
      NEARFULLDISTANCE => 32
   )
   port map
   ( 
      clk      => clk2x,
      reset    => rspfifo_reset,  
      Din      => rspfifo_Din,     
      Wr       => (rspfifo_Wr and clk2xIndex),
      Full     => error_fifo,    
      NearFull => rspfifo_nearfull,
      Dout     => rspfifo_Dout,    
      Rd       => rspfifo_Rd,      
      Empty    => rspfifo_empty   
   );   
   
   iRDPFifo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 256,
      DATAWIDTH        => 64 + 20 + 8, -- 64bit data + 20 bit address + 8 byte enables
      NEARFULLDISTANCE => 240
   )
   port map
   ( 
      clk      => clk2x,
      reset    => '0',  
      Din      => rdpfifo_Din,     
      Wr       => (rdpfifo_Wr and clk2xIndex),
      Full     => open,    
      NearFull => rdpfifo_nearfull,
      Dout     => rdpfifo_Dout,    
      Rd       => rdpfifo_Rd,      
      Empty    => rdpfifo_empty   
   );   
   
   iRDPFifoZ: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 256,
      DATAWIDTH        => 64 + 20 + 8, -- 64bit data + 20 bit address + 8 byte enables
      NEARFULLDISTANCE => 240
   )
   port map
   ( 
      clk      => clk2x,
      reset    => '0',  
      Din      => rdpfifoZ_Din,     
      Wr       => (rdpfifoZ_Wr and clk2xIndex),
      Full     => open,    
      NearFull => rdpfifoZ_nearfull,
      Dout     => rdpfifoZ_Dout,    
      Rd       => rdpfifoZ_Rd,      
      Empty    => rdpfifoZ_empty   
   );   
   
   iPIFifo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 256,
      DATAWIDTH        => 64 + 21 + 8, -- 64bit data + 21 bit address + 8 byte enables
      NEARFULLDISTANCE => 128
   )
   port map
   ( 
      clk      => clk2x,
      reset    => '0',  
      Din      => PIFifo_Din,     
      Wr       => (PIFifo_Wr and clk2xIndex),
      Full     => open,    
      NearFull => PIfifo_nearfull,
      Dout     => PIFifo_Dout,    
      Rd       => PIFifo_Rd,      
      Empty    => PIFifo_empty   
   );   
   
   iVIFBFifo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 1024,
      DATAWIDTH        => 64 + 24, -- 64bit data + 24 bit address
      NEARFULLDISTANCE => 1000
   )
   port map
   ( 
      clk      => clk2x,
      reset    => '0',  
      Din      => VIFBfifo_Din,     
      Wr       => (VIFBfifo_Wr and clk2xIndex),
      Full     => open,    
      NearFull => open,
      Dout     => VIFBfifo_Dout,    
      Rd       => VIFBfifo_Rd,      
      Empty    => VIFBfifo_empty   
   );

end architecture;





