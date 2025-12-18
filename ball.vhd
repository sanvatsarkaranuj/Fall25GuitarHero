LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY noteColumn IS
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
END noteColumn;

ARCHITECTURE Behavioral OF noteColumn IS
    -- Note appearance constants
    CONSTANT NOTE_RADIUS : INTEGER := 18;         -- Radius of circular note
    
    -- Target circle constants
    CONSTANT TARGET_Y : INTEGER := 565;           -- Y position of target circle
    CONSTANT CIRCLE_RADIUS : INTEGER := 28;       -- Radius of target circle
    CONSTANT CIRCLE_THICKNESS : INTEGER := 4;     -- Ring thickness
    
    -- Notes disappear after this Y position
    CONSTANT NOTE_DISAPPEAR_Y : INTEGER := 540;
    
    -- Tempo constant
    CONSTANT FALL_SPEED_BITS : INTEGER := 18;
    
    -- Internal signals
    SIGNAL note_on : STD_LOGIC := '0';
    SIGNAL note_col : STD_LOGIC_VECTOR(599 DOWNTO 0) := (OTHERS => '0');
    SIGNAL counter : STD_LOGIC_VECTOR(25 DOWNTO 0) := (OTHERS => '0');
    SIGNAL local_clk : STD_LOGIC := '0';
    SIGNAL local_clk_prev : STD_LOGIC := '0';
    
    -- Pixel position as integers
    SIGNAL pixel_row_int : INTEGER RANGE 0 TO 2047;
    SIGNAL pixel_col_int : INTEGER RANGE 0 TO 2047;
    SIGNAL horiz_int : INTEGER RANGE 0 TO 2047;
    
    -- Region detection signals
    SIGNAL in_target_ring : STD_LOGIC := '0';
    SIGNAL in_target_fill : STD_LOGIC := '0';
    
BEGIN
    -- Convert to integers
    pixel_row_int <= CONV_INTEGER(pixel_row);
    pixel_col_int <= CONV_INTEGER(pixel_col);
    horiz_int <= CONV_INTEGER(horiz);
    
    -- Output the note column state
    note_col_out <= note_col;
    
    -- note drawing: check if current pixel row has a note
    -- and if we're within horizontal range for a circle
    ndraw : PROCESS (pixel_row_int, pixel_col_int, horiz_int, note_col)
        VARIABLE temp_note_on : STD_LOGIC;
        VARIABLE dx, dy : INTEGER;
        VARIABLE dist_sq : INTEGER;
        VARIABLE radius_sq : INTEGER;
        VARIABLE row_check : INTEGER;
    BEGIN
        temp_note_on := '0';
        radius_sq := NOTE_RADIUS * NOTE_RADIUS;
        
        -- Only check if we're in the visible area (above disappear line)
        -- and within horizontal bounds of where a note could be
        IF pixel_row_int < NOTE_DISAPPEAR_Y AND
           pixel_col_int >= horiz_int - NOTE_RADIUS AND 
           pixel_col_int <= horiz_int + NOTE_RADIUS THEN
            
            -- Calculate horizontal distance once
            dx := pixel_col_int - horiz_int;
            
            -- Only need to check a small range of rows around current pixel
            -- A note at row Y affects pixels from Y-radius to Y+radius
            FOR offset IN -NOTE_RADIUS TO NOTE_RADIUS LOOP
                row_check := pixel_row_int + offset;
                IF row_check >= 0 AND row_check < NOTE_DISAPPEAR_Y THEN
                    IF note_col(row_check) = '1' THEN
                        -- Check if this pixel is within the circle
                        dy := offset;  -- This is (pixel_row - note_row)
                        dist_sq := dx * dx + dy * dy;
                        IF dist_sq <= radius_sq THEN
                            temp_note_on := '1';
                            EXIT;
                        END IF;
                    END IF;
                END IF;
            END LOOP;
        END IF;
        
        note_on <= temp_note_on;
    END PROCESS;
    
    -- Target circle regions
    region_check : PROCESS(pixel_col_int, pixel_row_int, horiz_int)
        VARIABLE dx, dy : INTEGER;
        VARIABLE dist_sq : INTEGER;
        VARIABLE outer_radius_sq, inner_radius_sq : INTEGER;
    BEGIN
        dx := pixel_col_int - horiz_int;
        dy := pixel_row_int - TARGET_Y;
        dist_sq := dx * dx + dy * dy;
        
        outer_radius_sq := CIRCLE_RADIUS * CIRCLE_RADIUS;
        inner_radius_sq := (CIRCLE_RADIUS - CIRCLE_THICKNESS) * (CIRCLE_RADIUS - CIRCLE_THICKNESS);
        
        -- Ring (between outer and inner)
        IF dist_sq <= outer_radius_sq AND dist_sq >= inner_radius_sq THEN
            in_target_ring <= '1';
        ELSE
            in_target_ring <= '0';
        END IF;
        
        -- Fill (inside inner)
        IF dist_sq <= inner_radius_sq THEN
            in_target_fill <= '1';
        ELSE
            in_target_fill <= '0';
        END IF;
    END PROCESS;
    
    -- Color output
    color_output : PROCESS(note_on, in_target_ring, in_target_fill, color, keypress)
    BEGIN
        -- Default: white (no drawing)
        red <= '1';
        green <= '1';
        blue <= '1';
        
        -- Priority 1: Note
        IF note_on = '1' THEN
            red <= color(2);
            green <= color(1);
            blue <= color(0);
        -- Priority 2: Keypress fill
        ELSIF in_target_fill = '1' AND keypress = '1' THEN
            red <= '1';
            green <= '1';
            blue <= '1';  -- White when pressed
        -- Priority 3: Target ring
        ELSIF in_target_ring = '1' THEN
            red <= color(2);
            green <= color(1);
            blue <= color(0);
        END IF;
    END PROCESS;
    
    -- Counter process
    counter_proc : PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            counter <= counter + 1;
            local_clk_prev <= local_clk;
            local_clk <= counter(FALL_SPEED_BITS);
        END IF;
    END PROCESS;
    
    -- Note column shift process
    mcolumn : PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF hit_signal_in = '1' THEN
                note_col(580 DOWNTO 550) <= (OTHERS => '0');
                hit_signal_out <= '1';
            ELSE
                hit_signal_out <= '0';
                
                IF local_clk = '1' AND local_clk_prev = '0' THEN
                    note_col(599 DOWNTO 1) <= note_col(598 DOWNTO 0);
                    note_col(0) <= note_input;
                END IF;
            END IF;
        END IF;
    END PROCESS;
    
END Behavioral;