//
// ************ Bandscope*****************
//
//




module bandscope (
   input clock,
	input bs_on,
	input [7:0] bs_period,
	
	output reg bs_ready,
	output reg [11:0] mem_addr,
	
	input slow_clock  // 200 kHz
	);
	
	
	
	reg bs_start, bs_start_old;
	reg [15:0] cnt;
	
	initial
   begin	
	  bs_ready = 0;
	  mem_addr = 1'd0;
	  bs_start = 0;
	  bs_start_old = 0;
	  cnt <= 0;
	end  
	
	wire [15:0] comp = bs_period * 8'd200;
	
	always @(posedge slow_clock)  // start filling every .... ms
	begin
	   if(bs_on)
		begin
		  if(cnt<comp) cnt <= cnt + 1'd1;
		  else
		  begin
		    bs_start <= ~bs_start;
			 cnt <= 0;
		  end
		end
		else cnt <= 0;
	end
	

	
	always @(posedge clock)  // filling memory
	begin
		if(bs_start!=bs_start_old)
		begin
			if (mem_addr < 4095) mem_addr <= mem_addr + 1'd1;
			else 
			begin
			  bs_ready <= ~bs_ready;
			  bs_start_old <= bs_start;
			  mem_addr <= 0;
			end  
		end
	end
	
	
endmodule
	