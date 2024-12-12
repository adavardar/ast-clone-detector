module Sequence

import HelperFunctions;
import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::json::IO;
import IO;
import Node;
import List;
import String;

// the sequence detection algorithm
// parameters:
//  - sequenceHashMap: a map where each key is a hash list (representing a sequence of nodes), and the value is a list of node lists that match that hash 
//  - minSequenceLength/maxSequenceLength: minimum/maximum number of statements in a sequence to be considered as a clone candidate 
//  - isType2: if true, normalizes the sequence to detect type 2 (near-miss) clones
// returns:
//  - the updated sequenceHashMap, now containing all sequences detected 
map[list[str], list[list[node]]] sequence(
    map[list[str], list[list[node]]] sequenceHashMap,  
    int minSequenceLength, 
    int maxSequenceLength, 
    loc sourceFile, 
    bool isType2) {

    // parse the source file into an AST model 
    M3 astModel = createM3FromDirectory(sourceFile);

    // loop through all files in the model 
    for (<loc file, _> <- astModel.containment) {
        if (endsWith(file.path, ".java")) { 
            // create an AST for the Java file 
            Declaration abstractSyntaxTree = createAstFromFile(file, true);
            
            // step 1: extract all block-level sequences from the AST 
            list[list[node]] rawSequences = []; // list to store initial sequences (blocks of statements)
            visit(abstractSyntaxTree) {
                case \block(statements): {
                    // add blocks that meet the size threshold to rawSequences 
                    if (thresholdSequence(size(statements), minSequenceLength, maxSequenceLength)) {
                        rawSequences += [statements];
                    }
                }
            }

            // step 2: normalize the sequences if detecting type 2 clones 
            list[list[node]] normalizedSequences = [];
            // Add aditional block statements within block statements if needed. 
            for (sequence <- rawSequences) {
                list[node] normalizedSequence = [];

                for (seq <- sequence) {
                    if (isType2) {
                        // replace identifiers with "Normalized" for type 2 detection 
                        normalizedSequence += visit(seq) {
                            //case \variable(_,x,y) => \variable("Normal", x, y)
                            //case \variable(_,x) => \variable("Normal", x)
                            //case \variable(x,_,_) => \variable("Normal", _,_)
                            //case \variable(x,_) => \variable("Normal",_)
                            case \typeParameter(_,x) => \typeParameter("Normalized",x)
                            //case \method(_, _, _, x, _, _, _) => \method(_, _, _, "Normal", _, _, _)
                            //case \method(_, _, _, x, _, _) => \method(_, _, _, "Normal", _, _)
                            //case \method(a, b, c, _, d, e, f) => \method(a, b, c, "Normal", d, e, f)
                            //case \method(a, b, c, _, d, e) => \method(a, b, c, "Normal", d, e)
                        }
                    } 
                    else {
                        normalizedSequence += seq; 
                    }
                }
                normalizedSequences += [normalizedSequence];
            }

            // step 3: generate subsequences from the normalized sequences 
            for (sequence <- normalizedSequences) {
                list[list[node]] subsequences = [
                    sequence[start..end] | start <- [0..size(sequence)], end <- [0..size(sequence)],
                    thresholdSequence(size(sequence[start..end]), minSequenceLength, maxSequenceLength),
                    end >= start + minSequenceLength
                ];

                // remove duplicate subsequences by converting to a set 
                set[list[node]] uniqueSubsequences = {};
                for (subsequence <- subsequences) {
                    uniqueSubsequences += subsequence;
                }

                // step 4: add unique subsequences to the sequenceHashMap
                for (subsequence <- uniqueSubsequences) {
                    list[str] subsequenceHashList = [];
                    for (element <- subsequence) {
                        // compute the hash value of each element and append it to the hash list 
                        subsequenceHashList += hash(element);
                    }

                    // temporary list to store existing sequences that match the current hash list
                    list[list[node]] existingSequences = [];

                    // check if the hash list already exists in the hashMap 
                    if (subsequenceHashList in sequenceHashMap) {
                        // if it exists, retrieve the matching sequences 
                        for (sequence <- sequenceHashMap[subsequenceHashList]) {
                            existingSequences += [sequence];
                        }
                    }

                    // if no existing sequences are found, add the current subsequence as a new entry
                    if (existingSequences == []) {
                        sequenceHashMap += (subsequenceHashList: [subsequence]);
                    } else {
                        // otherwise, append the current subsequence to the list of existing sequences
                        sequenceHashMap += (subsequenceHashList: existingSequences + [subsequence]);
                    }
                }
            }
        }
    }

    // return the updated hash map containing detected clones 
    return(sequenceHashMap);
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
            if (contains("<otherClonePair>"[1..size("<otherClonePair>")-1], "<candidateClonePair[0]>"[1..size("<candidateClonePair[0]>")-1]))  
            { 
                isSubsumed = true;

                // single-element clone pair is always removed 
                if (size(candidateClonePair[0]) == 1) {
                    clonePairs -= candidateClonePair;
                    break;
                }

                // collect file locations of candidateClonePair
                list[value] candidateFileLocations = [];
                for (c <- candidateClonePair[1][1]) {
                    candidateFileLocations += (c@src);
                }
                for (c <- candidateClonePair[1][0]) {
                    candidateFileLocations += (c@src);
                }

                // collect file locations of otherClonePair
                list[value] otherFileLocations = [];
                for (c <- otherClonePair[1][1]) {
                    otherFileLocations += (c@src);
                }
                for (c <- otherClonePair[1][0]) {
                    otherFileLocations += (c@src);
                }

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
                }

                // break out of loop if candidateClonePair has been removed 
                if (isRemoved) {
                  break;
                }
            }

            // break out of loop if candidateClonePair has been removed 
            if (isRemoved) {
                break;
            }
        }
    }

    // return the updated clonePairs set with subsumed pairs removed 
    return(clonePairs);
} 