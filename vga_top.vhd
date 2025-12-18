library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY vga_top IS
    PORT (
        clk_in    : IN STD_LOGIC;
        vga_red   : OUT STD_LOGIC_VECTOR (2 DOWNTO 0);
        vga_green : OUT STD_LOGIC_VECTOR (2 DOWNTO 0);
        vga_blue  : OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
        vga_hsync : OUT STD_LOGIC;
        vga_vsync : OUT STD_LOGIC;
        SEG7_anode : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
        SEG7_seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0);
        bt_clr : IN STD_LOGIC;    -- Center button: Reset game/score AND start song
        bt_strt : IN STD_LOGIC;   -- Left button: Manual red note (column 2)
        bt_strt1 : IN STD_LOGIC;  -- Down button: Manual green note (column 1)
        bt_strt2 : IN STD_LOGIC;  -- Right button: Manual purple note (column 3)
        bt_strt3 : IN STD_LOGIC;  -- Up button: Manual blue note (column 4)
        SW : IN STD_LOGIC;        -- Switch 0: Toggle song mode (ON=song, OFF=manual)
        LED : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- Debug LEDs
        -- Audio output
        AUD_PWM : OUT STD_LOGIC;  -- PWM audio signal to 3.5mm jack
        AUD_SD  : OUT STD_LOGIC;  -- Audio shutdown (active low, set HIGH to enable)
        KB_col : OUT STD_LOGIC_VECTOR (4 DOWNTO 1);
        KB_row : IN STD_LOGIC_VECTOR (4 DOWNTO 1)
    );
END vga_top;

ARCHITECTURE Behavioral OF vga_top is
    SIGNAL pxl_clk : STD_LOGIC;
    
    -- VGA signals
    SIGNAL S_red, S_green, S_blue : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL fin_red, fin_green, fin_blue : STD_LOGIC;
    SIGNAL S_vsync : STD_LOGIC;
    SIGNAL S_pixel_row, S_pixel_col : STD_LOGIC_VECTOR (10 DOWNTO 0);
    
    -- Note column data
    SIGNAL Note_column1, Note_column2, Note_column3, Note_column4 : STD_LOGIC_VECTOR(599 downto 0);
    
    -- Timing and control
    SIGNAL cnt : std_logic_vector(32 DOWNTO 0) := (others => '0');
    SIGNAL kp_clk : STD_LOGIC;
    
    -- Keypad signals
    SIGNAL keypresses : STD_LOGIC_VECTOR(3 DOWNTO 0);
    
    -- Scoring signals
    SIGNAL total_score, blue_score, red_score, green_score, purple_score : std_logic_vector(31 DOWNTO 0);
    SIGNAL hit_signals_out, hit_signals_back : STD_LOGIC_VECTOR(3 DOWNTO 0);
    
    -- Individual color signals from each note column
    SIGNAL s_red1, s_red2, s_red3, s_red4 : STD_LOGIC;
    SIGNAL s_green1, s_green2, s_green3, s_green4 : STD_LOGIC;
    SIGNAL s_blue1, s_blue2, s_blue3, s_blue4 : STD_LOGIC;
    
    -- Song player signals
    SIGNAL song_note1, song_note2, song_note3, song_note4 : STD_LOGIC;
    SIGNAL song_position : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL song_playing, song_done : STD_LOGIC;
    SIGNAL song_start : STD_LOGIC := '0';
    SIGNAL song_start_prev : STD_LOGIC := '0';
    
    -- Combined note inputs (song + manual)
    SIGNAL note_input1, note_input2, note_input3, note_input4 : STD_LOGIC;
    
    -- Game state
    SIGNAL game_active : STD_LOGIC := '0';
    
    -- Song reset signal (only reset in manual mode)
    SIGNAL song_reset : STD_LOGIC := '0';
    
    -- Component declarations
    COMPONENT noteColumn IS
        PORT (
            clk       : IN STD_LOGIC;
            v_sync    : IN STD_LOGIC;
            pixel_row : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            pixel_col : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            horiz     : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            note_input: IN STD_LOGIC;
            hit_signal_in : IN std_logic;
            color : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            keypress     : IN STD_LOGIC;
            hit_signal_out : OUT STD_LOGIC;
            note_col_out  : OUT STD_LOGIC_VECTOR(599 DOWNTO 0);
            red       : OUT STD_LOGIC;
            green     : OUT STD_LOGIC;
            blue      : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT vga_sync IS
        PORT (
            pixel_clk : IN STD_LOGIC;
            red_in    : IN STD_LOGIC;
            green_in  : IN STD_LOGIC;
            blue_in   : IN STD_LOGIC;
            red_out   : OUT STD_LOGIC;
            green_out : OUT STD_LOGIC;
            blue_out  : OUT STD_LOGIC;
            hsync     : OUT STD_LOGIC;
            vsync     : OUT STD_LOGIC;
            pixel_row : OUT STD_LOGIC_VECTOR (10 DOWNTO 0);
            pixel_col : OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT colorCombiner IS
        PORT (
            clk          : IN STD_LOGIC;
            pixel_row    : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            pixel_col    : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            red_inputs   : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            green_inputs : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            blue_inputs  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            hit_signals  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            keypress_signals : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            red_out      : OUT STD_LOGIC;
            green_out    : OUT STD_LOGIC;
            blue_out     : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT buttonTracker IS
        PORT (
            clk          : IN  STD_LOGIC;
            reset        : IN  STD_LOGIC;
            keypress     : IN  STD_LOGIC;
            note_col_1   : IN  STD_LOGIC_VECTOR(599 DOWNTO 0);
            hit_sigB_1   : IN STD_LOGIC;
            hit_signal_1 : OUT STD_LOGIC;
            score        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;
    
    COMPONENT clk_wiz_0 is
        PORT (
            clk_in1  : in std_logic;
            clk_out1 : out std_logic
        );
    END COMPONENT;
    
    COMPONENT keypad IS
        PORT (
            samp_ck : IN STD_LOGIC;
            col : OUT STD_LOGIC_VECTOR (4 DOWNTO 1);
            row : IN STD_LOGIC_VECTOR (4 DOWNTO 1);
            value : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            keypress_out : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            hit : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT leddec16 IS
        PORT (
            dig : IN STD_LOGIC_VECTOR (2 DOWNTO 0);
            data : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
            anode : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
            seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0)
        );
    END COMPONENT;
    
    COMPONENT songPlayer IS
        PORT (
            clk           : IN  STD_LOGIC;
            reset         : IN  STD_LOGIC;
            start         : IN  STD_LOGIC;
            note_out_1    : OUT STD_LOGIC;
            note_out_2    : OUT STD_LOGIC;
            note_out_3    : OUT STD_LOGIC;
            note_out_4    : OUT STD_LOGIC;
            song_position : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            song_playing  : OUT STD_LOGIC;
            song_done     : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT toneGenerator IS
        PORT (
            clk         : IN  STD_LOGIC;
            reset       : IN  STD_LOGIC;
            hit_green   : IN  STD_LOGIC;
            hit_red     : IN  STD_LOGIC;
            hit_purple  : IN  STD_LOGIC;
            hit_blue    : IN  STD_LOGIC;
            audio_pwm   : OUT STD_LOGIC;
            audio_sd    : OUT STD_LOGIC
        );
    END COMPONENT;
    
BEGIN
    -- VGA driver only drives MSB of red, green & blue
    vga_red(1 DOWNTO 0) <= "00";
    vga_green(1 DOWNTO 0) <= "00";
    vga_blue(0) <= '0';
    
    -- Keypad clock derived from counter
    kp_clk <= cnt(15);
    
    -- Song reset only when SW is OFF (manual mode) and BTNC pressed
    song_reset <= (NOT SW) AND bt_clr;
    
    -- Debug LEDs to see what's happening
    -- LED(0) = SW state (ON when switch is up)
    -- LED(1) = song_playing state
    -- LED(2) = bt_clr button state  
    -- LED(3) = song start signal going to songPlayer
    LED(0) <= SW;
    LED(1) <= song_playing;
    LED(2) <= bt_clr;
    LED(3) <= song_start;
    
    -- Song start: directly pass button when in song mode (SW=1)
    -- The songPlayer does its own edge detection
    song_start <= bt_clr AND SW;
    
    -- Clock and control process
    ck_proc : process(clk_in)
    BEGIN
        IF rising_edge(clk_in) THEN
            cnt <= cnt + 1;
            total_score <= blue_score + red_score + green_score + purple_score;
        END IF;
    END PROCESS;
    
    -- Combine song notes with manual button notes
    -- SW = '1' (ON): Song mode - use song notes
    -- SW = '0' (OFF): Manual mode - use button inputs
    note_input1 <= song_note1 WHEN (SW = '1' AND song_playing = '1') ELSE bt_strt1;
    note_input2 <= song_note2 WHEN (SW = '1' AND song_playing = '1') ELSE bt_strt;
    note_input3 <= song_note3 WHEN (SW = '1' AND song_playing = '1') ELSE bt_strt2;
    note_input4 <= song_note4 WHEN (SW = '1' AND song_playing = '1') ELSE bt_strt3;
    
    -- Color signal assignments
    S_red(0) <= s_red1;
    S_red(1) <= s_red2;
    S_red(2) <= s_red3;
    S_red(3) <= s_red4;
    
    S_green(0) <= s_green1;
    S_green(1) <= s_green2;
    S_green(2) <= s_green3;
    S_green(3) <= s_green4;
    
    S_blue(0) <= s_blue1;
    S_blue(1) <= s_blue2;
    S_blue(2) <= s_blue3;
    S_blue(3) <= s_blue4;
    
    -- Song player instance
    -- Reset only when SW is OFF and BTNC pressed (manual mode reset)
    -- Start when SW is ON and BTNC pressed (song mode start)
    song_inst : songPlayer
    PORT MAP(
        clk           => clk_in,
        reset         => song_reset,
        start         => song_start,
        note_out_1    => song_note1,
        note_out_2    => song_note2,
        note_out_3    => song_note3,
        note_out_4    => song_note4,
        song_position => song_position,
        song_playing  => song_playing,
        song_done     => song_done
    );
    
    -- Note column 1: Green (leftmost) - position 160
    green_note : noteColumn
    PORT MAP(
        clk        => clk_in,
        v_sync     => S_vsync, 
        pixel_row  => S_pixel_row, 
        pixel_col  => S_pixel_col, 
        horiz      => conv_std_logic_vector(160, 11),
        note_input => note_input1,
        hit_signal_in => hit_signals_out(0),
        note_col_out  => note_column1,
        color      => "010", -- Green
        keypress   => keypresses(0),
        hit_signal_out => hit_signals_back(0),
        red        => S_red1, 
        green      => S_green1, 
        blue       => S_blue1
    );
    
    -- Note column 2: Red - position 320
    red_note : noteColumn
    PORT MAP(
        clk        => clk_in,
        v_sync     => S_vsync, 
        pixel_row  => S_pixel_row, 
        pixel_col  => S_pixel_col, 
        horiz      => conv_std_logic_vector(320, 11),
        note_input => note_input2,
        hit_signal_in => hit_signals_out(1),
        note_col_out  => note_column2,
        color      => "100", -- Red
        keypress   => keypresses(1),
        hit_signal_out => hit_signals_back(1),
        red        => S_red2, 
        green      => S_green2, 
        blue       => S_blue2
    );
    
    -- Note column 3: Purple - position 480
    purple_note : noteColumn
    PORT MAP(
        clk        => clk_in,
        v_sync     => S_vsync, 
        pixel_row  => S_pixel_row, 
        pixel_col  => S_pixel_col, 
        horiz      => conv_std_logic_vector(480, 11),
        note_input => note_input3,
        hit_signal_in => hit_signals_out(2),
        note_col_out  => note_column3,
        color      => "101", -- Purple (Red + Blue)
        keypress   => keypresses(2),
        hit_signal_out => hit_signals_back(2),
        red        => S_red3, 
        green      => S_green3, 
        blue       => S_blue3
    );
    
    -- Note column 4: Blue (rightmost) - position 640
    blue_note : noteColumn
    PORT MAP(
        clk        => clk_in,
        v_sync     => S_vsync, 
        pixel_row  => S_pixel_row, 
        pixel_col  => S_pixel_col, 
        horiz      => conv_std_logic_vector(640, 11),
        note_input => note_input4,
        hit_signal_in => hit_signals_out(3),
        note_col_out  => note_column4,
        color      => "001", -- Blue
        keypress   => keypresses(3),
        hit_signal_out => hit_signals_back(3),
        red        => S_red4, 
        green      => S_green4, 
        blue       => S_blue4
    );
    
    -- Keypad module
    add_keypad : keypad
    PORT MAP(
        samp_ck => kp_clk,
        col => KB_col,
        row => KB_row,
        value => open,
        keypress_out => keypresses,
        hit => open
    );
    
    -- 7-segment display for score
    display : leddec16
    PORT MAP(
        dig => cnt(19 downto 17),
        data => total_score,
        anode => SEG7_anode,
        seg => SEG7_seg
    );
    
    -- Color combiner with enhanced graphics
    vga_combine : colorCombiner
    PORT MAP(
        clk => clk_in,
        pixel_row => S_pixel_row,
        pixel_col => S_pixel_col,
        red_inputs => S_red, 
        green_inputs => S_green,
        blue_inputs => S_blue,
        hit_signals => hit_signals_out,
        keypress_signals => keypresses,
        red_out => fin_red,  
        green_out => fin_green,
        blue_out => fin_blue
    );
    
    -- VGA sync module
    vga_driver : vga_sync
    PORT MAP(
        pixel_clk => pxl_clk, 
        red_in    => fin_red, 
        green_in  => fin_green, 
        blue_in   => fin_blue, 
        red_out   => vga_red(2), 
        green_out => vga_green(2), 
        blue_out  => vga_blue(1), 
        pixel_row => S_pixel_row, 
        pixel_col => S_pixel_col, 
        hsync     => vga_hsync, 
        vsync     => S_vsync
    );
    
    -- Button trackers for scoring
    green_button_track : buttonTracker
    PORT MAP(
        clk => clk_in, 
        reset => bt_clr,  
        keypress => keypresses(0),
        note_col_1 => note_column1,
        hit_sigB_1 => hit_signals_back(0),
        hit_signal_1 => hit_signals_out(0),
        score => green_score
    );
    
    red_button_track : buttonTracker
    PORT MAP(
        clk => clk_in,
        reset => bt_clr,   
        keypress => keypresses(1),
        note_col_1 => note_column2,
        hit_sigB_1 => hit_signals_back(1),
        hit_signal_1 => hit_signals_out(1),
        score => red_score
    );
    
    purple_button_track : buttonTracker
    PORT MAP(
        clk => clk_in,
        reset => bt_clr,   
        keypress => keypresses(2),
        note_col_1 => note_column3,
        hit_sigB_1 => hit_signals_back(2),
        hit_signal_1 => hit_signals_out(2),
        score => purple_score
    );
    
    blue_button_track : buttonTracker
    PORT MAP(
        clk => clk_in,
        reset => bt_clr,   
        keypress => keypresses(3),
        note_col_1 => note_column4,
        hit_sigB_1 => hit_signals_back(3),
        hit_signal_1 => hit_signals_out(3),
        score => blue_score
    );
    
    -- Tone generator for hit sounds
    sound_gen : toneGenerator
    PORT MAP(
        clk         => clk_in,
        reset       => bt_clr,
        hit_green   => hit_signals_out(0),
        hit_red     => hit_signals_out(1),
        hit_purple  => hit_signals_out(2),
        hit_blue    => hit_signals_out(3),
        audio_pwm   => AUD_PWM,
        audio_sd    => AUD_SD
    );
    
    vga_vsync <= S_vsync;
        
    -- Clock wizard for pixel clock
    clk_wiz_0_inst : clk_wiz_0
    port map (
        clk_in1 => clk_in,
        clk_out1 => pxl_clk
    );
    
END Behavioral;