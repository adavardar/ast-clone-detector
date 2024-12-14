module Main

import HelperFunctions;
import Sequence;
import CloneHelper;

import lang::json::IO;
import IO;
import Type;
import List;
import Set;
import String;
import lang::java::m3::Core;
import lang::java::m3::AST;
import Node;

int MIN_CLONE_SIZE = 6;
int MAX_CLONE_SIZE = 12;

int TEST_MIN_CLONE_SIZE = 1;
int TEST_MAX_CLONE_SIZE = 10;


str main () {

    println("Starting the clone detection process...");

    processFolder("test1", |cwd:///Tests/CodeClones1/|, true);
    processFolder("test2", |cwd:///Tests/CodeClones2/|, true);
    processFolder("test3", |cwd:///Tests/CodeClones3/|, true);

    //processFolder(|cwd:///smallsql0.21_src|, "smallsql", false);
    //processFolder(|cwd:///hsqldb-2.3.1|, "hsqldb", false);

    return "Detection is done!";
}

void processFolder(str baseName, loc folder, bool isTest) {
    map[str,value] cloningData = ();
    //println(cloningData);
    println("Processing the <baseName> folder...");
    
    // Type1 clones
    cloningData = cloneDetection(folder, "<baseName>_Type1", true, cloningData, isTest);
    //println(cloningData);

    // Type1 + Type2 clones
    cloningData = cloneDetection(folder, "<baseName>_Type2", false, cloningData, isTest);
    //println(cloningData);

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
    set[tuple[list[str], tuple[list[node],list[node]]]] clonePairs = subsumption(getClonePairs({}, hashMap));

    // Sequence algorithm: Retrieve clone classes.
    set[list[str]] cloneClasses = getCloneClasses(clonePairs);

    // Number of clone classes
    println("<baseName>: Number of clone classes (Sequence): <size(cloneClasses)>");

    // Sequence algorithm: Get folder data ready. 
    list[map[str,str]] dataClonePair = clonePairsToFile([], clonePairs);

    list[map[str,str]] dataCloneClass = cloneClassToFile([], cloneClasses, true);

    // Get specific folder data.
    cloningData += getFileData(dataCloneClass, fileLines, isType1, dataClonePair);

    // Write sequence data to a json folder.
    writeJSON(|cwd:///Results/<baseName>/cloning_data_<baseName>.txt|, cloningData, indent=1);


    return cloningData;
}

