LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY LCD IS
    PORT(LCD_DB: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
         RS:OUT STD_LOGIC;
         RW:OUT STD_LOGIC;
         CLK:IN STD_LOGIC;
         OE:OUT STD_LOGIC;
         RST:IN STD_LOGIC;
         LEDS : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
         PS2D, PS2C: IN STD_LOGIC);
END LCD;

ARCHITECTURE BEHAVIORAL OF LCD IS

------------------------------------------------------------------
--  COMPONENT DECLARATIONS
------------------------------------------------------------------
COMPONENT KB_CODE PORT(CLK, RESET: IN  STD_LOGIC; --CLK DA FPGA
                       PS2D, PS2C: IN  STD_LOGIC; 
                       RD_KEY_CODE: IN STD_LOGIC; -- LIBERA O BUFFER
                       KEY_CODE: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);--TECLA NO BUFFER
                       KB_BUF_EMPTY: OUT STD_LOGIC); -- TECLA FOI ESCRITA NO BUFFER
END COMPONENT KB_CODE;

------------------------------------------------------------------
--  LOCAL TYPE DECLARATIONS
-----------------------------------------------------------------

--LCD CONTROL STATE MACHINE
TYPE MSTATE IS (STFUNCTIONSET,		 	
                STDISPLAYCTRLSET,
                STDISPLAYCLEAR,
                STPOWERON_DELAY,  				
                STFUNCTIONSET_DELAY,
                STDISPLAYCTRLSET_DELAY, 	
                STDISPLAYCLEAR_DELAY,
                STINITDNE,				
                STACTWR,
                STCHARDELAY);

--WRITE CONTROL STATE MACHINE
TYPE WSTATE IS (STRW,						
                STENABLE,				
                STIDLE);

TYPE JESTADOS IS (JESPERA,
                  JACERTO,
                  JERRO,
                  JPERDE);

TYPE MLEITOR IS (MINICIAL,
                MMEIO,
                MFINAL);

SIGNAL CLKCOUNT:STD_LOGIC_VECTOR(5 DOWNTO 0);
SIGNAL ACTIVATEW:STD_LOGIC:= '0';
SIGNAL COUNT:STD_LOGIC_VECTOR (16 DOWNTO 0):= "00000000000000000";
SIGNAL DELAYOK:STD_LOGIC:= '0';
SIGNAL ONEUSCLK:STD_LOGIC;	
SIGNAL STCUR:MSTATE:= STPOWERON_DELAY;
SIGNAL JATUAL:JESTADOS:= JESPERA;
SIGNAL JNEXT:JESTADOS;
SIGNAL STNEXT:MSTATE;
SIGNAL MATUAL: MLEITOR:= MINICIAL;
SIGNAL STCURW:WSTATE:= STIDLE;
SIGNAL STNEXTW:WSTATE;
SIGNAL WRITEDONE:STD_LOGIC:= '0';
SIGNAL LIBERABUF : STD_LOGIC := '0';
SIGNAL KEYREAD : STD_LOGIC_VECTOR (7 DOWNTO 0):= "00000000";
SIGNAL KEYBUFFER : STD_LOGIC_VECTOR (7 DOWNTO 0);
SIGNAL BUFEMPTY : STD_LOGIC ;
SIGNAL ERROCOUNT: UNSIGNED (3 DOWNTO 0):= "0000";
SIGNAL TECLOU : STD_LOGIC := '0';
SIGNAL LEU : STD_LOGIC := '0';
SIGNAL PERDEU : STD_LOGIC_VECTOR (7 DOWNTO 0):= "11111111";
TYPE SHOW_T IS ARRAY(INTEGER RANGE 0 TO 5) OF STD_LOGIC_VECTOR(9 DOWNTO 0);
SIGNAL SHOW : SHOW_T := (
0 => "10"&X"2E",
1 => "10"&X"2E",
2 => "10"&X"2E",
3 => "10"&X"2E",
4 => "10"&X"2E",
5 => "10"&X"2E"
);
--- pontinhos
TYPE LCD_CMDS_T IS ARRAY(INTEGER RANGE 0 TO 13) OF STD_LOGIC_VECTOR(9 DOWNTO 0);
SIGNAL LCD_CMDS : LCD_CMDS_T := (
0 => "00"&X"3C",			--FUNCTION SET
1 => "00"&X"0C",			--DISPLAY ON, CURSOR OFF, BLINK OFF
2 => "00"&X"01",			--CLEAR DISPLAY
3 => "00"&X"02", 			--RETURN HOME

4 => "10"&X"48", 			--H 
5 => "10"&X"65",  			--E
6 => "10"&X"6C",  			--L
7 => "10"&X"6C", 			--L
8 => "10"&X"6F", 			--O
9 => "10"&X"20",  			--SPACE
10 => "10"&X"46", 			--F
11 => "10"&X"72", 			--R
12 => "10"&X"72", 			--R
13 => "10"&X"72");

SIGNAL LCD_CMD_PTR : INTEGER RANGE 0 TO LCD_CMDS'HIGH + 1 := 0;
BEGIN
LEDS(0) <= KEYREAD(0);
LEDS(1) <= KEYREAD(1);
LEDS(2) <= KEYREAD(2);
LEDS(3) <= KEYREAD(3);
LEDS(4) <= KEYREAD(4);
LEDS(5) <= KEYREAD(5);
LEDS(6) <= KEYREAD(6);
LEDS(7) <= KEYREAD(7);

LCD_CMDS(0) <= "00"&X"3C";
LCD_CMDS(1) <= "00"&X"0C";
LCD_CMDS(2) <= "00"&X"01";
LCD_CMDS(3) <= "00"&X"02";	

LCD_CMDS(4) <= SHOW(0); -- P
LCD_CMDS(5) <= SHOW(1); -- R
LCD_CMDS(6) <= SHOW(2); -- O
LCD_CMDS(7) <= SHOW(3); -- J
LCD_CMDS(8) <= SHOW(4); -- E
LCD_CMDS(9) <= SHOW(5); -- T
LCD_CMDS(10) <= SHOW(2); -- O


LCD_CMDS(11) <= "1000100000";

LCD_CMDS(12) <= "10"&"0011"&(STD_LOGIC_VECTOR(ERROCOUNT));
LCD_CMDS(13) <= "00"&X"02";

KBC: KB_CODE PORT MAP (CLK, RST, PS2D, PS2C, LIBERABUF, KEYBUFFER, BUFEMPTY);

PROCESS (CLK, ONEUSCLK)
BEGIN
    IF (CLK = '1' AND CLK'EVENT) THEN
        CLKCOUNT <= CLKCOUNT + 1;
    END IF;
END PROCESS;


ONEUSCLK <= CLKCOUNT(5);
PROCESS (ONEUSCLK, DELAYOK)
BEGIN
    IF (ONEUSCLK = '1' AND ONEUSCLK'EVENT) THEN
        IF DELAYOK = '1' THEN
            COUNT <= "00000000000000000";
        ELSE
            COUNT <= COUNT + 1;
        END IF;
    END IF;
END PROCESS;

WRITEDONE <= '1' WHEN (LCD_CMD_PTR = LCD_CMDS'HIGH) 
ELSE '0';
PROCESS (LCD_CMD_PTR, ONEUSCLK)
BEGIN
    IF (ONEUSCLK = '1' AND ONEUSCLK'EVENT) THEN
        IF ((STNEXT = STINITDNE OR STNEXT = STDISPLAYCTRLSET OR STNEXT = STDISPLAYCLEAR) AND WRITEDONE = '0') THEN 
            LCD_CMD_PTR <= LCD_CMD_PTR + 1;
        ELSIF STCUR = STPOWERON_DELAY OR STNEXT = STPOWERON_DELAY THEN
            LCD_CMD_PTR <= 0;
        ELSIF TECLOU = '1' THEN
            LCD_CMD_PTR <= 3;
        ELSE
            LCD_CMD_PTR <= LCD_CMD_PTR;
        END IF;
    END IF;
END PROCESS;

--  DETERMINES WHEN COUNT HAS GOTTEN TO THE RIGHT NUMBER, DEPENDING ON THE STATE.

DELAYOK <= '1' WHEN ((STCUR = STPOWERON_DELAY AND COUNT = "00100111001010010") OR   
                     (STCUR = STFUNCTIONSET_DELAY AND COUNT = "00000000000110010") OR
                     (STCUR = STDISPLAYCTRLSET_DELAY AND COUNT = "00000000000110010") OR
                     (STCUR = STDISPLAYCLEAR_DELAY AND COUNT = "00000011001000000") OR
                     (STCUR = STCHARDELAY AND COUNT = "11111111111111111"))
               ELSE	'0';

-- THIS PROCESS RUNS THE LCD STATUS STATE MACHINE
PROCESS (ONEUSCLK, RST)
BEGIN
    IF ONEUSCLK = '1' AND ONEUSCLK'EVENT THEN
        IF RST = '1' THEN
            STCUR <= STPOWERON_DELAY;
        ELSE
            STCUR <= STNEXT;
        END IF;
    END IF;
END PROCESS;


--  THIS PROCESS GENERATES THE SEQUENCE OF OUTPUTS NEEDED TO INITIALIZE AND WRITE TO THE LCD SCREEN
PROCESS (STCUR, DELAYOK, WRITEDONE, LCD_CMD_PTR)
BEGIN   

    CASE STCUR IS

        --  DELAYS THE STATE MACHINE FOR 20MS WHICH IS NEEDED FOR PROPER STARTUP.
        WHEN STPOWERON_DELAY =>
            IF DELAYOK = '1' THEN
                STNEXT <= STFUNCTIONSET;
            ELSE
                STNEXT <= STPOWERON_DELAY;
            END IF;
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '0';

        -- THIS ISSUSE THE FUNCTION SET TO THE LCD AS FOLLOWS 
        -- 8 BIT DATA LENGTH, 2 LINES, FONT IS 5X8.
        WHEN STFUNCTIONSET =>
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '1';	
            STNEXT <= STFUNCTIONSET_DELAY;

        --GIVES THE PROPER DELAY OF 37US BETWEEN THE FUNCTION SET AND
        --THE DISPLAY CONTROL SET.
        WHEN STFUNCTIONSET_DELAY =>
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '0';
            IF DELAYOK = '1' THEN
                STNEXT <= STDISPLAYCTRLSET;
            ELSE
                STNEXT <= STFUNCTIONSET_DELAY;
            END IF;

        --ISSUSE THE DISPLAY CONTROL SET AS FOLLOWS
        --DISPLAY ON,  CURSOR OFF, BLINKING CURSOR OFF.
        WHEN STDISPLAYCTRLSET =>
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '1';
            STNEXT <= STDISPLAYCTRLSET_DELAY;

        --GIVES THE PROPER DELAY OF 37US BETWEEN THE DISPLAY CONTROL SET
        --AND THE DISPLAY CLEAR COMMAND. 
        WHEN STDISPLAYCTRLSET_DELAY =>
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '0';
            IF DELAYOK = '1' THEN
                STNEXT <= STDISPLAYCLEAR;
            ELSE
                STNEXT <= STDISPLAYCTRLSET_DELAY;
            END IF;

        --ISSUES THE DISPLAY CLEAR COMMAND.
        WHEN STDISPLAYCLEAR	=>
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '1';
            STNEXT <= STDISPLAYCLEAR_DELAY;

        --GIVES THE PROPER DELAY OF 1.52MS BETWEEN THE CLEAR COMMAND
        --AND THE STATE WHERE YOU ARE CLEAR TO DO NORMAL OPERATIONS.
        WHEN STDISPLAYCLEAR_DELAY =>
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '0';
            IF DELAYOK = '1' THEN
                STNEXT <= STINITDNE;
            ELSE
                STNEXT <= STDISPLAYCLEAR_DELAY;
            END IF;

        --STATE FOR NORMAL OPERATIONS FOR DISPLAYING CHARACTERS, CHANGING THE
        --CURSOR POSITION ETC.
        WHEN STINITDNE =>		
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '0';
            STNEXT <= STACTWR;

        WHEN STACTWR =>		
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '1';
            STNEXT <= STCHARDELAY;

        --PROVIDES A MAX DELAY BETWEEN INSTRUCTIONS.
        WHEN STCHARDELAY =>
            RS <= LCD_CMDS(LCD_CMD_PTR)(9);
            RW <= LCD_CMDS(LCD_CMD_PTR)(8);
            LCD_DB <= LCD_CMDS(LCD_CMD_PTR)(7 DOWNTO 0);
            ACTIVATEW <= '0';					
            IF DELAYOK = '1' THEN
                STNEXT <= STINITDNE;
            ELSE
                STNEXT <= STCHARDELAY;
            END IF;
    END CASE;

END PROCESS;					

PROCESS (ONEUSCLK, RST)
BEGIN
    IF ONEUSCLK = '1' AND ONEUSCLK'EVENT THEN
        IF RST = '1' THEN
            STCURW <= STIDLE;
        ELSE
            STCURW <= STNEXTW;
        END IF;
    END IF;
END PROCESS;

PROCESS (STCURW, ACTIVATEW)
BEGIN   

    CASE STCURW IS
        WHEN STRW =>
            OE <= '0';
            STNEXTW <= STENABLE;
        WHEN STENABLE => 
            OE <= '0';
            STNEXTW <= STIDLE;
        WHEN STIDLE =>
            OE <= '1';
        IF ACTIVATEW = '1' THEN
            STNEXTW <= STRW;
        ELSE
            STNEXTW <= STIDLE;
        END IF;
    END CASE;
END PROCESS;



PROCESS(RST,ONEUSCLK,TECLOU,KEYREAD)
BEGIN
--- PONTINHOS QUE OCULTAM AS PALAVRAS
    IF RST = '1' THEN
        SHOW(0) <= "10"&X"2E";
        SHOW(1) <= "10"&X"2E";
        SHOW(2) <= "10"&X"2E";
        SHOW(3) <= "10"&X"2E";
        SHOW(4) <= "10"&X"2E";
        SHOW(5) <= "10"&X"2E";
        ERROCOUNT <= "0000";

    ELSIF ONEUSCLK = '1' AND ONEUSCLK'EVENT THEN
    --- TEXTO QUE APARECE QUANDO PERDE O JOGO (ERRAR MAIS QUE 7 VEZES)
        IF ERROCOUNT >= 3 THEN
            SHOW(0) <= "10"&X"48"; 
            SHOW(1) <= "10"&X"41"; 
            SHOW(2) <= "10"&X"48"; 
            SHOW(3) <= "10"&X"41"; 
            SHOW(4) <= "10"&X"48"; 
            SHOW(5) <= "10"&X"41";

        ELSIF TECLOU = '1' THEN
        --- A PALAVRA  PROJETO
            CASE KEYREAD IS
                WHEN "01001101" => 					---P EM BINARIO
                    SHOW(0) <= "10"&X"50";			--- P EM HEXADECIMAL
                    SHOW(1 TO 5) <= SHOW(1 TO 5);
                WHEN "00101101" =>					--- R EM BINARIO
                    SHOW(1) <= "10"&X"52";			--- R EM HEXADECIMAL
                    SHOW(0) <= SHOW(0);
                    SHOW(2 TO 5) <= SHOW(2 TO 5);
                WHEN "01000100" =>					--- O EM BINARIO
                    SHOW(2) <= "10"&X"4F";			--- O EM HEXADECIMAL
                    SHOW(0 TO 1) <= SHOW(0 TO 1);
                    SHOW(3 TO 5) <= SHOW(3 TO 5);
                WHEN "00111011" =>					--- J EM BINARIO
                    SHOW(3) <= "10"&X"4A";			--- J EM HEXADECIMAL
                    SHOW(0 TO 2) <= SHOW(0 TO 2);
                    SHOW(4 TO 5) <= SHOW(4 TO 5);
                WHEN "00100100" =>					--- E EM BINARIO
                    SHOW(4) <= "10"&X"45";			--- E EM HEXADECIMAL
                    SHOW(0 TO 3) <= SHOW(0 TO 3);
                    SHOW(5) <= SHOW(5);
                WHEN "00101100" =>					--- T EM BINARIO
                    SHOW(5) <= "10"&X"54";			--- T EM HEXADECIMAL
                    SHOW(0 TO 4) <= SHOW(0 TO 4);
                WHEN OTHERS =>
                    ERROCOUNT <= ERROCOUNT + 1;
                    SHOW(0 TO 5)<= SHOW(0 TO 5);
            END CASE;
            LEU <= '1';	
    ELSE
        SHOW<=SHOW;
        END IF;
    END IF;
END PROCESS;

----------------------------------------------------			
PROCESS(ONEUSCLK)
BEGIN
    IF ONEUSCLK = '1' AND ONEUSCLK'EVENT THEN
        CASE MATUAL IS
            WHEN MINICIAL=>
                IF BUFEMPTY = '0' THEN
                    MATUAL <= MMEIO;
                END IF;

            WHEN MMEIO =>
                IF LEU <= '1' THEN
                    MATUAL <= MFINAL;
                END IF;

            WHEN MFINAL =>
                MATUAL <= MINICIAL;
        END CASE;
    END IF;
END PROCESS;
    ----------------------------------------------------	
PROCESS(ONEUSCLK)
BEGIN
    IF ONEUSCLK = '1' AND ONEUSCLK'EVENT THEN
        CASE MATUAL IS
            WHEN MINICIAL =>
                LIBERABUF <= '0';
            WHEN MMEIO =>
                TECLOU <= '1';
                KEYREAD <= KEYBUFFER;
            WHEN MFINAL =>
                TECLOU <= '0';
                LEU<= '0';
                LIBERABUF <= '1';
        END CASE;
    END IF;
END PROCESS;


END BEHAVIORAL;
