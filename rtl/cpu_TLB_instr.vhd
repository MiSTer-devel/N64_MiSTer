library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;    

entity cpu_TLB_instr is
   port 
   (
      clk93                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      RANDOMMISS           : in  unsigned(3 downto 0);
                           
      TLBInvalidate        : in  std_logic;
                           
      TLB_Req              : in  std_logic;
      TLB_ss_load          : in  std_logic;
      TLB_AddrIn           : in  unsigned(63 downto 0);
      TLB_useCache         : out std_logic := '0';           
      TLB_Stall            : out std_logic := '0';
      TLB_UnStall          : out std_logic := '0';
      TLB_AddrOutFound     : out unsigned(31 downto 0) := (others => '0');
      TLB_AddrOutLookup    : out unsigned(31 downto 0) := (others => '0');
      
      TLB_ExcRead          : out std_logic := '0';
      TLB_ExcMiss          : out std_logic := '0';
      
      TLB_ClearEna         : out std_logic := '0';
      TLB_ClearIndex       : out unsigned(4 downto 0) := (others => '0');
      
      TLB_fetchReq         : out std_logic := '0';
      TLB_fetchAddrIn      : out unsigned(63 downto 0) := (others => '0');
      TLB_fetchDone        : in  std_logic;
      TLB_fetchExcInvalid  : in  std_logic;
      TLB_fetchExcNotFound : in  std_logic;
      TLB_fetchCached      : in  std_logic;
      TLB_fetchRandom      : in  std_logic;
      TLB_fetchSource      : in  unsigned(4 downto 0);
      TLB_fetchAddrOut     : in  unsigned(31 downto 0)
   );
end entity;

architecture arch of cpu_TLB_instr is
 
   type tstate is
   (
      IDLE,
      REQUEST,
      EXCEPTION
   );
   signal state : tstate := IDLE;
   
   signal mini_valid    : std_logic := '0';
   signal mini_region   : unsigned(1 downto 0) := (others => '0'); 
   signal mini_virtual  : unsigned(39 downto 0) := (others => '0'); 
   signal mini_physical : unsigned(31 downto 0) := (others => '0'); 
   signal mini_cached   : std_logic := '0';
   signal mini_random   : std_logic := '0';
   
   signal mini_hit      : std_logic;
   
   signal random_check     : std_logic;
   signal random_counter   : unsigned(5 downto 0) := (others => '0'); 
   signal random_checkCnt  : unsigned(5 downto 0) := (others => '0'); 

begin 

   mini_hit <= '1' when (mini_valid = '1' and TLB_AddrIn(39 downto 12) = mini_virtual(39 downto 12) and TLB_AddrIn(63 downto 62) = mini_region) else '0';

   TLB_Stall <= TLB_Req when (random_check = '1' or mini_hit = '0') else '0';
   
   TLB_AddrOutFound <= mini_physical(31 downto 12) & TLB_AddrIn(11 downto 0);
   TLB_useCache     <= mini_cached;

   random_check     <= '0'; --'1' when (mini_random = '1' and random_counter >= random_checkCnt) else '0';

   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         --random_checkCnt <= RANDOMMISS & "00";
         random_checkCnt <= "00" & RANDOMMISS;
         --random_checkCnt <= to_unsigned(5, random_checkCnt'length);
         
         if (TLB_Req = '1') then
            if (random_counter >= random_checkCnt) then
               random_counter <= (others => '0');
            else
               random_counter <= random_counter + 1;
            end if;
         end if;
         
         TLB_ClearEna  <= '0';
      
         if (ce = '1') then
            TLB_UnStall   <= '0';
            TLB_fetchReq  <= '0';
            TLB_ExcRead   <= '0';
            TLB_ExcMiss   <= '0';
         end if;
         
         if (reset = '1') then
         
            state      <= IDLE;
            mini_valid <= '0';
           
         else
         
            if (TLBInvalidate = '1') then
               mini_valid <= '0';
            end if;
         
            case (state) is
            
               when IDLE =>
                  if (TLB_ss_load = '1') then
                     TLB_fetchAddrIn  <= TLB_AddrIn(63 downto 40) & (TLB_AddrIn(39 downto 0) - 4);
                  elsif (TLB_Req = '1') then
                     TLB_fetchAddrIn  <= TLB_AddrIn;
                  end if;
                  if (TLB_Stall = '1') then
                     if (mini_hit = '1' and random_check = '1') then
                        state            <= EXCEPTION;
                        TLB_ExcRead      <= '1';
                        TLB_ExcMiss      <= '1';
                        TLB_ClearEna     <= '1';
                     else
                        state            <= REQUEST;
                        TLB_fetchReq     <= '1';
                     end if;
                  end if;
                 
               when REQUEST =>
                  if (TLB_fetchDone = '1') then
                     if (TLB_fetchExcInvalid = '0' and TLB_fetchExcNotFound = '0') then
                        state         <= IDLE;
                        TLB_UnStall   <= '1';
                     else
                        state         <= EXCEPTION;
                     end if;
                     TLB_AddrOutLookup <= TLB_fetchAddrOut;
                     TLB_ExcRead       <= TLB_fetchExcInvalid or TLB_fetchExcNotFound;
                     TLB_ExcMiss       <= TLB_fetchExcNotFound;
                     
                     mini_valid        <= '0';
                     if (TLB_fetchExcInvalid = '0' and TLB_fetchExcNotFound = '0') then
                        mini_valid     <= '1';
                     end if;
                     
                     mini_region       <= TLB_fetchAddrIn(63 downto 62);
                     mini_virtual      <= TLB_fetchAddrIn(39 downto 12) & x"000";
                     mini_physical     <= TLB_fetchAddrOut(31 downto 12) & x"000";
                     mini_cached       <= TLB_fetchCached;
                     mini_random       <= TLB_fetchRandom;
                     if (random_checkCnt = 0) then
                        mini_random <= '0';
                     end if;
                     
                     TLB_ClearIndex <= TLB_fetchSource;
                     
                  end if;
            
               when EXCEPTION =>
                  state       <= IDLE;
                  TLB_UnStall <= '1';
            
            end case;

         end if;
      end if;
   end process;
   
   -- synthesis translate_off
   ganalyze : if 1 = 1 generate
      signal cycles        : integer := 0;
      signal stall_cycles  : integer := 0;
      signal stall_count   : integer := 0;
      signal request_count : integer := 0;
   begin
   
      process
      begin
         wait until rising_edge(clk93);
         
         cycles <= cycles + 1;
         
         if (state /= IDLE or TLB_UnStall = '1') then
            stall_cycles <= stall_cycles + 1;
         end if;
         
         if (state = IDLE and TLB_Req = '1') then
            request_count <= request_count + 1;
         end if;         
         
         if (state = IDLE and TLB_Stall = '1') then
            stall_count <= stall_count + 1;
         end if;
         
         if (reset = '1') then
            cycles        <= 0;
            stall_cycles  <= 0;
            stall_count   <= 0;
            request_count <= 0;
         end if;
         
      end process;
   
   end generate ganalyze;

   -- synthesis translate_on   
   
end architecture;
