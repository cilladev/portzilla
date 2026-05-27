import Foundation

struct PortInfo: Identifiable, Hashable {
    let id: String
    let port: Int
    let pid: Int32
    let processName: String
    let command: String
    let user: String
    let isOwnedByCurrentUser: Bool
}
