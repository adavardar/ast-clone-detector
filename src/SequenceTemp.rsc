module SequenceTemp

import HelperFunctions;
import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::json::IO;
import IO;
import Node;
import List;
import String;

// The sequence algorithm
map[list[str], list[list[node]]] sequence(
    map[list[str], list[list[node]]] hashMap, 
    int minSequenceLength, 
    int maxSequenceLength, 
    loc sourceFile, 
    bool type2) {
        
    M3 model = createM3FromDirectory(sourceFile);

    for (<loc file, _> <- model.containment) {
        if(endsWith(file.path, ".java")) {
            Declaration tree = createAstFromFile(file, true);
            list[list[node]] sequences = [];
            list[list[node]] sequences2 = [];

            // Visit every statement in every file of the file system.
            visit(tree) {
                case \block(s): {
                    if (thresholdSequence(size(s), minSequenceLength, maxSequenceLength)) {
                        sequences += [s];
                    }
                }
            }

            // Add aditional block statements within block statements if needed. 
            for(s <- sequences) {
                list[node] sequenceTemp = [];

                for(ss <- s) {
                    if(type2) {
                        sequenceTemp += visit(ss) { 
                            case \simpleName(_) => \simpleName("Normal")
                            //case \variable(_,x,y) => \variable("Normal", x, y)
                            //case \variable(_,x) => \variable("Normal", x)
                            case \typeParameter(_, x) => \typeParameter("Normal", x)
                        }
                    } 
                    else {
                        sequenceTemp += ss;
                    }
                }

                sequences2 += [sequenceTemp];
            }

            // Generate all subsequences according to the following requirements:
            // - Sequence is greater than or equal than seqMin.
            // - Sequence is less than or equal to seqMax.
            for(s <- sequences2) {
                list[list[node]] n = [ s[s1..s2] | s1 <- [0..size(s) + 1], s2 <- [0..size(s) + 1], 
                thresholdSequence(size(s[s1..s2]), minSequenceLength, maxSequenceLength), s2 >= s1 + minSequenceLength];

                set[list[node]] noDupeSubSequences = {};

                for(l <- n) {
                    noDupeSubSequences+=l;
                }

                // Add the subsequences to the hash map.
                for(e <- noDupeSubSequences) {
                    hashList = [];
                    for(el <- e) {
                        hashList+= hash(el);
                    }

                    temp = [];

                    if(hashList in hashMap) {
                        for(k <- hashMap[hashList]) {
                            temp += [k];
                        }
                    }

                    if(temp == []) {
                        hashMap += (hashList :  [e]);
                    }
                    else {
                        hashMap += (hashList : temp + [e]);
                    }
                }
            }
        }
    }

    // Return the hashmap and a list of the original subsequences so it can be used for type 2 clone detection
    return(hashMap);
}
 
// retrieve pairs of sequences that are clones based on hash map, it compares sequences in the hash map to identify all clone pairs 
set[tuple[list[str], tuple[list[node],list[node]]]] getClonePairs (
    set[tuple[list[str], tuple[list[node],list[node]]]] detectedClonePairs,
    map[list[str], list[list[node]]] sequenceHashMap) {
    
    for (sequenceHash <- sequenceHashMap) {
        // retrieve sequences with the same hash 
        list[list[node]] sequences = sequenceHashMap[sequenceHash];
        // only consider hashes with multiple sequences 
        if (size(sequences) > 1) {
            for (seq1 <- sequences) {
                for (seq2 <- sequences) {
                    if(<sequenceHash, <(seq1),(seq2)>> notin detectedClonePairs && seq1 != seq2) {
                            detectedClonePairs += <sequenceHash, <(seq1),(seq2)>>;
                    }
                }
            }
        }
    }

    return(detectedClonePairs);
}


// check if the sequence is contained in the other sequence 
bool isContained(
    tuple[list[str], tuple[list[node],list[node]]] candidateClonePair, 
    tuple[list[str], tuple[list[node],list[node]]] otherClonePair) {
    return 
        contains("<otherClonePair>"[1..size("<otherClonePair>")-1], "<candidateClonePair[0]>"[1..size("<candidateClonePair[0]>")-1]);
}

// collect file locations of a given clone pair 
list[value] collectFileLocations(
    tuple[list[str], tuple[list[node],list[node]]] clonePairs) {
    list[value] fileLocations = [];
    for(clonePair <- clonePairs[1][1]) {
        fileLocations += (clonePair@src);
    }
    for(clonePair <- clonePairs[1][0]) {
        fileLocations += (clonePair@src);
    } 
    return fileLocations;
}


// subsumption

// remove subsumed clone pairs to retain only the maximal clone pairs 
set[tuple[list[str], tuple[list[node],list[node]]]] subsumption (
    set[tuple[list[str], tuple[list[node],list[node]]]] clonePairs) {
    
    // iterate through each clone pair
    for(candidateClonePair <- clonePairs) {
        bool isSubsumed = true; // flag to track if candidateClonePair is subsumed
        bool isRemoved = false; // flag to track if candidateClonePair has been removed
        
        // compare candidateClonePair against every other clone pair
         for (otherClonePair <- clonePairs) {
            // skip if otherClonePair is smaller or equal in size 
            if (size(otherClonePair[0]) <= size(candidateClonePair[0])) {
                continue;
            }

            // check if the candidateClonePair sequence is entirely contained in the otherClonePair sequence 
            if (isContained(candidateClonePair, otherClonePair))  
            { 
                isSubsumed = true;

                // single-element clone pair is always removed 
                if (size(candidateClonePair[0]) == 1) {
                    clonePairs -= candidateClonePair;
                    break;
                }

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
                    isRemoved = true;
                    clonePairs -= candidateClonePair;
                    break;
                }
            }  
        }
    }

    // return the updated clonePairs set with subsumed pairs removed 
    return(clonePairs);
} 