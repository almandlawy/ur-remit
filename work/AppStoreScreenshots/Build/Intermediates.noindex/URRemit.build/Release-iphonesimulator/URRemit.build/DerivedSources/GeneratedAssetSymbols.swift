import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "LaunchBackground" asset catalog color resource.
    static let launchBackground = DeveloperToolsSupport.ColorResource(name: "LaunchBackground", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "DollarStack" asset catalog image resource.
    static let dollarStack = DeveloperToolsSupport.ImageResource(name: "DollarStack", bundle: resourceBundle)

    /// The "DubaiSkyline" asset catalog image resource.
    static let dubaiSkyline = DeveloperToolsSupport.ImageResource(name: "DubaiSkyline", bundle: resourceBundle)

    /// The "EuroStack" asset catalog image resource.
    static let euroStack = DeveloperToolsSupport.ImageResource(name: "EuroStack", bundle: resourceBundle)

    /// The "PoundStack" asset catalog image resource.
    static let poundStack = DeveloperToolsSupport.ImageResource(name: "PoundStack", bundle: resourceBundle)

}

