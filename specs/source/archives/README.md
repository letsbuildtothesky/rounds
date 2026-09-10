# Private original archive

The original `Rounds-Complete-Project-v2.3.zip` is retained on the development computer and deliberately excluded from Git because it contains an account-specific map token. Its required SHA-256 is `d4eb74b39335d5a97bea9300da4f65612773220ffdadff6465a954b9efedc39e`. Do not upload it or the local original-checkpoint branch to a public repository.

The complete working spec/design tree is published in the sibling `Rounds-Complete-Project-v2.3` folder. Eight HTML references replace only the reviewed map-token string with `MAPBOX_PUBLIC_TOKEN_REQUIRED`; layouts, copy, styles, assets and interaction code are otherwise preserved. Application maps continue to use their separately configured runtime credentials.

Original-provenance checks require obtaining that original ZIP privately from the project owner and placing it in this folder under its original filename. A public clone without the ZIP cannot claim original-archive verification; the guards report it missing rather than silently passing. Building the applications does not require uploading or publishing the original archive.
