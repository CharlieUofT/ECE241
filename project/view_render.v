`ifndef view_render_m
`define view_render_m

//`include "knight_w.v"
//`include "pawn_w.v"
//`include "king_w.v"
//`include "queen_w.v"
//`include "rook_w.v"
//`include "bishop_w.v"
//`include "knight_b.v"
//`include "pawn_b.v"
//`include "king_b.v"
//`include "queen_b.v"
//`include "rook_b.v"
//`include "bishop_b.v"
//`include "board_rom_top.v"
//`include "board_rom_bottom.v"
//
//`include "configrable_clock.v"
//`include "box_render.v"
//`include "pic_render.v"

module view_render (
  input clk,
  input reset,
  input reset_clock, // clock used for select box blinking
  input [3:0] piece_read,
  input [2:0] box_x, box_y, // position of the select box
  input current_player,
  input winning_msg,
  input start_render_board,
  input re_render_box_position,

  output reg [8:0] x,
  output reg [7:0] y,
  output reg colour,
  output reg writeEn,
  output reg [2:0] view_x, view_y,
  output erase_complete,
  output reg board_render_complete,
  output reg start_render_board_received
  );

  // controlling select box blinking
  wire flip_signal;
  configrable_clock #(26'd25000000) clock_view(clk, reset_clock, flip_signal);
  reg box_on;
  always @ ( posedge clk ) begin
    if(reset_clock)
      box_on <= 1'b0;
    if(flip_signal)
      box_on <= box_on + 1'b1;
  end


  // necessary wires
  wire [9:0] knight_w_address, pawn_w_address, king_w_address,
              queen_w_address, rook_w_address, bishop_w_address,
              knight_b_address, pawn_b_address, king_b_address,
              queen_b_address, rook_b_address, bishop_b_address;
  wire [1:0] knight_w_data, pawn_w_data, king_w_data,
              queen_w_data, rook_w_data, bishop_w_data,
              knight_b_data, pawn_b_data, king_b_data,
              queen_b_data, rook_b_data, bishop_b_data;

  // white pieces
  knight_w kw(knight_w_address, clk, knight_w_data);
  pawn_w pw(pawn_w_address, clk, pawn_w_data);
  king_w kingw(king_w_address, clk, king_w_data);
  queen_w qw(queen_w_address, clk, queen_w_data);
  rook_w rw(rook_w_address, clk, rook_w_data);
  bishop_w bw(bishop_w_address, clk, bishop_w_data);
  // black pieces
  knight_b kb(knight_b_address, clk, knight_b_data);
  pawn_b pb(pawn_b_address, clk, pawn_b_data);
  king_b kingb(king_b_address, clk, king_b_data);
  queen_b qb(queen_b_address, clk, queen_b_data);
  rook_b rb(rook_b_address, clk, rook_b_data);
  bishop_b bb(bishop_b_address, clk, bishop_b_data);

  // winning msg
  // each picture 320*120 size
  wire [15:0] b_win_address, w_win_address;
  wire [1:0] b_win_data, w_win_data;
  black_win bwin(b_win_address, clk, b_win_data);
  white_win wwin(w_win_address, clk, w_win_data);

  // background picture
  // 320x240 bigger than 65536(max memory size Quartus could provide)
  // use 2 65535 instead
  wire [15:0] board_address_top, board_address_bottom;
  wire [1:0] board_data_top, board_data_bottom;
  board_rom_top background_top(board_address_top, clk, board_data_top);
  board_rom_bottom background_bottom(board_address_bottom, clk, board_data_bottom);

  reg board_top_render_start, board_bottom_render_start,
      square_render_start, box_render_start, b_win_render_start,
      w_win_render_start;
  reg start_erase;
  wire board_top_render_complete, board_bottom_render_complete,
       box_render_complete;
  wire [8:0] x_coordinate;
  wire [7:0] y_coordinate;
  reg square_render_complete, win_render_complete;
  // convert from 8*8 to 224*224
  // there is 8 pixel bezzle on each edge of the board
  // each square is 28*28 pixel big
  assign x_coordinate = (view_x * 28) + 8;
  assign y_coordinate = (view_y * 28) + 8;

  // FSM (render the board)
  reg [3:0] current_state, next_state;
  localparam  S_INIT = 4'd0,
              S_RENDER_BACKGROUND_TOP = 4'd1,
              S_RENDER_BACKGROUND_TOP_WAIT = 4'd2,
              S_RENDER_BACKGROUND_BOTTOM = 4'd3,
              S_RENDER_BACKGROUND_BOTTOM_WAIT = 4'd4,
              S_RENDER_SQUARE = 4'd5,
              S_RENDER_SQUARE_WAIT = 4'd6,
              S_COUNT_COL = 4'd7,
              S_COUNT_ROW = 4'd8,
              S_RENDER_BOX = 4'd9,
              S_RENDER_BOX_WAIT = 4'd10,
              S_COMPLETE = 4'd11,
              S_ERASE_BOX = 4'd12,
              S_ERASE_BOX_WAIT = 4'd13,
              S_RENDER_WIN_MSG = 4'd14,
              S_RENDER_WIN_MSG_WAIT = 4'd15;

  always @ ( * ) begin
    start_render_board_received = 1'b0;
    case (current_state)
      S_INIT: begin
        start_render_board_received = 1'b1;
        next_state = start_render_board ? S_RENDER_BACKGROUND_TOP : S_INIT;
      end
      S_RENDER_BACKGROUND_TOP: next_state = S_RENDER_BACKGROUND_TOP_WAIT;
      S_RENDER_BACKGROUND_TOP_WAIT: next_state = board_top_render_complete ? S_RENDER_BACKGROUND_BOTTOM : S_RENDER_BACKGROUND_TOP_WAIT;
      S_RENDER_BACKGROUND_BOTTOM: next_state = S_RENDER_BACKGROUND_BOTTOM_WAIT;
      S_RENDER_BACKGROUND_BOTTOM_WAIT: next_state = board_bottom_render_complete ? S_RENDER_SQUARE : S_RENDER_BACKGROUND_BOTTOM_WAIT;
      S_RENDER_SQUARE: next_state = S_RENDER_SQUARE_WAIT;
      S_RENDER_SQUARE_WAIT: next_state = square_render_complete ? S_COUNT_COL : S_RENDER_SQUARE_WAIT;
      S_COUNT_COL: next_state = (view_x == 3'd7) ? S_COUNT_ROW : S_RENDER_SQUARE;
      S_COUNT_ROW: next_state = (view_y == 3'd7) ? S_RENDER_BOX : S_RENDER_SQUARE;
      S_RENDER_BOX: next_state = S_RENDER_BOX_WAIT;
      S_RENDER_BOX_WAIT: next_state = box_render_complete ? S_COMPLETE : S_RENDER_BOX_WAIT;
      S_COMPLETE: begin
        if(start_render_board) begin
          next_state = S_RENDER_BACKGROUND_TOP;
          start_render_board_received = 1'b1;
        end
        else if(winning_msg) begin
          next_state = S_RENDER_WIN_MSG;
        end
        else if (re_render_box_position) begin
          next_state = S_ERASE_BOX;
		  end
		  else begin
		    next_state = S_RENDER_BOX;
		  end
      end
      S_ERASE_BOX: next_state = S_ERASE_BOX_WAIT;
      S_ERASE_BOX_WAIT: next_state = erase_complete ? S_RENDER_BOX : S_ERASE_BOX_WAIT;
      S_RENDER_WIN_MSG: next_state = S_RENDER_WIN_MSG_WAIT;
      S_RENDER_WIN_MSG_WAIT: next_state = win_render_complete ? S_INIT : S_RENDER_WIN_MSG_WAIT;
      default: next_state = S_INIT;
    endcase
  end

  // instantanious signals
  always @ ( * ) begin
    // by default set everything to 0
    board_top_render_start = 1'b0;
    board_bottom_render_start = 1'b0;
    start_erase = 1'b0;
    square_render_start = 1'b0;
    box_render_start = 1'b0;
    b_win_render_start = 1'b0;
    w_win_render_start = 1'b0;
    board_render_complete = 1'b0;

    case (current_state)
      S_RENDER_BACKGROUND_TOP: board_top_render_start = 1'b1;
      S_RENDER_BACKGROUND_BOTTOM: board_bottom_render_start = 1'b1;
      S_RENDER_SQUARE: square_render_start = 1'b1;
      S_RENDER_BOX: box_render_start = 1'b1;
      S_COMPLETE: board_render_complete = 1'b1;
      S_ERASE_BOX: start_erase = 1'b1;
      S_RENDER_WIN_MSG: begin
        if(current_player == 1'b1) // black win
          b_win_render_start = 1'b1;
        else
          w_win_render_start = 1'b1;
      end
    endcase
  end

  // counters
  always @ ( posedge clk ) begin
    case (current_state)
      S_INIT: begin
        view_x <= 3'b0;
        view_y <= 3'b0;
      end
      S_COUNT_COL: begin
        view_x <= view_x + 1;
      end
      S_COUNT_ROW: begin
        view_y <= view_y + 1;
      end
    endcase
  end

  always @ ( posedge clk ) begin
    if(reset)
      current_state <= S_INIT;
    else
      current_state <= next_state;
  end

  // render the select box
  wire [8:0] x_box;
  wire [7:0] y_box;
  wire colour_box;
  wire wren_box;
  // box x is on 8*8; x_box is on 224 * 224
  box_render br(clk, reset, box_render_start, start_erase, box_x, box_y,
                box_on, x_box, y_box, colour_box, wren_box,
                box_render_complete, erase_complete);

  // mux all piece rendering outputs
  wire [8:0] x_board_top, x_board_bottom, x_knight_w, x_pawn_w, x_king_w,
            x_queen_w, x_rook_w, x_bishop_w, x_knight_b, x_pawn_b, x_king_b,
            x_queen_b, x_rook_b, x_bishop_b, x_b_win, x_w_win;
  wire [7:0] y_board_top, y_board_bottom, y_knight_w, y_pawn_w, y_king_w,
            y_queen_w, y_rook_w, y_bishop_w, y_knight_b, y_pawn_b, y_king_b,
            y_queen_b, y_rook_b, y_bishop_b, y_b_win, y_w_win;
  wire colour_board_top, colour_board_bottom, colour_knight_w, colour_pawn_w, colour_king_w,
      colour_queen_w, colour_rook_w, colour_bishop_w, colour_knight_b, colour_pawn_b, colour_king_b,
      colour_queen_b, colour_rook_b, colour_bishop_b, colour_b_win, colour_w_win;
  wire wren_board_top, wren_board_bottom, wren_knight_w, wren_pawn_w, wren_king_w,
      wren_queen_w, wren_rook_w, wren_bishop_w, wren_knight_b, wren_pawn_b, wren_king_b,
      wren_queen_b, wren_rook_b, wren_bishop_b, wren_b_win, wren_w_win;
  wire knight_w_complete, pawn_w_complete, king_w_complete,
        queen_w_complete, rook_w_complete, bishop_w_complete,
        knight_b_complete, pawn_b_complete, king_b_complete,
        queen_b_complete, rook_b_complete, bishop_b_complete,
        b_win_complete, w_win_complete;

  // WIDTH, HEIGHT, WIDTH_B, HEIGHT_B, PIC_LENGTH
  pic_render #(320, 120, 9, 7, 16) pBK_top(clk, reset, board_top_render_start, 9'd0, 8'd0,
                                            board_data_top, board_address_top, x_board_top, y_board_top,
                                            colour_board_top, wren_board_top, board_top_render_complete);
  pic_render #(320, 120, 9, 7, 16) pBK_bottom(clk, reset, board_bottom_render_start, 9'd0, 8'd120,
                                              board_data_bottom, board_address_bottom, x_board_bottom, y_board_bottom,
                                              colour_board_bottom, wren_board_bottom, board_bottom_render_complete);
  // white pieces
  pic_render pwknight(clk, reset, square_render_start, x_coordinate, y_coordinate,
                      knight_w_data, knight_w_address, x_knight_w, y_knight_w,
                      colour_knight_w, wren_knight_w, knight_w_complete);
  pic_render pwpawn(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    pawn_w_data, pawn_w_address, x_pawn_w, y_pawn_w,
                    colour_pawn_w, wren_pawn_w, pawn_w_complete);
  pic_render pwking(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    king_w_data, king_w_address, x_king_w, y_king_w,
                    colour_king_w, wren_king_w, king_w_complete);
  pic_render pwqueen(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    queen_w_data, queen_w_address, x_queen_w, y_queen_w,
                    colour_queen_w, wren_queen_w, queen_w_complete);
  pic_render pwrook(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    rook_w_data, rook_w_address, x_rook_w, y_rook_w,
                    colour_rook_w, wren_rook_w, rook_w_complete);
  pic_render pwbishop(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    bishop_w_data, bishop_w_address, x_bishop_w, y_bishop_w,
                    colour_bishop_w, wren_bishop_w, bishop_w_complete);
  // black pieces
  pic_render pbpawn(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    pawn_b_data, pawn_b_address, x_pawn_b, y_pawn_b,
                    colour_pawn_b, wren_pawn_b, pawn_b_complete);
  pic_render pbknight(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    knight_b_data, knight_b_address, x_knight_b, y_knight_b,
                    colour_knight_b, wren_knight_b, knight_b_complete);
  pic_render pbking(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    king_b_data, king_b_address, x_king_b, y_king_b,
                    colour_king_b, wren_king_b, king_b_complete);
  pic_render pbqueen(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    queen_b_data, queen_b_address, x_queen_b, y_queen_b,
                    colour_queen_b, wren_queen_b, queen_b_complete);
  pic_render pbrook(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    rook_b_data, rook_b_address, x_rook_b, y_rook_b,
                    colour_rook_b, wren_rook_b, rook_b_complete);
  pic_render pbbishop(clk, reset, square_render_start, x_coordinate, y_coordinate,
                    bishop_b_data, bishop_b_address, x_bishop_b, y_bishop_b,
                    colour_bishop_b, wren_bishop_b, bishop_b_complete);
  // winning msg
  pic_render #(320, 120, 9, 7, 16) pbwin(clk, reset, b_win_render_start, 9'd0, 8'd60, b_win_data, b_win_address,
                                         x_b_win, y_b_win, colour_b_win, wren_b_win, b_win_complete);
  pic_render #(320, 120, 9, 7, 16) pwwin(clk, reset, w_win_render_start, 9'd0, 8'd60, w_win_data, w_win_address,
                                         x_w_win, y_w_win, colour_w_win, wren_w_win, w_win_complete);
  always @ ( * ) begin
    if(current_state == S_RENDER_SQUARE_WAIT) begin
      case (piece_read)
        4'd8: begin // render a white knight
          writeEn = wren_knight_w;
          x = x_knight_w;
          y = y_knight_w;
          colour = colour_knight_w;
          square_render_complete = knight_w_complete;
        end
        4'd7: begin // render a white pawn
          writeEn = wren_pawn_w;
          x = x_pawn_w;
          y = y_pawn_w;
          colour = colour_pawn_w;
          square_render_complete = pawn_w_complete;
        end
        4'd12: begin // render a white king
          writeEn = wren_king_w;
          x = x_king_w;
          y = y_king_w;
          colour = colour_king_w;
          square_render_complete = king_w_complete;
        end
        4'd11: begin // render a white queen
          writeEn = wren_queen_w;
          x = x_queen_w;
          y = y_queen_w;
          colour = colour_queen_w;
          square_render_complete = queen_w_complete;
        end
        4'd10: begin // render a white rook
          writeEn = wren_rook_w;
          x = x_rook_w;
          y = y_rook_w;
          colour = colour_rook_w;
          square_render_complete = rook_w_complete;
        end
        4'd9: begin // render a white bishop
          writeEn = wren_bishop_w;
          x = x_bishop_w;
          y = y_bishop_w;
          colour = colour_bishop_w;
          square_render_complete = bishop_w_complete;
        end
        4'd1: begin // render a black pawn
          writeEn = wren_pawn_b;
          x = x_pawn_b;
          y = y_pawn_b;
          colour = colour_pawn_b;
          square_render_complete = pawn_b_complete;
        end
        4'd2: begin // render a black knight
          writeEn = wren_knight_b;
          x = x_knight_b;
          y = y_knight_b;
          colour = colour_knight_b;
          square_render_complete = knight_b_complete;
        end
        4'd6: begin // render a black king
          writeEn = wren_king_b;
          x = x_king_b;
          y = y_king_b;
          colour = colour_king_b;
          square_render_complete = king_b_complete;
        end
        4'd5: begin // render a black queen
          writeEn = wren_queen_b;
          x = x_queen_b;
          y = y_queen_b;
          colour = colour_queen_b;
          square_render_complete = queen_b_complete;
        end
        4'd4: begin // render a black rook
          writeEn = wren_rook_b;
          x = x_rook_b;
          y = y_rook_b;
          colour = colour_rook_b;
          square_render_complete = rook_b_complete;
        end
        4'd3: begin // render a black bishop
          writeEn = wren_bishop_b;
          x = x_bishop_b;
          y = y_bishop_b;
          colour = colour_bishop_b;
          square_render_complete = bishop_b_complete;
        end
      default: begin // render nothing
          writeEn = 1'b0;
          x = 9'b0;
          y = 8'b0;
          colour = 1'b0;
          square_render_complete = 1'b1;
      end
      endcase
    end
    else if(current_state == S_RENDER_BACKGROUND_TOP_WAIT) begin
      writeEn = wren_board_top;
      x = x_board_top;
      y = y_board_top;
      colour = colour_board_top;
    end
    else if(current_state == S_RENDER_BACKGROUND_BOTTOM_WAIT) begin
      writeEn = wren_board_bottom;
      x = x_board_bottom;
      y = y_board_bottom;
      colour = colour_board_bottom;
    end
    else if(current_state == S_RENDER_BOX_WAIT) begin
      writeEn = wren_box;
      x = x_box;
      y = y_box;
      colour = colour_box;
    end
    else if(current_state == S_RENDER_WIN_MSG_WAIT) begin
      if(current_player == 1'b1) begin // black wins
        writeEn = wren_b_win;
        x = x_b_win;
        y = y_b_win;
        colour = colour_b_win;
        win_render_complete = b_win_complete;
      end
      else begin // white wins
        writeEn = wren_w_win;
        x = x_w_win;
        y = y_w_win;
        colour = colour_w_win;
        win_render_complete = w_win_complete;
      end
    end
   else begin
    writeEn = 1'b0;
    x = 9'b0;
    y = 8'b0;
    colour = 1'b0;
   end
  end

  // log block
  wire write_log;
  configrable_clock #(26'd10000) clog(clk, reset_clock, write_log);
  always @(posedge clk) begin
  if(write_log) begin
    $display("---------------view_render--------------");
    $display("Current state: %d", current_state);
    $display("x:%d, y:%d", x, y);
    $display("writeEn:%b", writeEn);
    $display("Writing colour:%b", colour);
  end
//  if(board_bottom_render_complete) begin
//    $display("Bottom complete!");
//    $display("current_state", current_state);
//    $display("next_state", next_state);
//  end
//  if(board_top_render_complete)
//    $display("Top complete!");
//  if(current_state >= S_RENDER_SQUARE && current_state != S_RENDER_SQUARE_WAIT && current_state != S_RENDER_BOX_WAIT) begin
//    $display("---------------view_render2--------------");
//    $display("Current state: %d", current_state);
////    $display("")
//  end
//  if(current_state == S_RENDER_SQUARE)
//    $display("[RENDER SQUARE]Reading %d from x:%d, y:%d", piece_read, view_x, view_y);
//  if(current_state == S_RENDER_BOX)
//    $display("PIECES render complete!");
  if(current_state == S_COMPLETE)
    $display("[ViewRender]Everything DONE!!!!!!!!!!!!!!!!!!!!!");
  end

endmodule // view_render
`endif
