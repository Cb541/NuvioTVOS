import SwiftUI

/// Sets the custom theme's accent from a phone, and shows what it produces on the television.
///
/// Fifth page on `LocalConfigServer`, and the reason it is a page rather than a picker is the one
/// upstream's colour picker runs into: choosing a hue with a D-pad is slow and imprecise, which is
/// why most people never touch such a control. A hex field on a phone — with the browser's own
/// colour picker beside it — is the same choice made in two seconds.
///
/// The preview is the point of doing it here rather than only there. A palette derived from one
/// colour has to be *looked at* on the screen it will be used on: an accent that reads well on a
/// phone can be unreadable as focus on a television across a room.
struct CustomThemeView: View {
    @Environment(\.nuvioColors) private var colors
    @Environment(AppSettings.self) private var settings

    @State private var server = LocalConfigServer()

    private var accentHex: String { settings.app.customThemeAccentHex }

    private var pressedHex: String {
        resolved(
            settings.app.customThemePressedHex,
            fallback: CustomThemePalette.derivedPressedHex(from: accentHex)
        )
    }

    private var focusRingHex: String {
        resolved(
            settings.app.customThemeFocusRingHex,
            fallback: CustomThemePalette.derivedFocusRingHex(from: accentHex)
        )
    }

    private var focusBackgroundHex: String {
        resolved(
            settings.app.customThemeFocusBackgroundHex,
            fallback: CustomThemePalette.derivedFocusBackgroundHex(from: accentHex)
        )
    }

    private var cardBackgroundHex: String {
        resolved(
            settings.app.customThemeCardBackgroundHex,
            fallback: CustomThemePalette.derivedCardBackgroundHex(from: accentHex)
        )
    }

    private var palette: ThemeColorPalette {
        CustomThemePalette.palette(
            accentHex: accentHex,
            pressedHex: settings.app.customThemePressedHex,
            focusRingHex: settings.app.customThemeFocusRingHex,
            focusBackgroundHex: settings.app.customThemeFocusBackgroundHex,
            cardBackgroundHex: settings.app.customThemeCardBackgroundHex
        )
    }

    private func resolved(_ raw: String, fallback: String) -> String {
        CustomThemePalette.components(fromHex: raw).map(CustomThemePalette.hex) ?? fallback
    }

    var body: some View {
        NuvioScreenBackground {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvioTheme.components.settings.rowGap) {
                    Text(L10n.text("settings.appearance.custom_theme", fallback: "Custom"))
                        .nuvioText(NuvioTextStyles.display)
                        .foregroundStyle(colors.textPrimary)

                    editorCard
                    previewCard
                }
                .padding(.bottom, NuvioTheme.spacing.xxxl)
            }
            .scrollClipDisabled()
        }
        .task { start() }
        .onDisappear { server.stop() }
    }

    private var editorCard: some View {
        SettingsCard(title: L10n.text("settings.appearance.set_on_phone", fallback: "Set from a phone")) {
            VStack(alignment: .leading, spacing: NuvioTheme.spacing.lg) {
                Text(L10n.text(
                    "settings.appearance.custom_instructions",
                    fallback: """
                    This Apple TV is serving a page on your network. Scan the code with a phone on \
                    the same Wi-Fi and pick a colour there. The rest of the palette follows from \
                    it, the way each built-in theme's does.
                    """
                ))
                .nuvioText(NuvioTextStyles.bodyCompact)
                .foregroundStyle(colors.textSecondary)
                .frame(maxWidth: dp(620), alignment: .leading)

                if let failure = server.failure {
                    Text(failure)
                        .nuvioText(NuvioTextStyles.bodyCompact)
                        .foregroundStyle(colors.error)
                } else if let address = server.address {
                    HStack(alignment: .top, spacing: NuvioTheme.spacing.xl) {
                        qrCode(address)
                        VStack(alignment: .leading, spacing: NuvioTheme.spacing.xs) {
                            Text(L10n.text("settings.poster.or_type", fallback: "Or type this in a browser"))
                                .nuvioText(NuvioTextStyles.metadata)
                                .foregroundStyle(colors.textTertiary)
                            Text(address)
                                .nuvioText(NuvioTextStyles.cardTitle)
                                .foregroundStyle(colors.textPrimary)
                                .monospacedDigit()
                        }
                    }
                } else {
                    Text(L10n.text("settings.poster.starting", fallback: "Starting…"))
                        .nuvioText(NuvioTextStyles.bodyCompact)
                        .foregroundStyle(colors.textTertiary)
                }
            }
            .padding(NuvioTheme.spacing.lg)
        }
    }

    /// The derived palette, at the size and distance it will actually be seen from.
    private var previewCard: some View {
        SettingsCard(
            title: L10n.text("settings.appearance.custom_preview", fallback: "Preview"),
            footnote: L10n.text(
                "settings.appearance.custom_preview_footnote",
                fallback: "The focus ring is the one to judge — it is what tells you where you are."
            )
        ) {
            VStack(alignment: .leading, spacing: NuvioTheme.spacing.lg) {
                VStack(alignment: .leading, spacing: NuvioTheme.spacing.xxs) {
                    Text("Accent  #\(accentHex)")
                    Text("Pressed  #\(pressedHex)")
                    Text("Focus Ring  #\(focusRingHex)")
                    Text("Focused Background  #\(focusBackgroundHex)")
                    Text("Card Background  #\(cardBackgroundHex)")
                }
                .nuvioText(NuvioTextStyles.metadata)
                .foregroundStyle(colors.textSecondary)

                HStack(spacing: NuvioTheme.spacing.md) {
                    swatch(palette.secondary, L10n.text("settings.appearance.swatch_accent", fallback: "Accent"))
                    swatch(palette.secondaryVariant, L10n.text("settings.appearance.swatch_pressed", fallback: "Pressed"))
                    swatch(palette.focusRing, L10n.text("settings.appearance.swatch_focus", fallback: "Focus Ring"))
                    swatch(palette.focusBackground, "Focused BG")
                    swatch(palette.backgroundCard, L10n.text("settings.appearance.swatch_card", fallback: "Card"))
                }

                // A real card in the real palette, because four squares do not answer the
                // question the viewer is actually asking.
                HStack(spacing: NuvioTheme.spacing.md) {
                    RoundedRectangle(cornerRadius: NuvioTheme.radii.md, style: .continuous)
                        .fill(palette.backgroundCard)
                        .frame(width: dp(220), height: dp(96))
                        .overlay {
                            RoundedRectangle(cornerRadius: NuvioTheme.radii.md, style: .continuous)
                                .strokeBorder(palette.focusRing, lineWidth: NuvioTheme.strokes.medium)
                        }
                        .overlay {
                            Text(L10n.text("settings.appearance.swatch_focused", fallback: "Focused"))
                                .nuvioText(NuvioTextStyles.cardTitle)
                                .foregroundStyle(colors.textPrimary)
                        }

                    Text(L10n.text("detail.play", fallback: "Play"))
                        .nuvioText(NuvioTextStyles.button)
                        .foregroundStyle(palette.onSecondary)
                        .padding(.horizontal, NuvioTheme.spacing.xl)
                        .frame(height: NuvioTheme.components.buttonHeight)
                        .background {
                            Capsule().fill(palette.secondary)
                        }
                }
            }
            .padding(NuvioTheme.spacing.lg)
            .id(server.revision)
        }
    }

    private func swatch(_ colour: Color, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: NuvioTheme.spacing.xxs) {
            RoundedRectangle(cornerRadius: NuvioTheme.radii.sm, style: .continuous)
                .fill(colour)
                .frame(width: dp(92), height: dp(52))
            Text(label)
                .nuvioText(NuvioTextStyles.metadata)
                .foregroundStyle(colors.textTertiary)
        }
    }

    private func qrCode(_ address: String) -> some View {
        Group {
            if let image = QRCodeRenderer.image(for: address) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: dp(200), height: dp(200))
                    .padding(NuvioTheme.spacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: NuvioTheme.radii.md, style: .continuous)
                            .fill(.white)
                    }
            }
        }
    }

    private func start() {
        server.start(
            page: {
                CustomThemePage.html(
                    accentHex: settings.app.customThemeAccentHex,
                    pressedHex: settings.app.customThemePressedHex,
                    focusRingHex: settings.app.customThemeFocusRingHex,
                    focusBackgroundHex: settings.app.customThemeFocusBackgroundHex,
                    cardBackgroundHex: settings.app.customThemeCardBackgroundHex
                )
            },
            onSubmit: { fields in
                if fields["action"] == "reset" {
                    // Keep the viewer's chosen accent and return the other four slots to automatic
                    // derivation from it.
                    settings.app.customThemePressedHex = ""
                    settings.app.customThemeFocusRingHex = ""
                    settings.app.customThemeFocusBackgroundHex = ""
                    settings.app.customThemeCardBackgroundHex = ""
                    return
                }

                func parsed(_ key: String) -> String? {
                    guard let components = CustomThemePalette.components(
                        fromHex: fields[key] ?? ""
                    ) else { return nil }
                    return CustomThemePalette.hex(components)
                }

                // Save atomically: one malformed field leaves the previous complete theme intact.
                guard
                    let accent = parsed("accent"),
                    let pressed = parsed("pressed"),
                    let focusRing = parsed("focusRing"),
                    let focusBackground = parsed("focusBackground"),
                    let cardBackground = parsed("cardBackground")
                else { return }

                settings.app.customThemeAccentHex = accent
                settings.app.customThemePressedHex = pressed
                settings.app.customThemeFocusRingHex = focusRing
                settings.app.customThemeFocusBackgroundHex = focusBackground
                settings.app.customThemeCardBackgroundHex = cardBackground
            }
        )
    }
}
