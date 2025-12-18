LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY songMap IS
    GENERIC (
        song_map : STD_LOGIC_VECTOR(599 DOWNTO 0) -- Song map for the column
    );
    PORT (
        clk          : IN  STD_LOGIC;  -- Clock input
        reset        : IN  STD_LOGIC;  -- Reset signal to restart the song
        song_pointer : OUT INTEGER RANGE 0 TO 599; -- Current pointer in the song map
        note_active  : OUT STD_LOGIC   -- Indicates if a note is active at the current pointer
    );
END songMap;

ARCHITECTURE Behavioral OF songMap IS
    SIGNAL local_pointer : INTEGER RANGE 0 TO 599 := 0; -- Pointer for song map
    SIGNAL local_clk      : STD_LOGIC;                  -- Internal clock for timing
    SIGNAL counter        : STD_LOGIC_VECTOR(25 DOWNTO 0) := (OTHERS => '0'); -- Clock divider

BEGIN

    -- Clock division to control the speed of the song playback
    clk_divider : PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            counter <= counter + 1;
            local_clk <= counter(20);
        END IF;
    END PROCESS;

    -- Song map logic
    song_logic : PROCESS(local_clk, reset)
    BEGIN
        IF reset = '1' THEN
            local_pointer <= 0; -- Reset the song pointer
        ELSIF rising_edge(local_clk) THEN
            IF local_pointer = 599 THEN
                local_pointer <= 0; -- Loop back to the beginning of the song map
            ELSE
                local_pointer <= local_pointer + 1; -- Increment the pointer
            END IF;
        END IF;
    END PROCESS;

    -- Output the active note state and song pointer
    note_active <= song_map(local_pointer);
    song_pointer <= local_pointer;

END Behavioral;
