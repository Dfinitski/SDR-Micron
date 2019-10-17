//
// ************ Bandscope*****************
//  David Fainitski for SDR Micron project
//  2019




module bandscope (
   input clock,
	input _bs_on,
	input [7:0] _bs_period,
	
	output reg bs_ready,
	output reg [14:0] mem_addr,
	
	input slow_clock  // 200 kHz
	);
	
	
	
	wire bs_on;
	cdc_sync #(1)
	b_o (.siga(_bs_on), .rstb(0), .clkb(clock), .sigb(bs_on));
	
	wire [7:0] bs_period;
	cdc_sync #(8)
	b_p (.siga(_bs_period), .rstb(0), .clkb(clock), .sigb(bs_period));
	
	
	reg _bs_start, bs_start_old;
	reg [15:0] cnt;
	
	initial
   begin	
	  bs_ready = 0;
	  mem_addr = 1'd0;
	  bs_start_old = 0;
	  cnt <= 0;
	end  
	
	wire [15:0] comp = bs_period < 8'd50 ? 8'd50 * 8'd200 : bs_period * 8'd200;
	
	// start filling every .... ms
	always @(posedge slow_clock)  
	begin
	   if(bs_on)
		begin
		  if(cnt<comp) cnt <= cnt + 1'd1;
		  else
		  begin
		    _bs_start <= ~_bs_start;
			 cnt <= 0;
		  end
		end
		else cnt <= 0;
	end
	
	
   wire bs_start;
	cdc_sync #(1)
	s_c (.siga(_bs_start), .rstb(0), .clkb(clock), .sigb(bs_start));
	
	
	// filling memory
	always @(negedge clock)  
	begin
		if(bs_start!=bs_start_old)
		begin
			if (mem_addr<16383) mem_addr <= mem_addr + 1'd1;
			else 
			begin
			  bs_ready <= ~bs_ready;
			  bs_start_old <= bs_start;
			  mem_addr <= 0;
			end  
		end
	end
	
	
endmodule
	