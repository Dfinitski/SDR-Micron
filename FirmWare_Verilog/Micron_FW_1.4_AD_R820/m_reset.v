




module master_reset (
	input clock,
	input pll2,
	output reset		
	);
	
	reg [31:0] reset_timer;

	initial
	begin
		reset_timer = 32'd100_000;	// time to release reset = 0.5 sec
	end
	
	assign reset = (reset_timer == 0);
		
	always @(posedge clock)
		if (reset_timer != 0 & pll2)
			reset_timer <= reset_timer - 1'd1;
endmodule
