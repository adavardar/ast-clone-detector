module Tests

import Basic;
import HelperFunctions;
import SequenceAlgorithn;

import IO;
import Set;
import String;

// Check starting line of string
test bool startingLineTest() {
    str line = "166,176,\<13,0\>,\<18,1\>";

    return(getStartLine(line) == 13);
}

// Check the file name of string
test bool fileNameTest() {
    str line = "///Software-Evolution/src/|";

    return(getFileName(line) == "Software-Evolution/src/");
}

// Check the file location of a string
test bool fileLocTest() {
    str line = "Software-Evolution/src/|(331,147,\<20,0\>,\<24,1\>)";

    return(getLoc(line) == "331,147,\<20,0\>,\<24,1\>");
}

// Check if the function returns the correct number of file lines per file and as file-system
test bool getFileLinesTest () {
    // This file system has 3 files with the following sizes
    // [ 19, 11, 11] = 41
    tuple[map[str, int], int] file = computeTotalNonCommentNonEmptyLines(|cwd:///Tests/CodeClones1/|);
    
    int count = 0;
    for(f <- file[0]) {
        count += file[0][f];
    }

    return(file[1] == count);
}
