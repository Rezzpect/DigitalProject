----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    05:12:26 11/07/2023 
-- Design Name: 
-- Module Name:    main - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity main is
	port(
			P_LEFT : in std_logic;
			P_RIGHT : in std_logic;
			START : in std_logic;

			CLOCK : in std_logic;
			HSYNC : out std_logic;
			VSYNC : out std_logic;
			RED : out std_logic;
			GREEN : out std_logic;
			BLUE : out std_logic;
			
         SEGMENT : out std_logic_vector (6 downto 0);
			
			COMMON : out std_logic_vector (3 downto 0); 

			BUZZER : out std_logic
		);
end main;

architecture Behavioral of main is

	---- VGA TIMING ----
	signal x : natural range 0 to 656 := 0;
	signal y : natural range 0 to 421 := 0;

	constant X_VISIBLE_AREA : natural := 520;
	constant X_FRONT_PORCH : natural := 32;
	constant X_SYNC_PULSE : natural := 72;
	constant X_BACK_PORCH : natural := 32;
	constant X_WHOLE_LINE : natural := 656;

	constant Y_VISIBLE_AREA : natural := 400;
	constant Y_FRONT_PORCH : natural := 8;
	constant Y_SYNC_PULSE : natural := 5;
	constant Y_BACK_PORCH : natural := 8;
	constant Y_WHOLE_FRAME : natural := 421;

	constant right_border : natural := X_WHOLE_LINE - X_FRONT_PORCH;
	constant left_border : natural := X_SYNC_PULSE + X_BACK_PORCH;
	constant lower_border : natural := Y_WHOLE_FRAME - Y_FRONT_PORCH;
	constant upper_border : natural := Y_SYNC_PULSE + Y_BACK_PORCH;
	constant screen_width : natural := right_border - left_border;
	constant screen_height : natural := lower_border - upper_border;
	
	---- CLOCK AND DELAY GAME FPS ----
	-- constant my_clock : natural := 20_000_000;
	-- constant FPS : natural := my_clock / ;
	constant delay_clock : natural := X_WHOLE_LINE * Y_WHOLE_FRAME;
	signal game_delay : natural range 0 to delay_clock := 0;

	variable score : natural range 0 to 130 :=0;
	variable health : natural range 0 to 3 := 3;
	variable common_port : natural range 0 to 3 := 0;
	variable common_f_mod : natural range 0 to 200000:=200000;
	variable game_start : boolean := false;
	variable brick_counter : natural range 0 to brick_num := 0;
	variable buzzer_time : natural := 0;
	
	---- CONSTANT ----
	constant brick_row : natural := 6;
	constant brick_column : natural := 5;
	constant brick_num : natural := brick_row*brick_column;
	
	---- RECORD ----
	
	type box_entity is record
		x : integer range -10 to screen_width;
		y : integer range -10 to screen_height;
		vx : integer range -10 to 10;
		vy : integer range -10 to 10;
		width : natural range 0 to screen_width;
		height : natural range 0 to screen_height;
	end record;
	
	type color is record
		r : std_logic;
		g : std_logic;
		b : std_logic;
	end record;
	
	type brick_life is record
		life : natural range 0 to 2;
	end record;

	---- VARIABLE ----		
	shared variable player : box_entity := (
		x => (screen_width/2)- 48,
		y => ((2*screen_height)/3) + 40 ,
		vx => 0 ,
		vy => 0 ,
		width => 60,
		height => 4
	);
			
	shared variable brick : box_entity := (
		x => 0,
		y => 0,
		vx => 0 ,
		vy => 0 ,
		width => 100,
		height => 22
	);
			
	constant default_brick_hp : brick_life := (life => 2);
				
	type record_of_brick is array (natural range 0 to brick_row*brick_column) of brick_life;
		
	shared variable brick_list : record_of_brick :=(
		others => default_brick_hp);
			
	shared variable brick_for_display : box_entity := (
		x => 0,
		y => 0,
		vx => 0 ,
		vy => 0 ,
		width => 100,
		height => 22
	);
		
	shared variable ball : box_entity := (
		x => screen_width/2 - 4,
		y => (2*screen_height)/3,
		vx => -3 ,
		vy => -3 ,
		width => 8 ,
		height => 8
	);
	
begin
	game_refresh : process(CLOCK) begin
		
		if rising_edge(CLOCK) then
			if (game_delay < 1_000_000) then
				game_delay <= game_delay + 1;
			else
				game_delay <= 0;
			end if;
		
		end if;
	end process;
	
	drawing : process(CLOCK) is
		
		procedure set_color(
			color_c : color) is
		begin
			RED <= color_c.r;
			GREEN <= color_c.g;
			BLUE <= color_c.b;
		end procedure;

        procedure BCD_to_seven(
            num : natural) is 
            variable BCD : std_logic_vector(3 downto 0);
			variable A,B,C,D,E,F,G : std_logic;
        begin
            BCD := std_logic_vector(to_unsigned(num,4));
            A := BCD(0) OR BCD(2) OR (BCD(1) AND BCD(3)) OR (NOT BCD(1) AND NOT BCD(3));
            B := (NOT BCD(1)) OR (NOT BCD(2) AND NOT BCD(3)) OR (BCD(2) AND BCD(3));
            C := BCD(1) OR NOT BCD(2) OR BCD(3);
            D := (NOT BCD(1) AND NOT BCD(3)) OR (BCD(2) AND NOT BCD(3)) OR (BCD(1) AND NOT BCD(2) AND BCD(3)) OR (NOT BCD(1) AND BCD(2)) OR BCD(0);
            E := (NOT BCD(1) AND NOT BCD(3)) OR (BCD(2) AND NOT BCD(3));
            F := BCD(0) OR (NOT BCD(2) AND NOT BCD(3)) OR (BCD(1) AND NOT BCD(2)) OR (BCD(1) AND NOT BCD(3));
            G := BCD(0) OR (BCD(1) AND NOT BCD(2)) OR ( NOT BCD(1) AND BCD(2)) OR (BCD(2) AND NOT BCD(3));

			segment <= A&B&C&D&E&F&G;
        end procedure;

		procedure select_digit(
			place : natural;
			num : natural) is 
			variable digit : natural;
		begin
			if place = 0 then
				digit := num mod 10;
				BCD_to_seven(digit);
			elsif place = 1 then
				digit := num mod 100;
				BCD_to_seven(digit/10);
			elsif place = 2 then
				digit := num mod 1000;
				BCD_to_seven(digit/100);
			else
				BCD_to_seven(digit*0);
			end if;
		end procedure;
			
		procedure draw_shape(
			shape : box_entity;
			color_c : color;
			transparent : boolean) is
		begin
			if x >= shape.x + left_border and x < shape.x + left_border + shape.width and y >= shape.y + upper_border and y < shape.y + shape.height + upper_border then
				if transparent then
					if x mod 2 = 0 then
						set_color(color_c);
					end if;
				else
					set_color(color_c);
				end if;
			end if;
		end procedure;
			
		procedure draw_ball(
			ball : box_entity)is
			variable radius : natural := ball.width/2;
		begin 
			if (x-(ball.x+left_border+radius))*(x-(ball.x+left_border+radius)) + (y-(ball.y+upper_border+radius))*(y-(ball.y+upper_border+radius)) <= radius*radius then
				set_color((r=>'1',g=>'1',b=>'1'));
			end if;
		end procedure;

        procedure draw_hp(
            hp : natural;
            cord_x : natural;
            cord_y : natural) is
			variable temp_x :natural;
        begin 
			temp_x := cord_x;
            --L--
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 12,height => 16),(r=>'1',g=>'1',b=>'1'),false);
            draw_shape((x => temp_x + 4,y => cord_y,vx => 0,vy => 0,width => 8,height => 12),(r=>'0',g=>'0',b=>'0'),false);
            --I--
            temp_x := temp_x + 12 +2;
            draw_shape((x =>  temp_x,y => cord_y,vx => 0,vy => 0,width => 12,height => 16),(r=>'1',g=>'1',b=>'1'),false);
            draw_shape((x => temp_x,y => cord_y+4,vx => 0,vy => 0,width => 4,height => 8),(r=>'0',g=>'0',b=>'0'),false);
            draw_shape((x => temp_x + 8,y => cord_y+4,vx => 0,vy => 0,width => 4,height => 8),(r=>'0',g=>'0',b=>'0'),false);
            --V--
            temp_x := temp_x + 12 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 12,height => 16),(r=>'1',g=>'1',b=>'1'),false);
            draw_shape((x => temp_x,y => cord_y+12,vx => 0,vy => 0,width => 4,height => 4),(r=>'0',g=>'0',b=>'0'),false);
            draw_shape((x => temp_x + 4,y => cord_y,vx => 0,vy => 0,width => 4,height => 12),(r=>'0',g=>'0',b=>'0'),false);
            draw_shape((x => temp_x + 8,y => cord_y+12,vx => 0,vy => 0,width => 4,height => 4),(r=>'0',g=>'0',b=>'0'),false);
            --E--
            temp_x :=  temp_x + 12 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 12,height => 16),(r=>'1',g=>'1',b=>'1'),false);
            draw_shape((x => temp_x + 4,y => cord_y+4,vx => 0,vy => 0,width => 8,height => 3),(r=>'0',g=>'0',b=>'0'),false);
            draw_shape((x => temp_x + 4,y => cord_y+9,vx => 0,vy => 0,width => 8,height => 3),(r=>'0',g=>'0',b=>'0'),false);

            temp_x := temp_x + 16;
            for i in 0 to hp loop
                draw_shape((x => temp_x+(i*4),y => cord_y,vx => 0,vy => 0,width => 6,height => 16),(r=>'1',g=>'0',b=>'0'),false);
            end loop;
        end procedure;

			procedure set_common(
				digit_num : natural) is
			begin
				if digit_num = 0 then
					COMMON <= "1110";
				elsif digit_num = 1 then
					COMMON <= "1101";
				elsif digit_num = 2 then
					COMMON <= "1011";
				else
					COMMON <= "0111";
				end if;
			end procedure;
		
		begin
		if rising_edge(CLOCK) then
			RED <= '0';
			GREEN <= '0';
			BLUE <= '0';

			--switch common--
            if common_f_mod = 200000 then
                set_common(common_port);
					select_digit(common_port,score);
					common_f_mod := 0;

					common_port := common_port +1 ;
					if common_port > 3 then
						common_port := 0;
					end if;
            end if;
			common_f_mod := common_f_mod + 1;
	
			draw_ball(ball);
			
			draw_shape(player,(r=>'1',g=>'1',b=>'1'),false);

         	draw_hp(health,screen_width*3/4,4);
			
          	-- draw brick--
			for i in 0 to brick_row -1 loop
				for j in 0 to brick_column - 1 loop
					brick_for_display.x := (j mod brick_column)*(brick_for_display.width + 2);
					brick_for_display.y := 32 + (i mod brick_row)*(brick_for_display.height +2);
					if brick_list((5*i)+j).life = 2 then
						 draw_shape(brick_for_display,(r=>'1',g=>'1',b=>'1'),false);
					end if;
					if brick_list((5*i)+j).life = 1 then
						 draw_shape(brick_for_display,(r=>'1',g=>'0',b=>'0'),false);
					end if;
				end loop;
			end loop;
		
		end if;
	end process;

	game : process(CLOCK)
		---- FUNCTION ----
	
		impure function is_collide(
			box1 : box_entity;
			box2 : box_entity) return boolean is
		begin 
			if (box1.x + box1.width > box2.x and box1.x < box2.x + box2.width) and
				(box1.y + box1.height > box2.y and box1.y < box2.y + box2.height) then
				return true;
			else
				return false;
			end if;
	
		end function;
				
		impure function collide(
			box1 : box_entity;
			box2 : box_entity) return box_entity is
			variable collidee : box_entity;
		begin
			collidee := box1;
			if is_collide(box1,box2) then
			
				if box1.x >= box2.x + box2.width or box1.x <= box2.x - box1.width then
					collidee.vx := -collidee.vx;
				end if;
				
				if box1.y >= box2.y + box2.height or box1.y <= box2.y - box1.height then
					collidee.vy := -collidee.vy;
				end if;
				
			end if;
			return collidee;
			
		end function;
			
		impure function to_integer (
			s : std_logic ) return natural is
		begin
			if s = '1' then
				return 1;
			end if;
			return 0;
		end function;
		
	begin 
		
		if rising_edge(CLOCK) and (game_delay = delay_clock) then
			---- Update Game ----
			if START ='1' then
				game_start := true;
			else
				game_start := false;
			end if; 

			--When game is not on pause -> do these thing--
			if game_start then
				-- Player Movement --
				player.vx := 3*(to_integer(P_RIGHT)-to_integer(P_LEFT));
				
				if player.x <= 1 then
					player.x := 2;

				elsif player.x >= screen_width-player.width then
					player.x := screen_width-player.width-1;

				else
					player.x := player.x + player.vx;

				end if;
					
				--collide with left and right wall--
				if ball.x <= 1 or ball.x >= screen_width - ball.width then
					ball.vx := 0 - ball.vx;
					buzzer_time := 10000000;
				end if;

				--collide with upper wall--
				if ball.y <= 1 or ball.y >= screen_height - ball.height then
					ball.vy := 0 - ball.vy;
					buzzer_time := 10000000;
				end if;

				--move ball--
				ball.x := ball.x + ball.vx;
				ball.y := ball.y + ball.vy;

				--collide with player--
				ball := collide(ball,player);

				--collide with brick--
				brick.x := (brick_counter mod brick_column)*(brick.width + 2);
				brick.y := 32 + (brick_counter / brick_column)*(brick.height +2);
				if brick_list(brick_counter).life > 0 and is_collide(ball,brick) then
					buzzer_time := 10000000;
					ball := collide(ball,brick);
					brick_list(brick_counter).life:=  brick_list(brick_counter).life - 1;
					if brick_list(brick_counter).life > 0 then
						score := score + 1;
					else
						score := score + 3;
					end if;
					ball.x := ball.x + ball.vx;
					ball.y := ball.y + ball.vy;
				end if;

			end if;

			brick_counter := brick_counter + 1;
			if brick_counter = brick_num then
				brick_counter := 0;
			end if;

			--Sound Buzzer--
			if buzzer_time > 0 then
				buzzer_time := buzzer_time -1;
				BUZZER <= '1';
			else
				BUZZER <= '0';
			end if;
			
		end if;
	end process;
	
	vga_timing : process(CLOCK) begin

		if rising_edge(CLOCK) then
			-- Hsync and Vsync --
			if x > 0 and x <= X_SYNC_PULSE then
				HSYNC <= '0';
			else
				HSYNC <= '1';
			end if;

			if y > 0 and y <= Y_SYNC_PULSE then
				VSYNC <= '0';
			else
				VSYNC <= '1';
			end if;

			-- Frame and Line --
			if (x < X_WHOLE_LINE) then
				x <= x + 1;
			else
				x <= 0;
				
				if (y < Y_WHOLE_FRAME) then
					y <= y + 1;
				else
					y <= 0;
				end if;
			end if;

		end if;
	end process;

end Behavioral;

