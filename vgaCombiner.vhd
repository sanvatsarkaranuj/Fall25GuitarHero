LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY colorCombiner IS
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
END colorCombiner;
        
ARCHITECTURE Behavioral OF colorCombiner IS
    
    -- Screen layout
    CONSTANT HEADER_HEIGHT : INTEGER := 40;
    
    -- Column X positions (center of each lane)
    CONSTANT COL1_X : INTEGER := 160;   -- Green
    CONSTANT COL2_X : INTEGER := 320;   -- Red
    CONSTANT COL3_X : INTEGER := 480;   -- Purple
    CONSTANT COL4_X : INTEGER := 640;   -- Blue
    
    -- Target Y position and circle radius (must match ball.vhd)
    CONSTANT TARGET_Y : INTEGER := 565;
    CONSTANT CIRCLE_RADIUS : INTEGER := 28;
    
    -- Lane boundaries
    CONSTANT LANE1_LEFT  : INTEGER := 90;
    CONSTANT LANE1_RIGHT : INTEGER := 230;
    CONSTANT LANE2_LEFT  : INTEGER := 250;
    CONSTANT LANE2_RIGHT : INTEGER := 390;
    CONSTANT LANE3_LEFT  : INTEGER := 410;
    CONSTANT LANE3_RIGHT : INTEGER := 550;
    CONSTANT LANE4_LEFT  : INTEGER := 570;
    CONSTANT LANE4_RIGHT : INTEGER := 710;
    
    -- Flame area
    CONSTANT FLAME_LEFT_END : INTEGER := 80;
    CONSTANT FLAME_RIGHT_START : INTEGER := 720;
    
    -- Target zone
    CONSTANT TARGET_ZONE_TOP : INTEGER := 540;
    CONSTANT TARGET_ZONE_BOT : INTEGER := 590;
    
    -- Hit flash counters
    SIGNAL flash_counter_1 : INTEGER RANGE 0 TO 500000 := 0;
    SIGNAL flash_counter_2 : INTEGER RANGE 0 TO 500000 := 0;
    SIGNAL flash_counter_3 : INTEGER RANGE 0 TO 500000 := 0;
    SIGNAL flash_counter_4 : INTEGER RANGE 0 TO 500000 := 0;
    CONSTANT FLASH_DURATION : INTEGER := 400000;
    
    -- Animation counter for flames
    SIGNAL anim_counter : INTEGER RANGE 0 TO 10000000 := 0;
    SIGNAL flame_phase : INTEGER RANGE 0 TO 7 := 0;
    
    -- Previous hit signals
    SIGNAL hit_prev : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
    
    -- Output registers
    SIGNAL r_out, g_out, b_out : STD_LOGIC := '0';
    
BEGIN

    PROCESS(clk)
        VARIABLE row : INTEGER RANGE 0 TO 2047;
        VARIABLE col : INTEGER RANGE 0 TO 2047;
        VARIABLE in_lane : BOOLEAN;
        VARIABLE on_divider : BOOLEAN;
        VARIABLE in_header : BOOLEAN;
        VARIABLE note_pixel : BOOLEAN;
        VARIABLE flash_active_1, flash_active_2, flash_active_3, flash_active_4 : BOOLEAN;
        VARIABLE in_left_flame, in_right_flame : BOOLEAN;
        VARIABLE flame_intensity : INTEGER;
        
        -- Circle calculations for keypress/flash feedback
        VARIABLE dx1, dy1, dist_sq_1 : INTEGER;
        VARIABLE dx2, dy2, dist_sq_2 : INTEGER;
        VARIABLE dx3, dy3, dist_sq_3 : INTEGER;
        VARIABLE dx4, dy4, dist_sq_4 : INTEGER;
        VARIABLE radius_sq : INTEGER;
        VARIABLE in_circle_1, in_circle_2, in_circle_3, in_circle_4 : BOOLEAN;
    BEGIN
        IF rising_edge(clk) THEN
            
            -- Animation counter for flames
            IF anim_counter < 5000000 THEN
                anim_counter <= anim_counter + 1;
            ELSE
                anim_counter <= 0;
                IF flame_phase < 7 THEN
                    flame_phase <= flame_phase + 1;
                ELSE
                    flame_phase <= 0;
                END IF;
            END IF;
            
            -- Hit flash edge detection
            hit_prev <= hit_signals;
            
            IF hit_signals(0) = '1' AND hit_prev(0) = '0' THEN
                flash_counter_1 <= FLASH_DURATION;
            ELSIF flash_counter_1 > 0 THEN
                flash_counter_1 <= flash_counter_1 - 1;
            END IF;
            
            IF hit_signals(1) = '1' AND hit_prev(1) = '0' THEN
                flash_counter_2 <= FLASH_DURATION;
            ELSIF flash_counter_2 > 0 THEN
                flash_counter_2 <= flash_counter_2 - 1;
            END IF;
            
            IF hit_signals(2) = '1' AND hit_prev(2) = '0' THEN
                flash_counter_3 <= FLASH_DURATION;
            ELSIF flash_counter_3 > 0 THEN
                flash_counter_3 <= flash_counter_3 - 1;
            END IF;
            
            IF hit_signals(3) = '1' AND hit_prev(3) = '0' THEN
                flash_counter_4 <= FLASH_DURATION;
            ELSIF flash_counter_4 > 0 THEN
                flash_counter_4 <= flash_counter_4 - 1;
            END IF;
            
            -- Convert to integers
            row := CONV_INTEGER(pixel_row);
            col := CONV_INTEGER(pixel_col);
            
            -- Flash states
            flash_active_1 := flash_counter_1 > 0;
            flash_active_2 := flash_counter_2 > 0;
            flash_active_3 := flash_counter_3 > 0;
            flash_active_4 := flash_counter_4 > 0;
            
            -- Calculate distance to each target circle center
            radius_sq := CIRCLE_RADIUS * CIRCLE_RADIUS;
            
            dx1 := col - COL1_X;
            dy1 := row - TARGET_Y;
            dist_sq_1 := dx1 * dx1 + dy1 * dy1;
            in_circle_1 := dist_sq_1 <= radius_sq;
            
            dx2 := col - COL2_X;
            dy2 := row - TARGET_Y;
            dist_sq_2 := dx2 * dx2 + dy2 * dy2;
            in_circle_2 := dist_sq_2 <= radius_sq;
            
            dx3 := col - COL3_X;
            dy3 := row - TARGET_Y;
            dist_sq_3 := dx3 * dx3 + dy3 * dy3;
            in_circle_3 := dist_sq_3 <= radius_sq;
            
            dx4 := col - COL4_X;
            dy4 := row - TARGET_Y;
            dist_sq_4 := dx4 * dx4 + dy4 * dy4;
            in_circle_4 := dist_sq_4 <= radius_sq;
            
            -- Region detection
            in_header := row < HEADER_HEIGHT;
            
            in_lane := (col >= LANE1_LEFT AND col <= LANE1_RIGHT) OR
                       (col >= LANE2_LEFT AND col <= LANE2_RIGHT) OR
                       (col >= LANE3_LEFT AND col <= LANE3_RIGHT) OR
                       (col >= LANE4_LEFT AND col <= LANE4_RIGHT);
            
            on_divider := (col >= 238 AND col <= 242) OR
                          (col >= 398 AND col <= 402) OR
                          (col >= 558 AND col <= 562);
            
            -- Flame regions
            in_left_flame := col < FLAME_LEFT_END AND row > HEADER_HEIGHT;
            in_right_flame := col > FLAME_RIGHT_START AND row > HEADER_HEIGHT;
            
            -- Flame pattern
            flame_intensity := 0;
            IF in_left_flame THEN
                IF ((row + flame_phase * 20) MOD 80) < 40 THEN
                    IF col < (FLAME_LEFT_END - ((row + flame_phase * 20) MOD 40)) THEN
                        flame_intensity := 2;
                    ELSIF col < FLAME_LEFT_END THEN
                        flame_intensity := 1;
                    END IF;
                ELSE
                    IF col < (FLAME_LEFT_END - (40 - ((row + flame_phase * 20) MOD 40))) THEN
                        flame_intensity := 1;
                    END IF;
                END IF;
            END IF;
            
            IF in_right_flame THEN
                IF ((row + flame_phase * 20) MOD 80) < 40 THEN
                    IF col > (FLAME_RIGHT_START + ((row + flame_phase * 20) MOD 40)) THEN
                        flame_intensity := 2;
                    ELSIF col > FLAME_RIGHT_START THEN
                        flame_intensity := 1;
                    END IF;
                ELSE
                    IF col > (FLAME_RIGHT_START + (40 - ((row + flame_phase * 20) MOD 40))) THEN
                        flame_intensity := 1;
                    END IF;
                END IF;
            END IF;
            
            -- Note pixel check
            note_pixel := (red_inputs(0) = '0' OR green_inputs(0) = '0' OR blue_inputs(0) = '0') OR
                          (red_inputs(1) = '0' OR green_inputs(1) = '0' OR blue_inputs(1) = '0') OR
                          (red_inputs(2) = '0' OR green_inputs(2) = '0' OR blue_inputs(2) = '0') OR
                          (red_inputs(3) = '0' OR green_inputs(3) = '0' OR blue_inputs(3) = '0');
            
            -- === RENDER PRIORITY ===
            
            -- 1. Notes (highest priority)
            IF note_pixel THEN
                IF red_inputs(0) = '0' OR green_inputs(0) = '0' OR blue_inputs(0) = '0' THEN
                    r_out <= red_inputs(0);
                    g_out <= green_inputs(0);
                    b_out <= blue_inputs(0);
                ELSIF red_inputs(1) = '0' OR green_inputs(1) = '0' OR blue_inputs(1) = '0' THEN
                    r_out <= red_inputs(1);
                    g_out <= green_inputs(1);
                    b_out <= blue_inputs(1);
                ELSIF red_inputs(2) = '0' OR green_inputs(2) = '0' OR blue_inputs(2) = '0' THEN
                    r_out <= red_inputs(2);
                    g_out <= green_inputs(2);
                    b_out <= blue_inputs(2);
                ELSE
                    r_out <= red_inputs(3);
                    g_out <= green_inputs(3);
                    b_out <= blue_inputs(3);
                END IF;
            
            -- 2. Header bar (blue)
            ELSIF in_header THEN
                r_out <= '0';
                g_out <= '0';
                b_out <= '1';
            
            -- 3. Hit flash effects (circle-shaped, white flash)
            ELSIF in_circle_1 AND flash_active_1 THEN
                r_out <= '1'; g_out <= '1'; b_out <= '1';  -- White flash
            ELSIF in_circle_2 AND flash_active_2 THEN
                r_out <= '1'; g_out <= '1'; b_out <= '1';
            ELSIF in_circle_3 AND flash_active_3 THEN
                r_out <= '1'; g_out <= '1'; b_out <= '1';
            ELSIF in_circle_4 AND flash_active_4 THEN
                r_out <= '1'; g_out <= '1'; b_out <= '1';
            
            -- 4. Keypress feedback (circle-shaped, colored)
            ELSIF in_circle_1 AND keypress_signals(0) = '1' THEN
                r_out <= '0'; g_out <= '1'; b_out <= '0';  -- Green glow
            ELSIF in_circle_2 AND keypress_signals(1) = '1' THEN
                r_out <= '1'; g_out <= '0'; b_out <= '0';  -- Red glow
            ELSIF in_circle_3 AND keypress_signals(2) = '1' THEN
                r_out <= '1'; g_out <= '0'; b_out <= '1';  -- Purple glow
            ELSIF in_circle_4 AND keypress_signals(3) = '1' THEN
                r_out <= '0'; g_out <= '0'; b_out <= '1';  -- Blue glow
            
            -- 5. Target zone horizontal lines
            ELSIF in_lane AND (row = TARGET_ZONE_TOP OR row = TARGET_ZONE_TOP + 1 OR 
                              row = TARGET_ZONE_BOT OR row = TARGET_ZONE_BOT - 1) THEN
                r_out <= '1'; g_out <= '1'; b_out <= '1';
            
            -- 6. Lane dividers
            ELSIF on_divider AND row > HEADER_HEIGHT THEN
                r_out <= '0'; g_out <= '0'; b_out <= '1';
            
            -- 7. Flames
            ELSIF flame_intensity = 2 THEN
                r_out <= '1'; g_out <= '1'; b_out <= '0';  -- Yellow
            ELSIF flame_intensity = 1 THEN
                r_out <= '1'; g_out <= '0'; b_out <= '0';  -- Red
            
            -- 8. Default background (black)
            ELSE
                r_out <= '0'; g_out <= '0'; b_out <= '0';
                
            END IF;
            
        END IF;
    END PROCESS;
    
    red_out <= r_out;
    green_out <= g_out;
    blue_out <= b_out;
    
END Behavioral;