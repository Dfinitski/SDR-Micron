




module clip_led (	// turn on LED for some milliseconds for clip indication
	input clock,
	input adc_overrange,
	output led_red);
	
	reg [31:0] timer;
	assign led_red = timer != 0;
	
	always @(posedge clock)
	begin
		if (adc_overrange)
			timer <= 32'd40000;// 200 msec
		else if (timer != 0)
			timer <= timer - 1'd1;
	end
	
	
endmodule


