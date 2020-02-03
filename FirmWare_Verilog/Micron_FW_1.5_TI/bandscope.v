//
// ************ Bandscope*****************
//  David Fainitski for SDR Micron project
//  2019




module bandscope (
   input clock,
	input bs_on,
	input [7:0] bs_period,
	
	output reg bs_ready,
	output reg [14:0] mem_addr,
	
	input slow_clock  // 200 kHz
	);
	
	
	reg _bs_start, bs_start_old;
	reg [15:0] cnt;
	
	
	// start filling every .... ms
	always @(posedge slow_clock)  
	begin
	   if(!bs_on)
		begin
		   cnt <= 0;
			_bs_start <= 0;
		end
	   else
		begin
		  if(cnt<(bs_period * 8'd200)) cnt <= cnt + 1'd1;
		  else
		  begin
		    _bs_start <= ~_bs_start;
			 cnt <= 0;
		  end
		end
	end
	
   wire bs_start;
	cdc_sync #(1)
	s_c (.siga(_bs_start), .rstb(0), .clkb(clock), .sigb(bs_start));
	
	
	initial
	begin
	   bs_start_old <= 0;
		mem_addr <= 1'd0;
		bs_ready <= 0;
	end
	
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
	
	//
endmodule
	