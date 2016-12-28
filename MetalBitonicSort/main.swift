//
//  main.swift
//  MetalBitonicSort
//
//  Created by Alexander Tarasikov on 23/12/2016.
//  Copyright © 2016 test. All rights reserved.
//

import Foundation
import Metal

func byteSize(array : [Int32] ) -> Int {
    return array.count * MemoryLayout.size(ofValue: array[0])
}

func checkSorted(result: [Int32]) {
    var prev = result[0]
    var idx = 0
    for item in result {
        /**
         * Ensure the resulting array is sorted to verify the algorithm works correctly
         */
        if (item < prev) {
            print(String(format: "at [%d]: %d < %d", idx, item, prev))
        }
        
        /**
         * Don't print too many items
         */
        if (idx > 256) {
            break;
        }
        idx += 1
        prev = item
        print(String(format:"%08X", item))
    }
}

func runMetal() {
    print("Hello, World!")
    let dataLength = 1 << 8
    
    /**
      * Sanity check: ensure the input size is the power of two.
      */
    if (dataLength & (dataLength - 1)) != 0 {
        print("Data size must be a power of two. Requested: ", dataLength)
        return
    }
    
    var input = [Int32](repeating:0, count: dataLength)
    for i in (0...(dataLength - 1)) {
        //input[i] = Int32(2 * dataLength) - i;
        input[i] = Int32(arc4random_uniform(1024))
    }
    let dataByteLength = dataLength * MemoryLayout.size(ofValue: input[0])
    
    /**
     * The buffer to store the "stage" and "pass" indices (arguments for the kernel).
     */
    var paramData = [Int32](repeating:0, count: 2)
    
    let device = MTLCreateSystemDefaultDevice()
    print("Metal Device:", device as Any)
    
    let defaultLibrary = device?.newDefaultLibrary()
    let sigmoidFunction = defaultLibrary?.makeFunction(name: "bitonic")
    
    let cmdQueue = device?.makeCommandQueue()
    
    let threadsPerGroup = MTLSize(width: 32, height: 1, depth: 1)
    let numThreadGroups = MTLSize(width: dataLength / threadsPerGroup.width, height: 1, depth: 1)
    
    let inBuffer = device?.makeBuffer(bytes: &input, length:dataByteLength, options: MTLResourceOptions())
    let paramBuffer = device?.makeBuffer(bytes: &paramData, length:byteSize(array:paramData), options: MTLResourceOptions.storageModeManaged)
    
    var pipeline : MTLComputePipelineState? = nil
    do {
        pipeline = try device?.makeComputePipelineState(function: sigmoidFunction!)
    }
    catch {
        print("ffuu")
        return
    }
    
    /*
     This roughly does the following.
     The "dipatchThreadgroups" acts as the inner loop distributing the job across GPU threads.
     
     for (int k = 2; k <= NUM_ITEMS; k <<= 1) {
         for (int j = k >> 1; j > 0; j >>= 1) {
             for (int i = 0; i < NUM_ITEMS; i++) {
                 bitonicStep(inVector, i, j, k);
             }
         }
     }
 */
    
    var stage = 2
    var stepInStage = 0
    while stage <= dataLength {
        stepInStage = stage >> 1
        while stepInStage > 0 {
            
            paramData[0] = Int32(stepInStage)
            paramData[1] = Int32(stage)
            memcpy(paramBuffer?.contents(), &paramData, byteSize(array: paramData))
            paramBuffer?.didModifyRange(NSMakeRange(0, byteSize(array: paramData)))
            
            let cmdBuffer = cmdQueue?.makeCommandBuffer()
            let cmdEncoder = cmdBuffer?.makeComputeCommandEncoder()
            cmdEncoder?.setComputePipelineState(pipeline!)
            cmdEncoder?.setBuffer(inBuffer, offset: 0, at: 0)
            cmdEncoder?.setBuffer(paramBuffer, offset: 0, at: 1)
            cmdEncoder?.dispatchThreadgroups(numThreadGroups, threadsPerThreadgroup: threadsPerGroup)
            cmdEncoder?.endEncoding()
            cmdBuffer?.commit()
            cmdBuffer?.waitUntilCompleted()

            stepInStage >>= 1
        }
        stage <<= 1
    }

    let data = NSData(bytesNoCopy: inBuffer!.contents(), length: dataByteLength, freeWhenDone: false)
    var result = [Int32](repeating:0, count: dataLength)
    data.getBytes(&result, length: dataByteLength)
    
    NSLog("Done")
    checkSorted(result: result)
}

runMetal()
