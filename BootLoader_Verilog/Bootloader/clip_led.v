




module clip_led (	// turn on LED for some milliseconds for clip indication
	input clock,
	input reset,
	input mode,
	output reg led_red
	);
	
	localparam period = 32'd50_000;
	
	reg [31:0] timer;
	initial
   begin
   	timer = period;
		led_red = 0;
	end	
	
	
	always @(posedge clock)
	begin
	   if(!reset | !mode) led_red <= 0;
		else if(timer != 0) timer <= timer - 1'd1;
		else 
		begin
			timer <= period;
			led_red <= ~led_red;
		end	
	end
	
endmodule


