module Basic

import CloneHelper;
import HelperFunctions;

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::json::IO;
import IO;
import Node;
import List;
import String;

// The basic clone detection algorithm
tuple[set[list[str]],list[tuple[tuple[value,value],tuple[value,value]]]] basic(loc file, int massThreshold) {
    M3 model = createM3FromDirectory(file);
    list[node] subTrees = [];
    map[str, list[tuple[value, value]]] hashMap = ();
    list[tuple[tuple[value,value],tuple[value,value]]] clonepairs = [];

    // Clone classes
    set[tuple[value,value]] cc = {};  

    for (<loc file, _> <- model.containment) {
        if(endsWith(file.path, ".java")) {
            Declaration tr = createAstFromFile(file, true);
            top-down visit(tr) {
                case node t : {
                    int count = 0;
                    // Calculate the number of child nodes of the subtree to calculate if the given mass is above the threshold.
                    top-down visit (t) {
                        case node s: { 
                            count += size(getChildren(s));
                        }
                    }

                    if (count + 1 >= massThreshold) {
                        subTrees += t;
                    }
                }
            }
        }
    }
    
    for (s <- subTrees) {
        try 
            s_src = s@src;
        catch _:
            continue;

        s1 = <s@src, unsetRec(s)>;
        temp = [];

        if(hash(s) in hashMap) {     
            for(h <- hashMap[hash(s)]) {
                 temp += h;
            } 

            s2 = hashMap[hash(s)];  
            cc += s1; 

            for(ss <- s2) {
                cc += ss;
                if(s1 != ss) { 
                    clonepairs += <s1, ss>; 
                }
            }
        }   
        hashMap += (hash(s): (temp + s1));
    }
    
    noDuplicateCloneClasses = {};

    for(d <- cc) {
        noDuplicateCloneClasses += ["<d[0]>"];
    }

    return <noDuplicateCloneClasses, clonepairs>;
}