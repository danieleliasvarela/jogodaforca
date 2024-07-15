LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

--=======================================================
-- ENTIDADE
--=======================================================
ENTITY KB_CODE IS
   GENERIC(W_SIZE: INTEGER:=2);  -- 2^W_SIZE WORDS IN FIFO
   PORT (
      CLK, RESET: IN  STD_LOGIC;
      PS2D, PS2C: IN  STD_LOGIC;
      RD_KEY_CODE: IN STD_LOGIC;
      KEY_CODE: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      KB_BUF_EMPTY: OUT STD_LOGIC
   );
END KB_CODE;
--=======================================================
-- ARQUITETURA
--=======================================================
ARCHITECTURE ARCH OF KB_CODE IS
   CONSTANT BRK: STD_LOGIC_VECTOR(7 DOWNTO 0):="11110000";
   -- F0 (BREAK CODE)
   TYPE STATETYPE IS (WAIT_BRK, GET_CODE);
   SIGNAL STATE_REG, STATE_NEXT: STATETYPE;
   SIGNAL SCAN_OUT, W_DATA: STD_LOGIC_VECTOR(7 DOWNTO 0);
   SIGNAL SCAN_DONE_TICK, GOT_CODE_TICK: STD_LOGIC;

BEGIN
--=======================================================
-- INSTANCIAR
--=======================================================
   PS2_RX_UNIT: ENTITY WORK.PS2_RX(ARCH)
      PORT MAP(CLK=>CLK, 
					RESET=>RESET, 
					RX_EN=>'1',
					PS2D=>PS2D, 
					PS2C=>PS2C,
               RX_DONE_TICK=>SCAN_DONE_TICK,
               DOUT=>SCAN_OUT);

   FIFO_KEY_UNIT: ENTITY WORK.FIFO(ARCH)
      GENERIC MAP(B=>8, W=>W_SIZE)
      PORT MAP(CLK=>CLK, 
					RESET=>RESET, 
					RD=>RD_KEY_CODE,
               WR=>GOT_CODE_TICK, 
					W_DATA=>SCAN_OUT,
               EMPTY=>KB_BUF_EMPTY, 
					FULL=>OPEN,
               R_DATA=>KEY_CODE);
--=======================================================
-- FSM TO GET THE SCAN CODE AFTER F0 RECEIVED
--=======================================================
   PROCESS (CLK, RESET)
   BEGIN
      IF RESET='1' THEN
         STATE_REG <= WAIT_BRK;
      ELSIF (CLK'EVENT AND CLK='1') THEN
         STATE_REG <= STATE_NEXT;
      END IF;
   END PROCESS;

   PROCESS(STATE_REG, SCAN_DONE_TICK, SCAN_OUT)
   BEGIN
      GOT_CODE_TICK <='0';
      STATE_NEXT <= STATE_REG;
      CASE STATE_REG IS
         WHEN WAIT_BRK => -- WAIT FOR F0 OF BREAK CODE
            IF SCAN_DONE_TICK='1' AND SCAN_OUT=BRK THEN
               STATE_NEXT <= GET_CODE;
            END IF;
         WHEN GET_CODE => -- GET THE FOLLOWING SCAN CODE
            IF SCAN_DONE_TICK='1' THEN
               GOT_CODE_TICK <='1';
               STATE_NEXT <= WAIT_BRK;
            END IF;
      END CASE;
   END PROCESS;
END ARCH;
