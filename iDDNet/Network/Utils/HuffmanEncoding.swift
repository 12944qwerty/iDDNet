//
//  HuffmanEncoding.swift
//  iDDNet
//
//  Created by King Fish on 2/20/26.
//

import Foundation

let FREQ_TABLE: [UInt32] = [
    1 << 30, 4545, 2657, 431, 1950, 919, 444, 482, 2244, 617, 838, 542, 715, 1814, 304, 240, 754, 212, 647, 186,
    283, 131, 146, 166, 543, 164, 167, 136, 179, 859, 363, 113, 157, 154, 204, 108, 137, 180, 202, 176,
    872, 404, 168, 134, 151, 111, 113, 109, 120, 126, 129, 100, 41, 20, 16, 22, 18, 18, 17, 19,
    16, 37, 13, 21, 362, 166, 99, 78, 95, 88, 81, 70, 83, 284, 91, 187, 77, 68, 52, 68,
    59, 66, 61, 638, 71, 157, 50, 46, 69, 43, 11, 24, 13, 19, 10, 12, 12, 20, 14, 9,
    20, 20, 10, 10, 15, 15, 12, 12, 7, 19, 15, 14, 13, 18, 35, 19, 17, 14, 8, 5,
    15, 17, 9, 15, 14, 18, 8, 10, 2173, 134, 157, 68, 188, 60, 170, 60, 194, 62, 175, 71,
    148, 67, 167, 78, 211, 67, 156, 69, 1674, 90, 174, 53, 147, 89, 181, 51, 174, 63, 163, 80,
    167, 94, 128, 122, 223, 153, 218, 77, 200, 110, 190, 73, 174, 69, 145, 66, 277, 143, 141, 60,
    136, 53, 180, 57, 142, 57, 158, 61, 166, 112, 152, 92, 26, 22, 21, 28, 20, 26, 30, 21,
    32, 27, 20, 17, 23, 21, 30, 22, 22, 21, 27, 25, 17, 27, 23, 18, 39, 26, 15, 21,
    12, 18, 18, 27, 20, 18, 15, 19, 11, 17, 33, 12, 18, 15, 19, 18, 16, 26, 17, 18,
    9, 10, 25, 22, 22, 17, 20, 16, 6, 16, 15, 20, 14, 18, 24, 335, 1517
]
let huffman = DDNetHuffman(frequencies: FREQ_TABLE)

/// Teeworlds / DDNet Huffman Compression implementation.
/// Converts standard byte streams into Huffman-compressed packets and vice versa.
public class DDNetHuffman {

    // Represents a single node in the Huffman Tree
    private struct Node {
        var freq: UInt32 = 0
        var numBits: UInt32 = 0
        var bits: UInt32 = 0
        var leaf1: Int = -1 // Left branch (0)
        var leaf2: Int = -1 // Right branch (1)
    }

    private var nodes: [Node]
    private var rootIdx: Int = 512
    private let EOF_SYMBOL = 256

    /// Initializes the Huffman tree.
    /// - Parameter frequencies: The 256-element frequency table. If nil, falls back to a dummy tree.
    ///   **IMPORTANT:** To communicate with a real DDNet server, you MUST pass the exact
    ///   Teeworlds frequency array (found in TeeAI/huffman.py as `freqs = [...]`).
    public init(frequencies: [UInt32]? = nil) {
        self.nodes = [Node](repeating: Node(), count: 513)
        let freqs = frequencies ?? DDNetHuffman.buildDummyFrequencies()
        buildTree(frequencies: freqs)
    }

    private static func buildDummyFrequencies() -> [UInt32] {
        var freqs = [UInt32](repeating: 1, count: 256)
        freqs[0] = 1 << 30
        return freqs
    }

    private func buildTree(frequencies: [UInt32]) {
        for i in 0..<256 {
            nodes[i].freq = frequencies[i]
        }
        nodes[EOF_SYMBOL].freq = 1

        var list = Array(0...256)
        var numNodes = 257

        while list.count > 1 {
            var node1 = 0
            var node2 = 1

            if nodes[list[node1]].freq > nodes[list[node2]].freq {
                node1 = 1
                node2 = 0
            }

            for i in 2..<list.count {
                let freq = nodes[list[i]].freq
                if freq < nodes[list[node1]].freq {
                    node2 = node1
                    node1 = i
                } else if freq < nodes[list[node2]].freq {
                    node2 = i
                }
            }

            let newNodeIdx = numNodes
            nodes[newNodeIdx].freq = nodes[list[node1]].freq + nodes[list[node2]].freq
            nodes[newNodeIdx].leaf1 = list[node1]
            nodes[newNodeIdx].leaf2 = list[node2]

            list[node1] = newNodeIdx
            list[node2] = list[list.count - 1]
            list.removeLast()

            numNodes += 1
        }

        rootIdx = list[0]
        setBits(nodeIdx: rootIdx, bits: 0, depth: 0)
    }

    // Recursively calculate bitpaths for all leaf nodes
    private func setBits(nodeIdx: Int, bits: UInt32, depth: UInt32) {
        if nodes[nodeIdx].leaf2 != -1 {
            setBits(nodeIdx: nodes[nodeIdx].leaf2, bits: bits | (1 << depth), depth: depth + 1)
        }
        if nodes[nodeIdx].leaf1 != -1 {
            setBits(nodeIdx: nodes[nodeIdx].leaf1, bits: bits, depth: depth + 1)
        }

        if nodes[nodeIdx].leaf1 == -1 && nodes[nodeIdx].leaf2 == -1 {
            nodes[nodeIdx].bits = bits
            nodes[nodeIdx].numBits = depth
        }
    }

    /// Compresses standard data into a Teeworlds Huffman payload
    public func compress(input: Data) -> Data {
        var output = Data()
        var bitBuffer: UInt64 = 0
        var bitCount: UInt32 = 0

        for byte in input {
            let node = nodes[Int(byte)]
            bitBuffer |= (UInt64(node.bits) << bitCount)
            bitCount += node.numBits

            while bitCount >= 8 {
                output.append(UInt8(bitBuffer & 0xFF))
                bitBuffer >>= 8
                bitCount -= 8
            }
        }

        let eofNode = nodes[EOF_SYMBOL]
        bitBuffer |= (UInt64(eofNode.bits) << bitCount)
        bitCount += eofNode.numBits

        while bitCount >= 8 {
            output.append(UInt8(bitBuffer & 0xFF))
            bitBuffer >>= 8
            bitCount -= 8
        }

        if bitCount > 0 {
            output.append(UInt8(bitBuffer & 0xFF))
        }

        return output
    }

    /// Decompresses a Teeworlds Huffman payload back to raw data
    public func decompress(input: Data) -> Data {
        var output = Data()
        var bitBuffer: UInt32 = 0
        var bitCount: UInt32 = 0
        var byteIndex = 0

        var currentNodeIdx = rootIdx

        while true {
            if bitCount == 0 {
                if byteIndex >= input.count {
                    break
                }
                bitBuffer = UInt32(input[byteIndex])
                byteIndex += 1
                bitCount = 8
            }

            let bit = bitBuffer & 1
            bitBuffer >>= 1
            bitCount -= 1

            if bit == 0 {
                currentNodeIdx = nodes[currentNodeIdx].leaf1
            } else {
                currentNodeIdx = nodes[currentNodeIdx].leaf2
            }

            if nodes[currentNodeIdx].leaf1 == -1 {
                if currentNodeIdx == EOF_SYMBOL {
                    break
                }

                output.append(UInt8(currentNodeIdx))
                currentNodeIdx = rootIdx
            }
        }

        return output
    }
}
