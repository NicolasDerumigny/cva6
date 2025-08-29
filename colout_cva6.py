def theme(context):
    # Theme for coloring AMD/Xilinx Vivado IDE synthesis and implementation output
    return context,[
        [ ".* 0 FAILED.*", "green", "bold" ],
        [ ".*\[PASSED\].*", "green", "bold" ],
        [ ".*INFO.*", "blue", "bold" ],
        [ ".*WARNING.*", "yellow", "bold" ],
        [ ".*ERROR.*", "red", "bold" ],
    ]
