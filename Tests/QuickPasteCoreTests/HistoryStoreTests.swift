import XCTest
@testable import QuickPasteCore

final class HistoryStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        super.tearDown()
    }

    func testAddInsertsNewestFirst() {
        let store = HistoryStore(fileURL: nil)
        store.add("a")
        store.add("b")
        XCTAssertEqual(store.items.map(\.text), ["b", "a"])
    }

    func testAddIgnoresEmptyAndWhitespaceOnly() {
        let store = HistoryStore(fileURL: nil)
        store.add("")
        store.add("  \n\t")
        XCTAssertTrue(store.items.isEmpty)
    }

    func testDuplicateMovesToFront() {
        let store = HistoryStore(fileURL: nil)
        store.add("a")
        store.add("b")
        store.add("a")
        XCTAssertEqual(store.items.map(\.text), ["a", "b"])
    }

    func testLimitDropsOldest() {
        let store = HistoryStore(fileURL: nil, limit: 3)
        ["1", "2", "3", "4"].forEach(store.add)
        XCTAssertEqual(store.items.map(\.text), ["4", "3", "2"])
    }

    func testRemoveAndClear() {
        let store = HistoryStore(fileURL: nil)
        store.add("a")
        store.add("b")
        store.remove(id: store.items[0].id)
        XCTAssertEqual(store.items.map(\.text), ["a"])
        store.clear()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testSearchIsCaseInsensitive() {
        let store = HistoryStore(fileURL: nil)
        ["Hello World", "foo", "say hello"].forEach(store.add)
        XCTAssertEqual(store.search("HELLO").map(\.text), ["say hello", "Hello World"])
        XCTAssertEqual(store.search("  ").count, 3)
    }

    func testPersistsAcrossInstances() {
        let store = HistoryStore(fileURL: tempURL)
        store.add("a")
        store.add("b")
        let reloaded = HistoryStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.items.map(\.text), ["b", "a"])
    }

    func testCorruptFileStartsEmpty() throws {
        try FileManager.default.createDirectory(
            at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: tempURL)
        XCTAssertTrue(HistoryStore(fileURL: tempURL).items.isEmpty)
    }
}

final class HistoryStoreImageTests: XCTestCase {
    private var dir: URL!
    private var store: HistoryStore!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = HistoryStore(fileURL: dir.appendingPathComponent("history.json"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func fileExists(_ item: ClipItem) -> Bool {
        guard let url = store.imageURL(for: item) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func testAddImageWritesFile() throws {
        store.addImage(png: Data("png-1".utf8), width: 10, height: 20)
        let item = try XCTUnwrap(store.items.first)
        XCTAssertEqual(item.image?.width, 10)
        XCTAssertEqual(item.image?.height, 20)
        XCTAssertTrue(fileExists(item))
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(store.imageURL(for: item))), Data("png-1".utf8))
    }

    func testAddImageIgnoresEmptyData() {
        store.addImage(png: Data(), width: 1, height: 1)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testDuplicateImageMovesToFront() {
        store.addImage(png: Data("a".utf8), width: 1, height: 1)
        store.add("text")
        store.addImage(png: Data("a".utf8), width: 1, height: 1)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertNotNil(store.items[0].image)
        XCTAssertTrue(fileExists(store.items[0]))
    }

    func testTextAndImageDoNotDeduplicateEachOther() {
        store.add("x")
        store.addImage(png: Data("x".utf8), width: 1, height: 1)
        store.add("x")
        XCTAssertEqual(store.items.count, 2)
    }

    func testRemoveDeletesImageFile() throws {
        store.addImage(png: Data("a".utf8), width: 1, height: 1)
        let item = store.items[0]
        let url = try XCTUnwrap(store.imageURL(for: item))
        store.remove(id: item.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testClearDeletesImageFiles() throws {
        store.addImage(png: Data("a".utf8), width: 1, height: 1)
        let url = try XCTUnwrap(store.imageURL(for: store.items[0]))
        store.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testLimitDeletesDroppedImageFile() throws {
        let small = HistoryStore(fileURL: dir.appendingPathComponent("small.json"), limit: 1)
        small.addImage(png: Data("a".utf8), width: 1, height: 1)
        let url = try XCTUnwrap(small.imageURL(for: small.items[0]))
        small.add("b")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testImagesPersistAcrossInstances() {
        store.addImage(png: Data("a".utf8), width: 3, height: 4)
        let reloaded = HistoryStore(fileURL: dir.appendingPathComponent("history.json"))
        XCTAssertEqual(reloaded.items.first?.image, store.items.first?.image)
    }

    func testLoadDropsItemsWithMissingImageAndDeletesOrphans() throws {
        store.addImage(png: Data("a".utf8), width: 1, height: 1)
        store.add("keep")
        try FileManager.default.removeItem(at: XCTUnwrap(store.imageURL(for: store.items[1])))
        let orphan = store.imageDirectory.appendingPathComponent("orphan.png")
        try Data("o".utf8).write(to: orphan)

        let reloaded = HistoryStore(fileURL: dir.appendingPathComponent("history.json"))
        XCTAssertEqual(reloaded.items.map(\.text), ["keep"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }

    func testSearchMatchesImagesByKeyword() {
        store.add("hello")
        store.addImage(png: Data("a".utf8), width: 1, height: 1)
        XCTAssertEqual(store.search("hello").map(\.text), ["hello"])
        XCTAssertEqual(store.search("图片").count, 1)
        XCTAssertEqual(store.search("Image").count, 1)
    }

    func testDecodesLegacyTextOnlyHistory() throws {
        let url = dir.appendingPathComponent("legacy.json")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let legacy = #"[{"id":"\#(UUID().uuidString)","text":"old","date":0}]"#
        try Data(legacy.utf8).write(to: url)
        let loaded = HistoryStore(fileURL: url)
        XCTAssertEqual(loaded.items.map(\.text), ["old"])
        XCTAssertNil(loaded.items[0].image)
    }
}
