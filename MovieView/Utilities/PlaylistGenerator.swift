import Foundation

enum PlaylistGenerator {
    static func createM3U8(from urls: [URL], at location: URL) throws -> URL {
        let playlistContent = """
        #EXTM3U
        
        """ + urls.map { url in
            """
            #EXTINF:-1,\(url.lastPathComponent)
            \(url.path)
            """
        }.joined(separator: "\n\n")
        
        let playlistURL = location.appendingPathComponent("playlist.m3u8")
        try playlistContent.write(to: playlistURL, atomically: true, encoding: .utf8)
        return playlistURL
    }
} 