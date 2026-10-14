# TCGP Trading

Players of Pokemon TCG Pocket record which cards they want and which they can give away, find other players to trade with, and coordinate the trade before finishing it in-game.

## Language

### Collection

**Collection**:
Everything one user has declared about cards: their wishlist entries, their listings, and the trade conditions on those listings. A card is either a wishlist entry or a listing in a collection, never both.
_Avoid_: user cards, inventory

**Wishlist entry**:
A card the user wants to receive, in either any language or one or more specific languages.
_Avoid_: want, wanted card

**Listing**:
A card the user offers to trade away, in exactly one specific language.
_Avoid_: owned card, have, offer

**Trade condition**:
A card (in any language or specific languages) that the owner of a listing will accept in exchange for it. A listing with no trade conditions accepts any card the matching rules allow.
_Avoid_: accepted card, requirement

**Card language**:
The in-game language edition of a card. "Any language" is a wildcard that matches every specific language and is never combined with specific languages.
_Avoid_: locale, region

**Collection draft**:
A user's unsaved edits to their collection. It applies the collection rules as the user edits, correcting choices that would break one, and is saved as the desired state of each changed card in one atomic save.
_Avoid_: pending edits

**Preferred language**:
The specific card language a user lists cards in unless they choose another.
_Avoid_: default language, main language
