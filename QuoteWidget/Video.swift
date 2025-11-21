import Foundation

struct Video: Codable, Identifiable {
    let id: String
    let name: String
    let link: String

    /// Extracts the YouTube video ID from various URL formats
    var videoID: String {
        // Handle shorts URL format: youtube.com/shorts/VIDEO_ID
        if link.contains("shorts/") {
            return link.components(separatedBy: "shorts/").last?.components(separatedBy: "?").first ?? ""
        }
        // Handle standard watch URL: youtube.com/watch?v=VIDEO_ID
        else if link.contains("watch?v=") {
            return link.components(separatedBy: "watch?v=").last?.components(separatedBy: "&").first ?? ""
        }
        // Handle short URL: youtu.be/VIDEO_ID
        else if link.contains("youtu.be/") {
            return link.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first ?? ""
        }
        // Handle embed URL: youtube.com/embed/VIDEO_ID
        else if link.contains("embed/") {
            return link.components(separatedBy: "embed/").last?.components(separatedBy: "?").first ?? ""
        }
        return link
    }
}
