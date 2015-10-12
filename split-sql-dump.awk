function closing_file(){
    if (PRINT_ROW == 1){
        close(CURRENT_FILE_NAME"_"CHUNK_NUMBER".sql")
        print CURRENT_FILE_NAME"_"CHUNK_NUMBER".sql"
    }
    CHUNK_NUMBER = CHUNK_NUMBER + 1
    AMOUNT_OF_ROWS = 0
}


BEGIN{
    # variables that possible goes from input^ "-v" options in awk
    if (DRY_RUN == "") DRY_RUN=1
    if (AMOUNT_OF_ROWS_PER_CHUNK == "") AMOUNT_OF_ROWS_PER_CHUNK=10
    # INCLUDE         - include pattern
    # EXCLUDE         - exclude pattern
    # STARTING_TABLE  - starting from this table

    # create target folder
    if (SPLIT_FOLDER != ""){
        CMD_MKDIR="mkdir -p " SPLIT_FOLDER " 2>/dev/null"
        system(CMD_MKDIR)
        close(CMD_MKDIR)
    }

    # calculated variables
    PRINT_ROW= SPLIT_FOLDER == "" ? 1 : 0
    IS_FOUND_START_TABLE = STARTING_TABLE == "" ? 1 : 0
    AMOUNT_OF_ROWS=0
    CURRENT_FILE_NAME=""
    CHUNK_NUMBER=1
    IS_PRINTING_TABLE_DEFINITION=0
}

/^-- Table structure for table/{
    if ( match($0, "`.*`") > 0 ){
        TABLE_NAME=substr($0, RSTART + 1, RLENGTH - 2)
        IS_PRINTING_TABLE_DEFINITION=1
        if (STARTING_TABLE != "" && IS_FOUND_START_TABLE == 0 && STARTING_TABLE == TABLE_NAME) IS_FOUND_START_TABLE = 1

        if (match(TABLE_NAME, INCLUDE) > 0 && ((match(TABLE_NAME, EXCLUDE) == 0 && EXCLUDE != "") || (EXCLUDE == "")) && IS_FOUND_START_TABLE == 1 ){
            print "-- Importing:", TABLE_NAME, "(line=" NR, "data:", $0, ")" > "/dev/stderr"
            PRINT_ROW  = 1
            PRINT_DATA = 1
            CURRENT_FILE_NAME = SPLIT_FOLDER"/"TABLE_NAME"__table_schema"
            AMOUNT_OF_ROWS = 0
            CHUNK_NUMBER = 1
        }
        else if (CREATE_ALL != "" && IS_FOUND_START_TABLE == 1){ 
            print "-- Importing structure:", TABLE_NAME, "(line=" NR, "data:", $0, ")" > "/dev/stderr"
            PRINT_ROW  = 1
            PRINT_DATA = 0
        }
        else {
            PRINT_ROW  = 0
            PRINT_DATA = 0
            print "-- Skipping: " TABLE_NAME, "(line=" NR ")" > "/dev/stderr"
        }
    }
}

/^LOCK TABLES / {
    closing_file()
    if (PRINT_DATA == 0) PRINT_ROW = 0
    IS_PRINTING_TABLE_DEFINITION=0
    CURRENT_FILE_NAME = SPLIT_FOLDER"/"TABLE_NAME"__table_data_"
}

	
/./ && ! /^--/{
    if (PRINT_ROW == 1 && DRY_RUN != 1 ){
        if (SPLIT_FOLDER != "")	{
            print $0 >> CURRENT_FILE_NAME"_"CHUNK_NUMBER".sql"
            AMOUNT_OF_ROWS = AMOUNT_OF_ROWS + 1
            if (AMOUNT_OF_ROWS > AMOUNT_OF_ROWS_PER_CHUNK && IS_PRINTING_TABLE_DEFINITION == 0) closing_file()
        }
        else print $0
    } 
}

/^UNLOCK TABLES;$/{ 
    if (SPLIT_FOLDER == "") PRINT_ROW = 1
    else {
        closing_file()
        PRINT_ROW = 0
    }
}

