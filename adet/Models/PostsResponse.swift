struct PostsResponse: Codable {
    let posts: [Post]
    let count: Int
    let hasMore: Bool
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case posts
        case count
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}