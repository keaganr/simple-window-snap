import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Pressed while dragging a window to temporarily disable snapping for
    /// that one drag. Default is a quadruple-modifier combo rather than an
    /// F13+ key - most modern Mac keyboards don't have physical F13+ keys,
    /// so that "conventionally rare" choice isn't actually available to
    /// everyone out of the box.
    public static let toggleSnapSuppression = Self(
        "toggleSnapSuppression",
        default: .init(.d, modifiers: [.control, .option, .command])
    )
}
