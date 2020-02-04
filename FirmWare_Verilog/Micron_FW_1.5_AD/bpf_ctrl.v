

//  BPF control///



module bpf_ctrl (
   input clock,
	input reset,
   input [31:0]freq,
	output [31:0] freq_hf,
	//
	output bpf_0,
	output bpf_1,
	output bpf_2,
	output vhf
	);

	
wire DATA = 0, CLK = 0, EN = 0;
assign bpf_0 = !vhf ? _bpf[0] : DATA;
assign bpf_1 = !vhf ? _bpf[1] : CLK;
assign bpf_2 = !vhf ? _bpf[2] : EN;
//
assign vhf = 0; // freq[31:16] > 458;

assign freq_hf = freq;

reg [2:0] _bpf;
	
always @(posedge clock)	
if(!reset)
begin
   _bpf <= 3'd7;
end
else
begin
   if (freq[31:16] <= 38) _bpf <= 3'd6; // 0-2.5MHz
	else
	if (freq[31:16] <= 91) _bpf <= 3'd2; // 2.5-6.0 MHz
	else
	if (freq[31:16] <= 191) _bpf <= 3'd0; // 6.0 - 12.5 MHz
	else
	if (freq[31:16] <= 305) _bpf <= 3'd3; // 12.5 - 20.0 MHz
	else
	if (freq[31:16] <= 458) _bpf <= 3'd1; // 20 - 30 MHz
	else
	_bpf <= 3'd7; // > 30 MHz Bypass
end	
//


reg [7:0] state;

always @(posedge clock)
if(!reset)
begin
   state <= 1'd0;
end
else case (state)

   0: state <= 0;
	
	
   default: state <= 1'd0;
	





endcase
	
endmodule

