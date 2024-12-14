module SequenceAlgorithm

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::json::IO;
import IO;
import Node;
import List;
import String;

// the sequence detection algorithm
map[list[str], list[list[node]]] sequenceAlgorithm(
    map[list[str], list[list[node]]] hashMap, 
    int minSequenceLength, 
    int maxSequenceLength, 
    loc sourceFile, 
    bool isType2) {
        
    M3 model = createM3FromDirectory(sourceFile);
    list[list[node]] initialSequences = []; 
    list[list[node]] sequences = []; // the transformed sequences after processing (based on isType2 flag) 
           
    for (<loc file, _> <- model.containment) {
        if(endsWith(file.path, ".java")) {
            // create the AST for the current file 
            Declaration astTree = createAstFromFile(file, true);
            initialSequences = []; 
            sequences = [];

            // traverse the ast and identify blocks of statements 
            visit(astTree) {
                case \block(statement): {
                    // only consider sequences that meet the minimum and maximum length thresholds 
                    if (checkThresholdForSequence(minSequenceLength, maxSequenceLength, size(statement)))
                        initialSequences += [statement];
                }
            }

            // depend on the isType2 flag, either normalize or retain sequences 
            sequences += [
                [isType2 ? visit(seq) { 
                            case \id(_) => \id("NormalizedName")
                            // case \type(_) => \type("NormalizedType")

                            /*
                            case \variable(_, x, y) => \variable("NormalizedName", x, y)
                            case \variable(_, x) => \variable("NormalizedName", x)
                            case \typeParameter(_, x) => \typeParameter("NormalizedType", x)
                            case \method(mods, typeParams, returnType, _, params, exceptions, body) => \method(mods, typeParams, returnType, "NormalizedName", params, exceptions, body)
                            case \method(mods, typeParams, returnType, _, params, exceptions) => \method(mods, typeParams, returnType, "NormalizedName", params, exceptions)
                            */
                        } 
                        : seq | seq <- sequence] // if not type 2, retain the sequence as is 
                | sequence <- initialSequences
            ];

            for(sequence <- sequences) {
                // generate all valid subsequences of the current sequence that meet criteria 
                // iterate over start and end indices, extract subsequence, filter by threshold, and ensure minimum length 
                set[list[node]] uniqueSubsequences = { 
                    sequence[seq_start..seq_end] | 
                    seq_start <- [0..size(sequence) + 1], 
                    seq_end <- [0..size(sequence) + 1], 
                    checkThresholdForSequence(minSequenceLength, maxSequenceLength, size(sequence[seq_start..seq_end])),
                    minSequenceLength <= seq_end - seq_start
                };

                // for each valid subsequence, compute the hash and store it in the hash map 
                for(subsequence <- uniqueSubsequences) {
                    list[str] hashList = [hash(subseqNode) | subseqNode <- subsequence]; // generate a list of hashes for all elements in the subsequence 
                    // update the hashMap: add the subsequence to the map, or append it to existing entries if the hash already exists 
                    hashMap += (hashList : (hashList in hashMap ? hashMap[hashList] : []) + [subsequence]); 
                }
            }
        }
    }

    return(hashMap); // return the updated hashMap, containing all subsequences with their hashes 
}

bool checkThresholdForSequence (int minimum, int maximum, int sequenceSize) { 
    return sequenceSize >= minimum && sequenceSize <= maximum; 
}

str hash (value sequence) { 
    return md5Hash(unsetRec(sequence)); 
}

// subsumption
// remove subsumed clone pairs to retain only the maximal clone pairs 
set[tuple[list[str], tuple[list[node], list[node]]]] removeSubsumedClones (
    set[tuple[list[str], tuple[list[node], list[node]]]] clonePairs) {
    
    // iterate through each clone pair
    for(candidateClonePair <- clonePairs) {
        bool isSubsumed = false; 

        // compare candidateClonePair against every other clone pair
         for (otherClonePair <- clonePairs) {
            // skip if otherClonePair is smaller or equal in size 
            if (size(otherClonePair[0]) <= size(candidateClonePair[0])) {
                continue;
            }

            // check if the candidateClonePair sequence is entirely contained in the otherClonePair sequence 
            if (isContained(candidateClonePair, otherClonePair)) {
                isSubsumed = true;
                list[value] candidateFileLocations = collectFileLocations(candidateClonePair); // collect file locations of candidateClonePair                
                list[value] otherFileLocations = collectFileLocations(otherClonePair); // collect file locations of otherClonePair

                // verify if all file locations of candidateClonePair exist in otherClonePair
                for (location <- candidateFileLocations) {
                    if (location notin otherFileLocations) {
                        isSubsumed = false;
                        break;
                    }
                }

                // if candidateClonePair is confirmed as subsumed, remove it
                if (isSubsumed) {
                    clonePairs -= candidateClonePair;
                    break;
                }
            }  
        }
    }

    // return the updated clonePairs set with subsumed pairs removed 
    return(clonePairs);
} 

// check if the sequence is contained in the other sequence 
bool isContained(
    tuple[list[str], tuple[list[node],list[node]]] candidateClonePair, 
    tuple[list[str], tuple[list[node],list[node]]] otherClonePair) {
    return 
        contains(
            "<otherClonePair[0]>"[1..size("<otherClonePair[0]>")-1], 
            "<candidateClonePair[0]>"[1..size("<candidateClonePair[0]>")-1]
            );
}

// collect file locations of a given clone pair 
list[value] collectFileLocations(
    tuple[list[str], tuple[list[node],list[node]]] clonePairs) {
    list[value] fileLocations = [];
    for(clonePair <- clonePairs[1][0]) {
        fileLocations += (clonePair@src);
    }
    for(clonePair <- clonePairs[1][1]) {
        fileLocations += (clonePair@src);
    } 
    return fileLocations;
}
