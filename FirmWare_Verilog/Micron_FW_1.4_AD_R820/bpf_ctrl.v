

//  BPF control///



module bpf_ctrl (
   input clock,
	input reset,
   input [15:0] freq,
	//
	inout bpf_0,
	output bpf_1,
	inout bpf_2,
	input vhf,
	//
	input vhf_sda,
	input vhf_scl
	);


assign bpf_0 = !vhf ? _bpf[0] : (vhf_sda ? 1'bz : 1'b0);
assign bpf_1 = _bpf[1];
assign bpf_2 = !vhf ? _bpf[2] : (vhf_scl ? 1'bz : 1'b0);

reg [2:0] _bpf;
	
always @(posedge clock )	// freq is frequency in Hz devided by 65536
if(!reset)
begin
   _bpf <= 3'd7;
end
else
begin
   if (freq <= 38) _bpf <= 3'd6; // 0-2.5MHz
	else
	if (freq <= 91) _bpf <= 3'd2; // 2.5-6.0 MHz
	else
	if (freq <= 191) _bpf <= 3'd0; // 6.0 - 12.5 MHz
	else
	if (freq <= 305) _bpf <= 3'd3; // 12.5 - 20.0 MHz
	else
	if (freq <= 534) _bpf <= 3'd1; // 20 - 35 MHz
	else
	_bpf <= 3'd7; // > 35 MHz Bypass
end	
	//
	
endmodule

