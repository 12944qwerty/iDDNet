//
//  HuffmanEncodingTests.swift
//  iDDNetTests
//
//  Created by King Fish on 2/20/26.
//

import Testing
import Foundation

struct HuffmanEncodingTests {

    @Test func testCompressionRoundTrip() async throws {
        let huffman = DDNetHuffman()

        let originalString = "host_info\0my_cool_server\0standard\0"
        let originalData = Data(originalString.utf8)

        let compressedData = huffman.compress(input: originalData)

        #expect(!compressedData.isEmpty)

        let decompressedData = huffman.decompress(input: compressedData)

        #expect(originalData == decompressedData)

        let resultString = String(data: decompressedData, encoding: .utf8)
        #expect(resultString == originalString)
    }

    @Test func testEmptyData() async throws {
        let huffman = DDNetHuffman()
        let emptyData = Data()

        let compressed = huffman.compress(input: emptyData)
        let decompressed = huffman.decompress(input: compressed)

        #expect(decompressed.isEmpty)
    }

}
