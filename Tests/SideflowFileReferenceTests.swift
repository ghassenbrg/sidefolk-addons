import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

@Suite struct SideflowFileReferenceTests {
    @Test func aValueNamesTheFilesItsFieldsSayItMade() {
        let value: JSON = .object(["path": .string("/Users/x/out.pdf"), "files": .array([.string("~/a.txt"), .string("not a place")]), "text": .string("/etc/passwd"), "nested": .object(["output": .string("/tmp/b.png")])])
        let found = Set(Pages.files(in: value))
        #expect(found == ["/Users/x/out.pdf", "~/a.txt", "/tmp/b.png"], "only fields that say where a file is: \(found)")
        #expect(Pages.files(in: .string("/a/b")).isEmpty, "words alone aren't a file's place")
    }
}
