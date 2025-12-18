LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY keypad IS
    PORT (
        samp_ck : IN STD_LOGIC;
        col : OUT STD_LOGIC_VECTOR (4 DOWNTO 1);
        row : IN STD_LOGIC_VECTOR (4 DOWNTO 1);
        value : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        keypress_out : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        hit : OUT STD_LOGIC
    );
END keypad;

ARCHITECTURE Behavioral OF keypad IS
    SIGNAL CV1, CV2, CV3, CV4 : std_logic_vector (4 DOWNTO 1) := "1111";
    SIGNAL curr_col : std_logic_vector (4 DOWNTO 1) := "1110";
    SIGNAL keypress_reg : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
    SIGNAL any_hit : STD_LOGIC := '0';
BEGIN
    
    -- Column scanning process
    strobe_proc : PROCESS
    BEGIN
        WAIT UNTIL rising_edge(samp_ck);
        CASE curr_col IS
            WHEN "1110" => 
                CV1 <= row;
                curr_col <= "1101";
            WHEN "1101" => 
                CV2 <= row;
                curr_col <= "1011";
            WHEN "1011" => 
                CV3 <= row;
                curr_col <= "0111";
            WHEN "0111" => 
                CV4 <= row;
                curr_col <= "1110";
            WHEN OTHERS => 
                curr_col <= "1110";
        END CASE;
    END PROCESS;
    
    -- Key detection process for bottom row buttons (0, F, E, D)
    -- These map to keypresses for the 4 note columns
    key_detect : PROCESS(CV1, CV2, CV3, CV4)
    BEGIN
        -- Default: no keys pressed
        keypress_reg <= "0000";
        any_hit <= '0';
        
        -- Column 1, Row 4 = Button "0" -> keypress(0) for green column
        IF CV1(4) = '0' THEN
            keypress_reg(0) <= '1';
            any_hit <= '1';
        END IF;
        
        -- Column 2, Row 4 = Button "F" -> keypress(1) for red column
        IF CV2(4) = '0' THEN
            keypress_reg(1) <= '1';
            any_hit <= '1';
        END IF;
        
        -- Column 3, Row 4 = Button "E" -> keypress(2) for purple column
        IF CV3(4) = '0' THEN
            keypress_reg(2) <= '1';
            any_hit <= '1';
        END IF;
        
        -- Column 4, Row 4 = Button "D" -> keypress(3) for blue column
        IF CV4(4) = '0' THEN
            keypress_reg(3) <= '1';
            any_hit <= '1';
        END IF;
    END PROCESS;
    
    -- Output assignments
    col <= curr_col;
    keypress_out <= keypress_reg;
    hit <= any_hit;
    value <= "0000"; -- Not used in this application
    
END Behavioral;