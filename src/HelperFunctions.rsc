module HelperFunctions

import lang::java::m3::Core;
import lang::java::m3::AST;
import IO;
import Node;
import Set;
import String;


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

// this function computes the total number of non-comment, non-empty lines in all java files and returns the total number of lines and the number of lines of a specific file.
tuple[map[str, int], int] computeTotalNonCommentNonEmptyLines(loc projectPath) {
//int computeTotalNonCommentNonEmptyLines(loc projectPath) {
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

// Get the largest clone class by members
set[str] getLargeCloneClassMember (list[map[str,str]] allData) {
    map[str, int] count = ();
    for(c <- allData) {
        str c1 = "<c["targetFile"]>";
        str c2 = "<c["currentFile"]>";

        if(c1 in count) {
           count += (c1 : count[c1] + 1);
        }
        else {
           count += (c1 : 0);
        }
        if(c2 in count) {
           count += (c2 : count[c2] + 1);
        }
        else {
           count += (c2 : 0);
        }
    }
    
    int max = 0;
    set[str] maxString = {};

    for(c <- count) {
        if(count[c] > max) {
            max = count[c];
            maxString = {c};
        }
        if(count[c] == max) {
            maxString += c;

        }
    }


    return maxString;    

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