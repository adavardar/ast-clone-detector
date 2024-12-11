module Main

//import CloneDetectionAlgorithm;
//import Helpers; 
import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::json::IO; 
import IO;
import List;
import Type;
import String;
import Set;
import lang::rascalcore::md5;
import Node;
import lang::rascal::tutor::Compiler;
import lang::smtlib2::Compiler;


str main () {
    // run the test
    runCloneDetectionTest();

    println("");
    return "";
}

// function to run the test on ExampleCode1.java and ExampleCode2.java 
void runCloneDetectionTest() {

    loc testDirectory = |cwd:///Tests/TestClone1/|; 

    loc cloneClassesFilePath = |cwd:///Results/cloneClassesTest1.txt|;
    loc clonePairsFilePath = |cwd:///Results/clonePairsTest1.txt|;

    //println("Running clone detection on the test directory: ", testDirectory);

    // run the type 1 clone detection algorithm 
    tuple[set[list[str]] a, list[tuple[tuple[value, value], tuple[value, value]]] b] cloneResults = detectExactClones(testDirectory, 20);

    println("classes");
    //println("clone classes: <size(cloneResults[0])>");
    println(size(cloneResults.a));
    println(cloneResults.a);

    println("pairs");
    println(size(cloneResults.b));

    // process and prepare clone class data for JSON 
    list[map[str, str]] formattedCloneClasses = [];
    formattedCloneClasses = prepareCloneClassData(formattedCloneClasses, cloneResults[0]);

    // process and prepare clone pair data for JSON 
    list[map[str, str]] formattedClonePairs = [];
    formattedClonePairs = prepareClonePairs(formattedClonePairs, cloneResults[1]);

    // write the clone classes and clone pairs data to JSON files 
    writeJSON(cloneClassesFilePath, formattedCloneClasses, indent = 1);
    writeJSON(clonePairsFilePath, formattedClonePairs, indent = 1);

    // log the file write operations 
    //println("Clone classes data written to: ", cloneClassesFilePath);
    //println("Clone pairs data written to: ", clonePairsFilePath);
}

// type 1 clone detection algorithm 
// parameters:
//     - sourceDirectory: directory of Java source files
//     - massThreshold: minimum subtree mass (number of nodes) value to be considered, so that small pieces of code (e.g., expressions) are ignored (take from paper) 
// returns:
//     - set[list[str]]: set of maximal clone classes (subsumption removed)
//     - list[tuple[tuple[value, value], tuple[value, value]]]: list of clone pairs

tuple[set[list[str]], list[tuple[tuple[value, value], tuple[value, value]]]] detectExactClones(loc sourceDirectory, int massThreshold) {

    // create an M3 model
    M3 programModel = createM3FromDirectory(sourceDirectory);

    // list to store valid subtrees that meet the mass threshold 
    list[node] validSubtrees = [];

    // hash buckets
    map[str, list[tuple[value, value]]] hashBuckets = ();


    // list to store clone pairs
    list[tuple[tuple[value, value], tuple[value, value]]] clonePairs = [];

    // set to store detected clone classes 
    set[tuple[value, value]] detectedClones = {};

    // step 1: extract subtrees that meet the mass threshold 
    for (<loc filePath, _> <- programModel.containment) {
        if (endsWith(filePath.path, ".java")) {

            // parse the Java file into an Abstract Syntax Tres (AST) 
            Declaration fileAST = createAstFromFile(filePath, true);
            
            // traverse the AST and extract subtrees meeting the mass threshold 
            top-down visit(fileAST) {
                case node subtree: {
                    int subtreeSize = 0;

                    // recrusively calculate the mass (node count) of the subtree 
                    top-down visit(subtree) {
                        case node childNode: {
                            subtreeSize += size(getChildren(childNode));
                        }
                    }

                    // if the subtree's mass is above the threshold, add it to the valid subtrees list 
                    if (subtreeSize + 1 >= massThreshold) {
                        validSubtrees += subtree;
                    }
                }
            }
        }
    }
    
    // step 2: hash the subtrees and group them into buckets
for (node subtree <- validSubtrees) {
        try 
            subtree_src = subtree.src;
        catch _:
            continue;

    value subtreeLocation = "Unknown"; // Default value

    if (subtree.src != null) {
        subtreeLocation = subtree.src;
    }
        // create a representation of the subtree including its source and structure
        tuple[value,value] subtreeData = <subtreeLocation, unsetRec(subtree)>;

        // compute a hash value for the subtree
        str hashValue = hash(subtree);

        // add the subtree to the appropriate hash bucket 
        if (hashValue in hashBuckets) {
            hashBuckets[hashValue] += subtreeData;
        } else {
            hashBuckets += (hashValue: [subtreeData]);
        }
    }

    // step 3: compare subtrees within each hash bucket and detect clone pairs 
    for (str hashValue <- hashBuckets) {
        list[tuple[value,value]] bucketSubtrees = hashBuckets[hashValue];

        // compare each pair of subtrees within the same hash bucket 
        for (tuple[value,value] subtreeA <- bucketSubtrees) {
            for (tuple[value,value] subtreeB <- bucketSubtrees) {

                if (subtreeA == subtreeB) {
                    // if the two subtrees are exactly the same, record them as a clone pair 
                    clonePairs += <subtreeA, subtreeB>;

                    // add the subtrees to the detected clones set 
                    detectedClones += subtreeA;
                    detectedClones += subtreeB;
                }
            }
        }
    }

    // step 4: remove subsumed clones
    set[list[str]] maximalCloneClasses = {}; // store maximal clone classes (without subsumed clones) 

    // // sort the detected clones by subtree size (larger subtrees first)
    // list[tuple[value,value]] sortedClones = toList(detectedClones);
    // sortedClones = sortedClones[<size(getChildren(clone[1])) | clone <- sortedClones>];

    // compare each clone with others to check for subsumption 
    for (tuple[value,value] cloneA <- detectedClones) {

        // flag to indicate whether cloneA is subsumed by another clone 
        bool isSubsumed = false;

        for (tuple[value,value] cloneB <- detectedClones) {
            // check if cloneA is a subtree of cloneB
            if (cloneA != cloneB && isSubtree(cloneA[1], cloneB[1])) {
                isSubsumed = true; // if subsumed, mark it
                break; // no need to check further
            }
        ;}

        // if cloneA is not subsumed by any other clone, add it to the maximal clone classes set 
        if (!isSubsumed) {
            maximalCloneClasses += ["<cloneA[0]>"];
        }   
    }

    // return the maximal clone classes and the list of clone pairs 
    return <maximalCloneClasses, clonePairs>;

;}

// helper function: check if treeA is a subtree of treeB 
bool isSubtree(node treeA, node treeB) {

    // if treeA and treeB are exactly the same, return true
    if (treeA == treeB) {
        return true;
    }

    // recursively check if treeA is a subtree of any child of treeB 
    for (node child <- getChildren(treeB)) {
        if (isSubtree(treeA, child)) {
            return true; // if treeA is found as a subtree of a child, return true 
        }
    }

    return false; // if no match is found, return false 
}

str hash (value s) { 
    return md5Hash(unsetRec(s)); 
}

// prepare clone pair data for JSON output
list[map[str, str]] prepareClonePairs( 
    list[map[str, str]] clonePairsData,
    list[tuple[tuple[value, value], tuple[value, value]]] clonePairs
) {
    for (pair <- clonePairs) {
        // Convert pair[0][0] and pair[1][0] to strings
        // println("type of pair 1: <typeOf(pair[0][0])>");
        // println("type of p1 with str interpolation: <typeOf(<pair[0][0]>)>");
        // println("pair 1: <pair[0][0]>");
        // println("pair 2: <pair[1][0]>");

        str sourceLocation = "<pair[0][0]>";
        str targetLocation = "<pair[1][0]>";
        
        // println("source location: <sourceLocation>");

        // Extract details for the first subtree (source clone)
        str sourceFile = getFileName(sourceLocation);  // Source file name
        int sourceLine = getStartLine(sourceLocation); // Source start line
        str sourceRange = getRange(sourceLocation);    // Source range
        list[str] sourceRangeParts = split(sourceRange, "-");
        int sourceRangeEnd = (size(sourceRangeParts) > 1) ? toInt(sourceRangeParts[1]) : sourceLine;
        str sourceRangeStr = "<sourceLine>" + " - " + "<sourceRangeEnd>";

        // Print details for the first subtree
        //println("file name: <sourceFile>");
        // println("source line: <sourceLine>");
        // println("source range: <sourceRange>");
        // println("source range parts: <sourceRangeParts>");
        // println("source range end: <sourceRangeEnd>");
        // println("source range str: <sourceRangeStr>");

        // Extract details for the second subtree (target clone)
        str targetFile = getFileName(targetLocation);  // Target file name
        int targetLine = getStartLine(targetLocation); // Target start line
        str targetRange = getRange(targetLocation);    // Target range
        if (targetRange == "Unknown") {
            targetRange = "1";
        }
        str targetRangeStr = "<targetLine> - <targetLine + (toInt(targetRange) - 1)>"; 

        // // Print details for the second subtree
        // println("target file: <targetFile>");
        // println("target line: <targetLine>");
        // println("target range: <targetRange>");
        // println("target range str: <targetRangeStr>");

        
        // Prepare a single clone pair entry
        map[str, str] clonePair = ();
        clonePair += (
            "currentFile": sourceFile + "(" + sourceRangeStr + ")",
            "targetFile": targetFile + "(" + targetRangeStr + ")",
            "sourceCode": "<unsetRec(pair[0][1])>"
        );

        // Add to the result list
        clonePairsData += clonePair;
    }

    return clonePairsData;
}

// Prepare clone class data for JSON output
list[map[str, str]] prepareCloneClassData(
    list[map[str, str]] formattedCloneClasses, // list to store final JSON data
    set[list[str]] cloneClasses // set of clone classes to process
) {
    // Iterate through each clone class in the set
    for (cloneClass <- cloneClasses) {
        // Map to group the ranges by their respective files
        map[str, list[str]] fileToRanges = ();

        // Process each clone instance within the current clone class
        for (clone <- cloneClass) {
            str fileName = getFileName(clone); // Extract the file name (e.g., File1.java) from the clone's location string
            println("file name: <fileName>");
            str cloneRange = getRange(clone); // Extract the range (e.g., 1-3) from the clone's location string
            println("clone range: <cloneRange>");

            // Group by file name and add ranges
            if (fileName in fileToRanges) {
                // If the file name already exists in the map, append range to the list
                fileToRanges[fileName] += cloneRange;
            } else {
                // If the file name doesn't exist, initialize with the first range
                fileToRanges[fileName] = [cloneRange];
            }
        }

        // Prepare the clone class entry as a string
        list[str] cloneClassList = [];
        for (file <- fileToRanges) {
            for (range <- fileToRanges[file]) {
                // Concatenate file name and range in the format "file:range"
                cloneClassList += file + ":" + range;
            }
        }

        // Create a single string by joining all file:range entries with ", "
        str joinedCloneClass = "";
        for (int i <- [0 .. size(cloneClassList) - 1]) {
            if (i == 0) {
                joinedCloneClass = cloneClassList[i];
            } else {
                joinedCloneClass += ", " + cloneClassList[i];
            }
        }

        // Add the processed clone class data to the map
        map[str, str] temp = ();
        temp["cloneClass"] = joinedCloneClass;

        // Add the current clone class's data to the main JSON data list
        formattedCloneClasses += temp;
    }

    return formattedCloneClasses;
}

// extract the file name from a given string representatin of code location 
str getFileName (str locationString) {
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

// // extract the starting line number
int getStartLine(str locationString) {
    list[str] extractedChars = [];
    int startIndex = findFirst(locationString, "\<");
    int endIndex = findFirst(locationString, "\>");
    str contentBetween = locationString[startIndex + 1..endIndex];
    int commaIndex = findFirst(contentBetween, ",");

    str startLineString = contentBetween[0..commaIndex];

    return toInt(startLineString);
}

// // extract the range of lines from a clone location string 
str getRange(str locationString) {
    list[str] extractedChars = [];
    int startIndex = findFirst(locationString, "\<");
    int endIndex = findFirst(locationString, "\>");
    str contentBetween = locationString[startIndex + 1..endIndex];
    int commaIndex = findFirst(contentBetween, ",");

    str rangeString = contentBetween[0..commaIndex];

    return rangeString;
}