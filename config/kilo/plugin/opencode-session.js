// Add the stable conversation identifier required by OpenCode Go.

const sessionIds = new Map()

const sessionUuid = async (sessionID) => {
  const cached = sessionIds.get(sessionID)
  if (cached) return cached

  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`kilo-opencode-session:${sessionID}`),
  )
  const bytes = new Uint8Array(digest).slice(0, 16)
  bytes[6] = (bytes[6] & 0x0f) | 0x50
  bytes[8] = (bytes[8] & 0x3f) | 0x80

  const hex = [...bytes].map((byte) => byte.toString(16).padStart(2, "0"))
  const uuid = [
    hex.slice(0, 4).join(""),
    hex.slice(4, 6).join(""),
    hex.slice(6, 8).join(""),
    hex.slice(8, 10).join(""),
    hex.slice(10, 16).join(""),
  ].join("-")

  sessionIds.set(sessionID, uuid)
  return uuid
}

const plugin = async () => ({
  "chat.headers": async ({ sessionID, provider }, output) => {
    if (provider.info.id !== "opencode-go") return

    output.headers["x-opencode-session"] = await sessionUuid(sessionID)
  },
})

export default plugin
export const server = plugin
