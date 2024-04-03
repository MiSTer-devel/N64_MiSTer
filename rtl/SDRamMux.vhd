-----------------------------------------------------------------
--------------- DDR3Mux Package  --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pSDRAM is

   constant SDRAMMUXCOUNT : integer := 5;
   
   constant SDRAMMUX_SAV  : integer := 0;
   constant SDRAMMUX_PIF  : integer := 1;
   constant SDRAMMUX_PI   : integer := 2;
   constant SDRAMMUX_RDP  : integer := 3;
   constant SDRAMMUX_VI   : integer := 4;
   
   type tSDRAMSingle     is array(0 to SDRAMMUXCOUNT - 1) of std_logic;
   type tSDRAMReqAddr    is array(0 to SDRAMMUXCOUNT - 1) of unsigned(26 downto 0);
   type tSDRAMBurstcount is array(0 to SDRAMMUXCOUNT - 1) of unsigned(7 downto 0);
   type tSDRAMBwriteMask is array(0 to SDRAMMUXCOUNT - 1) of std_logic_vector(3 downto 0);
   type tSDRAMBwriteData is array(0 to SDRAMMUXCOUNT - 1) of std_logic_vector(31 downto 0);
  
end package;

-----------------------------------------------------------------
--------------- SDRamMux module    -------------------------------
-----------------------------------------------------------------

--  0..1  Mbyte = 9th bit of RDRAM
--  4..5  Mbyte = Saverams 
--  5..6  Mbyte = Controller Paks
--  8..16 Mbyte = GB ROM 
-- 16..80 Mbyte = N64 ROM 

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pSDRAM.all;

entity SDRamMux is
   generic 
   (
      FASTSIM              : std_logic
   );
   port 
   (
      clk1x                : in  std_logic;
      ss_reset             : in  std_logic;
                           
      error                : out std_logic;
      
      isIdle               : out std_logic;
      
      sdram_ena            : out std_logic;
      sdram_rnw            : out std_logic;
      sdram_Adr            : out std_logic_vector(26 downto 0);
      sdram_be             : out std_logic_vector(3 downto 0);
      sdram_dataWrite      : out std_logic_vector(31 downto 0);
      sdram_reqprocessed   : in  std_logic;  
      sdram_done           : in  std_logic;  
      sdram_dataRead       : in  std_logic_vector(31 downto 0);

      sdramMux_request     : in  tSDRAMSingle;
      sdramMux_rnw         : in  tSDRAMSingle;    
      sdramMux_address     : in  tSDRAMReqAddr;
      sdramMux_burstcount  : in  tSDRAMBurstcount;  
      sdramMux_writeMask   : in  tSDRAMBwriteMask;  
      sdramMux_dataWrite   : in  tSDRAMBwriteData;
      sdramMux_granted     : out tSDRAMSingle;
      sdramMux_done        : out tSDRAMSingle;
      sdramMux_dataRead    : out std_logic_vector(31 downto 0);
      
      romcopy_dataNew      : in  std_logic;
      romcopy_dataRead     : in  std_logic_vector(63 downto 0);
      romcopy_active       : in  std_logic;
      romcopy_nearFull     : out std_logic;
      
      rdp9fifo_Din         : in  std_logic_vector(53 downto 0); -- 32bit data + 18 bit address + 4bit byte enable
      rdp9fifo_Wr          : in  std_logic;  
      rdp9fifo_nearfull    : out std_logic;  
      rdp9fifo_empty       : out std_logic;        
      
      rdp9fifoZ_Din        : in  std_logic_vector(49 downto 0); -- 32bit data + 18 bit address
      rdp9fifoZ_Wr         : in  std_logic;  
      rdp9fifoZ_nearfull   : out std_logic;  
      rdp9fifoZ_empty      : out std_logic  
   );
end entity;

architecture arch of SDRamMux is

   type tstate is
   (
      IDLE,
      WAITREAD,
      WAITWRITE,
      WAITFIFOWRITE,
      RESETBIT9,
      WAITWRITERESET,
      ROMCOPY
   );
   signal state            : tstate := IDLE;
      
   signal timeoutCount     : unsigned(12 downto 0);
      
   signal req_latched      : tSDRAMSingle := (others => '0');
   signal lastIndex        : integer range 0 to SDRAMMUXCOUNT - 1;
   signal remain           : unsigned(7 downto 0);

   signal ss_reset_latched : std_logic := '0';
   signal resetAddr9       : unsigned(17 downto 0) := (others => '0');

   -- rdp fifo
   signal rdpfifo_Dout     : std_logic_vector(53 downto 0);
   signal rdpfifo_Rd       : std_logic := '0';    
   
   -- rdp fifo Z Buffer
   signal rdpfifoZ_Dout    : std_logic_vector(49 downto 0);
   signal rdpfifoZ_Rd      : std_logic := '0'; 
   
   -- romcopy fifo
   signal romcopy_busy        : std_logic := '0';
   signal romcopy_next        : std_logic := '0';
   signal romcopyfifo_wr      : std_logic := '0';
   signal romcopyfifo_rd      : std_logic := '0';
   signal romcopyfifo_empty   : std_logic;
   signal romcopyfifo_din     : std_logic_vector(31 downto 0);
   signal romcopyfifo_dout    : std_logic_vector(31 downto 0);

begin 

   isIdle <= '1' when (state = IDLE) else '0';

   sdramMux_dataRead <= sdram_dataRead;

   process (all)
   begin
      
      sdramMux_done <= (others => '0');
      if (state = WAITWRITE and sdram_ena = '1') then
         sdramMux_done(lastIndex) <= '1';   
      elsif (state = WAITREAD and sdram_done = '1' and remain <= 1) then
         sdramMux_done(lastIndex) <= '1';    
      end if;
      
   end process;
      

   process (clk1x)
      variable activeRequest : std_logic;
      variable activeIndex   : integer range 0 to SDRAMMUXCOUNT - 1;
   begin
      if rising_edge(clk1x) then
      
         error             <= '0';
         sdram_ena         <= '0';
         rdpfifo_rd        <= '0';
         rdpfifoZ_rd       <= '0';
         romcopyfifo_wr    <= '0';
         romcopyfifo_rd    <= '0';
         sdramMux_granted  <= (others => '0');

         -- request handling
         activeRequest := '0';
         for i in 0 to SDRAMMUXCOUNT - 1 loop
            if (sdramMux_request(i) = '1') then
               req_latched(i) <= '1';
            end if;
            
            if (sdramMux_request(i) = '1' or req_latched(i) = '1') then
               activeRequest := '1';
               activeIndex   := i;
            end if;
            
         end loop;
         
         if (ss_reset = '1') then
            ss_reset_latched <= '1';
         end if;

         -- main statemachine
         case (state) is
            when IDLE =>
               
               lastIndex    <= activeIndex;
               timeoutCount <= (others => '0');
               
               if (romcopy_active = '1') then
               
                  state     <= ROMCOPY;
                  sdram_Adr <= 27x"1000000";
                  sdram_rnw <= '0';
                  sdram_be  <= x"F";  
               
               elsif (ss_reset_latched = '1') then
            
                  state            <= RESETBIT9;
                  if (FASTSIM = '1') then
                     resetAddr9 <= 18x"3F000";
                  end if;
            
               elsif (activeRequest = '1') then
               
                  req_latched(activeIndex) <= '0';
                  sdram_dataWrite          <= sdramMux_dataWrite(activeIndex);
                  sdram_be                 <= sdramMux_writeMask(activeIndex);
                  sdram_Adr                <= std_logic_vector(sdramMux_address(activeIndex));
                  
                  remain                   <= sdramMux_burstcount(activeIndex);
   
                  if (sdramMux_rnw(activeIndex) = '1') then
                     state                         <= WAITREAD;
                     sdram_ena                     <= '1';
                     sdram_rnw                     <= '1';
                     sdramMux_granted(activeIndex) <= '1';
                  else
                     state                         <= WAITWRITE;
                     sdram_ena                     <= '1';
                     sdram_rnw                     <= '0';
                  end if;
                  
               elsif (rdp9fifo_empty = '0') then
                  
                  state             <= WAITFIFOWRITE;
                  rdpfifo_rd        <= '1';
                  sdram_ena         <= '1';
                  sdram_rnw         <= '0';
                  sdram_dataWrite   <= rdpfifo_Dout(31 downto 0);      
                  sdram_be          <= rdpfifo_Dout(53 downto 50);       
                  sdram_Adr         <= 7x"0" & rdpfifo_Dout(49 downto 32) & "00";               
                  
               elsif (rdp9fifoZ_empty = '0') then
                  
                  state             <= WAITFIFOWRITE;
                  rdpfifoZ_rd       <= '1';
                  sdram_ena         <= '1';
                  sdram_rnw         <= '0';
                  sdram_dataWrite   <= rdpfifoZ_Dout(31 downto 0);      
                  sdram_be          <= x"F";       
                  sdram_Adr         <= 7x"0" & rdpfifoZ_Dout(49 downto 32) & "00";
               
               end if;   
                  
            when WAITWRITE | WAITFIFOWRITE =>
               timeoutCount <= timeoutCount + 1;
               if (timeoutCount(timeoutCount'high) = '1') then
                  error <= '1';
               end if;
               if (sdram_done = '1') then
                  state <= IDLE;
               end if;
                  
            when WAITREAD =>
               timeoutCount <= timeoutCount + 1;
               if (timeoutCount(timeoutCount'high) = '1') then
                  error <= '1';
               end if;
               
               if (sdram_done = '1') then
                  remain <= remain - 1;
                  if (remain <= 1) then
                     state  <= IDLE;  
                  end if;
               end if;
                  
               if (sdram_reqprocessed = '1' and remain >= 2) then
                  timeoutCount <= (others => '0');
                  sdram_Adr    <= std_logic_vector(unsigned(sdram_Adr) + 4);
                  sdram_ena    <= '1';
               end if;
               
            when RESETBIT9 =>
               state             <= WAITWRITERESET;
               sdram_ena         <= '1';
               sdram_Adr         <= 7x"0" & std_logic_vector(resetAddr9) & "00";
               sdram_rnw         <= '0';
               sdram_dataWrite   <= (others => '1');
               sdram_be          <= x"F";   
               resetAddr9        <= resetAddr9 + 1;
               
            when WAITWRITERESET =>
               if (sdram_done = '1') then
                  state <= RESETBIT9;
                  if (resetAddr9 = 0) then
                     state            <= IDLE;
                     ss_reset_latched <= '0';
                  end if;
               end if;
               
            when ROMCOPY =>
               if (romcopy_dataNew = '1') then
                  romcopyfifo_wr  <= '1';
                  romcopyfifo_din <= romcopy_dataRead(31 downto 0);
                  romcopy_next    <= '1';
               elsif (romcopy_next = '1') then
                  romcopy_next    <= '0';
                  romcopyfifo_wr  <= '1';
                  romcopyfifo_din <= romcopy_dataRead(63 downto 32);
               end if;
               
               if (romcopy_busy = '0' and romcopyfifo_empty = '0') then
                  romcopy_busy     <= '1';
                  romcopyfifo_rd   <= '1';
                  sdram_ena        <= '1';
                  sdram_dataWrite  <= romcopyfifo_dout;     
               end if;
               
               if (romcopy_busy = '1' and sdram_done = '1') then
                  romcopy_busy <= '0';
                  sdram_Adr    <= std_logic_vector(unsigned(sdram_Adr) + 4);
               end if;
               
               if (romcopy_busy = '0' and romcopy_active = '0' and romcopyfifo_empty = '1') then
                  state <= IDLE;
               end if;

         end case;

      end if;
   end process;
   
   iRDPFifo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 128,
      DATAWIDTH        => 32 + 18 + 4 , -- 32bit data + 18 bit address + 4bit byte enable
      NEARFULLDISTANCE => 64
   )
   port map
   ( 
      clk      => clk1x,
      reset    => '0',  
      Din      => rdp9fifo_Din,     
      Wr       => rdp9fifo_Wr,
      Full     => open,    
      NearFull => rdp9fifo_nearfull,
      Dout     => rdpfifo_Dout,    
      Rd       => rdpfifo_rd,      
      Empty    => rdp9fifo_empty   
   );   
   
   iRDPFifoZ: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 128,
      DATAWIDTH        => 32 + 18, -- 32bit data + 18 bit address
      NEARFULLDISTANCE => 64
   )
   port map
   ( 
      clk      => clk1x,
      reset    => '0',  
      Din      => rdp9fifoZ_Din,     
      Wr       => rdp9fifoZ_Wr,
      Full     => open,    
      NearFull => rdp9fifoZ_nearfull,
      Dout     => rdpfifoZ_Dout,    
      Rd       => rdpfifoZ_rd,      
      Empty    => rdp9fifoZ_empty   
   );

   iROMCOPYFifo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 32,
      DATAWIDTH        => 32,
      NEARFULLDISTANCE => 24
   )
   port map
   ( 
      clk      => clk1x,
      reset    => '0',  
      Din      => romcopyfifo_din,     
      Wr       => romcopyfifo_wr,
      Full     => open,    
      NearFull => romcopy_nearFull,
      Dout     => romcopyfifo_dout,    
      Rd       => romcopyfifo_rd,      
      Empty    => romcopyfifo_empty   
   );
   
   
end architecture;





