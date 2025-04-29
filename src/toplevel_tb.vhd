library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity toplevel_tb is
--  Port ( );
end toplevel_tb;

architecture Behavioral of toplevel_tb is

-- this component is a vhdl model of what the actual ADC card looks like to the FPGA,
-- it creates an LVDS clock and 8 LVDS data signals.
-- this particular device puts out a fixed data pattern which represents (if read correctly)
-- 0, 7070, 10000, 7070, 0, -7070, -1000, -7070, 0, 7070 ...etc. 
-- the model outputs 'X' at times when the data would not be wise to sample (i.e. right around when it is changing)
component ad_9467_model is
  Port (dco_p : out std_logic;
        dco_n : out std_logic;
        -- data out.  dout(7) corresponds to the line D15/14, 6 is 13/12...etc
        dout_p : out std_logic_vector(7 downto 0);
        dout_n : out std_logic_vector(7 downto 0)
         );
end component;

-- this is the component that was discussed in class and is the custom logic inside the FPGA which will
-- be responsible for taking the signals from the ADC and creating signed 16-bit data from it.
-- ADC_DATA, and ADC_CLK are the two signals which represent that data.  ADC_DATA can be used on the rising edge
-- of ADC_CLK by any part of the FPGA that wants data from the ADC.
-- PSINCDEC, PSEN, PSCLK, PSDONE are used to control the phase of the ADC_CLK and line it up for reliable data-reading
component AD9467_INTERFACE is 
  Port ( 
    PSINCDEC : in std_logic;
    PSEN : in std_logic;
    PSCLK : in std_logic;
    PSDONE : out std_logic;
    Unshifted_clk : out std_logic;
    ADCCLK : out std_logic;
    ADC_DATA : out std_logic_vector (15 downto 0);
    -- LVDS signals from AD9467
    Din_p : in std_logic_vector (7 downto 0);
    Din_n : in std_logic_vector (7 downto 0);
    CLK_p : in std_logic;
    CLK_N : in std_logic
    );
end component;

signal ADC_DATA: std_logic_vector (15 downto 0);
signal dco_p, dco_n : std_logic;
signal dout_p, dout_n : std_logic_vector(7 downto 0);
signal psclk, psen, reset, PSDONE : std_logic;
constant TbPeriod : time := 8 ns;
signal TbClock : std_logic := '0';
signal Unshifted_clk , ADCCLK : std_logic;
signal psenCnt : natural := 0;

begin
TbClock <= not TbClock after 2.5ns; -- create a 200MHz clock for kicks, this clock is arbitrary and is just for the PSCLK
psclk <= TbClock; -- this will be the board clock 125MHz

stimuli : process
    constant STEP_SIZE_PS : real := 17.9; -- phase shift step size (ps)
    constant CLOCK_PERIOD_NS : real := 8.0; -- ADC_CLK period (ns)
    constant NUM_STEPS : integer := integer((CLOCK_PERIOD_NS * 1000.0) / STEP_SIZE_PS); 
    -- 8 ns = 8000 ps, 8000 / 17.9 ≈ 447 steps
begin
    PSEN <= '0';
    wait for 10 us;
    -- TODO : in here, write some code to create PSEN signals which will rotate the the ADC_CLK a full 360 degrees from 
    -- its starting location.  Then stop rotating.
    for i in 0 to NUM_STEPS-1 loop
        wait until rising_edge(TbClock);
        psenCnt <= psenCnt + 1;
        -- Start a phase shift
        PSEN <= '1';
        wait until rising_edge(TbClock);
        PSEN <= '0';

        -- Now wait for PSDONE to become 1
        wait until PSDONE = '1';
        
    end loop;

    
    wait; 
 end process;

-- instantiate the ADC itself
ADC_inst: ad_9467_model 
  Port map (
        dco_p => dco_p,
        dco_n => dco_n,
        dout_p => dout_p, 
        dout_n => dout_n);
        

-- instantiate the ADC Interface
ADCInterface_inst : AD9467_INTERFACE
    port map (
        PSINCDEC => '1',
        PSEN => psen,
        PSCLK => TbClock,
        PSDONE => PSDONE,
        Unshifted_clk => Unshifted_clk,
        ADCCLK => ADCCLK,
        ADC_DATA => ADC_DATA,
        -- LVDS signals from AD9467
        Din_p => dout_p,
        Din_n => dout_n,
        CLK_p => dco_p,
        CLK_N => dco_n
        );

end Behavioral;
