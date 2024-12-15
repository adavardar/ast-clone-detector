module HelperFunctions

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::json::IO;

import IO;
import String;
import List;
import Map;
import Node;
import Set;

// retrieve pairs of sequences that are clones based on hash map, it compares sequences in the hash map to identify all clone pairs 
set[tuple[list[str], tuple[list[node],list[node]]]] extractClonePairs (
    set[tuple[list[str], tuple[list[node],list[node]]]] detectedClonePairs,
    map[list[str], list[list[node]]] sequenceHashMap) {
    
    for (sequenceHash <- sequenceHashMap) {
        // retrieve sequences with the same hash 
        list[list[node]] sequences = sequenceHashMap[sequenceHash];
        // only consider hashes with multiple sequences 
        if (size(sequences) <= 1) {
            continue;
        }
            
        for (seq1 <- sequences) {
            for (seq2 <- sequences) { 
                if(seq1 != seq2) { 
                    if( <sequenceHash, <(seq1),(seq2)>> notin detectedClonePairs) {
                        detectedClonePairs += <sequenceHash, <(seq1),(seq2)>>;
                    }
                }
            }
        }
    }

    return(detectedClonePairs);
} 


// Return all clone classes from clone pairs
set[list[str]] classifyCloneGroups(set[tuple[list[str], tuple[list[node], list[node]]]] clonePairs) {
    set[list[str]] classSet = {};

    for (clonePair <- clonePairs) {
        // extract the first and second clone groups from the pair
        list[str] firstGroup = ["<(clone.src)>" | clone <- clonePair[1][0]];
        list[str] secondGroup = ["<(clone.src)>" | clone <- clonePair[1][1]];

        // add both clone groups to the result set
        classSet += firstGroup;
        classSet += secondGroup;
    }

    return classSet;
}


// prepare clone class data for JSON output
list[map[str, str]] convertCloneClassesToStructuredData(list[map[str, str]] cloneClassesData, set[list[str]] cloneClasses) {
    list[str] nameOfBiggestCloneClass = [];
    map[str, int] cloneClassLineCountMap = ();

    int sizeOfBiggestCloneClass = 0;

    // iterate over each clone class in cloneClasses
    for (cloneClass <- cloneClasses) {
        str file = "";
        list[int] cloneLines = [];

        // collect file name and line numbers for the current clone class
        for (clone <- cloneClass) {
            file = findFileName(clone);
            cloneLines += findFirstLine(clone);
        }

        int cloneClassSize = size(cloneLines);

        map[str, str] buffer = ();

        // format the line range as a string: file (startLine, endLine)
        str lineRange = "<file>(<cloneLines[0]>,<cloneLines[size(cloneLines)-1]>)";

        // add the filename and its corresponding clone lines to a temporary map
        buffer += ("file": lineRange);

        if (cloneClassSize >= sizeOfBiggestCloneClass) {
            sizeOfBiggestCloneClass = cloneClassSize;
        }

        cloneClassLineCountMap += (lineRange : cloneClassSize);
        cloneClassesData += buffer;
    }

    // identify the clone classes with the biggest size
    for (entry <- cloneClassLineCountMap) {
        if (cloneClassLineCountMap[entry] == sizeOfBiggestCloneClass) {
            nameOfBiggestCloneClass += entry;
        }
    }

    cloneClassesData += ("BiggestCloneClassInLines" : "<nameOfBiggestCloneClass>");
    cloneClassesData += ("BiggestCloneClassLineSize" : "<sizeOfBiggestCloneClass>");

    return cloneClassesData;
}


list[map[str,str]] convertClonePairsToStructuredData(list[map[str,str]] infoClone, set[tuple[list[str], tuple[list[node],list[node]]]] ClonePairs) {
    // process each clone pair
    for (pair <- ClonePairs) {
        // process clone file 1
        tuple[str, list[int], list[str]] pair1Data = collectCloneData(pair[1][1]);
        str file1 = pair1Data[0];
        list[int] cloneLines1 = pair1Data[1];
        list[str] cloneSource1 = pair1Data[2];

        // process clone file 2
        tuple[str, list[int], list[str]] pair2Data = collectCloneData(pair[1][0]);
        str file2 = pair2Data[0];
        list[int] cloneLines2 = pair2Data[1];
        list[str] cloneSources2 = pair2Data[2];

        //str concatenatedSourceCode = join(", ", cloneSource1 + cloneSources2);

        // create clone pair data
        map[str,str] infoClonePairs = ();

        infoClonePairs += ("NumberOfLines": "<(size(cloneLines1))>");
        infoClonePairs += ("Pair1": "<file1>(<cloneLines1[0]>,<cloneLines1[size(cloneLines1)-1]>)");
        infoClonePairs += ("Pair2": "<file2>(<cloneLines2[0]>,<cloneLines2[size(cloneLines2)-1]>)");
        infoClonePairs += ("SourceCode": "<cloneSource1>"); 

        infoClone += infoClonePairs;
    }

    return infoClone;
}

 // to collect file name and line numbers
tuple[str, list[int], list[str]] collectCloneData(list[node] clones) {
    list[int] cloneLines = [];
    list[str] cloneSources = [];
    list[str] buffer = [];

    for (clone <- clones) {
        buffer += "<clone.src>";
        cloneSources += "<unsetRec(clone)>";
        cloneLines += findFirstLine("<clone>");
    }

    str file = findFileName(buffer[0]);

    return <file, cloneLines, cloneSources>;
}


// this function computes the total number of non-comment, non-empty lines in all java files and returns the total number of lines and the number of lines of specific files
tuple[map[str, int], int] computeTotalNonCommentNonEmptyLines(loc projectPath) {
    int totalLineCount = 0; 
    map[str, int] fileLineCounts = (); 
    M3 model = createM3FromDirectory(projectPath);  

    //iterate through the files in the project model  
    for (<loc file, _> <- model.containment) {
        if (endsWith(file.path, ".java")) {
            // count non-comment, non-empty lines in the file
            int fileLineCount = countNonCommentNonEmptyLines(file);

            // update total line count
            totalLineCount += fileLineCount;

            str fileName = findFileName("<file>");

            // store the individual file's count in the map
            fileLineCounts += (fileName: fileLineCount);
        }
    }
    return <fileLineCounts, totalLineCount>;
}

// this function counts the number of non-comment, non-empty lines in a file
int countNonCommentNonEmptyLines(loc filePath) {
    str fileContent = "";

    // read the file content and return 0 if the file cannot be read. 
    try fileContent = readFile(filePath); 
        catch: return 0;

    fileContent = removeBlockComments(fileContent);

    // split the file content into lines. 
    list[str] lines = split("\n", fileContent);

    int validCodeLineCount = 0; 

    for (str line <- lines) { // iterate through each line and check if it is a valid code line. 
        line = trim(line);
        if (isNonCommentNonEmptyLine(line)) {
            validCodeLineCount += 1;  
        }
    }

    return validCodeLineCount;
}   

// this function removes block comments (/* ... */) from the content of a file. 
str removeBlockComments(str content) {
    for (/<multiLineComment:\/\*[\s\S]*?\*\/>/ := content) {
        content = replaceAll(content, multiLineComment, "");
    }

    return content;
}

// this function checks if a line of code is a valid non-commnet, non-empty line. 
bool isNonCommentNonEmptyLine(str line) {
    return !startsWith(line, "//") && !isOnlyWhitespace(line);
}

bool isOnlyWhitespace(str line) {
  return /^\s*$/ := line;
}

// extract the starting line number
int findFirstLine(str locationString) {
    list[str] extractedChars = [];

    int startIndex = findFirst(locationString, "\<");
    int endIndex = findFirst(locationString, "\>");

    str contentBetween = locationString[startIndex + 1..endIndex];
    int commaIndex = findFirst(contentBetween, ",");

    str startLineString = contentBetween[0..commaIndex];

    int startLine = toInt(startLineString);

    return startLine;
}

// extract the file name from a given string representatin of code location 
str findFileName(str locationString) {
    //find the start and end indices for the file name 
    int startIndex = findFirst(locationString, "///");
    int endIndex = findLast(locationString, "|");

    // validate the indices to ensure the format is correct 
    if (startIndex == -1 || endIndex == -1 || startIndex + 3 >= endIndex) {
        return "Unknown";
    }

    // extract and return the file name 
    return locationString[startIndex + 3..endIndex];
}

// get the biggest clone class in members and its count
tuple[set[str], int] findBiggestCloneClassMember(list[map[str, str]] cloneData) {
    int maxFileCount = 0;
    map[str, int] cloneCount = ();
    set[str] maxCloneClassMembers = {};

    // count occurrences of each clone in the clone data
    for (clone <- cloneData) {
        // extract the target file name and current file name from the clone data
        str targetFile = clone["Pair2"];
        str currentFile = clone["Pair1"];

        // update the count for the target and current file
        cloneCount[targetFile] = (targetFile in cloneCount) ? cloneCount[targetFile] + 1 : 1;
        cloneCount[currentFile] = (currentFile in cloneCount) ? cloneCount[currentFile] + 1 : 1;
    }

    // find the clone class members with the maximum count
    for (file <- cloneCount) {
        if (cloneCount[file] == maxFileCount) {
            maxCloneClassMembers += file;
        } else if (cloneCount[file] > maxFileCount) {
            maxCloneClassMembers = {file};
            maxFileCount = cloneCount[file];
        }
    }

    // return the set of clones with the maximum count and their count
    return <maxCloneClassMembers, maxFileCount>;
}
// calculate the percentage of duplicated lines for each file
map[str,real] calculateFilePercentage(map[str, int] countLine, map[str, int] duplicateLine) {
    map[str,real] result = ();

    // iterate over each file in countLine
    for (str key <- duplicateLine) {

        int totalLine = countLine[key]; // get the total line count for the file
        real dupLine = duplicateLine[key] * 1.0; // get the duplicated line count for the file and convert to real
        real percent = (dupLine / totalLine) * 100.0; // calculate the percentage of duplicated lines
        result[key] = percent; // store the result in the map
    }

    return result;
}

// function to process and gather statistics on clone data
map[str,value] findCloneStatistics(list[map[str,str]] clonePairs, list[map[str,str]] cloneClasses, tuple[map[str,int], int] fileLines, bool isType2) {
    // initialize a map to store clone data and related maps
    map[str,value] cloneStatistics = ();
    map[str,set[int]] fileCloneLocations = ();
    map[str,int] fileCloneLineCounts = ();
    
    // variable to store the total number of duplicated lines
    real totalDuplicatedLines = 0.0;

    // the total number of lines in the folder and LOC for each file
    int totalLineCount = fileLines[1];
    map[str,int] lineCountPerFile = fileLines[0];

    // subtract two from the total size of cloneClasses to exclude the "BiggestCloneClassInLines" entry and the "sizeOfBiggestCloneClass" entry
    int totalCloneClasses = size(cloneClasses) - 2;

    // process cloneClasses to get the locations of cloned code lines
    fileCloneLocations = processCloneClassesData(cloneClasses, fileCloneLocations);

    // get the count of duplicated lines 
    int duplicatedLinesCount = size(fileCloneLocations);

    // loop through the clone classes to find the "BiggestCloneClassInLines" entry and the "BiggestCloneClassLineSize" entry
    for (cloneClass <- cloneClasses) {
        if ("BiggestCloneClassInLines" in cloneClass) {
            cloneStatistics["BiggestCloneClassInLines"] = cloneClass["BiggestCloneClassInLines"];
            continue;  // Skip further processing for this entry
        } else if ("BiggestCloneClassLineSize" in cloneClass) {
            cloneStatistics["BiggestCloneClassLineSize"] = cloneClass["BiggestCloneClassLineSize"];
            continue;  // Skip further processing for this entry
        }
    }

    // calculate total duplicated lines and populate fileCloneLineCounts with the size of each entry in fileCloneLocations
    for (file <- fileCloneLocations) {
        fileCloneLineCounts += (file: size(fileCloneLocations[file]));  // add the size of each cloned line set to fileCloneLineCounts
        totalDuplicatedLines += size(fileCloneLocations[file]);  // accumulate the total number of duplicated lines
    }

    // calculate the percentage of duplicated lines
    real duplicationPercentage = (totalDuplicatedLines / totalLineCount) * 100;

    map[str,real] duplicationPercentagePerFile = calculateFilePercentage(lineCountPerFile, fileCloneLineCounts);

    // fill the cloneStatistics map with various statistics
    cloneStatistics += ("TotalLineCountOfFolder": totalLineCount); 
    cloneStatistics += ("LineCountOfFiles": lineCountPerFile);
    cloneStatistics += ("NumberOfClonesClasses": totalCloneClasses); 
    cloneStatistics += ("NumberOfFilesWithDuplicatedCode": duplicatedLinesCount);
    cloneStatistics += ("TotalNumberOfClonePairs": totalDuplicatedLines);  
    cloneStatistics += ("PercentageOfDuplicatedLines": "<duplicationPercentage>%");
    cloneStatistics += ("NumberOfDuplicatedLinesPerFile": fileCloneLineCounts);
    cloneStatistics += ("PercentageOfDuplicatedLinesPerFile": duplicationPercentagePerFile);

    // process clone examples and add more data to cloneStatistics
    cloneStatistics = processCloneExamples(clonePairs, cloneStatistics);

    // return the result based on the type of clone detection
    return isType2 ? ("Type-2": cloneStatistics) : ("Type-1": cloneStatistics);
}
map[str, value] transformCloneStatisticsToD3Format(map[str, value] cloneStatistics) {
    map[str, value] d3Data = ();
    list[map[str, value]] children = [];

    // transform each entry in cloneStatistics into a hierarchical format
    for (key <- cloneStatistics) {
        map[str, value] child = ();
        child["name"] = key;
        child["value"] = cloneStatistics[key];
        children += child;
    }

    // create the root node
    d3Data["name"] = "CloneStatistics";
    d3Data["children"] = children;

    return d3Data;
}

map[str, set[int]] processCloneClassesData(list[map[str, str]] cloneClassesData, map[str, set[int]] fileDuplicatedLOC) {
    for (clone <- cloneClassesData) {
        if ("BiggestCloneClassInLines" in clone) continue;
        if ("BiggestCloneClassLineSize" in clone) continue;
        // find the index of the left and right brackets
        str fileNameFull = clone["file"];
        int leftIndex = findFirst(fileNameFull, "(");
        int rightIndex = findFirst(fileNameFull, ")");

        // for the JSON, remove the location part of the string to get the file name
        str file = fileNameFull[0 .. leftIndex];
        // extract the file location from the string
        str fileLocation = fileNameFull[leftIndex + 1 .. rightIndex];

        // split the fileLocation string by "," and convert it to a list of integers of indices
        list[int] splits = [toInt(s) | s <- split(",", fileLocation)];

        // generate the line numbers list for indices
        list[int] lineNumbersList = [splits[0] .. splits[1] + 1];

        // convert the list of line numbers into a set
        set[int] lineNumbers = {l | l <- lineNumbersList};
        
        if (file in fileDuplicatedLOC) {
            lineNumbers += fileDuplicatedLOC[file];
        }

        fileDuplicatedLOC[file] = lineNumbers;
    }
    return fileDuplicatedLOC;
}

// process clone examples
map[str, value] processCloneExamples(list[map[str, str]] clonePairs, map[str, value] cloneStatistics) {
    int cloneExampleCount = size(clonePairs);
    int maxCloneExamples = 5;
    list[map[str, str]] cloneExamples = [];

    // select up to maxCloneExamples clone examples
    for (int i <- [0 .. maxCloneExamples]) {
        if (i < cloneExampleCount) {
            cloneExamples += clonePairs[i];
        }
    }

    // add clone examples to cloneStatistics
    cloneStatistics += ("ExampleClones": cloneExamples);

    biggerCloneClass = findBiggestCloneClassMember(clonePairs);

    // add the biggest clone classes by member to cloneStatistics
    cloneStatistics += ("BiggestCloneClassInMembers": biggerCloneClass[0]);
    cloneStatistics += ("BiggestCloneClassMemberCount": biggerCloneClass[1]);
    
    return cloneStatistics;
}

