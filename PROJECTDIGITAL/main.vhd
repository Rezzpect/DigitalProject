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
			
         A : out std_logic;
         B : out std_logic;
         C : out std_logic;
         D : out std_logic;
         E : out std_logic;
         F : out std_logic;
         G : out std_logic;
			
			C0 : out std_logic;
			C1 : out std_logic;
			C2 : out std_logic;
			C3 : out std_logic;

			BUZZER : out std_logic
		);
end main;

architecture Behavioral of main is
	signal x : natural range 0 to 635 := 0;
	signal y : natural range 0 to 525 := 0;

	constant X_VISIBLE_AREA : natural := 508;
	constant X_FRONT_PORCH : natural := 13;
	constant X_SYNC_PULSE : natural := 76;
	constant X_BACK_PORCH : natural := 38;
	constant X_WHOLE_LINE : natural := 635;

	constant Y_VISIBLE_AREA : natural := 480;
	constant Y_FRONT_PORCH : natural := 10;
	constant Y_SYNC_PULSE : natural := 2;
	constant Y_BACK_PORCH : natural := 33;
	constant Y_WHOLE_FRAME : natural := 525;

	constant right_border : natural := X_WHOLE_LINE - X_FRONT_PORCH + 2;
	constant left_border : natural := X_SYNC_PULSE + X_BACK_PORCH + 1;
	constant lower_border : natural := Y_WHOLE_FRAME - Y_FRONT_PORCH + 1;
	constant upper_border : natural := Y_SYNC_PULSE + Y_BACK_PORCH + 1;
	constant screen_width : natural := right_border - left_border;
	constant screen_height : natural := lower_border - upper_border;
	
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
	
begin
	process(CLOCK)
		---- FUNCTION ----
	
		impure function is_collide(
			box1 : box_entity;
			box2 : box_entity) return boolean is
		begin 
			if (box1.x + box1.width >= box2.x and box1.x + box1.width <= box2.x + box2.width) or (box1.x >= box2.x and box1.x <= box2.x + box2.width) then
				if (box1.y + box1.height >= box2.y and box1.y + box1.height <= box2.y + box2.height) or (box1.y >= box2.y and box1.y <= box2.y + box2.height) then
					return true;
				end if;
			end if;
			return false;
		end function;
				
		impure function collide(
			box1 : box_entity;
			box2 : box_entity) return box_entity is
			variable collidee : box_entity;
		begin
			collidee := box1;
			if is_collide(box1,box2) then
				if box1.x >= box2.x + box2.width or box1.x <= box2.x - box1.width then
					collidee.vx := 0 - collidee.vx;
				end if;
				if box1.y >= box2.y + box2.height or box1.y <= box2.y - box1.height then
					collidee.vy := 0 - collidee.vy;
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
		
		---- PROCEDURE ----	
		
		procedure set_color(
			color_c : color) is
		begin
			RED <= color_c.r;
			GREEN <= color_c.g;
			BLUE <= color_c.b;
		end procedure;

        procedure set_seven(
            num : natural) is 
            variable BCD : std_logic_vector(3 downto 0);
        begin
            BCD := std_logic_vector(to_unsigned(num,4));
            A <= BCD(0) OR BCD(2) OR (BCD(1) AND BCD(3)) OR (NOT BCD(1) AND NOT BCD(3));
            B <= (NOT BCD(1)) OR (NOT BCD(2) AND NOT BCD(3)) OR (BCD(2) AND BCD(3));
            C <= BCD(1) OR NOT BCD(2) OR BCD(3);
            D <= (NOT BCD(1) AND NOT BCD(3)) OR (BCD(2) AND NOT BCD(3)) OR (BCD(1) AND NOT BCD(2) AND BCD(3)) OR (NOT BCD(1) AND BCD(2)) OR BCD(0);
            E <= (NOT BCD(1) AND NOT BCD(3)) OR (BCD(2) AND NOT BCD(3));
            F <= BCD(0) OR (NOT BCD(2) AND NOT BCD(3)) OR (BCD(1) AND NOT BCD(2)) OR (BCD(1) AND NOT BCD(3));
            G <= BCD(0) OR (BCD(1) AND NOT BCD(2)) OR ( NOT BCD(1) AND BCD(2)) OR (BCD(2) AND NOT BCD(3));
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
            draw_shape((x => temp_x + 4,y => cord_y+7,vx => 0,vy => 0,width => 8,height => 3),(r=>'0',g=>'0',b=>'0'),false);

            temp_x := temp_x + 16;
            for i in 0 to hp loop
                draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 6,height => 16),(r=>'1',g=>'0',b=>'0'),false);
            end loop;
        end procedure;

			procedure set_common(
				digit_num : natural) is
			begin
				C0 <= '1';
				C1 <= '1';
				C2 <= '1';
				C3 <= '1';
				if digit_num = 0 then
					C0 <= '0';
				elsif digit_num = 1 then
					C1 <= '0';
				elsif digit_num = 2 then
					C2 <= '0';
				else
					C3 <= '0';
				end if;
			end procedure;

		---- VARIABLE ----
	
		variable player : box_entity := (
			x => (screen_width/2)- 48,
			y => ((2*screen_height)/3) + 40 ,
			vx => 0 ,
			vy => 0 ,
			width => 60,
			height => 4
		);
			
		variable brick : box_entity := (
			x => 0,
			y => 0,
			vx => 0 ,
			vy => 0 ,
			width => 100,
			height => 22
		);
			
		constant default_brick_hp : brick_life :=(life => 2);
				
		type record_of_brick is array (natural range 0 to brick_row*brick_column) of brick_life;
		variable brick_list : record_of_brick :=(
			others => default_brick_hp);
			
		variable brick_for_display : box_entity := (
			x => 0,
			y => 0,
			vx => 0 ,
			vy => 0 ,
			width => 100,
			height => 22
		);
		
		variable ball : box_entity := (
			x => (screen_width/2) - 4,
			y => (2*screen_height)/3,
			vx => -1 ,
			vy => -1 ,
			width => 8 ,
			height => 8
		);
		
		variable game_delay : natural range 0 to 1000000 := 0;
      	variable score : natural range 0 to 130 :=0;
      	variable health : natural range 0 to 3 := 3;
      	variable common : natural range 0 to 3 := 3;
    	variable temp_score : natural := 0;
      	variable c_count : natural range 0 to 100000:=0;
      	variable digit_score : natural := 0;
		variable game_start : boolean := false;
		variable brick_counter : natural range 0 to brick_num := 0;
		
	begin 
		
		if CLOCK'event and CLOCK = '1' then
			RED <= '0';
			GREEN <= '0';
			BLUE <= '0';
			set_common(common);
			
			game_delay := game_delay + 1;
			if game_delay = 100000 then
				--pause game--	
				if START ='1' then
					game_start := true;
				else
					game_start := false;
				end if; 

				game_delay := 0;
				---- update game ----
				--collide with left and right wall--
				if ball.x <= 1 or ball.x >= screen_width - ball.width then
					ball.vx := 0 - ball.vx;
				end if;
				--collide with upper wall--
				if ball.y <= 1 or ball.y >= screen_height - ball.height then
					ball.vy := 0 - ball.vy;
				end if;
				--collide with player--
				ball := collide(ball,player);
				

				--When game is not on pause -> do these thing--
				if game_start then
					--player movement--
					player.vx := 2*(to_integer(P_RIGHT)-to_integer(P_LEFT));
					if player.x > 1 and player.x < screen_width-player.width then
						player.x := player.x + player.vx;
					end if;
				
					if player.x < 1 then
						player.x := 2;
					end if;
					if player.x > screen_width-player.width then
						player.x := screen_width-player.width-1;
					end if;
						
					--move ball--
					ball.x := ball.x + ball.vx;
					ball.y := ball.y + ball.vy;
				end if;
			end if;
			draw_ball(ball);
			
			draw_shape(player,(r=>'1',g=>'1',b=>'1'),false);

         draw_hp(health,screen_width*3/4,4);

			--collide with brick--
			brick.x := (brick_counter mod brick_column)*(brick.width + 2);
			brick.y := 32 + (brick_counter / brick_column)*(brick.height +2);
			if brick_list(brick_counter).life > 0 and is_collide(ball,brick) then
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
			
				
            -- 7 segment --
            temp_score := score;
            c_count := c_count + 1;
            if c_count = 100000 then
                c_count := 0;
                if common = 0 then
                    temp_score := (temp_score mod 10);
                    digit_score := temp_score;
                elsif common = 1 then
                    temp_score := (temp_score mod 100);
                    digit_score := temp_score/10;
                elsif common = 2 then
                    digit_score := temp_score/100;
                elsif common = 3 then
                    digit_score := 0;
                end if;
                set_seven(digit_score);
            end if;

            
			-- Hsync and Vsync
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

			x <= x + 1;

			if x = X_WHOLE_LINE then
				y <= y + 1;
				x <= 0;
			end if;

        common := common +1 ;

        if common > 3 then
            common := 0;
        end if;

			if y = Y_WHOLE_FRAME then
				y <= 0;
			end if;
			
			brick_counter := brick_counter + 1;
				if brick_counter = brick_num then
					brick_counter := 0;
				end if;
		end if;
	end process;

end Behavioral;

