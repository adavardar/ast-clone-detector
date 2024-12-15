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

int MIN_CLONE_SIZE = 6;
int MAX_CLONE_SIZE = 100;

int TEST_MIN_CLONE_SIZE = 1;
int TEST_MAX_CLONE_SIZE = 10;

str main () {

    println("Starting the clone detection process...");

    processFolder("Test1", |cwd:///Tests/CodeClones1/|, true);
    processFolder("Test2", |cwd:///Tests/CodeClones2/|, true);
    processFolder("Test3", |cwd:///Tests/CodeClones3/|, true);

    processFolder("smallsql", |cwd:///smallsql0.21_src|, false);
    processFolder("hsqldb", |cwd:///hsqldb-2.3.1|, false);

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

map[str, value] cloneDetection(loc folder, str baseName, bool isType1, map[str, value] cloningData, bool isTest) {

    // Get number of lines of the whole folder system and a specific folder. 
    tuple[map[str,int], int] fileLines = computeTotalNonCommentNonEmptyLines(folder);

    // Hashmap to keep track of all clones.
    map[list[str], list[list[node]]] hashMap = ();

    // Sequence algorithm: Return all subsequences.
    if (isTest) {
        hashMap = sequenceAlgorithm(hashMap, TEST_MIN_CLONE_SIZE, TEST_MAX_CLONE_SIZE, folder, isType1);
    } else {
        hashMap = sequenceAlgorithm(hashMap, MIN_CLONE_SIZE, MAX_CLONE_SIZE, folder, isType1);
    }

    // Sequence algorithm: Return all clone pairs and subsumination after performing the sequence algorithm.
    set[tuple[list[str], tuple[list[node],list[node]]]] clonePairs = removeSubsumedClones(getClonePairs({}, hashMap));

    // Sequence algorithm: Retrieve clone classes.
    set[list[str]] cloneClasses = getCloneClasses(clonePairs);

    // Number of clone classes
    println("<baseName>: Number of clone classes (Sequence): <size(cloneClasses)>");

    // Sequence algorithm: Get folder data ready. 
    list[map[str,str]] dataClonePair = clonePairsToFile([], clonePairs);

    list[map[str,str]] dataCloneClass = cloneClassToFile([], cloneClasses);

    // Get specific folder data.
    cloningData += findCloneStatistics(dataCloneClass, fileLines, isType1, dataClonePair);

    // Write sequence data to a json folder.
    writeJSON(|cwd:///Results/<baseName>/cloning_data_<baseName>.txt|, cloningData, indent=1);


    return cloningData;
}

