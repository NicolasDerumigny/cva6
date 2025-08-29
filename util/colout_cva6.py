def theme(context):
    return context,[
        [ ".*ERROR.*", "red", "bold" ],
        [ ".*\[FAILED\].*", "red", "bold" ],
        [ ".*[0-9]*[1-9]+[0-9]* FAILED.*", "red", "bold" ],
        [ ".*WARNING.*", "yellow", "bold" ],
        [ ".* 0 FAILED.*", "green", "bold" ],
        [ ".*\[PASSED\].*", "green", "bold" ],
        [ ".*INFO.*", "blue", "bold" ],
   ]
