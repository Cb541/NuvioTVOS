import Foundation

/// Phone editor for every colour used by the custom theme.
enum CustomThemePage {
    static func html(
        accentHex: String,
        pressedHex: String,
        focusRingHex: String,
        focusBackgroundHex: String,
        cardBackgroundHex: String
    ) -> String {
        func clean(_ raw: String, fallback: String) -> String {
            CustomThemePalette.components(fromHex: raw).map(CustomThemePalette.hex) ?? fallback
        }

        let accent = clean(accentHex, fallback: CustomThemePalette.defaultHex)
        let pressed = clean(
            pressedHex,
            fallback: CustomThemePalette.derivedPressedHex(from: accent)
        )
        let focusRing = clean(
            focusRingHex,
            fallback: CustomThemePalette.derivedFocusRingHex(from: accent)
        )
        let focusBackground = clean(
            focusBackgroundHex,
            fallback: CustomThemePalette.derivedFocusBackgroundHex(from: accent)
        )
        let cardBackground = clean(
            cardBackgroundHex,
            fallback: CustomThemePalette.derivedCardBackgroundHex(from: accent)
        )

        func picker(_ id: String, _ title: String, _ value: String, _ hint: String) -> String {
            """
            <section class="colour">
              <label for="\(id)-picker">\(title)</label>
              <p class="hint">\(hint)</p>
              <div class="pick">
                <input type="color" id="\(id)-picker" value="#\(value)"
                       oninput="syncPicker('\(id)')">
                <input type="text" id="\(id)" name="\(id)" value="\(value)"
                       spellcheck="false" autocapitalize="characters" autocorrect="off"
                       inputmode="latin" maxlength="7"
                       oninput="syncText('\(id)')">
              </div>
            </section>
            """
        }

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Nuvio — custom theme</title>
        <style>
          :root { color-scheme: dark; }
          * { box-sizing: border-box; }
          body {
            margin: 0; padding: 24px 18px 64px;
            background: #101014; color: #ececf1;
            font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
          }
          .wrap { max-width: 720px; margin: 0 auto; }
          h1 { font-size: 24px; margin: 0 0 4px; letter-spacing: -.01em; }
          p.lede { margin: 0 0 28px; color: #9a9aa8; font-size: 15px; }
          .colour {
            border-bottom: 1px solid #24242e;
            padding: 0 0 22px;
            margin: 0 0 22px;
          }
          label { display: block; font-weight: 650; margin: 0 0 4px; font-size: 16px; }
          .hint { color: #9a9aa8; font-size: 13px; margin: 0 0 10px; }
          .pick { display: flex; gap: 14px; align-items: center; }
          input[type=color] {
            appearance: none; -webkit-appearance: none; border: 0; padding: 0;
            width: 76px; height: 76px; border-radius: 14px; background: none; cursor: pointer;
          }
          input[type=color]::-webkit-color-swatch-wrapper { padding: 0; }
          input[type=color]::-webkit-color-swatch {
            border: 1px solid #2c2c38; border-radius: 14px;
          }
          input[type=text] {
            flex: 1; background: #191920; color: #ececf1;
            border: 1px solid #2c2c38; border-radius: 10px; padding: 14px 12px;
            font: 16px/1.2 ui-monospace, SFMono-Regular, Menlo, monospace;
            text-transform: uppercase; -webkit-appearance: none;
          }
          input:focus {
            outline: 2px solid #4fc9dd; outline-offset: 1px; border-color: transparent;
          }
          .row { display: flex; gap: 10px; flex-wrap: wrap; margin-top: 10px; }
          button {
            flex: 1 1 180px; padding: 14px 18px; border-radius: 10px; border: 0;
            font: 600 16px/1 -apple-system, system-ui, sans-serif; cursor: pointer;
          }
          button.apply { background: #343440; color: #ececf1; margin-bottom: 18px; width: 100%; }
          button.save { background: #4fc9dd; color: #06222a; }
          button.reset { background: #24242e; color: #ececf1; }
          .note {
            margin-top: 30px; border-top: 1px solid #24242e; padding-top: 18px;
            color: #9a9aa8; font-size: 14px;
          }
        </style>
        <script>
          function normalise(value) {
            return value.replace('#', '').toUpperCase();
          }

          function syncPicker(id) {
            const picker = document.getElementById(id + '-picker');
            document.getElementById(id).value =
              picker.value.slice(1).toUpperCase();
          }

          function syncText(id) {
            const field = document.getElementById(id);
            const value = normalise(field.value);
            if (/^[0-9A-F]{6}$/.test(value)) {
              document.getElementById(id + '-picker').value = '#' + value;
            }
          }

          function applyAccentToAll() {
            const accent = normalise(document.getElementById('accent').value);
            if (!/^[0-9A-F]{6}$/.test(accent)) return;

            ['pressed', 'focusRing', 'focusBackground', 'cardBackground'].forEach(function(id) {
              document.getElementById(id).value = accent;
              document.getElementById(id + '-picker').value = '#' + accent;
            });
          }
        </script>
        </head>
        <body>
        <div class="wrap">
          <h1>Custom theme</h1>
          <p class="lede">
            Set each part of the Nuvio theme independently, or choose one accent and apply it everywhere.
          </p>

          <form method="post">
            \(picker("accent", "Accent", accent,
                "Buttons, highlights and the main identity of the theme."))

            <button class="apply" type="button" onclick="applyAccentToAll()">
              Apply Accent to All
            </button>

            \(picker("pressed", "Pressed", pressed,
                "The colour used for the pressed or secondary button state."))

            \(picker("focusRing", "Focus Ring", focusRing,
                "The outline that shows which item currently has Apple TV focus."))

            \(picker("focusBackground", "Focused Background", focusBackground,
                "The surface behind focused controls and focused content."))

            \(picker("cardBackground", "Card Background", cardBackground,
                "The normal background colour used by theme-aware cards."))

            <div class="row">
              <button class="save" type="submit" name="action" value="save">
                Save Theme
              </button>
              <button class="reset" type="submit" name="action" value="reset">
                Restore Automatic Defaults
              </button>
            </div>
          </form>

          <p class="note">
            Apply Accent to All only copies the accent into the other fields. You can still change
            any of them individually before saving. Restore Automatic Defaults keeps your accent
            and returns the other four colours to Nuvio's automatically derived values.
          </p>
        </div>
        </body>
        </html>
        """
    }
}
