library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity buttonTracker is
    PORT (
        clk          : IN  STD_LOGIC;
        reset        : IN  STD_LOGIC;
        keypress     : IN  STD_LOGIC;
        note_col_1   : IN  STD_LOGIC_VECTOR(599 DOWNTO 0);
        hit_sigB_1   : IN  STD_LOGIC;
        hit_signal_1 : OUT STD_LOGIC;
        score        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
end buttonTracker;

architecture Behavioral of buttonTracker is
    CONSTANT ZERO_VECTOR : STD_LOGIC_VECTOR(580 downto 530) := (OTHERS => '0'); 
    SIGNAL keypress_prev : STD_LOGIC := '0';
    SIGNAL keypress_edge : STD_LOGIC := '0';
    SIGNAL timeout_active : STD_LOGIC := '0';
    SIGNAL timeout_count : INTEGER range 0 to 10000001 := 0;
    SIGNAL total_score : STD_LOGIC_VECTOR(31 downto 0) := (OTHERS => '0');
    SIGNAL hit_sig : STD_LOGIC := '0';
begin
    
    hit_tracker : process(clk)
    begin
        if rising_edge(clk) then
            -- Edge detection for keypress
            keypress_prev <= keypress;
            
            -- Detect rising edge of keypress
            if keypress = '1' and keypress_prev = '0' then
                keypress_edge <= '1';
            else
                keypress_edge <= '0';
            end if;
            
            -- Reset handling
            if reset = '1' then
                total_score <= (OTHERS => '0');
                timeout_active <= '0';
                timeout_count <= 0;
                hit_sig <= '0';
            else
                -- Clear hit signal when acknowledged
                if hit_sigB_1 = '1' then
                    hit_sig <= '0';
                end if;
                
                -- Check for keypress and handle scoring
                if keypress_edge = '1' and timeout_active = '0' then
                    -- Check if there's a note in the hit zone (rows 530-580)
                    if note_col_1(580 downto 530) /= ZERO_VECTOR then
                        -- Note hit! Add score
                        total_score <= total_score + conv_std_logic_vector(256, 32);
                    end if;
                    -- Always send hit signal to clear notes (even if miss)
                    hit_sig <= '1';
                    timeout_active <= '1';
                    timeout_count <= 0;
                end if;
                
                -- Timeout counter to prevent double-hits
                if timeout_active = '1' then
                    if timeout_count < 10000000 then
                        timeout_count <= timeout_count + 1;
                    else
                        timeout_count <= 0;
                        timeout_active <= '0';
                    end if;
                end if;
            end if;
        end if;
    END PROCESS;
    
    -- Output assignments
    hit_signal_1 <= hit_sig;
    score <= total_score;
    
end Behavioral;