vlib work
vlog control.v
vsim control

log {/*}
add wave {/*}

set time 0
force clk 0 0, 1 2500 -repeat 5000

# mocking the selected piece (empty)
force {selected_piece} 0000

# initiate everything
force {initialize_complete} 0
force {move_complete} 0
force {board_render_complete} 0
run 20 ns

force {initialize_complete} 1
run 10 ns

force {initialize_complete} 0

# moving the selecting box
force {up} 1
force {down} 0
force {right} 0
force {left} 0
run 30 ns

force {up} 0
force {left} 1
run 30 ns
force {left} 0

# select empty
# should back to move box 1
force {select} 1
run 10 ns
force {select} 0
run 10 ns

# mocking the selected piece (black knight)#2
force {selected_piece} 0010

# select black knight
force {select} 1
run 10 ns
force {select} 0
run 10 ns

# mocking the destination square (white king)#12
#force {selected_piece} 1100
# mocking the empty case for another test
force {selected_piece} 0011

# in s_move 2
force {up} 1
run 30 ns
force {up} 0
force {right} 1
run 30 ns
force {right} 0

# (should be a deselect case here)
#force {deselect} 1
#run 10 ns
#force {deselect} 0
#run1 10 ns

# select white king
force {select} 1
run 10 ns
force {select} 0
run 100 ns

force {move_complete} 1
run 10 ns

force {move_complete} 0
force {board_render_complete} 1
run 10 ns
