//
//  CowabungaAPI.swift
//  Pocket Poster
//
//  Created by lemin on 7/15/25.
//  Updated for parallel async fetching
//

import UIKit

enum FilterType: String, CaseIterable {
    case random = "Random"
    case newest = "Newest"
    case oldest = "Oldest"
}

enum APIError: Error {
    case connectionFailed
    case repoHashError
}

class CowabungaAPI: ObservableObject {
    
    static let shared = CowabungaAPI()
    
    private(set) var serverURL = ""
    private var session = URLSession.shared
    
    // MARK: - Fetch Wallpapers for a single type
    func fetchWallpapers(type: DownloadableWallpaper.WallpaperType) async throws -> [DownloadableWallpaper] {
        if serverURL.isEmpty {
            let hash = try await getCommitHash()
            serverURL = "https://raw.githubusercontent.com/SerStars/nugget-wallpapers/\(hash)/"
        }
        
        let request = URLRequest(url: URL(string: serverURL + "wallpapers-\(type.rawValue).json")!)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.connectionFailed
        }
        
        var wallpapers = try JSONDecoder().decode([DownloadableWallpaper].self, from: data)
        for i in wallpapers.indices { wallpapers[i].type = type }
        return wallpapers
    }
    
    // MARK: - Fetch Wallpapers for multiple types in parallel
    func fetchWallpapers(types: [DownloadableWallpaper.WallpaperType]) async throws -> [DownloadableWallpaper] {
        // 並列取得
        async let results: [[DownloadableWallpaper]] = {
            try await withThrowingTaskGroup(of: [DownloadableWallpaper].self) { group in
                for type in types {
                    group.addTask {
                        return try await self.fetchWallpapers(type: type)
                    }
                }
                
                var combined: [DownloadableWallpaper] = []
                for try await wallpapers in group {
                    combined.append(contentsOf: wallpapers)
                }
                return combined
            }
        }()
        
        return try await results
    }
    
    // MARK: - Filter Wallpapers
    func filterWallpapers(wallpapers: [DownloadableWallpaper], filterType: FilterType) -> [DownloadableWallpaper] {
        switch filterType {
        case .newest:
            return wallpapers.reversed()
        case .random:
            return wallpapers.shuffled()
        case .oldest:
            return wallpapers
        }
    }
    
    // MARK: - Get Commit Hash
    func getCommitHash() async throws -> String {
        let request = URLRequest(url: URL(string: "https://api.github.com/repos/SerStars/nugget-wallpapers/commits/main")!)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.connectionFailed
        }
        
        guard let repoinfo = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hash = repoinfo["sha"] as? String else {
            throw APIError.repoHashError
        }
        return hash
    }
    
    // MARK: - URLs
    func getDownloadURLForWallpaper(wallpaper: DownloadableWallpaper) -> URL {
        return wallpaper.url.hasPrefix("https://")
            ? URL(string: wallpaper.url)!
            : URL(string: serverURL + wallpaper.url)!
    }
    
    func getPreviewURLForWallpaper(wallpaper: DownloadableWallpaper) -> URL {
        return URL(string: serverURL + wallpaper.preview)!
    }
    
    // MARK: - Initializer
    private init() {}
}
