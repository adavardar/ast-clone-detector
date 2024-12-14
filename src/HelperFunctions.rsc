module HelperFunctions

import lang::java::m3::Core;
import lang::java::m3::AST;
import IO;
import Node;
import Set;
import String;
import List;
import lang::json::IO;
import Map;

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
    return !startsWith(line, "//") && !isWhitespaceLine(line);
}

//bool isOnlyWhitespace(str line) 
bool isWhitespaceLine(str line) {
  return /^\s*$/ := line;
}

// extract the starting line number
int getStartLine(str locationString) {
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
str getFileName(str locationString) {
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

// this function computes the total number of non-comment, non-empty lines in all java files and returns the total number of lines and the number of lines of specific files
tuple[map[str, int], int] computeTotalNonCommentNonEmptyLines(loc projectPath) {
    int totalLineCount = 0; 
    map[str, int] fileLineCounts = (); 
    M3 model = createM3FromDirectory(projectPath);  

    // iterate through the files in the project model.  
    for (<loc file, _> <- model.containment) {
        if (endsWith(file.path, ".java")) {
            totalLineCount += countNonCommentNonEmptyLines(file); 
            fileLineCounts += (getFileName("<projectPath>"): totalLineCount);
        }
    }

    return <fileLineCounts, totalLineCount>;
}

// get the biggest clone class in members
set[str] getLargeCloneClassMember(list[map[str, str]] cloneData) {
    int maxFileCount = 0;
    map[str, int] cloneCount = ();
    set[str] maxCloneClassMembers = {};

    // count occurrences of each clone in the clone data
    for (clone <- cloneData) {
        // extract the target file name and current file name from the clone data
        str Pair2Name = clone["Pair2"];
        str Pair1Name = clone["Pair1"];

        // update the count for the target and current file
        cloneCount[Pair2Name] = (Pair2Name in cloneCount) ? cloneCount[Pair2Name] + 1 : 1;
        cloneCount[Pair1Name] = (Pair1Name in cloneCount) ? cloneCount[Pair1Name] + 1 : 1;
    }

    // find the clone class members with the maximum count
    for (clone <- cloneCount) {
        if (cloneCount[clone] == maxFileCount) {
            maxCloneClassMembers += clone;
        } else if (cloneCount[clone] > maxFileCount) {
            maxCloneClassMembers = {clone};
            maxFileCount = cloneCount[clone];
        } 
    }

    // return the set of clones with the maximum count
    return maxCloneClassMembers;
}

// Function to process and gather statistics on clone data
map[str, value] getFileData(list[map[str, str]] cloneClasses, tuple[map[str, int], int] fileLines, bool isType2, list[map[str, str]] cloneExamples) {
    // Initialize a map to store clone data and related maps
    map[str, value] cloneStatistics = ();
    map[str, set[int]] fileCloneLocations = ();
    map[str, int] fileCloneLineCounts = ();
    
    // Variable to store the total number of duplicated lines
    real totalDuplicatedLines = 0.0;

    // The total number of lines in the folder
    int totalLineCount = fileLines[1];

    // Subtract one from the total size of cloneClasses to exclude the "largestCloneClasses" entry
    int totalCloneClasses = size(cloneClasses) - 1;

    // Process cloneClasses to get the locations of cloned code lines
    fileCloneLocations = processCloneClassesData(cloneClasses, fileCloneLocations);

    // Get the count of duplicated lines by examining the size of fileCloneLocations
    int duplicatedLinesCount = size(fileCloneLocations);

    // Loop through the clone classes and handle the special case for "largestCloneClasses"
    for (cloneClass <- cloneClasses) {
        // If the current clone class contains a "largestCloneClasses" entry, store it in cloneStatistics
        if ("largestCloneClasses" in cloneClass) {
            cloneStatistics["BiggestCloneInLines"] = cloneClass["largestCloneClasses"];
            continue;  // Skip further processing for this entry
        }
    }

    // Calculate total duplicated lines and populate fileCloneLineCounts with the size of each entry in fileCloneLocations
    for (file <- fileCloneLocations) {
        fileCloneLineCounts += (file: size(fileCloneLocations[file]));  // Add the size of each cloned line set to fileCloneLineCounts
        totalDuplicatedLines += size(fileCloneLocations[file]);  // Accumulate the total number of duplicated lines
    }

    // Calculate the percentage of duplicated lines relative to the total lines in the file
    real duplicationPercentage = (totalDuplicatedLines / totalLineCount) * 100;

    // Populate the cloneStatistics map with various statistics
    cloneStatistics += ("TotalLineCountOfFolder": totalLineCount); 
    cloneStatistics += ("LineCountOfFiles": fileLines[0]);
    cloneStatistics += ("NumberOfClonesClasses": totalCloneClasses); 
    cloneStatistics += ("NumberOfFilesWithDuplicatedCode": duplicatedLinesCount);
    cloneStatistics += ("TotalNumberOfClonePairs": totalDuplicatedLines);  
    cloneStatistics += ("PercentageOfDuplicatedLines": "<duplicationPercentage>%");
    cloneStatistics += ("NumberOfDuplicatedLinesPerFile": fileCloneLineCounts);

    // Process clone examples (adds more data to cloneStatistics)
    cloneStatistics = processCloneExamples(cloneExamples, cloneStatistics);

    // Return the result based on the isType2 flag (either 'type2' or 'type1' as the key)
    return isType2 ? ("Type-2": cloneStatistics) : ("Type-1": cloneStatistics);
}


map[str, set[int]] processCloneClassesData(list[map[str, str]] cloneClassesData, map[str, set[int]] fileDuplicatedLOC) {
    for (clone <- cloneClassesData) {
        if ("largestCloneClasses" in clone) continue;
        // find the index of the left and right brackets
        str fileNameFull = clone["fileName"];
        int leftIndex = findFirst(fileNameFull, "(");
        int rightIndex = findFirst(fileNameFull, ")");

        // for the JSON, remove the location part of the string to get the file name
        str fileName = fileNameFull[0 .. leftIndex];
        // extract the file location from the string
        str fileLocation = fileNameFull[leftIndex + 1 .. rightIndex];

        // split the fileLocation string by "," and convert it to a list of integers of indices
        list[int] splits = [toInt(s) | s <- split(",", fileLocation)];

        // generate the line numbers list for indices
        list[int] lineNumbersList = [splits[0] .. splits[1] + 1];

        // convert the list of line numbers into a set
        set[int] lineNumbers = {l | l <- lineNumbersList};
        
        if (fileName in fileDuplicatedLOC) {
            lineNumbers += fileDuplicatedLOC[fileName];
        }

        fileDuplicatedLOC[fileName] = lineNumbers;
    }
    return fileDuplicatedLOC;
}

// process clone examples
map[str, value] processCloneExamples(list[map[str, str]] allData, map[str, value] fileData) {
    int cloneExampleCount = size(allData);
    int maxCloneExamples = 5;
    list[map[str, str]] cloneExamples = [];

    // select up to maxCloneExamples from allData
    for (int i <- [0 .. maxCloneExamples]) {
        if (i < cloneExampleCount) {
            cloneExamples += allData[i];
        }
    }

    // add clone examples to fileData
    fileData += ("ExampleClones": cloneExamples);

    // add the largest clone classes by member to fileData
    fileData += ("BiggestCloneClassInMembers": getLargeCloneClassMember(allData));

    return fileData;
}

// retrieve pairs of sequences that are clones based on hash map, it compares sequences in the hash map to identify all clone pairs 
set[tuple[list[str], tuple[list[node],list[node]]]] getClonePairs (
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
set[list[str]] getCloneClasses(set[tuple[list[str], tuple[list[node], list[node]]]] clonePairs) {
    set[list[str]] cloneClassesSet = {};

    for (clonePair <- clonePairs) {
        // extract the first and second clone groups from the pair
        list[str] firstGroup = ["<(clone.src)>" | clone <- clonePair[1][0]];
        list[str] secondGroup = ["<(clone.src)>" | clone <- clonePair[1][1]];

        // add both clone groups to the result set
        cloneClassesSet += firstGroup;
        cloneClassesSet += secondGroup;
    }

    return cloneClassesSet;
}


// Get clone class data ready to be written to a json; needed
// Prepare clone class data for JSON output
list[map[str, str]] cloneClassToFile(list[map[str, str]] cloneClassesData, set[list[str]] cloneClasses) {
    int largestCloneClassSize = 0;
    list[str] largestCloneClassNames = [];
    map[str, int] cloneClassSizeMap = ();

    for (cloneClass <- cloneClasses) {
        list[int] lineNumbers = [];
        str fileName = "";

        for (clone <- cloneClass) {
            fileName = getFileName(clone);
            lineNumbers += getStartLine(clone);
        }

        // Add the filename and its corresponding clone lines to a temporary map
        map[str, str] temp = ();
        temp += ("fileName":("<fileName>(<lineNumbers[0]>,<lineNumbers[size(lineNumbers)-1]>)"));
        
        if (size(lineNumbers) >= largestCloneClassSize) {
            largestCloneClassSize = size(lineNumbers);
        }

        cloneClassSizeMap += (("<fileName>(<lineNumbers[0]>,<lineNumbers[size(lineNumbers)-1]>)") : size(lineNumbers));
        cloneClassesData += temp;
    }

    for (entry <- cloneClassSizeMap) {
        if (cloneClassSizeMap[entry] == largestCloneClassSize) {
            largestCloneClassNames += entry;
        }
    }

    map[str, str] largestClassEntry = ();
    largestClassEntry += ("largestCloneClasses" : "<largestCloneClassNames>");
    cloneClassesData += largestClassEntry;

    return cloneClassesData;
}


// Get clone pairs data ready to be written to a json (Sequence algorithm); needed
list[map[str,str]] clonePairsToFile (list[map[str,str]] clonePairsData, set[tuple[list[str], tuple[list[node],list[node]]]] clonepairs) {
for(c <- clonepairs) {
        // Clone file 1
        temp = [];
        sourceCode = [];

        list[int] lineNumbers1 = [];
        for(c1 <- c[1][1]) {
            temp += c1@src;
            sourceCode += unsetRec(c1);
        }
        
        fileName1 = getFileName("<temp[0]>");

        for(t <- temp) {
            lineNumbers1 += getStartLine("<t>");
        }

        // Clone file 2
        temp = [];     
        str fileName2 = "";
        list[int] lineNumbers2 = [];
        for(c2 <- c[1][0]) {
            temp += c2@src;
        }

        fileName2 = getFileName("<temp[0]>");

        for(t <- temp) {
            lineNumbers2 += getStartLine("<t>");
        }   

        // Print results to a json
        map[str,str] clonePairData = ();
        clonePairData +=("NumberOfLines":"<size(lineNumbers1)>");
        clonePairData +=("Pair1":("<fileName1>(<lineNumbers1[0]>,<lineNumbers1[size(lineNumbers1)-1]>)"));
        clonePairData +=("Pair2":("<fileName2>(<lineNumbers2[0]>,<lineNumbers2[size(lineNumbers2)-1]>)"));
        clonePairData +=("SourceCode":"<sourceCode>");
        clonePairsData += clonePairData;
    }

    return clonePairsData;
}

