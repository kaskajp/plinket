/// Fetched details by ID. A refresh marks them stale: they stay visible but the next request refetches them.
struct DetailCache<Detail: Identifiable & Sendable>: Sendable where Detail.ID: Sendable {
    private var details: [Detail.ID: Detail] = [:]
    private var freshIDs: Set<Detail.ID> = []

    subscript(id: Detail.ID) -> Detail? { details[id] }

    func freshDetail(id: Detail.ID) -> Detail? {
        freshIDs.contains(id) ? details[id] : nil
    }

    mutating func insert(_ detail: Detail) {
        details[detail.id] = detail
        freshIDs.insert(detail.id)
    }

    mutating func markAllStale() {
        freshIDs.removeAll()
    }

    mutating func updateAll(_ transform: (Detail) -> Detail) {
        details = details.mapValues(transform)
    }
}
