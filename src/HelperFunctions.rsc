module HelperFunctions

import lang::java::m3::Core;
import lang::java::m3::AST;
import IO;
import Node;
import Set;
import String;
import List;
import String;
import lang::json::IO;


// Set boundaries for the sequence

// // Reused method from series 1: This method will return the number of effective lines(LOC).
// this function counts the non-comment, non-empty lines in a file. 
// it reads the file, removes block comments, and counts the valid lines. 

//int countNonCommentNonEmptyLines(loc filePath) 
int countEffectiveLines(loc filePath) {
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

// this function computes the total number of non-comment, non-empty lines in all java files and returns the total number of lines and the number of lines of a specific file.
tuple[map[str, int], int] computeTotalNonCommentNonEmptyLines(loc projectPath) {
//int getFileLines(loc projectPath) {
    int totalLineCount = 0; 
    map[str, int] fileLineCounts = (); 
    M3 model = createM3FromDirectory(projectPath);  

    // iterate through the files in the project model.  
    for (<loc file, _> <- model.containment) {
        if (endsWith(file.path, ".java")) {
            totalLineCount += countEffectiveLines(file); 
            fileLineCounts += (getFileName("<projectPath>"): totalLineCount);
        }
    }

    return <fileLineCounts, totalLineCount>;
}

// Get the file location from a string
str getLoc (str s) {
    int leftBracket = findFirst(s, "(" );
    int rightBracket = findFirst(s, ")" );
    return s[leftBracket+1..rightBracket];
}

// Remove the location of a string: This is done to get the correct name for the json
str removeLoc (str s) {
    int leftBracket = findFirst(s, "(" );
    return s[0..leftBracket];
}

// Get the largest clone class by members: cant understand fully
set[str] getLargeCloneClassMember(list[map[str, str]] cloneData) {
    //println("Clone Data");
    //println(cloneData);
    int maxFileCount = 0;
    map[str, int] cloneCount = ();
    set[str] maxCloneClassMembers = {};

    // count occurrences of each clone in the clone data
    for (clone <- cloneData) {
        // extract the target file name and current file name from the clone data
        str targetFileName = clone["targetFile"];
        str currentFileName = clone["currentFile"];

        // update the count for the target and current file
        cloneCount[targetFileName] = (targetFileName in cloneCount) ? cloneCount[targetFileName] + 1 : 1;
        cloneCount[currentFileName] = (currentFileName in cloneCount) ? cloneCount[currentFileName] + 1 : 1;
    }
    //println("Clone Count");
    //println(cloneCount);
    // find the clone class members with the maximum count
    for (clone <- cloneCount) {
        if (cloneCount[clone] == maxFileCount) {
            maxCloneClassMembers += clone;
        } else if (cloneCount[clone] > maxFileCount) {
            maxCloneClassMembers = {clone};
            maxFileCount = cloneCount[clone];
        } 
    }
    //println(maxCloneClassMembers);
    // return the set of clones with the maximum count
    return maxCloneClassMembers;
}

// Retrieve data file data from the file system, which includes the following:
// - Total number of lines
// - Total number of duplicated lines
// - Total number of lines of a specific file
// - Total number of duplicated lines of a specific file
// - Total number of clones
// - Duplicated clones
// - Largest clone class within the file system
// - Duplication percentage in lines
// - Largest clone class in members
// - Clone examples
map[str, value] getFileData (list[map[str,str]] cloneClassesData, tuple[map[str, int], int] lines, bool type2, list[map[str,str]] allData) {
    map[str,set[int]] fileDuplicatedLOC = ();
    map[str, value] fileData = ();
    counter1 = 0;
    for(c1 <- cloneClassesData) {
        counter1 +=1;
    }

    for(c <- cloneClassesData) {
        if(contains("<c>", "largestCloneClasses")) {
            fileData+= ("largestCloneClassesByLines" : c["largestCloneClasses"]);
            continue;
        }

        fileName = removeLoc("<c["fileName"]>");
        splits = split(",",getLoc("<c["fileName"]>"));    
        list1 = [toInt(splits[0])..toInt(splits[1])+1];

        set[int] lineNumbers = {};
        for(l <- list1) {
            lineNumbers+=l;
        }
        
        for(f <- fileDuplicatedLOC) {
            if(fileName in fileDuplicatedLOC){
                lineNumbers += fileDuplicatedLOC[fileName];
            }
        }

        fileDuplicatedLOC+= (fileName : lineNumbers);
    }
    
    map[str,int] fileDuplicatedLOC2 = ();
    real totalDuplicated = 0.0;
    int counter2 = 0;
    for(f <- fileDuplicatedLOC) {
        counter2 +=1;
        fileDuplicatedLOC2 += (f: size(fileDuplicatedLOC[f]));
        totalDuplicated+= size(fileDuplicatedLOC[f]);
    }
    real v2 = 0.0 + lines[1];

    fileData += ("numberOfClonesClasses" : counter1 - 1);
    fileData += ("numberOfClones" : counter2);
    fileData += ("duplicatedLines" : fileDuplicatedLOC2);
    fileData += ("totalDuplicated" : totalDuplicated);
    fileData += ("duplicationPercentage" : "<((totalDuplicated / v2) * 100)>%");
    fileData += ("fileSize" : lines[0]);
    fileData += ("totalSize" : lines[1]);

    counter3 = 0;
    for(a<- allData) {
        counter3 +=1;
    }
    // Clone examples
    if(counter3 > 0) {
        cloneExamples = [];
        for(a <- [0..5]) {
            if(a < counter3) {
                cloneExamples += allData[a];
            }
        }
        fileData += ("cloneExamples" : cloneExamples);
        fileData += ("largestCloneClassesByMember":getLargeCloneClassMember(allData));
    }
    else {
        fileData += ("cloneExamples" : []);
        fileData += ("largestCloneClassesByMember":[]);
    }

    if(type2) {
        return ("type2" : fileData);
    }
    else {
        return ("type1" : fileData);
    }
}

// Return all clone classes from clone pairs
set[list[str]] getCloneClasses (set[tuple[list[str], tuple[list[node],list[node]]]] clonepairs) {
    list[list[str]] cloneClasses = [];

    for(f <- clonepairs) {
        list[str] temp = [];
        for(c <- f[1][0]) {
            temp+="<(c@src)>";
        }
        cloneClasses+=[temp];
        temp = [];
        for(c <- f[1][1]) {
            temp+="<(c@src)>";
        }
        cloneClasses+=[temp];
    }

    // Remove duplicates
    set[list[str]] cloneClasses1 = {};
    for(f <- cloneClasses) {
        cloneClasses1+=f;
    }

    return(cloneClasses1);
}

// Get clone class data ready to be written to a json; needed
list[map[str,str]] cloneClassToFile (list[map[str,str]] cloneClassesData, set[list[str]] cloneClasses, bool isSequence) {
    int largestCloneClassSize = 0;
    list[str] largestCloneClassNames = [];
    map[str,int] cloneClassMap = ();

    for(c <- cloneClasses) {
        list[int] lineNumbers = [];

        str fileName = "";
        for(cc <- c) {
            fileName = getFileName(cc);
            lineNumbers += getStartLine(cc);
        }

        // Add the filename and its corresponding clone lines to map.
        map[str,str] temp = ();
        temp += ("fileName":("<fileName>(<lineNumbers[0]>,<lineNumbers[size(lineNumbers)-1]>)"));

        if(isSequence) {
            if(size(lineNumbers) >= largestCloneClassSize) {
                largestCloneClassSize = size(lineNumbers);
            }

            cloneClassMap += (("<fileName>(<lineNumbers[0]>,<lineNumbers[size(lineNumbers)-1]>)") : size(lineNumbers));
        }

        cloneClassesData += temp;
    }
    
    if(isSequence) {
        for(c <- cloneClassMap) {
            if(cloneClassMap[c] == largestCloneClassSize) {
                largestCloneClassNames += c;
            }
        }

        cloneClassesData += ("largestCloneClasses" : "<largestCloneClassNames>");
    }

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
        clonePairData +=("currentFile":("<fileName1>(<lineNumbers1[0]>,<lineNumbers1[size(lineNumbers1)-1]>)"));
        clonePairData +=("targetFile":("<fileName2>(<lineNumbers2[0]>,<lineNumbers2[size(lineNumbers2)-1]>)"));
        clonePairData +=("sourceCode":"<sourceCode>");
        clonePairData +=("size":"<size(lineNumbers1)>");
        clonePairsData += clonePairData;
    }

    return clonePairsData;
}
