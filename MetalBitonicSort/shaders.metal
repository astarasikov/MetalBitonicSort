//
//  shaders.metal
//  MetalBitonicSort
//
//  Created by Alexander Tarasikov on 23/12/2016.
//  Copyright © 2016 test. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

static inline void bitonicStep(device int *arr, int i, int stepInStage, int stage)
{
    int idxSibling = i ^ stepInStage;
    
    if (i < idxSibling) {
        if (((i & stage) == 0) == (arr[i] > arr[idxSibling])) {
            int tmp = arr[i];
            arr[i] = arr[idxSibling];
            arr[idxSibling] = tmp;
        }
    }
}

kernel  void bitonic(
                     device int *inVector [[ buffer(0) ]],
                     const device int *inParams [[ buffer(1) ]],
                     uint id [[thread_position_in_grid]]
)
{
    /**
     * Call the implementation of the bitonic sorting.
     * Comment out this part of the code for debugging.
     */
    bitonicStep(inVector, id, inParams[0], inParams[1]);
    return;
    
    /**
     * for debugging, run only one thread.
     * After verifying single-threaded code, invoke the kernel with corresponding arguments
     */
    
    if (id != 0) {
        return;
    }
    
    enum {
        NUM_ITEMS = 256,
    };
    
#if 1
    for (int k = 2; k <= NUM_ITEMS; k <<= 1) {
        for (int j = k >> 1; j > 0; j >>= 1) {
            for (int i = 0; i < NUM_ITEMS; i++) {
                bitonicStep(inVector, i, j, k);
            }
        }
    }

#else
    /**
     * Bubblesort implementation for sanity check
     */
    for (int i = 0; i < NUM_ITEMS; i++) {
        for (int j = i + 1; j < NUM_ITEMS; j++) {
            if (inVector[i] > inVector[j]) {
                int tmp = inVector[i];
                inVector[i] = inVector[j];
                inVector[j] = tmp;
            }
        }
    }
#endif
}
