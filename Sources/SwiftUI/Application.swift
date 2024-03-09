import CGLFW3
import CVulkan

class Application {
  let WIDTH: Int32 = 800
  let HEIGHT: Int32 = 600
  var window: OpaquePointer?
  var instance: VkInstance?
  var validationLayers = [
    "VK_LAYER_KHRONOS_validation".cString
  ]

  #if DEBUG
    var enableValidationLayers = true
  #else
    var enableValidationLayers = false
  #endif

  func run() {
    initWindow()
    initVulkan()
    mainLoop()
    cleanup()
  }

  func initVulkan() {
    createInstance()
  }

  func checkValidationLayerSupport() -> Bool {
    var layerCount: UInt32 = 0
    vkEnumerateInstanceLayerProperties(&layerCount, nil)
    var availableLayers = Array(repeating: VkLayerProperties(), count: Int(layerCount))
    vkEnumerateInstanceLayerProperties(&layerCount, &availableLayers)

    for layerName in self.validationLayers {
      var layerFound = false

      for var layerProperties in availableLayers {
        let item = withUnsafePointer(to: &layerProperties.layerName) {
          $0.withMemoryRebound(to: CChar.self, capacity: Int(VK_MAX_EXTENSION_NAME_SIZE)) {
            String(cString: $0)
          }
        }

        if item == layerName.string {
          layerFound = true
          break
        }
      }

      if !layerFound {
        return false
      }
    }

    return true
  }

  func createInstance() {
    if self.enableValidationLayers && !checkValidationLayerSupport() {
      fatalError("Validation layers requested, but not available!")
    }

    var appInfo = VkApplicationInfo()
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
    appInfo.pApplicationName = "Hello Vulkan".cString
    appInfo.applicationVersion = vkMakeVersion(1, 0, 0)
    appInfo.pEngineName = "No Engine".cString
    appInfo.engineVersion = vkMakeVersion(1, 0, 0)
    appInfo.apiVersion = vkMakeApiVersion(0, 1, 0, 0)

    var glfwExtensionCount: UInt32 = 0
    glfwGetRequiredInstanceExtensions(&glfwExtensionCount)
    print("glfwExtensionCount: \(glfwExtensionCount)")

    let glfwExtensions = glfwGetRequiredInstanceExtensions(&glfwExtensionCount)!
    var requiredExtensions: [UnsafePointer<CChar>?] = [
      VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME.cString
    ]

    for i in 0..<Int(glfwExtensionCount) {
      if let cString = glfwExtensions[i] {
        requiredExtensions.append(cString)
        print("  \(i + 1): " + cString.string)
      }
    }

    print("Required extensions:")
    for (i, cString) in requiredExtensions.enumerated() {
      if let cString = cString {
        print("  \(i + 1):\(cString.string)")
      }
    }

    var createInfo = VkInstanceCreateInfo()
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    createInfo.pApplicationInfo = withUnsafePointer(to: &appInfo) { $0 }
    createInfo.enabledExtensionCount = UInt32(requiredExtensions.count)
    createInfo.enabledLayerCount = 0
    createInfo.ppEnabledExtensionNames =
      requiredExtensions.withUnsafeBufferPointer { $0 }.baseAddress
    createInfo.flags |= VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR.rawValue

    let result = vkCreateInstance(&createInfo, nil, &self.instance)
    if result != VK_SUCCESS {
      fatalError("Failed to create Vulkan instance: \(result)")
    }

    // Query the number of available instance extensions
    var extensionCount: UInt32 = 0
    vkEnumerateInstanceExtensionProperties(nil, &extensionCount, nil)

    print("Extension count: \(extensionCount)")

    var extensions = Array(repeating: VkExtensionProperties(), count: Int(extensionCount))
    vkEnumerateInstanceExtensionProperties(nil, &extensionCount, &extensions)

    // Print the available extensions
    for i in 0..<Int(extensionCount) {
      let extensionName = withUnsafePointer(to: &extensions[i].extensionName) {
        $0.withMemoryRebound(to: CChar.self, capacity: Int(VK_MAX_EXTENSION_NAME_SIZE)) {
          String(cString: $0)
        }
      }
      print("  \(i + 1): \(extensionName)")
    }
  }

  func initWindow() {
    glfwInit()

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API)
    glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE)

    window = glfwCreateWindow(WIDTH, HEIGHT, "Vulkan", nil, nil)
  }

  func mainLoop() {
    while glfwWindowShouldClose(window) == GLFW_FALSE {
      glfwPollEvents()
    }
  }

  func cleanup() {
    vkDestroyInstance(self.instance, nil)
    glfwDestroyWindow(self.window)

    glfwTerminate()
  }
}
