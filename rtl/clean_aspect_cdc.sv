// Controls for the aspect calculator live outside clk_vid. Only the
// synchronizer entry pins are asynchronous; all consumers use stage two.
module clean_aspect_cdc
(
 input  clk,
 input  reset_async,
 input  enabled_async,
 input  pal_async,
 output reset,
 output pal
);
 (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED", preserve *)
 reg reset_meta = 1'b1, reset_sync = 1'b1;
 (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED", preserve *)
 reg enabled_meta = 1'b0, enabled_sync = 1'b0;
 (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED", preserve *)
 reg pal_meta = 1'b0, pal_sync = 1'b0;

 // Assert even when the video clock is stopped; release on clk edges only.
 // The calculator itself retains its synchronous reset.
 always @(posedge clk or posedge reset_async) begin
  if (reset_async) begin
   reset_meta <= 1'b1;
   reset_sync <= 1'b1;
  end else begin
   reset_meta <= 1'b0;
   reset_sync <= reset_meta;
  end
 end

 always @(posedge clk) begin
  enabled_meta <= enabled_async;
  enabled_sync <= enabled_meta;
  pal_meta <= pal_async;
  pal_sync <= pal_meta;
 end

 assign reset = reset_sync | ~enabled_sync;
 assign pal = pal_sync;
endmodule
