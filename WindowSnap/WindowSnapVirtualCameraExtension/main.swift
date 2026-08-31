import CoreMediaIO

let providerSource = WindowSnapVirtualCameraProviderSource()
let provider = CMIOExtensionProvider(source: providerSource, clientQueue: nil)
providerSource.provider = provider
CMIOExtensionProvider.startService(provider: provider)
