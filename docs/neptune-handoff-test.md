# Neptune external-player probe (Nuvio tvOS 1.0.37)

This is an **experimental launcher probe**, not verified Neptune playback support.

## What the Nuvio fork does
- Includes `Neptune (Experimental)` in Settings > Playback > External player and in the Play with chooser.
- Creates a URL of the form `neptune://play?url=<percent-encoded-stream>&title=<percent-encoded-title>`.
- Tests both `neptune://` and `neptuneplayer://` as **hypothetical**, undocumented scheme names.
- Keeps the chooser open and shows a diagnostic if tvOS reports that neither scheme is handled.
- Does **not** forward subtitles, custom request headers, resume position, or progress callbacks.

## How to test
1. Install Neptune from the tvOS App Store.
2. Install this branch's unsigned Nuvio IPA (sign it with your usual sideloading method).
3. In Nuvio, enable `Settings > Playback > External player > Ask each time`, or select `Neptune (Experimental)`.
4. Choose a legal, simple HTTP(S) video stream and select `Neptune (Experimental)` in the Play with chooser.
5. Record the outcome:
   - **Nuvio displays a launch failure message**: Neither guessed scheme is registered; a published handler or Neptune modification would be needed.
   - **Neptune opens, but playback does not start**: A scheme exists, but it may not accept this handoff path/argument.
   - **Neptune starts playback**: The corresponding test path works for that stream; next test debrid URLs, Dolby Vision, and seeking.
6. Keep Nuvio's built-in player as a fallback.

## Important
Apple TV does not let Nuvio invoke Trident directly. The Neptune app must register and handle a supported handoff. Registration cannot be added from Nuvio, and `canOpenURL` does not validate the destination's interpretation of a query string.
