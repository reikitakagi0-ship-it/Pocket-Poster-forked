class DownloadableWallpaper: Identifiable, Codable {
    var name: String
    var description: String?
    var url: String
    var preview: String
    var authors: String?
    var type: WallpaperType?

    init(name: String, description: String?, authors: String?, preview: String, url: String) {
        self.name = name
        self.description = description
        self.authors = authors
        self.preview = preview
        self.url = url
    }
    
    enum WallpaperType: String, Codable {
        case custom, apple, template
    }
    
    func previewIsGif() -> Bool {
        return preview.lowercased().hasSuffix(".gif")
    }
}
