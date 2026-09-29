//
//  FavoritesStore.swift
//  URRemit
//
//  Created by RIFAD on 27/09/2026.
//

import Foundation
import Foundation
import Observation

@Observable
@MainActor
final class FavoritesStore {
    static let shared = FavoritesStore()

    private let key = "favorite_rate_ids"
    private(set) var favoriteIDs: Set<UUID> = []

    private init() { load() }

    func isFavorite(_ id: UUID) -> Bool { favoriteIDs.contains(id) }

    func toggle(_ id: UUID) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        save()
    }

    func add(_ id: UUID) {
        guard !favoriteIDs.contains(id) else { return }
        favoriteIDs.insert(id)
        save()
    }

    func remove(_ id: UUID) {
        guard favoriteIDs.contains(id) else { return }
        favoriteIDs.remove(id)
        save()
    }

    func removeAll() {
        favoriteIDs.removeAll()
        save()
    }

    private func load() {
        guard let array = UserDefaults.standard.array(forKey: key) as? [String] else { return }
        favoriteIDs = Set(array.compactMap(UUID.init(uuidString:)))
    }

    private func save() {
        UserDefaults.standard.set(favoriteIDs.map(\.uuidString), forKey: key)
    }
}
