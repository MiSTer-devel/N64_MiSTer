
module N64_SNAC(
		input reset,
		input clk_1x,
		input input1,
		output reg output1,
		input start,
		output reg [7:0]dataOut=8'd0,
		input [7:0] cmdData, 
		output reg byteRec,
		output reg ready,
		input toPad_ena,
		output reg timeout,
		input [5:0] receiveCnt,
		input [5:0] sendCnt
);

localparam THIRTYTWOuSECONDS = 12'd2560;
localparam THREEuSECONDS = 8'd245;
localparam TWOuSECONDS = 8'd161;
localparam ONEuSECONDS = 8'd82;

reg [11:0]waitTimer = 12'd0;
reg [8:0]counter = 9'd0;
reg [2:0]bitCnt = 3'd0;
reg [5:0]byteCnt = 6'd0;
reg [2:0]state;
reg input2;
reg oldinput;
reg counterEn;

//states
//00 idle
//01 send low part of bit
//02 send high part of bit
//03 next bit or byte or stop
//04 next bit
//05 stop bit
//06 send end
//07 receive

always@(posedge clk_1x)
begin

	if (reset) state <= 3'd0;
	if (timeout) timeout <= 1'b0;
	if (byteRec) byteRec <= 1'b0;
	
	input2 <= input1; //stabilize the input
	oldinput <= input2;

	case (state)
		3'd0: begin //idle
			ready <= 1'b1;
			if (start) begin //send command, data and stop bit
				bitCnt <= 3'd7;
				byteCnt <= sendCnt;
				state <= 3'd1;
				ready <= 1'b0;
			end
			output1 <= 1'b1;
		end

		3'd1: begin //send low part of bit
			counter <= cmdData[bitCnt] ? ONEuSECONDS : THREEuSECONDS;
			output1 <= 1'b0;
			state <= 3'd2;	
		end	

		3'd2: begin // wait + send high part of bit
			counter <= counter - 1'b1;
			if (counter == 1) begin
				counter <= cmdData[bitCnt] ? THREEuSECONDS : ONEuSECONDS;
				output1 <= 1'b1;
				state <= 3'd3;	
			end	
		end	

		3'd3: begin //wait + next bit or byte or stop bit
			counter<=counter - 1'b1;
			if (counter == 1) begin
				if (bitCnt > 0) begin//next bit
					bitCnt <= bitCnt - 3'd1;
					state <= 3'd1;	
				end	
				else begin
					if (byteCnt > 1) begin//next byte
					   ready <= 1'b1;
						state <= 3'd4;	
					end else begin //stop bit
						counter <= ONEuSECONDS;
						output1 <= 1'b0;
						state <= 3'd5;					
					end
				end
			end
		end
		
		3'd4: begin //next byte
			if (toPad_ena) begin
				ready <= 1'b0;
				byteCnt <= byteCnt - 6'd1;
				bitCnt <= 3'd7;
				state <= 3'd1;
			end	
		end		

		3'd5: begin // stop bit
			counter <= counter - 1'b1;		
			if (counter == 1) begin
				output1 <= 1'b1;
				state <= 3'd6;
				counter <= 9'd20; //short wait to make sure input is high
			end	
		end

		3'd6: begin // send end
			counter <= counter - 1'b1;		
			if (counter == 1) begin
				state <= 3'd7;
				bitCnt <= 3'd7;
				byteCnt <= 6'd0;
				waitTimer <= THIRTYTWOuSECONDS; //set timeout timer, unsure of value
			end
		end	

		3'd7: begin // receive
			waitTimer <= waitTimer - 1'b1;	
			if (waitTimer == 1) begin
				timeout <= 1'd1; //timeout,no pad check
				state <= 3'd0;				
			end
		
			if (oldinput && ~input2) begin //falling edge, start timer
				waitTimer <= THIRTYTWOuSECONDS; //reset wait timer
				counterEn <= 1'b1;
			end
		
			if(counterEn) counter <= counter + 1'b1;		

			if (~oldinput && input2) begin //rising edge, bit recieved
				waitTimer <= THIRTYTWOuSECONDS; 
				counterEn <= 1'b0;
				counter <= 9'd0;
				if (bitCnt > 0) begin
					bitCnt <= bitCnt - 3'd1; //next bit
					dataOut[bitCnt] <= (counter < TWOuSECONDS); //bit equals 1 if under 2us
				end else begin //next byte or stop.				
					if (byteCnt < receiveCnt) begin //next byte
						dataOut[bitCnt] <= (counter < TWOuSECONDS);
						byteCnt <= byteCnt + 1'b1;
						if (byteCnt < receiveCnt - 1'b1) begin //skip these on last byte, and wait for stop bit
							bitCnt <= 3'd7;
							byteRec <= 1'b1;
						end	
					end else begin //received stop bit, transmission done, go to idle
						state <= 3'd0;
						byteRec <= 1'b1;
						waitTimer <= 12'd0;
					end
				end
			end
		end	
	endcase
end

endmodule

