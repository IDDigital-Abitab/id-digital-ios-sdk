struct ValidationSession: Codable, Sendable {
  let id: String
  let status: String
  let challenges: [Challenge]
}
