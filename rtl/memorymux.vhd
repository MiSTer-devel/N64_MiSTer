library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pFunctions.all;

entity memorymux is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      FASTBUS              : in  std_logic;
      FASTRAM              : in  std_logic;
      
      error                : out std_logic;
     
      mem_request          : in  std_logic;
      mem_rnw              : in  std_logic; 
      mem_address          : in  unsigned(31 downto 0); 
      mem_req64            : in  std_logic; 
      mem_size             : in  unsigned(2 downto 0) := (others => '0');
      mem_writeMask        : in  std_logic_vector(7 downto 0); 
      mem_dataWrite        : in  std_logic_vector(63 downto 0); 
      mem_dataRead         : out std_logic_vector(63 downto 0); 
      mem_done             : out std_logic;
      
      rdram_request        : out std_logic := '0';
      rdram_rnw            : out std_logic := '0'; 
      rdram_address        : out unsigned(27 downto 0):= (others => '0');
      rdram_burstcount     : out unsigned(9 downto 0):= (others => '0');
      rdram_writeMask      : out std_logic_vector(7 downto 0) := (others => '0'); 
      rdram_dataWrite      : out std_logic_vector(63 downto 0) := (others => '0');
      rdram_done           : in  std_logic;
      rdram_dataRead       : in  std_logic_vector(63 downto 0);
      
      bus_RDR_addr         : out unsigned(19 downto 0) := (others => '0'); 
      bus_RDR_dataWrite    : out std_logic_vector(31 downto 0);
      bus_RDR_read         : out std_logic;
      bus_RDR_write        : out std_logic;
      bus_RDR_dataRead     : in  std_logic_vector(31 downto 0);
      bus_RDR_done         : in  std_logic;         
      
      bus_RSP_addr         : out unsigned(19 downto 0) := (others => '0'); 
      bus_RSP_dataWrite    : out std_logic_vector(31 downto 0);
      bus_RSP_read         : out std_logic;
      bus_RSP_write        : out std_logic;
      bus_RSP_dataRead     : in  std_logic_vector(31 downto 0);
      bus_RSP_done         : in  std_logic;           
      
      bus_RDP_addr         : out unsigned(19 downto 0) := (others => '0'); 
      bus_RDP_dataWrite    : out std_logic_vector(31 downto 0);
      bus_RDP_read         : out std_logic;
      bus_RDP_write        : out std_logic;
      bus_RDP_dataRead     : in  std_logic_vector(31 downto 0);
      bus_RDP_done         : in  std_logic;      
      
      bus_MI_addr          : out unsigned(19 downto 0) := (others => '0'); 
      bus_MI_dataWrite     : out std_logic_vector(31 downto 0);
      bus_MI_read          : out std_logic;
      bus_MI_write         : out std_logic;
      bus_MI_dataRead      : in  std_logic_vector(31 downto 0);
      bus_MI_done          : in  std_logic;      
      
      bus_VI_addr          : out unsigned(19 downto 0) := (others => '0'); 
      bus_VI_dataWrite     : out std_logic_vector(31 downto 0);
      bus_VI_read          : out std_logic;
      bus_VI_write         : out std_logic;
      bus_VI_dataRead      : in  std_logic_vector(31 downto 0);
      bus_VI_done          : in  std_logic;
      
      bus_AI_addr          : out unsigned(19 downto 0) := (others => '0'); 
      bus_AI_dataWrite     : out std_logic_vector(31 downto 0);
      bus_AI_read          : out std_logic;
      bus_AI_write         : out std_logic;
      bus_AI_dataRead      : in  std_logic_vector(31 downto 0);
      bus_AI_done          : in  std_logic;      
      
      bus_PIreg_addr       : out unsigned(19 downto 0) := (others => '0'); 
      bus_PIreg_dataWrite  : out std_logic_vector(31 downto 0);
      bus_PIreg_read       : out std_logic;
      bus_PIreg_write      : out std_logic;
      bus_PIreg_dataRead   : in  std_logic_vector(31 downto 0);
      bus_PIreg_done       : in  std_logic;
      
      bus_RI_addr          : out unsigned(19 downto 0) := (others => '0'); 
      bus_RI_dataWrite     : out std_logic_vector(31 downto 0);
      bus_RI_read          : out std_logic;
      bus_RI_write         : out std_logic;
      bus_RI_dataRead      : in  std_logic_vector(31 downto 0);
      bus_RI_done          : in  std_logic;      
      
      bus_SI_addr          : out unsigned(19 downto 0) := (others => '0'); 
      bus_SI_dataWrite     : out std_logic_vector(31 downto 0);
      bus_SI_read          : out std_logic;
      bus_SI_write         : out std_logic;
      bus_SI_dataRead      : in  std_logic_vector(31 downto 0);
      bus_SI_done          : in  std_logic;
      
      bus_PIcart_addr      : out unsigned(31 downto 0) := (others => '0'); 
      bus_PIcart_dataWrite : out std_logic_vector(31 downto 0);
      bus_PIcart_read      : out std_logic;
      bus_PIcart_write     : out std_logic;
      bus_PIcart_dataRead  : in  std_logic_vector(31 downto 0);
      bus_PIcart_done      : in  std_logic;
      
      bus_PIF_addr         : out unsigned(10 downto 0) := (others => '0'); 
      bus_PIF_dataWrite    : out std_logic_vector(31 downto 0);
      bus_PIF_read         : out std_logic;
      bus_PIF_write        : out std_logic;
      bus_PIF_dataRead     : in  std_logic_vector(31 downto 0);
      bus_PIF_done         : in  std_logic
   );
end entity;

architecture arch of memorymux is
  
   type tState is
   (
      IDLE,
      WAITSLOW,
      WAITBUS,
      WAITRAM
   );
   signal state                  : tState := IDLE;
   
   signal dataFromBusses : std_logic_vector(31 downto 0);
   signal bus_done       : std_logic;
   
   signal last_addr      : unsigned(31 downto 0); 
   
   signal bus_slow       : integer range 0 to 4095;

begin 

   process (mem_address, mem_request, mem_rnw, mem_dataWrite, mem_req64)
      variable address      : unsigned(28 downto 0);
      variable data_rotated : std_logic_vector(31 downto 0);
   begin
   
      address      := mem_address(28 downto 0);
      if (mem_req64 = '1') then
         data_rotated := byteswap32(mem_dataWrite(63 downto 32));
      else
         data_rotated := byteswap32(mem_dataWrite(31 downto 0));
      end if;
      
      -- RDRAM Regs
      bus_RDR_read       <= '0';
      bus_RDR_write      <= '0';
      bus_RDR_addr       <= mem_address(19 downto 2) & "00";
      bus_RDR_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#03F00000# and address < 16#04000000#) then
         bus_RDR_read    <= mem_rnw;
         bus_RDR_write   <= not mem_rnw;
      end if;        
      
      -- rsp
      bus_RSP_read       <= '0';
      bus_RSP_write      <= '0';
      bus_RSP_addr       <= mem_address(19 downto 2) & "00";
      bus_RSP_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#04000000# and address < 16#04100000#) then
         bus_RSP_read    <= mem_rnw;
         bus_RSP_write   <= not mem_rnw;
      end if;    

      -- RDP
      bus_RDP_read       <= '0';
      bus_RDP_write      <= '0';
      bus_RDP_addr       <= mem_address(19 downto 2) & "00";
      bus_RDP_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#04100000# and address < 16#04200000#) then
         bus_RDP_read    <= mem_rnw;
         bus_RDP_write   <= not mem_rnw;
      end if;        
            
      -- MI
      bus_MI_read       <= '0';
      bus_MI_write      <= '0';
      bus_MI_addr       <= mem_address(19 downto 2) & "00";
      bus_MI_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#04300000# and address < 16#04400000#) then
         bus_MI_read    <= mem_rnw;
         bus_MI_write   <= not mem_rnw;
      end if;        
      
      -- VI
      bus_VI_read       <= '0';
      bus_VI_write      <= '0';
      bus_VI_addr       <= mem_address(19 downto 2) & "00";
      bus_VI_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#04400000# and address < 16#04500000#) then
         bus_VI_read    <= mem_rnw;
         bus_VI_write   <= not mem_rnw;
      end if;            
      
      -- AI
      bus_AI_read       <= '0';
      bus_AI_write      <= '0';
      bus_AI_addr       <= mem_address(19 downto 2) & "00";
      bus_AI_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#04500000# and address < 16#04600000#) then
         bus_AI_read    <= mem_rnw;
         bus_AI_write   <= not mem_rnw;
      end if;      
      
      -- PI registers
      bus_PIreg_read       <= '0';
      bus_PIreg_write      <= '0';
      bus_PIreg_addr       <= mem_address(19 downto 2) & "00";
      bus_PIreg_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#04600000# and address < 16#04700000#) then
         bus_PIreg_read    <= mem_rnw;
         bus_PIreg_write   <= not mem_rnw;
      end if;
      
      -- RI
      bus_RI_read       <= '0';
      bus_RI_write      <= '0';
      bus_RI_addr       <= mem_address(19 downto 2) & "00";
      bus_RI_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#04700000# and address < 16#04800000#) then
         bus_RI_read    <= mem_rnw;
         bus_RI_write   <= not mem_rnw;
      end if;       
      
      -- SI
      bus_SI_read       <= '0';
      bus_SI_write      <= '0';
      bus_SI_addr       <= mem_address(19 downto 2) & "00";
      bus_SI_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#04800000# and address < 16#04900000#) then
         bus_SI_read    <= mem_rnw;
         bus_SI_write   <= not mem_rnw;
      end if; 
      
      -- PI cart
      bus_PIcart_read       <= '0';
      bus_PIcart_write      <= '0';
      bus_PIcart_addr       <= mem_address;
      bus_PIcart_dataWrite  <= data_rotated;
      if (mem_request = '1' and address >= 16#05000000# and address < 16#1FC00000#) then
         bus_PIcart_read    <= mem_rnw;
         bus_PIcart_write   <= not mem_rnw;
      end if;
      if (mem_request = '1' and address >= 16#1FD00000# and address <= 16#1FFFFFFF#) then
         bus_PIcart_read    <= mem_rnw;
         bus_PIcart_write   <= not mem_rnw;
      end if;
      
      -- PIF
      bus_PIF_read       <= '0';
      bus_PIF_write      <= '0';
      bus_PIF_addr       <= mem_address(10 downto 2) & "00";
      bus_PIF_dataWrite  <= byteswap32(data_rotated);
      if (mem_request = '1' and address >= 16#1FC00000# and address < 16#1FC00800#) then
         bus_PIF_read    <= mem_rnw;
         bus_PIF_write   <= not mem_rnw;
      end if;

   end process;

   dataFromBusses <= bus_RDR_dataRead or bus_RSP_dataRead or bus_RDP_dataRead or bus_MI_dataRead or bus_VI_dataRead or bus_AI_dataRead or bus_PIreg_dataRead or bus_RI_dataRead or 
                     bus_SI_dataRead or bus_PIcart_dataRead or bus_PIF_dataRead;
   
   bus_done <= bus_RDR_done or bus_RSP_done or bus_RDP_done or bus_MI_done or bus_VI_done or bus_AI_done or bus_PIreg_done or bus_RI_done or 
               bus_SI_done or bus_PIcart_done or bus_PIF_done;

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         error          <= '0';
         mem_done       <= '0';
         rdram_request  <= '0';
         
         if (bus_slow > 0) then
            bus_slow <= bus_slow - 1;
         end if;
         
         if (reset = '1') then

            state            <= IDLE;
           
         else
         
            case (state) is
               when IDLE =>
               
                  last_addr <= mem_address;
                  
                  rdram_rnw       <= mem_rnw;
                  rdram_address   <= mem_address(27 downto 3) & "000";
                  rdram_burstcount<= 7x"00" & mem_size;
                  
                  rdram_dataWrite <= mem_dataWrite(31 downto 0) & mem_dataWrite(63 downto 32);
                  rdram_writeMask <= mem_writeMask(3 downto 0) & mem_writeMask(7 downto 4);
                  if (mem_req64 = '0') then
                     if (mem_address(2) = '1') then
                        rdram_writeMask <= mem_writeMask(3 downto 0) & "0000";
                     else
                        rdram_writeMask <= "0000" & mem_writeMask(3 downto 0);
                        rdram_dataWrite(31 downto 0) <= mem_dataWrite(31 downto 0);
                     end if;
                  end if;
               
                  if (mem_request = '1') then
                  
                     if (mem_address(28 downto 0) < 16#03F00000#) then -- RAM
                        state           <= WAITRAM;
                        rdram_request   <= '1';
                        if (mem_rnw = '1') then
                           bus_slow <= 15;
                        else
                           bus_slow <= 6;
                        end if;                     
                        
                         
                     elsif (mem_address(28 downto 0) >= 16#03F00000# and mem_address(28 downto 0) < 16#04000000#) then -- RDRAM Regs
                        state    <= WAITBUS; 
                        if (mem_rnw = '1') then
                           bus_slow <= 15;
                        else
                           bus_slow <= 3;
                        end if;                     
                        
                     elsif (mem_address(28 downto 0) >= 16#04000000# and mem_address(28 downto 0) < 16#04040000#) then -- RSP RAMs
                        state    <= WAITBUS; 
                        if (mem_rnw = '1') then
                           bus_slow <= 13;
                        else
                           bus_slow <= 3;
                        end if;
                        
                     elsif (mem_address(28 downto 0) >= 16#04040000# and mem_address(28 downto 0) < 16#04100000#) then -- RSP Regs
                        state    <= WAITBUS; 
                        if (mem_rnw = '1') then
                           bus_slow <= 9;
                        else
                           bus_slow <= 3;
                        end if;

                     elsif (mem_address(28 downto 0) >= 16#04100000# and mem_address(28 downto 0) < 16#04200000#) then -- RDP
                        state    <= WAITBUS;     
                        if (mem_rnw = '1') then
                           bus_slow <= 9;
                        else
                           bus_slow <= 3;
                        end if;
                        
                     elsif (mem_address(28 downto 0) >= 16#04300000# and mem_address(28 downto 0) < 16#04400000#) then -- MI
                        state    <= WAITBUS;  
                        if (mem_rnw = '1') then
                           bus_slow <= 2;
                        else
                           bus_slow <= 0;
                        end if;
                        
                     elsif (mem_address(28 downto 0) >= 16#04400000# and mem_address(28 downto 0) < 16#04500000#) then -- VI
                        state    <= WAITBUS;    
                        bus_slow <= 9;
                        
                     elsif (mem_address(28 downto 0) >= 16#04500000# and mem_address(28 downto 0) < 16#04600000#) then -- AI
                        state    <= WAITBUS;     
                        if (mem_rnw = '1') then
                           bus_slow <= 9;
                        else
                           bus_slow <= 3;
                        end if;                        
                        
                     elsif (mem_address(28 downto 0) >= 16#04600000# and mem_address(28 downto 0) < 16#04700000#) then -- PI registers
                        state    <= WAITBUS;
                        if (mem_rnw = '1') then
                           bus_slow <= 9;
                        else
                           bus_slow <= 3;
                        end if;
                        
                     elsif (mem_address(28 downto 0) >= 16#04700000# and mem_address(28 downto 0) < 16#04800000#) then -- RI
                        state    <= WAITBUS;   
                        if (mem_rnw = '1') then
                           bus_slow <= 9;
                        else
                           bus_slow <= 3;
                        end if;
                         
                     elsif (mem_address(28 downto 0) >= 16#04800000# and mem_address(28 downto 0) < 16#04900000#) then -- SI
                        state    <= WAITBUS;       
                        if (mem_rnw = '1') then
                           bus_slow <= 9;
                        else
                           bus_slow <= 3;
                        end if;

                     elsif (mem_address(28 downto 0) >= 16#05000000# and mem_address(28 downto 0) < 16#1FC00000#) then -- PI cart
                        state    <= WAITBUS;   
                        if (mem_rnw = '1') then
                           bus_slow <= 137;
                        else
                           bus_slow <= 3;
                        end if;
                        
                     elsif (mem_address(28 downto 0) >= 16#1FC00000# and mem_address(28 downto 0) < 16#1FC007C0#) then -- PIF ROM
                        state    <= WAITBUS;
                        bus_slow <= 230;
                        if (mem_rnw = '1') then
                           bus_slow <= 230;
                        else
                           bus_slow <= 3;
                        end if;
                         
                     elsif (mem_address(28 downto 0) >= 16#1FC007C0# and mem_address(28 downto 0) < 16#1FC00800#) then -- PIF RAM
                        state    <= WAITBUS;
                        if (mem_rnw = '1') then
                           bus_slow <= 1910;
                        else
                           bus_slow <= 3;
                        end if;
                        
                     elsif (mem_address(28 downto 0) >= 16#1FD00000# and mem_address(28 downto 0) <= 16#1FFFFFFF#) then -- PI cart
                        state    <= WAITBUS;
                        if (mem_rnw = '1') then
                           bus_slow <= 137;
                        else
                           bus_slow <= 3;
                        end if;
                        
                     else
                        -- synthesis translate_off
                        report to_hstring(mem_address(28 downto 0));
                        -- synthesis translate_on
                        report "Accessed unmapped memory mux area" severity failure; 
                        error <= '1';
                     end if;
                     
                  end if;
                  
               when WAITSLOW =>
                  if (bus_slow = 0) then
                     mem_done <= '1';
                     state    <= IDLE;
                  end if;
                  
               when WAITBUS =>
                  if (bus_done = '1') then
                     if (bus_slow = 0 or FASTBUS = '1') then
                        mem_done <= '1';
                        state    <= IDLE;
                     else
                        state    <= WAITSLOW;
                     end if;
                     case (last_addr(1 downto 0)) is
                        when "00" => mem_dataRead(31 downto 0) <= dataFromBusses(7 downto 0) & dataFromBusses(15 downto 8) & dataFromBusses(23 downto 16) & dataFromBusses(31 downto 24);
                        when "01" => mem_dataRead(7 downto 0)  <= dataFromBusses(23 downto 16);
                        when "10" => mem_dataRead(15 downto 0) <= dataFromBusses(7 downto 0) & dataFromBusses(15 downto 8);
                        when "11" => mem_dataRead(7 downto 0)  <= dataFromBusses(7 downto 0);
                        when others => null;
                     end case;
                  end if;
                  
               when WAITRAM =>
                  if (rdram_done = '1') then
                     if (bus_slow = 0 or FASTRAM = '1') then
                        mem_done <= '1';
                        state    <= IDLE;
                     else
                        state    <= WAITSLOW;
                     end if;
                     case (last_addr(2 downto 0)) is
                        when "000" => mem_dataRead <= rdram_dataRead;
                        when "001" => mem_dataRead(7 downto 0)  <= rdram_dataRead(15 downto 8);
                        when "010" => mem_dataRead(15 downto 0) <= rdram_dataRead(31 downto 16);
                        when "011" => mem_dataRead(7 downto 0)  <= rdram_dataRead(31 downto 24);
                        when "100" => mem_dataRead(31 downto 0) <= rdram_dataRead(63 downto 32);
                        when "101" => mem_dataRead(7 downto 0)  <= rdram_dataRead(47 downto 40);
                        when "110" => mem_dataRead(15 downto 0) <= rdram_dataRead(63 downto 48);
                        when "111" => mem_dataRead(7 downto 0)  <= rdram_dataRead(63 downto 56);
                        when others => null;
                     end case;
                  end if;
                 
            
            end case;

         end if;
      end if;
   end process;  

end architecture;





