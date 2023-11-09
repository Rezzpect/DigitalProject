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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity main is
	port (
			P_LEFT : in std_logic;
			P_RIGHT : in std_logic;

			CLOCK : in std_logic;
			HSYNC : out std_logic;
			VSYNC : out std_logic;
			RED : out std_logic;
			GREEN : out std_logic;
			BLUE : out std_logic;

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
				if (box1.y + box1.height >= box2.y and box1.y + box1.height <= box2.y + box2.height) or (box1.y + box1.height >= box2.y and box1.y + box1.height <= box2.y + box2.height) then
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
			width => 96,
			height => 20
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
			width => 96,
			height => 20
		);
		
		variable ball : box_entity := (
			x => screen_width/2,
			y => (2*screen_height)/3,
			vx => -1 ,
			vy => -1 ,
			width => 8 ,
			height => 8
		);
		
		variable game_delay : natural range 0 to 1000000 := 0;
		
	begin 
		
		if CLOCK'event and CLOCK = '1' then
			RED <= '0';
			GREEN <= '0';
			BLUE <= '0';
			
			game_delay := game_delay + 1;
			if game_delay = 100000 then
				game_delay := 0;
				---- update game ----
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
				
				--move ball--
				ball.x := ball.x + ball.vx;
				ball.y := ball.y + ball.vy;
				
			end if;
			draw_ball(ball);
			
			draw_shape(player,(r=>'1',g=>'1',b=>'1'),false);
			
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

			if y = Y_WHOLE_FRAME then
				y <= 0;
			end if;
		end if;
	end process;

end Behavioral;

