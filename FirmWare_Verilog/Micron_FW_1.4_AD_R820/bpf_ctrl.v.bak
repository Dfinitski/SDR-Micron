

//  BPF control///



module bpf_ctrl (
   input [15:0] freq,
	output reg [2:0] bpf
	);
	
	
always @(freq)	// freq is freqoency in Hz devided by 65536
begin
   if (freq <= 38) bpf <= 3'd6; // 0-2.5MHz
	else
	if (freq <= 91) bpf <= 3'd2; // 2.5-6.0 MHz
	else
	if (freq <= 191) bpf <= 3'd0; // 6.0 - 12.5 MHz
	else
	if (freq <= 305) bpf <= 3'd3; // 12.5 - 20.0 MHz
	else
	bpf <= 3'd1; // 20 - 30 MHz
end



endmodule

