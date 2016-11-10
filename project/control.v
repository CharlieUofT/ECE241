`ifndef control_m
`define control_m
module control (
  input clk,
  input reset,
  input up, down, left, right,
  input select, deselect,
  input [3:0] selected_piece,
  input [3:0] validate_square,

  output reg current_player,
  output reg winning, // winning condition satisfied?
  output reg [2:0] piece_x, piece_y, // left down corner (0,0)
  output reg [2:0] move_x, move_y, // position piece is moving to
  output reg [3:0] piece_to_move,
  output reg [2:0] box_x, box_y,
  // control signals
  // 00: c  ontrol
  // 01: validator
  // 10: datapath
  output reg [1:0] memory_manage,
  output [2:0] validate_x, validate_y,
  output reg move_piece,
  output reg initialize_board
  );

  // FSM
  reg move_valid;
  wire piece_valid;
  wire clk_reset;
  reg box_can_move;
  reg read_destination;
  reg check_winning;
  reg validate_complete;

  reg [5:0] current_state, next_state;

  localparam  S_INIT = 6'd0,
              S_MOVE_BOX_1 = 6'd1,
              S_SELECT_PIECE = 6'd2,
              S_VALIDATE_PIECE = 6'd3,
              S_MOVE_BOX_2 = 6'd4,
              S_SELECT_DESTINATION = 6'd5,
              // S_VALIDATE_DESTINATION_WAIT = 6'd6,
              S_VALIDATE_DESTINATION = 6'd7,
              S_CHECK_WINNING = 6'd8,
              S_GAME_OVER = 6'd9;

  // validate piece
  // [BUG]: The player could only control his/her own piece
  assign piece_valid = (selected_piece == 4'b0) ? 1'b0 : 1'b1;
  assign clk_reset = reset || (current_state == S_INIT);

// state table
always @ ( * ) begin
    case (current_state)
      S_INIT: next_state = S_MOVE_BOX_1;
      S_MOVE_BOX_1: begin
        next_state = select ? S_SELECT_PIECE : S_MOVE_BOX_1;
      end
      S_SELECT_PIECE: begin
        next_state = S_VALIDATE_PIECE;
      end
      S_VALIDATE_PIECE: begin
        if(!select) begin // make sure not get into infinite loop
          next_state = piece_valid ? S_MOVE_BOX_2 : S_MOVE_BOX_1;
        end
        else begin
          next_state = S_VALIDATE_PIECE;
        end
      end
      S_MOVE_BOX_2: begin
        if(!deselect) begin
          next_state = select ? S_SELECT_DESTINATION : S_MOVE_BOX_2;
        end
        else begin
          // jump back if deselect piece
          if(!select) next_state = S_MOVE_BOX_1;
          else next_state = S_MOVE_BOX_2;
        end
      end
      S_SELECT_DESTINATION: begin
        next_state = validate_complete ? S_VALIDATE_DESTINATION : S_SELECT_DESTINATION;
      end
      S_VALIDATE_DESTINATION: begin
        if(!select) begin
          next_state = move_valid ? S_CHECK_WINNING : S_MOVE_BOX_2;
        end
        else begin
          next_state = S_VALIDATE_DESTINATION;
        end
      end
      S_CHECK_WINNING: begin
        next_state = winning ? S_GAME_OVER : S_MOVE_BOX_1;
      end
      S_GAME_OVER: begin
        next_state = reset ? S_INIT : S_GAME_OVER;
      end
      default: next_state = S_INIT;
    endcase
end

// setting signals
always @ ( * ) begin
  // by default set all signals to 0
  box_can_move = 1'b0;
  // default grant memory access to control module
  memory_manage = 2'b0;
  check_winning = 1'b0;
  initialize_board = 1'b0;
  move_piece = 1'b0;

  case(current_state)
    S_INIT: begin
      initialize_board = 1'b1;
    end
    S_MOVE_BOX_1: begin
      box_can_move = 1'b1;
    end
    S_MOVE_BOX_2: begin
      box_can_move = 1'b1;
    end
    S_SELECT_DESTINATION: begin
      // grant memory access to validator module
      memory_manage = 2'b1;
    end
    S_CHECK_WINNING: begin
      move_piece = 1'b1;
      check_winning = 1'b1;
    end
  endcase
end

// flip player
always @ ( posedge clk ) begin
  case (current_state)
    S_INIT: current_player <= 1'b0;
    S_CHECK_WINNING: current_player <= ~current_player;
    default: current_player <= current_player;
  endcase
end

// select piece
always @ ( posedge clk ) begin
  case (current_state)
    S_SELECT_PIECE: begin
      piece_x <= box_x;
      piece_y <= box_y;
      piece_to_move <= selected_piece; // info to datapath
    end
    S_INIT: begin
      piece_x <= 3'b0;
      piece_y <= 3'b0;
    end
    default: begin
      piece_x <= piece_x;
      piece_y <= piece_y;
    end
  endcase
  $display("[SelectPiece] %d x:%d, y:%d", piece_to_move, piece_x, piece_y);
end

// select destination
always @ ( posedge clk ) begin
  case (current_state)
    S_SELECT_DESTINATION: begin
      move_x <= box_x;
      move_y <= box_y;
    end
    S_INIT: begin
      move_x <= 3'b0;
      move_y <= 3'b0;
    end
    default: begin
      move_x <= move_x;
      move_y <= move_y;
    end
  endcase
  $display("[SelectDestination] x:%d, y:%d", move_x, move_y);
end

// check winning
always @ ( posedge clk ) begin
  if(check_winning)
    winning <= (selected_piece == 4'd6) || (selected_piece == 4'd12);
  if(current_state == S_INIT)
    winning <= 1'b0;
  $display("[CheckWinning] winning is %b", winning);
end

// validate move
// mocking move_validator
reg [2:0] move_counter;
always @ ( posedge clk ) begin
  if(clk_reset) move_counter <= 3'b0;
  else begin
    if(memory_manage == 2'b1) begin
      $display("[Mocking Validator]");
      move_counter <= move_counter + 1;
    end
  end
  validate_complete <= (move_counter == 3'b111);
  move_valid <= (move_counter == 3'b111);
end

// setting state
always @ ( posedge clk ) begin
  if(reset)
    current_state <= S_INIT;
  else
    current_state <= next_state;
  $display("---------------------------------------");
  $display("[StateTable] Current state is state[%d]", next_state);
  $display("[StateTable] Current player is %b", current_player);
  $display("[Memory] memory_manage:%b", memory_manage);
  $display("[Signal] select:%b", select);
  $display("[Signal] deselect:%b", deselect);
  $display("[Signal] piece_valid:%b", piece_valid);
  $display("[Signal] move_valid:%b", move_valid);
  $display("[Signal] validate_complete:%b", validate_complete);
end

wire frame_clk;
// 4Hz clock for not so fast select-box moving
//configrable_clock #(26'd12500000) c0(clk, reset, frame_clk);
// high frequency clk for testing
configrable_clock #(26'd1) c0(clk, clk_reset, frame_clk);
// select box
always @ ( posedge clk ) begin
  if(current_state == S_INIT) begin
    box_x <= 3'b0;
    box_y <= 3'b0;
  end
  if(box_can_move && frame_clk) begin
    if(up) box_x <= box_x + 1;
    if(down) box_x <= box_x - 1;
    if(right) box_y <= box_y + 1;
    if(left) box_y <= box_y - 1;
  end
  $display("[SelectBox] Current position [x:%d][y:%d]", box_x, box_y);
end

endmodule // control
`endif
