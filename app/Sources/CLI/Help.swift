import DASCore

enum Help {
    static func text(_ style: Style) -> String {
        let b = style.bold
        let d = style.dim
        return """
            \(b("das")) — \(AppMetadata.description)

            \(b("Usage"))
              das            \(d("Default App Switcher"))
              das --help     \(d("Help"))
              das --version  \(d("Version"))
            """
    }
}
