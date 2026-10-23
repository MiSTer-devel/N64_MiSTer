// Copyright (c) 2026 Jamie Blanks
//
// Aspect ratio of the unblanked picture as a 4:3 CRT would show it. The
// scaler stretches only the unblanked box, so the ratio it is given has
// to be the shape that box takes on the set the raster is meant for.
//
// Measured from the output raster itself: clocks per line, lines per
// frame, and the unblanked box. On a CRT the picture width is beam-on
// time within the line and the height is active lines within the frame,
// so each is compared with the standard's visible fraction:
//
//   ratio = 4/3 * (hactive / htotal) / H_VIS * V_VIS / (vactive / vtotal)
//
//   ARX = hactive * vtotal  * 4 * H_VIS_DEN * V_VIS_NUM
//   ARY = htotal  * vactive * 3 * H_VIS_NUM * V_VIS_DEN
//
// Two standards are parameterised; use_b picks the second. The
// defaults are NTSC (52.6 of 63.556 us, 240 of 262.5 lines) and PAL
// (52 of 64 us, 288 of 312.5 lines).
//
// A new box takes effect once two frames agree on it, and a change of
// one clock or line is ignored, so the half line of an interlaced
// raster cannot make the ratio flicker. The products are formed by a
// serial shift-and-add multiplier over a few hundred clocks per frame,
// then scaled by shifts to fill 12 bits.

module auto_crt_ar
#(
	parameter [11:0] DEFAULT_ARX = 12'd4,
	parameter [11:0] DEFAULT_ARY = 12'd3,
	parameter  [7:0] A_H_VIS_NUM = 8'd53,
	parameter  [7:0] A_H_VIS_DEN = 8'd64,
	parameter  [7:0] A_V_VIS_NUM = 8'd32,
	parameter  [7:0] A_V_VIS_DEN = 8'd35,
	parameter  [7:0] B_H_VIS_NUM = 8'd13,
	parameter  [7:0] B_H_VIS_DEN = 8'd16,
	parameter  [7:0] B_V_VIS_NUM = 8'd59,
	parameter  [7:0] B_V_VIS_DEN = 8'd64
)
(
	input             clk,
	input             reset,
	input             ce_pix,
	input             use_b,
	input             hsync,
	input             vsync,
	input             hblank,
	input             vblank,
	output     [11:0] arx,
	output     [11:0] ary
);

// the constant terms of the two standards, folded once
localparam [17:0] A_NUM = 18'd4 * A_H_VIS_DEN * A_V_VIS_NUM;
localparam [17:0] A_DEN = 18'd3 * A_H_VIS_NUM * A_V_VIS_DEN;
localparam [17:0] B_NUM = 18'd4 * B_H_VIS_DEN * B_V_VIS_NUM;
localparam [17:0] B_DEN = 18'd3 * B_H_VIS_NUM * B_V_VIS_DEN;

reg        hsync_q, vsync_q, use_b_q;
reg        valid;
reg [11:0] arx_r, ary_r;

// the frame being measured
reg [11:0] line_total, line_active;
reg [11:0] f_htotal, f_hactive, f_vtotal, f_vactive;
// the previous frame, and the one the ratio was made from
reg [11:0] m_htotal, m_hactive, m_vtotal, m_vactive;
reg [11:0] u_htotal, u_hactive, u_vtotal, u_vactive;

wire hs_rise = hsync & ~hsync_q;
wire vs_rise = vsync & ~vsync_q;
wire active  = ~hblank & ~vblank;
// active lines at the frame end, with the line still in progress: a picture
// reaching the last line ends after the sync of the field that follows
wire [11:0] f_vact_end = f_vactive + {11'd0, line_active != 12'd0};
// A simultaneous HS/VS edge completes a line before the frame counters
// are cleared. Include it here; the reset below overrides the HS increment.
wire [11:0] f_vtotal_end = f_vtotal + {11'd0, hs_rise};

wire frame_ok = (f_htotal >= 12'd128) && (f_hactive >= 12'd64) && (f_vtotal_end >= 12'd200) && (f_vact_end >= 12'd64) &&
                (f_hactive < f_htotal) && (f_vact_end < f_vtotal_end);

function automatic near;
	input [11:0] p, q;
	near = (p == q) || (p + 1'd1 == q) || (q + 1'd1 == p);
endfunction

wire same_as_last = near(f_htotal, m_htotal) && near(f_hactive, m_hactive) && near(f_vtotal_end, m_vtotal) && near(f_vact_end, m_vactive);
wire same_as_used = near(f_htotal, u_htotal) && near(f_hactive, u_hactive) && near(f_vtotal_end, u_vtotal) && near(f_vact_end, u_vactive);

// ---- serial multiplier and normaliser ----
localparam [3:0] S_IDLE = 4'd0, S_MUL_X = 4'd1, S_MUL_Y = 4'd2, S_SCALE_X = 4'd3, S_SCALE_Y = 4'd4,
                 S_SHRINK = 4'd5, S_GROW = 4'd6, S_DONE = 4'd7;
reg  [3:0] state;
reg        pending;
reg [23:0] base;
reg [41:0] num, den;
reg [41:0] acc;
reg [23:0] mcand;
reg [17:0] mplier;
reg  [4:0] mcount;

// Right-shift multiplication: add to the high half, then shift the
// accumulated product right. After 18 steps this is mcand times the
// original multiplier.
// Keeping mcand fixed needs only a 25-bit adder, rather than shifting a
// 42-bit operand through a 42-bit adder. All four products use 18 steps;
// the 12-bit geometry operands are zero-extended.
wire [24:0] sum_hi = {1'b0, acc[41:18]} + (mplier[0] ? {1'b0, mcand} : 25'd0);
wire [41:0] product_step = {sum_hi, acc[17:1]};
wire [17:0] std_num = use_b ? B_NUM : A_NUM;
wire [17:0] std_den = use_b ? B_DEN : A_DEN;

assign arx = valid ? arx_r : DEFAULT_ARX;
assign ary = valid ? ary_r : DEFAULT_ARY;

always @(posedge clk) begin
	if (reset || use_b != use_b_q) begin
		hsync_q <= 0; vsync_q <= 0; use_b_q <= use_b;
		valid <= 0; arx_r <= DEFAULT_ARX; ary_r <= DEFAULT_ARY;
		line_total <= 0; line_active <= 0;
		f_htotal <= 0; f_hactive <= 0; f_vtotal <= 0; f_vactive <= 0;
		m_htotal <= 0; m_hactive <= 0; m_vtotal <= 0; m_vactive <= 0;
		u_htotal <= 0; u_hactive <= 0; u_vtotal <= 0; u_vactive <= 0;
		pending <= 0; state <= S_IDLE;
	end
	else begin
		if (ce_pix) begin
			hsync_q <= hsync;
			vsync_q <= vsync;

			if (hs_rise) begin
				if (line_total > f_htotal) f_htotal <= line_total;
				if (line_active > f_hactive) f_hactive <= line_active;
				f_vtotal <= f_vtotal + 1'd1;
				if (line_active != 0) f_vactive <= f_vactive + 1'd1;
				line_total <= 12'd1;
				line_active <= active ? 12'd1 : 12'd0;
			end
			else begin
				line_total <= line_total + 1'd1;
				if (active) line_active <= line_active + 1'd1;
			end

			if (vs_rise) begin
				if (frame_ok) begin
					m_htotal <= f_htotal; m_hactive <= f_hactive; m_vtotal <= f_vtotal_end; m_vactive <= f_vact_end;
					if (same_as_last && !same_as_used) begin
						u_htotal <= f_htotal; u_hactive <= f_hactive; u_vtotal <= f_vtotal_end; u_vactive <= f_vact_end;
						pending <= 1;
					end
				end
				f_htotal <= 0; f_hactive <= 0; f_vtotal <= 0; f_vactive <= 0;
				line_active <= 0;
			end
		end

		case (state)
			S_IDLE: if (pending) begin
				pending <= 0;
				acc <= 0; mcand <= {12'd0, u_hactive}; mplier <= {6'd0, u_vtotal}; mcount <= 5'd18;
				state <= S_MUL_X;
			end

			// each product: shift the accumulator and multiplier down
			S_MUL_X, S_MUL_Y, S_SCALE_X, S_SCALE_Y: begin
				acc <= product_step;
				mplier <= mplier >> 1;
				mcount <= mcount - 1'd1;
				if (mcount == 5'd1) begin
					acc <= 0;
					case (state)
						S_MUL_X:   begin base <= product_step[23:0]; mcand <= {12'd0, u_htotal}; mplier <= {6'd0, u_vactive}; mcount <= 5'd18; state <= S_MUL_Y; end
						S_MUL_Y:   begin base <= product_step[23:0]; mcand <= base;             mplier <= std_num;           mcount <= 5'd18; state <= S_SCALE_X; end
						S_SCALE_X: begin num <= product_step;       mcand <= base;             mplier <= std_den;           mcount <= 5'd18; state <= S_SCALE_Y; end
						default:   begin den <= product_step; state <= S_SHRINK; end
					endcase
				end
			end

			// bring both into 12 bits, then fill them
			S_SHRINK: begin
				if (num[41:12] != 0 || den[41:12] != 0) begin num <= num >> 1; den <= den >> 1; end
				else state <= S_GROW;
			end
			S_GROW: begin
				if (num[11] == 0 && den[11] == 0 && (num | den) != 0) begin num <= num << 1; den <= den << 1; end
				else state <= S_DONE;
			end
			S_DONE: begin
				arx_r <= (num[11:0] == 0) ? 12'd1 : num[11:0];
				ary_r <= (den[11:0] == 0) ? 12'd1 : den[11:0];
				valid <= 1;
				state <= S_IDLE;
			end

			default: state <= S_IDLE;
		endcase
	end
end

endmodule
