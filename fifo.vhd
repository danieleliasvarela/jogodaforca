LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
ENTITY FIFO IS
   GENERIC(
      B: NATURAL:=8; -- NUMBER OF BITS
      W: NATURAL:=4 -- NUMBER OF ADDRESS BITS
   );
   PORT(
      CLK, RESET: IN STD_LOGIC;
      RD, WR: IN STD_LOGIC;
      W_DATA: IN STD_LOGIC_VECTOR (B-1 DOWNTO 0);
      EMPTY, FULL: OUT STD_LOGIC;
      R_DATA: OUT STD_LOGIC_VECTOR (B-1 DOWNTO 0)
   );
END FIFO;

ARCHITECTURE ARCH OF FIFO IS
   TYPE REG_FILE_TYPE IS ARRAY (2**W-1 DOWNTO 0) OF
        STD_LOGIC_VECTOR(B-1 DOWNTO 0);
   SIGNAL ARRAY_REG: REG_FILE_TYPE;
   SIGNAL W_PTR_REG, W_PTR_NEXT, W_PTR_SUCC:
      STD_LOGIC_VECTOR(W-1 DOWNTO 0);
   SIGNAL R_PTR_REG, R_PTR_NEXT, R_PTR_SUCC:
      STD_LOGIC_VECTOR(W-1 DOWNTO 0);
   SIGNAL FULL_REG, EMPTY_REG, FULL_NEXT, EMPTY_NEXT:
          STD_LOGIC;
   SIGNAL WR_OP: STD_LOGIC_VECTOR(1 DOWNTO 0);
   SIGNAL WR_EN: STD_LOGIC;
BEGIN
   --=================================================
   -- REGISTER FILE
   --=================================================
   PROCESS(CLK,RESET)
   BEGIN
     IF (RESET='1') THEN
        ARRAY_REG <= (OTHERS=>(OTHERS=>'0'));
     ELSIF (CLK'EVENT AND CLK='1') THEN
        IF WR_EN='1' THEN
           ARRAY_REG(TO_INTEGER(UNSIGNED(W_PTR_REG)))
                 <= W_DATA;
        END IF;
     END IF;
   END PROCESS;
   -- READ PORT
   R_DATA <= ARRAY_REG(TO_INTEGER(UNSIGNED(R_PTR_REG)));
   -- WRITE ENABLED ONLY WHEN FIFO IS NOT FULL
   WR_EN <= WR AND (NOT FULL_REG);

   --=================================================
   -- FIFO CONTROL LOGIC
   --=================================================
   -- REGISTER FOR READ AND WRITE POINTERS
   PROCESS(CLK,RESET)
   BEGIN
      IF (RESET='1') THEN
         W_PTR_REG <= (OTHERS=>'0');
         R_PTR_REG <= (OTHERS=>'0');
         FULL_REG <= '0';
         EMPTY_REG <= '1';
      ELSIF (CLK'EVENT AND CLK='1') THEN
         W_PTR_REG <= W_PTR_NEXT;
         R_PTR_REG <= R_PTR_NEXT;
         FULL_REG <= FULL_NEXT;
         EMPTY_REG <= EMPTY_NEXT;
      END IF;
   END PROCESS;

   -- SUCCESSIVE POINTER VALUES
   W_PTR_SUCC <= STD_LOGIC_VECTOR(UNSIGNED(W_PTR_REG)+1);
   R_PTR_SUCC <= STD_LOGIC_VECTOR(UNSIGNED(R_PTR_REG)+1);

   -- NEXT-STATE LOGIC FOR READ AND WRITE POINTERS
   WR_OP <= WR & RD;
   PROCESS(W_PTR_REG,W_PTR_SUCC,R_PTR_REG,R_PTR_SUCC,WR_OP,
           EMPTY_REG,FULL_REG)
   BEGIN
      W_PTR_NEXT <= W_PTR_REG;
      R_PTR_NEXT <= R_PTR_REG;
      FULL_NEXT <= FULL_REG;
      EMPTY_NEXT <= EMPTY_REG;
      CASE WR_OP IS
         WHEN "00" => -- NO OP
         WHEN "01" => -- READ
            IF (EMPTY_REG /= '1') THEN -- NOT EMPTY
               R_PTR_NEXT <= R_PTR_SUCC;
               FULL_NEXT <= '0';
               IF (R_PTR_SUCC=W_PTR_REG) THEN
                  EMPTY_NEXT <='1';
               END IF;
            END IF;
         WHEN "10" => -- WRITE
            IF (FULL_REG /= '1') THEN -- NOT FULL
               W_PTR_NEXT <= W_PTR_SUCC;
               EMPTY_NEXT <= '0';
               IF (W_PTR_SUCC=R_PTR_REG) THEN
                  FULL_NEXT <='1';
               END IF;
            END IF;
         WHEN OTHERS => -- WRITE/READ;
            W_PTR_NEXT <= W_PTR_SUCC;
            R_PTR_NEXT <= R_PTR_SUCC;
      END CASE;
   END PROCESS;
   -- OUTPUT
   FULL <= FULL_REG;
   EMPTY <= EMPTY_REG;
END ARCH;