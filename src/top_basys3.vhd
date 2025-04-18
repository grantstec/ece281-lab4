library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


-- Lab 4
entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(15 downto 0);
        btnU    :   in std_logic; -- master_reset
        btnL    :   in std_logic; -- clk_reset
        btnR    :   in std_logic; -- fsm_reset
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is

    -- signal declarations
    
    signal slow_clk : std_logic := '0';
    signal master_reset : std_logic := '0';
    signal clk_reset : std_logic := '0';
    signal fsm_reset : std_logic := '0';
    
    -- First elevator signals
    signal elevator1_floor : std_logic_vector(3 downto 0) := "0010"; -- Initialize to floor 2
    signal elevator1_stop : std_logic := '0';
    signal elevator1_up_down : std_logic := '0';
    
    -- Second elevator signals
    signal elevator2_floor : std_logic_vector(3 downto 0) := "0010"; -- Initialize to floor 2
    signal elevator2_stop : std_logic := '0';
    signal elevator2_up_down : std_logic := '0';
    
    -- Display signals
    signal display0 : std_logic_vector(3 downto 0) := "0000"; -- Rightmost display (elevator 1)
    signal display1 : std_logic_vector(3 downto 0) := "1111"; -- "F" for "floor"
    signal display2 : std_logic_vector(3 downto 0) := "0000"; -- Second from left (elevator 2)
    signal display3 : std_logic_vector(3 downto 0) := "1111"; -- "F" for "floor"
    signal display_data : std_logic_vector(3 downto 0) := "0000";
    signal display_select : std_logic_vector(3 downto 0) := "0000";

	-- component declarations
    component sevenseg_decoder is
        port (
            i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
            o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
        );
    end component sevenseg_decoder;
    
    component elevator_controller_fsm is
		Port (
            i_clk        : in  STD_LOGIC;
            i_reset      : in  STD_LOGIC;
            is_stopped   : in  STD_LOGIC;
            go_up_down   : in  STD_LOGIC;
            o_floor : out STD_LOGIC_VECTOR (3 downto 0)		   
		 );
	end component elevator_controller_fsm;
	
	component TDM4 is
		generic ( constant k_WIDTH : natural  := 4); -- bits in input and output
        Port ( i_clk		: in  STD_LOGIC;
           i_reset		: in  STD_LOGIC; -- asynchronous
           i_D3 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D2 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D1 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D0 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_data		: out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_sel		: out STD_LOGIC_VECTOR (3 downto 0)	-- selected data line (one-cold)
	   );
    end component TDM4;
     
	component clock_divider is
        generic ( constant k_DIV : natural := 2	); -- How many clk cycles until slow clock toggles
                                                   -- Effectively, you divide the clk double this 
                                                   -- number (e.g., k_DIV := 2 --> clock divider of 4)
        port ( 	i_clk    : in std_logic;
                i_reset  : in std_logic;		   -- asynchronous
                o_clk    : out std_logic		   -- divided (slow) clock
        );
    end component clock_divider;
	
begin
	-- PORT MAPS ----------------------------------------
    clk_div_inst : clock_divider
        generic map (k_DIV => 25000000)
        port map (
            i_clk => clk,
            i_reset => clk_reset,
            o_clk => slow_clk
        );
    
    elevator1_controller : elevator_controller_fsm
        port map (
            i_clk => slow_clk,
            i_reset => fsm_reset,
            is_stopped => elevator1_stop,
            go_up_down => elevator1_up_down,
            o_floor => elevator1_floor
        );
    
    elevator2_controller : elevator_controller_fsm
        port map (
            i_clk => slow_clk,
            i_reset => fsm_reset,
            is_stopped => elevator2_stop,
            go_up_down => elevator2_up_down,
            o_floor => elevator2_floor
        );
    
    display_tdm : TDM4
        generic map (k_WIDTH => 4)
        port map (
            i_clk => clk, -- Use fast clock for display multiplexing
            i_reset => master_reset,
            i_D3 => display3,
            i_D2 => display2,
            i_D1 => display1,
            i_D0 => display0,
            o_data => display_data,
            o_sel => display_select
        );
    
    -- 7-segment decoder
    seg_decoder : sevenseg_decoder
        port map (
            i_Hex => display_data,
            o_seg_n => seg
        );
    	
	
	-- CONCURRENT STATEMENTS ----------------------------
		-- Elevator 1: sw(0) for Up/Down, sw(1) for Stop
	elevator1_up_down <= sw(0);
	elevator1_stop <= sw(1);
	
	-- Elevator 2: sw(15) for Up/Down, sw(14) for Stop
	elevator2_up_down <= sw(15);
	elevator2_stop <= sw(14);
	
	-- Connect display data
	display0 <= elevator1_floor; -- Rightmost display shows elevator 1 floor
	display2 <= elevator2_floor; -- Second from left shows elevator 2 floor
	
	-- Connect displays to anodes (active low)
	an <= display_select;
	
	-- LED 15 gets the FSM slow clock signal. The rest are grounded.
	led(15) <= slow_clk;
	-- leave unused switches UNCONNECTED. Ignore any warnings this causes.
	led(14 downto 0) <= (others => '0');
	-- reset signals
    master_reset <= btnU; -- Master reset (resets both clock and FSM)
	clk_reset <= btnL or master_reset; -- Clock reset
	fsm_reset <= btnR or master_reset; -- FSM reset
	
end top_basys3_arch;
