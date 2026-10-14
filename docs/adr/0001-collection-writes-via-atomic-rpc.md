# Collection writes go through one atomic, validating RPC

All changes to a user's collection (wishlist entries, listings, trade conditions) are saved with a single RPC that receives the desired state of each changed card, validates the collection rules, and replaces that card's stored rows in one transaction. The client never writes `user_cards` or `trade_conditions` rows directly. Saving per row let a language change on a listing silently delete its trade conditions and left half-applied edit sessions that failed on every retry, and the rules (a card is a wishlist entry or a listing, never both; a listing has exactly one specific language; trade conditions are the same rarity as their listing) were only enforced by widgets. The Dart collection draft still applies the same rules for immediate feedback; the RPC is the backstop that trade matching in SQL relies on.

## Considered Options

- **Per-row writes behind one client commit method**: rejected because partial failures stay possible and the rules remain unenforced on the server.
- **A list of add/remove operations sent to the RPC**: rejected in favour of the desired state per card, which is idempotent, safe to retry, and makes "change the language but keep the listing" impossible to express wrongly.
