import DASCore

enum Help {
    static func text(_ style: Style) -> String {
        return """

            \(style.bold("das")) — \(AppMetadata.description)

            Usage:
              das            Switch default applications
              das --help     Show help
              das --version  Show version

            """
    }
}
