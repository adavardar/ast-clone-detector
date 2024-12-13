module CloneHelper

import HelperFunctions;
import Node;
import IO;
import List;
import String;
import lang::json::IO;


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
