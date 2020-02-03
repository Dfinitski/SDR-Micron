




module clip_led (	// turn on LED for some milliseconds for clip indication
	input clock,
	input reset,
	input run,
	input adc_overrange,
	output led
	);
	
	
	wire ovf;
	cdc_sync #(1)
	s_c (.siga(adc_overrange), .rstb(0), .clkb(clock), .sigb(ovf));
	
	reg [31:0] timer;
	
	assign led = reset & run & timer>0;

	always @(posedge clock) 
	begin
	   if(!reset | !run) timer <= 1'd0;
		else
		begin
		   if(ovf) timer <= 32'd40000;// 200 msec
		   else if(timer != 0) timer <= timer - 1'd1;
      end		
	end
	
	
endmodule


