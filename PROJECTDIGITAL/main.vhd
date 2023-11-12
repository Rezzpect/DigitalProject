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

    ---- CLOCK AND DELAY ----

	constant my_clock : natural := 20_000_000;
    constant start_dt : natural := 1000;
	constant game_dt : natural := X_WHOLE_LINE * Y_WHOLE_FRAME;
    constant common_mod : natural := my_clock / 200;
	
	---- CONSTANT ----
	
	constant brick_row : natural := 8;
	constant brick_column : natural := 5;
	constant brick_num : natural := brick_row*brick_column;
    constant brick_w : natural := (screen_width / brick_column);
    constant brick_h : natural := 20;
    constant brick_offsetY : natural := 32;
    constant brick_gap : natural := 2;

    constant max_score : natural := brick_num * 4;
    constant max_health : natural := 3 ;

    constant ball_size : natural := 8;
    constant ball_sx : natural := (screen_width / 2) - (ball_size / 2);
    constant ball_sy : natural := (5 * screen_height) / 6;
    constant ball_speed : integer := 2;

    constant player_w : natural := 60;
    constant player_h : natural := 4;
    constant player_sx : natural := (screen_width / 2) - (player_w / 2);
    constant player_sy : natural := ((9 * screen_height) / 10);

    ---- SIGANL ----

	signal mode_signal : boolean := false;
    signal game_start : boolean := false;
	signal game_running : boolean := false;
	signal game_end : boolean := false;
	signal game_win : boolean := false;
    signal start_delay : natural range 0 to start_dt:= 0;
	signal game_delay : natural range 0 to game_dt := 0;
	signal score : natural range 0 to max_score := 0;
	signal health : natural range 0 to max_health := max_health;
	signal brick_counter : natural range 0 to brick_num := 0;
    signal common_port : natural range 0 to 3 := 0;
	signal common_f_mod : natural range 0 to common_mod := common_mod;
	signal buzzer_time : natural := 0;
	signal end_delay : natural range 0 to game_dt := 0;
	
	---- RECORD ----
	
	type box_entity is record
		x : integer range -10 to screen_width+10;
		y : integer range -10 to screen_height+10;
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
	
	type more_color is record
		color1 : color;
		color2 : color;
	end record;

	type brick_life is record
	    life : natural range 0 to 2;
	end record;

    ---- VARIABLE ----

    shared variable player : box_entity := (
        x => player_sx,
        y => player_sy,
        vx => 0 ,
        vy => 0 ,
        width => player_w,
        height => player_h
    );
        
    shared variable brick : box_entity := (
        x => 0,
        y => 0,
        vx => 0 ,
        vy => 0 ,
        width => brick_w,
        height => brick_h
    );
        
    constant default_brick_hp : brick_life :=(life => 2);
            
    type record_of_brick is array ( natural range 0 to brick_num ) of brick_life;

    shared variable brick_list : record_of_brick := ( others => default_brick_hp);
        
    shared variable brick_for_display : box_entity := (
        x => 0,
        y => 0,
        vx => 0 ,
        vy => 0 ,
        width => brick_w,
        height => brick_h
    );
    
    shared variable ball : box_entity := (
        x => ball_sx,
        y => ball_sy,
        vx => -ball_speed ,
        vy => -ball_speed ,
        width => ball_size ,
        height => ball_size
    );
	
	---- COLOR ----
	constant color_grey : more_color := (
		color1 => ( r => '1', g => '1', b => '1' ),
		color2 => ( r => '0', g => '0', b => '0' )
	);
	constant color_white : more_color := (
		color1 => ( r => '1', g => '1', b => '1' ),
		color2 => ( r => '1', g => '1', b => '1' )
	);
	constant color_black : more_color := (
		color1 => ( r => '0', g => '0', b => '0' ),
		color2 => ( r => '0', g => '0', b => '0' )
	);
	constant color_red : more_color := (
		color1 => ( r => '1', g => '0', b => '0' ),
		color2 => ( r => '1', g => '0', b => '0' )
	);
	constant color_orange : more_color := (
		color1 => ( r => '1', g => '1', b => '0' ),
		color2 => ( r => '1', g => '0', b => '0' )
	);
	constant color_yellow : more_color := (
		color1 => ( r => '1', g => '1', b => '0' ),
		color2 => ( r => '1', g => '1', b => '0' )
	);
	constant color_lime : more_color := (
		color1 => ( r => '1', g => '1', b => '0' ),
		color2 => ( r => '0', g => '1', b => '0' )
	);
	constant color_green : more_color := (
		color1 => ( r => '0', g => '1', b => '0' ),
		color2 => ( r => '0', g => '1', b => '0' )
	);
	constant color_sky : more_color := (
		color1 => ( r => '0', g => '1', b => '1' ),
		color2 => ( r => '0', g => '1', b => '0' )
	);
	constant color_blue : more_color := (
		color1 => ( r => '0', g => '0', b => '1' ),
		color2 => ( r => '0', g => '0', b => '1' )
	);
	constant color_purple : more_color := (
		color1 => ( r => '1', g => '0', b => '1' ),
		color2 => ( r => '0', g => '0', b => '1' )
	);
	
	type color_array is array (natural range 0 to 7) of more_color;
		constant color_list : color_array := (
			0 => color_red,
			1 => color_orange,
			2 => color_yellow,
			3 => color_lime,
			4 => color_green,
			5 => color_sky,
			6 => color_blue,
			7 => color_purple
		);
	
begin

	geme_signal : process(CLOCK) begin

		if rising_edge(CLOCK) then

			-- Game Signal --	
			if START = '1' then
				start_delay <= start_delay + 1;

				if start_delay = start_dt then
					mode_signal <= true;
				else
					mode_signal <= false;	
				end if;

			else
				start_delay <= 0;
			end if; 

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
			end if;
			return false;
		end function;
				
		impure function collide(
			box1 : box_entity;
			box2 : box_entity) return box_entity is
			variable collidee : box_entity;
			constant tolerance : natural := 5;
		begin
			collidee := box1;
			if is_collide(box1,box2) then
				if abs((box2.y+box2.height) - box1.y) < tolerance and box1.vy < 0 then
					collidee.vy := -collidee.vy;
				end if;
				if abs(box2.y - (box1.y+box1.height)) < tolerance and box1.vy > 0 then
					collidee.vy := -collidee.vy;
				end if;
				if abs((box2.x+box2.width) - box1.x) < tolerance and box1.vx < 0 then
					collidee.vx := -collidee.vx;
				end if;
				if abs(box2.x - (box1.x+box1.width)) < tolerance and box1.vx > 0 then
					collidee.vx := -collidee.vx;
				end if;
                buzzer_time <= 5_000_000;
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
		
		if rising_edge(CLOCK) then

			-- Game Signal --	
			
			if mode_signal then

				if (not game_running) and (not game_end) and (end_delay = 0) then
					game_start <= true;
					game_running <= true;
				elsif game_end then
					brick_list := (others => default_brick_hp);
					health <= 3;
					score <= 0;
					game_end <= false;
					game_win <= false;
				else
					game_start <= not game_start;
				end if;

			end if;

            -- When game is not on pause -> do these thing --
				
			if (game_delay = game_dt) and game_running and game_start then
                -- player movement --
                player.vx := (2 * ball_speed) * (to_integer(P_RIGHT) - to_integer(P_LEFT));
                player.x := player.x + player.vx;

                -- player collide with left wall --
                if player.x < 1 then
                    player.x := 1;
                end if;

                -- player collide with right wall --
                if player.x > screen_width-player.width-1 then
                    player.x := screen_width-player.width-1;
                end if;
                    
                -- move ball --
                ball.x := ball.x + ball.vx;
                ball.y := ball.y + ball.vy;

			end if;

            -- ball collide with left and right wall --
            if ball.x <= 1 or ball.x >= screen_width - ball.width then
                ball.vx := -ball.vx;
                buzzer_time <= 5_000_000;
            end if;

            -- ball collide with upper wall --
            if ball.y <= 1 then
                ball.vy := -ball.vy;
                buzzer_time <= 5_000_000;
            end if;
            
            -- ball collide with bottom wall --
            if ball.y >= screen_height - ball.height then
                game_start <= false;
                ball.x := ball_sx;
                ball.y := ball_sy;
                player.x := player_sx;
                player.y := player_sy;
                buzzer_time <= 10_000_000;

				health <= health - 1;

            end if;	

			if health = 0 then
				game_start <= false;
				game_running <= false;
				game_end <= true;
			end if;

            -- collide with player --
			ball := collide(ball,player);

			-- collide with brick --
			brick.x := (brick_counter mod brick_column)*(brick.width + brick_gap);
			brick.y := brick_offsetY + (brick_counter / brick_column)*(brick.height + brick_gap);

			if brick_list(brick_counter).life > 0 and is_collide(ball,brick) then
				ball := collide(ball,brick);
				brick_list(brick_counter).life :=  brick_list(brick_counter).life - 1;

				if brick_list(brick_counter).life > 0 then
					score <= score + 1;
				else
					score <= score + 3;
				end if;

				ball.x := ball.x + ball.vx;
				ball.y := ball.y + ball.vy;
			end if;

			if score = max_score and not game_win then
				ball.x := ball_sx;
				ball.y := ball_sy;
				player.x := player_sx;
				player.y := player_sy;
				buzzer_time <= 10_000_000;
				game_win <= true;
				game_start <= false;
				game_running <= false;
				game_end <= true;
			end if;
			
			--Sound Buzzer--
			if buzzer_time > 0 then
				buzzer_time <= buzzer_time - 1;
				BUZZER <= '1';
			else
				BUZZER <= '0';
			end if;
			
		end if;
	end process;

    drawing : process(CLOCK) 

        ---- PROCEDURE ----

        procedure set_color(
			color_c : color) is
		begin
			RED <= color_c.r;
			GREEN <= color_c.g;
			BLUE <= color_c.b;
		end procedure;
			
		procedure draw_shape(
			shape : box_entity;
			color_c : more_color;
			transparent : boolean) is
		begin
			if x >= shape.x + left_border and x < shape.x + left_border + shape.width and y >= shape.y + upper_border and y < shape.y + shape.height + upper_border then
				if y mod 2 = 0 then
					if x mod 2 = 0 then
						set_color(color_c.color1);
					else
						set_color(color_c.color2);
					end if;
				elsif transparent = false then
					if x mod 2 = 1 then
						set_color(color_c.color1);
					else
						set_color(color_c.color2);
					end if;
				end if;

			end if;
		end procedure;
			
		procedure draw_ball(
			ball : box_entity)is
			variable radius : natural := ball.width/2;
		begin 
			if (x-(ball.x+left_border+radius))*(x-(ball.x+left_border+radius)) + (y-(ball.y+upper_border+radius))*(y-(ball.y+upper_border+radius)) <= radius*radius then
				set_color(color_white.color1);
			end if;
		end procedure;

        procedure draw_hp(
            hp : natural;
            cord_x : natural;
            cord_y : natural) is
			variable temp_x :natural;
			variable temp_hp :natural;
        begin 
			--L--
			temp_x := cord_x;
			draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 12,height => 16),color_white,false);
            draw_shape((x => temp_x + 4,y => cord_y,vx => 0,vy => 0,width => 8,height => 12),color_black,false);
            --I--
            temp_x := temp_x + 12 +2;
            draw_shape((x =>  temp_x,y => cord_y,vx => 0,vy => 0,width => 12,height => 16),color_white,false);
            draw_shape((x => temp_x,y => cord_y+4,vx => 0,vy => 0,width => 4,height => 8),color_black,false);
            draw_shape((x => temp_x + 8,y => cord_y+4,vx => 0,vy => 0,width => 4,height => 8),color_black,false);
            --V--
            temp_x := temp_x + 12 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 12,height => 16),color_white,false);
            draw_shape((x => temp_x,y => cord_y+12,vx => 0,vy => 0,width => 4,height => 4),color_black,false);
            draw_shape((x => temp_x + 4,y => cord_y,vx => 0,vy => 0,width => 4,height => 12),color_black,false);
            draw_shape((x => temp_x + 8,y => cord_y+12,vx => 0,vy => 0,width => 4,height => 4),color_black,false);
            --E--
            temp_x :=  temp_x + 12 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 12,height => 16),color_white,false);
            draw_shape((x => temp_x + 4,y => cord_y+4,vx => 0,vy => 0,width => 8,height => 3),color_black,false);
            draw_shape((x => temp_x + 4,y => cord_y+9,vx => 0,vy => 0,width => 8,height => 3),color_black,false);
				
			temp_x := temp_x + 16;
			temp_hp := hp;
            for i in 0 to 2 loop
					if temp_hp > 0 then
						draw_shape((x => temp_x+(i*10),y => cord_y,vx => 0,vy => 0,width => 6,height => 16),color_red,false);
						temp_hp := temp_hp - 1;
					end if;
            end loop;
        end procedure;

		procedure draw_start(
            cord_x : natural;
            cord_y : natural) is
			variable temp_x :natural;
			variable temp_hp :natural;
        begin 
			temp_x := cord_x;
            --S--
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x + 8,y => cord_y + 5,vx => 0,vy => 0,width => 14,height => 5),color_black,false);
			draw_shape((x => temp_x,y => cord_y + 16,vx => 0,vy => 0,width => 14,height => 5),color_black,false);
            --T--
            temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x,y => cord_y+5,vx => 0,vy => 0,width => 7,height => 21),color_black,false);
            draw_shape((x => temp_x+15,y => cord_y+5,vx => 0,vy => 0,width => 7,height => 21),color_black,false);
            --A--
            temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 7,height => 5),color_black,false);
            draw_shape((x => temp_x+15,y => cord_y,vx => 0,vy => 0,width => 7,height => 5),color_black,false);
			draw_shape((x => temp_x+7,y => cord_y+5,vx => 0,vy => 0,width => 8,height => 5),color_black,false);
			draw_shape((x => temp_x+7,y => cord_y+16,vx => 0,vy => 0,width => 8,height => 10),color_black,false);
            --R--
            temp_x :=  temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x+7,y => cord_y+5,vx => 0,vy => 0,width => 8,height => 5),color_black,false);
			draw_shape((x => temp_x+15,y => cord_y+11,vx => 0,vy => 0,width => 7,height => 5),color_black,false);
			draw_shape((x => temp_x+7,y => cord_y+16,vx => 0,vy => 0,width => 8,height => 10),color_black,false);
			--T--
            temp_x := temp_x + 22 +2;
            draw_shape((x =>  temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x,y => cord_y+5,vx => 0,vy => 0,width => 7,height => 21),color_black,false);
            draw_shape((x => temp_x+15,y => cord_y+5,vx => 0,vy => 0,width => 7,height => 21),color_black,false);

        end procedure;

		procedure draw_pause(
            cord_x : natural;
            cord_y : natural) is
			variable temp_x :natural;
			variable temp_hp :natural;
        begin 
			temp_x := cord_x;
            --P--
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
			draw_shape((x => temp_x+7,y => cord_y+5,vx => 0,vy => 0,width => 8,height => 5),color_black,false);
			draw_shape((x => temp_x+7,y => cord_y+16,vx => 0,vy => 0,width => 15,height => 10),color_black,false);
            --A--
			temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 7,height => 5),color_black,false);
            draw_shape((x => temp_x+15,y => cord_y,vx => 0,vy => 0,width => 7,height => 5),color_black,false);
			draw_shape((x => temp_x+7,y => cord_y+5,vx => 0,vy => 0,width => 8,height => 5),color_black,false);
			draw_shape((x => temp_x+7,y => cord_y+16,vx => 0,vy => 0,width => 8,height => 10),color_black,false);
            --U--
            temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
			draw_shape((x => temp_x+7,y => cord_y,vx => 0,vy => 0,width => 8,height => 20),color_black,false);
            --S--
			temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x+8,y => cord_y+5,vx => 0,vy => 0,width => 14,height => 5),color_black,false);
			draw_shape((x => temp_x,y => cord_y+16,vx => 0,vy => 0,width => 14,height => 5),color_black,false);
			--E--
			temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x+8,y => cord_y+5,vx => 0,vy => 0,width => 14,height => 5),color_black,false);
			draw_shape((x => temp_x+8,y => cord_y+16,vx => 0,vy => 0,width => 14,height => 5),color_black,false);

        end procedure;

		procedure draw_end(
            cord_x : natural;
            cord_y : natural) is
			variable temp_x :natural;
			variable temp_hp :natural;
        begin 
			temp_x := cord_x;
            --E--
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x+8,y => cord_y+5,vx => 0,vy => 0,width => 14,height => 5),color_black,false);
			draw_shape((x => temp_x+8,y => cord_y+16,vx => 0,vy => 0,width => 14,height => 5),color_black,false);
            --N--
            temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 5,height => 26),color_white,false);
            draw_shape((x => temp_x+5,y => cord_y+5,vx => 0,vy => 0,width => 4,height => 5),color_white,false);
			draw_shape((x => temp_x+9,y => cord_y+10,vx => 0,vy => 0,width => 4,height => 6),color_white,false);
			draw_shape((x => temp_x+13,y => cord_y+16,vx => 0,vy => 0,width => 4,height => 5),color_white,false);
			draw_shape((x => temp_x+17,y => cord_y,vx => 0,vy => 0,width => 5,height => 26),color_white,false);
            --D--
            temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x+15,y => cord_y,vx => 0,vy => 0,width => 7,height => 5),color_black,false);
            draw_shape((x => temp_x+15,y => cord_y+21,vx => 0,vy => 0,width => 7,height => 5),color_black,false);
			draw_shape((x => temp_x+7,y => cord_y+5,vx => 0,vy => 0,width => 7,height => 16),color_black,false);

        end procedure;

		procedure draw_win(
            cord_x : natural;
            cord_y : natural) is
			variable temp_x :natural;
			variable temp_hp :natural;
        begin 
			temp_x := cord_x;
            --W--
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x+5,y => cord_y,vx => 0,vy => 0,width => 4,height => 20),color_black,false);
			draw_shape((x => temp_x+13,y => cord_y,vx => 0,vy => 0,width => 4,height => 20),color_black,false);
			draw_shape((x => temp_x,y => cord_y+20,vx => 0,vy => 0,width => 5,height => 6),color_black,false);
			draw_shape((x => temp_x+17,y => cord_y+20,vx => 0,vy => 0,width => 5,height => 6),color_black,false);
			--I--
            temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 22,height => 26),color_white,false);
            draw_shape((x => temp_x,y => cord_y+5,vx => 0,vy => 0,width => 7,height => 16),color_black,false);
            draw_shape((x => temp_x+15,y => cord_y+5,vx => 0,vy => 0,width => 7,height => 16),color_black,false);
            --N--
            temp_x := temp_x + 22 +2;
            draw_shape((x => temp_x,y => cord_y,vx => 0,vy => 0,width => 5,height => 26),color_white,false);
            draw_shape((x => temp_x+5,y => cord_y+5,vx => 0,vy => 0,width => 4,height => 5),color_white,false);
			draw_shape((x => temp_x+9,y => cord_y+10,vx => 0,vy => 0,width => 4,height => 6),color_white,false);
			draw_shape((x => temp_x+13,y => cord_y+16,vx => 0,vy => 0,width => 4,height => 5),color_white,false);
			draw_shape((x => temp_x+17,y => cord_y,vx => 0,vy => 0,width => 5,height => 26),color_white,false);

        end procedure;
    
    begin

        if rising_edge(CLOCK) then
			RED <= '0';
			GREEN <= '0';
			BLUE <= '0';

			if (not game_running) and (not game_end) then
				draw_start(abs(player_sx - ((118-player_w)/2)) ,ball_sy - 26 - 10);

			elsif game_end then
				if game_win then
					draw_win(abs(player_sx - ((70-player_w)/2)) ,ball_sy - 26 - 10);
				else
					draw_end(abs(player_sx - ((70-player_w)/2)) ,ball_sy - 26 - 10);
				end if;

			elsif (not game_start) then
				draw_pause(abs(player_sx - ((118-player_w)/2)) ,ball_sy - 26 - 10);
			end if;

			if not game_end then
            	draw_ball(ball);
				draw_shape(player,color_white,false);
			end if;

         	draw_hp(health,screen_width*3/4,4);

            -- draw brick--
			for i in 0 to brick_row - 1 loop
				for j in 0 to brick_column - 1 loop
					brick_for_display.x := (j mod brick_column) * (brick_for_display.width + brick_gap);
					brick_for_display.y := brick_offsetY + (i mod brick_row) * (brick_for_display.height + brick_gap);

					if brick_list((brick_column*i) + j).life = 2 then
						 draw_shape(brick_for_display,color_list(i),false);
					end if;

					if brick_list((brick_column*i) + j).life = 1 then
						 draw_shape(brick_for_display,color_list(i),true);
					end if;

				end loop;
			end loop;

        end if;
    
    end process;
	
	Seven_segment : process(CLOCK)
	
		procedure BCD_to_seven(
            num : natural) is 
            variable BCD : std_logic_vector(3 downto 0);
        begin
            BCD := std_logic_vector(to_unsigned(num,4));
            if BCD = "0000" then
					SEGMENT <= "1111110";
				elsif BCD = "0001" then
					SEGMENT <= "0110000";
				elsif BCD = "0010" then
					SEGMENT <= "1101101";
				elsif BCD = "0011" then
					SEGMENT <= "1111001";
				elsif BCD = "0100" then
					SEGMENT <= "0110011";
				elsif BCD = "0101" then
					SEGMENT <= "1011011";
				elsif BCD = "0110" then
					SEGMENT <= "1011111";
				elsif BCD = "0111" then
					SEGMENT <= "1110000";
				elsif BCD = "1000" then
					SEGMENT <= "1111111";
				elsif BCD = "1001" then
					SEGMENT <= "1111011";
				end if;
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
			-- Switch Common--
			if common_f_mod = common_mod then

				set_common(common_port);
				select_digit(common_port,score);

				common_f_mod <= 0;
				common_port <= common_port +1 ;

				if common_port > 3 then
					common_port <= 0;
				end if;

			end if;
			common_f_mod <= common_f_mod + 1;

		end if;
	end process;

	counter_manager : process(CLOCK) begin

		if rising_edge(CLOCK) then
			-- Brick Counter --
			if brick_counter < brick_num - 1 then
				brick_counter <= brick_counter + 1;
			else
				brick_counter <= 0;
			end if;

            -- Game Counter --
			if (game_delay < game_dt) then
				game_delay <= game_delay + 1;
			else
				game_delay <= 0;
			end if;
			
			if (game_end) then
				end_delay <= game_dt;
			elsif (end_delay > 0) then
				end_delay <= end_delay - 1;
			else
				end_delay <= 0;
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
