//
// David Fainitski for SDR Micron project
//

module attenuator (
   input clock,
	input reset,
	input run,
	input [7:0] _att,
	
	output reg CLK,
	output reg DAT,
	output reg EN
);
		
wire [5:0] att = run ? {_att[4:0], 1'b0} : 6'd63;	
	
	
reg [2:0] state;
reg [5:0] att_old;
reg [2:0] bit_cnt;


always @(posedge clock)
begin
   if(!reset)
	begin
	   CLK <= 0;
		DAT <= 0;
	   EN <= 0;
		state <= 0;
		att_old <= 6'd63;
	end
   else
	case(state)
	0: if(att != att_old)
	   begin
		   att_old <= att;
			bit_cnt <= 3'd5;
		   state <= 1;
		end
	1: begin
	      DAT <= att[bit_cnt]; 
		   state <= 2;
		end
	2: begin
	      CLK <= 1;
			state <= 3;
	   end
	3: begin
	      CLK <= 0;
			if(bit_cnt!=0)
			begin
			   bit_cnt <= bit_cnt - 1'd1;
				state <= 1;
			end
			else state <= 4;
	   end
	 4: begin
	       EN <= 1;
			 state <= 5;
	    end
	 5: begin
	       EN <= 0;
			 state <= 0;
	    end
	default: state <= 0;
	endcase
end


endmodule

