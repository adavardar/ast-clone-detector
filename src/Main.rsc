module Main

import HelperFunctions;
import SequenceAlgorithm;

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::json::IO;

import IO;
import String;
import List;
import Map;
import Node;
import Set;
import Type;

int MIN_CLONE_SIZE = 12;
int MAX_CLONE_SIZE = 100;

int TEST_MIN_CLONE_SIZE = 1;
int TEST_MAX_CLONE_SIZE = 10;

str main () {

    println("Starting the clone detection process...");

    processFolder("Test1", |cwd:///Tests/CodeClones1/|, true);
    processFolder("Test2", |cwd:///Tests/CodeClones2/|, true);
    processFolder("Test3", |cwd:///Tests/CodeClones3/|, true);

    //processFolder("smallsql", |cwd:///smallsql0.21_src|, false);
    //processFolder("hsqldb", |cwd:///hsqldb-2.3.1|, false);

    return "Detection is done!";
}

void processFolder(str baseName, loc folder, bool isTest) {
    println("Processing the <baseName> folder...");

    map[str,value] cloningData = ();

    // Type1 clones
    cloningData = cloneDetection(folder, "<baseName>-Type1", false, cloningData, isTest);

    // Type1 + Type2 clones
    cloningData = cloneDetection(folder, "<baseName>-Type1&2", true, cloningData, isTest);

    println("");
}

/**
 * Detects code clones in the specified folder and generates cloning data.
 *
 * @param folder The location of the folder to analyze for code clones.
 * @param baseName The base name used for output files.
 * @param isType1 A boolean indicating whether to detect Type-1 clones.
 * @param cloningData A map to store the cloning data.
 * @param isTest A boolean indicating whether this is a test run.
 * @return A map containing the updated cloning data.
 *
 * The function performs the following steps:
 * 1. Computes the total number of non-comment, non-empty lines in the files within the folder.
 * 2. Initializes an empty hashMap to store sequences of code.
 * 3. Depending on the isTest flag, it runs the sequence algorithm.
 * 4. Retrieves clone pairs and removes subsumed clones.
 * 5. Extracts clone classes from the clone pairs.
 * 6. Prints the number of clone classes detected.
 * 7. Converts clone pairs and clone classes to file data.
 * 8. Updates the cloningData map with clone statistics.
 * 9. Writes the cloning data to a JSON file in the Results folder.
 */
 
map[str, value] cloneDetection(loc folder, str baseName, bool isType1, map[str, value] cloningData, bool isTest) {

    tuple[map[str,int], int] fileLines = computeTotalNonCommentNonEmptyLines(folder);

    map[list[str], list[list[node]]] cloneHashMap = ();

    if (isTest) {
        cloneHashMap = sequenceAlgorithm(cloneHashMap, TEST_MIN_CLONE_SIZE, TEST_MAX_CLONE_SIZE, folder, isType1);
    } else {
        cloneHashMap = sequenceAlgorithm(cloneHashMap, MIN_CLONE_SIZE, MAX_CLONE_SIZE, folder, isType1);
    }

    set[tuple[list[str], tuple[list[node],list[node]]]] clonePairs = removeSubsumedClones(extractClonePairs({}, cloneHashMap));

    set[list[str]] cloneClasses = classifyCloneGroups(clonePairs);

    //println("<baseName>: Number of clone classes (Sequence): <size(cloneClasses)>");

    list[map[str,str]] dataClonePair = convertClonePairsToStructuredData([], clonePairs);

    list[map[str,str]] dataCloneClass = convertCloneClassesToStructuredData([], cloneClasses);

    cloningData += findCloneStatistics(dataClonePair, dataCloneClass, fileLines, isType1);

    writeJSON(|cwd:///Results/<baseName>/cloning_data_<baseName>.txt|, cloningData, indent=1);


    return cloningData;
}

