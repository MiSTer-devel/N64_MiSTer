library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   
use ieee.math_real.all;  

library mem;
use work.pFunctions.all;

entity cpu_instrcache is
   port 
   (
      clk1x             : in  std_logic;
      clk93             : in  std_logic;
      clk2x             : in  std_logic;
      reset_93          : in  std_logic;
      ce_93             : in  std_logic;
      
      ram_request       : out std_logic := '0';
      ram_active        : in  std_logic := '0';
      ram_grant         : in  std_logic := '0';
      ram_done          : in  std_logic := '0';
      ddr3_DOUT         : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY   : in  std_logic;
      
      read_select       : in  std_logic;
      read_addr1        : in  unsigned(31 downto 0);
      read_addr2        : in  unsigned(31 downto 0);
      read_addrCompare1 : in  unsigned(31 downto 0);
      read_addrCompare2 : in  unsigned(31 downto 0);
      read_hit          : out std_logic;
      read_data         : out std_logic_vector(31 downto 0) := (others => '0');
      
      fill_request      : in  std_logic;
      fill_addrData     : in  unsigned(31 downto 0);
      fill_addrTag      : in  unsigned(31 downto 0);
      fill_done         : out std_logic := '0';
      
      CacheCommandEna   : in  std_logic;
      CacheCommand      : in  unsigned(4 downto 0);
      CacheCommandAddr  : in  unsigned(31 downto 0);
      
      TagLo_Valid       : in  std_logic;
      TagLo_Addr        : in  unsigned(19 downto 0);

      SS_reset          : in  std_logic
   );
end entity;

architecture arch of cpu_instrcache is

   -- tags
   signal tag_address_a    : std_logic_vector(8 downto 0) := (others => '0');
   signal tag_data_a       : std_logic_vector(20 downto 0) := (others => '0');
   signal tag_wren_a       : std_logic := '0';
   signal tag_address_b1   : std_logic_vector(8 downto 0);
   signal tag_address_b2   : std_logic_vector(8 downto 0);
   signal tag_q_b1         : std_logic_vector(20 downto 0);
   signal tag_q_b2         : std_logic_vector(20 downto 0);
   signal fill_addrTag_sav : unsigned(13 downto 0) := (others => '0');

   signal read_hit1        : std_logic;
   signal read_hit2        : std_logic;

   -- data
   signal fill_addrTag_1x  : unsigned(8 downto 0) := (others => '0');
   signal fill_addrTag_2x  : unsigned(8 downto 0) := (others => '0');
   signal ram_grant_2x     : std_logic := '0';
   signal cache_addr_a     : unsigned(10 downto 0) := (others => '0');
   signal cache_wr_a       : std_logic;
   
   signal cache_address_b  : std_logic_vector(11 downto 0);
   signal cache_q_b        : std_logic_vector(31 downto 0);
   
   -- state machine
   type tState is
   (
      IDLE,
      CLEARCACHE,
      FILL
   );
   signal state : tstate := IDLE;
   
   signal fill_latched : std_logic := '0';
   
begin 

   -- use two tag rams, so different fetch paths can be calculated in parallel to improve timing

   read_hit <= read_hit2 when (read_select = '1') else read_hit1;

   ------------------ tags
   itagram1 : entity mem.RamMLAB
   generic map
   (
      width      => 21, -- 20 bits(31..12) of address + 1 bit valid
      widthad    => 9
   )
   port map
   (
      inclock    => clk93,
      wren       => tag_wren_a,
      data       => tag_data_a,
      wraddress  => tag_address_a,
      rdaddress  => tag_address_b1,
      q          => tag_q_b1
   );
   
   tag_address_b1 <= std_logic_vector(read_addr1(13 downto 5));
   read_hit1      <= '1' when (unsigned(tag_q_b1(19 downto 0)) = read_addrCompare1(31 downto 12) and tag_q_b1(20) = '1') else '0';
   
   itagram2 : entity mem.RamMLAB
   generic map
   (
      width      => 21, -- 20 bits(31..12) of address + 1 bit valid
      widthad    => 9
   )
   port map
   (
      inclock    => clk93,
      wren       => tag_wren_a,
      data       => tag_data_a,
      wraddress  => tag_address_a,
      rdaddress  => tag_address_b2,
      q          => tag_q_b2
   );
   
   tag_address_b2 <= std_logic_vector(read_addr2(13 downto 5));
   read_hit2      <= '1' when (unsigned(tag_q_b2(19 downto 0)) = read_addrCompare2(31 downto 12) and tag_q_b2(20) = '1') else '0';

   --------- data
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         fill_addrTag_1x <= fill_addrTag_sav(13 downto 5);
      end if;
   end process;
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         fill_addrTag_2x <= fill_addrTag_1x;
      
         if (ram_grant = '1'and ram_active = '1') then
            ram_grant_2x <= '1';
         end if;
         
         if (ram_grant = '1') then
            cache_addr_a <= fill_addrTag_2x & "00";
         elsif (ddr3_DOUT_READY = '1') then
            cache_addr_a <= cache_addr_a + 1;
            if (ram_grant_2x = '1' and cache_addr_a(1 downto 0) = "11") then
               ram_grant_2x <= '0';
            end if;
         end if;
         
      end if;
   end process;

   cache_wr_a    <= ram_grant_2x and ddr3_DOUT_READY;

   icache: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 11,
      data_width_a  => 64,
      addr_width_b  => 12,
      data_width_b  => 32
   )
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(cache_addr_a),
      data_a      => ddr3_DOUT,
      wren_a      => cache_wr_a,
      
      clock_b     => clk93,
      clken_b     => ce_93,
      address_b   => cache_address_b,
      data_b      => x"00000000",
      wren_b      => '0',
      q_b         => cache_q_b
   );
   
   cache_address_b <= std_logic_vector(fill_addrTag_sav(13 downto 2))  when (state /= IDLE) else
                      std_logic_vector(read_addr2(13 downto 2)) when (read_select = '1') else
                      std_logic_vector(read_addr1(13 downto 2));
   
   read_data       <= byteswap32(cache_q_b);
   
   process (clk93)
   begin
      if rising_edge(clk93) then

         tag_wren_a  <= '0';
         fill_done   <= '0';
         ram_request <= '0';
         
         if (fill_request = '1') then
            fill_latched <= '1';
         end if;

         if (SS_reset = '1') then
            state          <= CLEARCACHE;
            tag_data_a     <= (others => '0');
            tag_address_a  <= (others => '0');
            tag_wren_a     <= '1';
            fill_latched   <= '0';
         else

            case(state) is
            
               when IDLE =>
                  fill_addrTag_sav <= fill_addrTag(13 downto 0);
                  if (CacheCommandEna = '1' and (CacheCommand = 5x"00" or CacheCommand = 5x"10")) then
                     -- HACK!
                     -- todo: should only clear if tag matches
                     tag_wren_a     <= '1';
                     tag_data_a     <= (others => '0');
                     tag_address_a  <= std_logic_vector(CacheCommandAddr(13 downto 5));
                  elsif (CacheCommandEna = '1' and CacheCommand = 5x"08") then
                     tag_wren_a     <= '1';
                     tag_data_a     <= TagLo_Valid & std_logic_vector(TagLo_Addr(19 downto 0));
                     tag_address_a  <= std_logic_vector(CacheCommandAddr(13 downto 5));
                  elsif (fill_request = '1' or fill_latched = '1') then
                     state          <= FILL;
                     ram_request    <= '1';
                     fill_latched   <= '0';
                  end if;
                  
               when CLEARCACHE =>
                  tag_wren_a     <= '1';
                  if (tag_address_a /= 9x"1FF") then
                     tag_address_a <= std_logic_vector(unsigned(tag_address_a) + 1);
                  else
                     state          <= IDLE;
                  end if;
                  
               when FILL =>
                  if (ram_done = '1') then
                     state          <= IDLE;
                     tag_wren_a     <= '1';
                     tag_data_a     <= '1' & std_logic_vector(fill_addrData(31 downto 12));
                     tag_address_a  <= std_logic_vector(fill_addrTag_sav(13 downto 5));
                     fill_done      <= '1'; 
                  end if;
                  
            end case;  
            
         end if;

      end if;
   end process;

   
end architecture;




























