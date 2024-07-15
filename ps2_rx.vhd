LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
ENTITY PS2_RX IS
   PORT (
      CLK, RESET: IN  STD_LOGIC;
      PS2D, PS2C: IN  STD_LOGIC;  -- KEY DATA, KEY CLOCK
      RX_EN: IN STD_LOGIC;
      RX_DONE_TICK: OUT  STD_LOGIC;
      DOUT: OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
   );
END PS2_RX;

ARCHITECTURE ARCH OF PS2_RX IS
   TYPE STATETYPE IS (IDLE, DPS, LOAD);
   SIGNAL STATE_REG, STATE_NEXT: STATETYPE;
   SIGNAL FILTER_REG, FILTER_NEXT:
          STD_LOGIC_VECTOR(7 DOWNTO 0);
   SIGNAL F_PS2C_REG,F_PS2C_NEXT: STD_LOGIC;
   SIGNAL B_REG, B_NEXT: STD_LOGIC_VECTOR(10 DOWNTO 0);
   SIGNAL N_REG,N_NEXT: UNSIGNED(3 DOWNTO 0);
   SIGNAL FALL_EDGE: STD_LOGIC;
BEGIN
   --=================================================
   -- FILTER AND FALLING EDGE TICK GENERATION FOR PS2C
   --=================================================
   PROCESS (CLK, RESET)
   BEGIN
      IF RESET='1' THEN
         FILTER_REG <= (OTHERS=>'0');
         F_PS2C_REG <= '0';
      ELSIF (CLK'EVENT AND CLK='1') THEN
         FILTER_REG <= FILTER_NEXT;
         F_PS2C_REG <= F_PS2C_NEXT;
      END IF;
   END PROCESS;

   FILTER_NEXT <= PS2C & FILTER_REG(7 DOWNTO 1);
   F_PS2C_NEXT <= '1' WHEN FILTER_REG="11111111" ELSE
                  '0' WHEN FILTER_REG="00000000" ELSE
                  F_PS2C_REG;
   FALL_EDGE <= F_PS2C_REG AND (NOT F_PS2C_NEXT);

   --=================================================
   -- FSMD TO EXTRACT THE 8-BIT DATA
   --=================================================
   -- REGISTERS
   PROCESS (CLK, RESET)
   BEGIN
      IF RESET='1' THEN
         STATE_REG <= IDLE;
         N_REG  <= (OTHERS=>'0');
         B_REG <= (OTHERS=>'0');
      ELSIF (CLK'EVENT AND CLK='1') THEN
         STATE_REG <= STATE_NEXT;
         N_REG <= N_NEXT;
         B_REG <= B_NEXT;
      END IF;
   END PROCESS;
   -- NEXT-STATE LOGIC
   PROCESS(STATE_REG,N_REG,B_REG,FALL_EDGE,RX_EN,PS2D)
   BEGIN
      RX_DONE_TICK <='0';
      STATE_NEXT <= STATE_REG;
      N_NEXT <= N_REG;
      B_NEXT <= B_REG;
      CASE STATE_REG IS
         WHEN IDLE =>
            IF FALL_EDGE='1' AND RX_EN='1' THEN
               -- SHIFT IN START BIT
               B_NEXT <= PS2D & B_REG(10 DOWNTO 1);
               N_NEXT <= "1001";
               STATE_NEXT <= DPS;
            END IF;
         WHEN DPS =>  -- 8 DATA + 1 PAIRTY + 1 STOP
            IF FALL_EDGE='1' THEN
            B_NEXT <= PS2D & B_REG(10 DOWNTO 1);
               IF N_REG = 0 THEN
                   STATE_NEXT <=LOAD;
               ELSE
                   N_NEXT <= N_REG - 1;
               END IF;
            END IF;
         WHEN LOAD =>
            -- 1 EXTRA CLOCK TO COMPLETE THE LAST SHIFT
            STATE_NEXT <= IDLE;
            RX_DONE_TICK <='1';
      END CASE;
   END PROCESS;
   -- OUTPUT
   DOUT <= B_REG(8 DOWNTO 1); -- DATA BITS
END ARCH;
