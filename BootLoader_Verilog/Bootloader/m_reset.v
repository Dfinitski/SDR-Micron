




module master_reset (
	input clock,
	input pll2,
	output m_reset,
   output b_reset	
	);
	
	reg [31:0] reset_timer, boot_timer;

	initial
	begin
		reset_timer = 32'd100_000;	// time to release reset = 0.5 sec
		boot_timer = 32'd100_000;
	end
	
	assign m_reset = (reset_timer == 0);
	assign b_reset = (boot_timer == 0);
		
	always @(posedge clock)
		if (reset_timer!=0 & pll2)
			reset_timer <= reset_timer - 1'd1;
			
			
			
	always @(posedge clock)	
      if(boot_timer!=0 & m_reset)
		      boot_timer <= boot_timer - 1'd1;	
			
endmodule
