




module clip_led (	// turn on LED for some milliseconds for clip indication
	input clock,
	input reset,
	input adc_overrange,
	output reg led_red);
	
	wire ovf;
	cdc_sync #(1)
	s_c (.siga(adc_overrange), .rstb(0), .clkb(clock), .sigb(ovf));
	
	reg [31:0] timer;
	
	always @(posedge clock)
	begin
	   if(!reset)
		begin
		   led_red <= 0;
			timer <= 0;
		end
		else 
		begin
		   if(ovf) timer <= 32'd40000;// 200 msec
		   else if (timer != 0) timer <= timer - 1'd1;
			led_red <= timer>0;
		end		
	end
	
	
endmodule


