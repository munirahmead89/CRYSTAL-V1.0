import Flutter
import UIKit
import Contacts

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let engine = engineBridge.engine as? FlutterEngine {
      DeviceInfoApiSetup.setUp(binaryMessenger: engine.binaryMessenger, api: DeviceInfoHandler())
      let contacts = FlutterMethodChannel(name: "crystal/contacts", binaryMessenger: engine.binaryMessenger)
      contacts.setMethodCallHandler { call, result in
        guard call.method == "readContacts" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
          guard granted, error == nil else {
            result(FlutterError(code: "permission_denied", message: "Contacts permission is required", details: nil))
            return
          }
          let keys: [CNKeyDescriptor] = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as NSString]
          var rows: [[String: String]] = []
          do {
            let request = CNFetchRequest< CNContact >(keysToFetch: keys)
            try store.enumerateContacts(with: request) { contact, _ in
              for phone in contact.phoneNumbers {
                rows.append(["displayName": CNContactFormatter.string(from: contact, style: .fullName) ?? "", "phone": phone.value.stringValue])
              }
            }
            result(rows)
          } catch {
            result(FlutterError(code: "read_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }
}

private class DeviceInfoHandler: DeviceInfoApi {
  func getSystemInfo(completion: @escaping (Result<SystemInfo, Error>) -> Void) {
    let device = UIDevice.current
    let bundle = Bundle.main.infoDictionary
    completion(
      .success(
        SystemInfo(
          fullName: device.name,
          platform: "ios",
          osVersion: device.systemVersion,
          appVersion: bundle?["CFBundleShortVersionString"] as? String ?? "",
          buildNumber: bundle?["CFBundleVersion"] as? String ?? ""
        )
      )
    )
  }
}
