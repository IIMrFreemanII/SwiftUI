import CGLFW3
import CVulkan

class Application {
  let WIDTH: Int32 = 800
  let HEIGHT: Int32 = 600
  var window: OpaquePointer!
  var instance: VkInstance!
  var surface: VkSurfaceKHR!
  var validationLayers: [UnsafePointer<CChar>?] = [
    "VK_LAYER_KHRONOS_validation".cString
  ]
  var deviceExtensions: [UnsafePointer<CChar>?] = [
    VK_KHR_SWAPCHAIN_EXTENSION_NAME.cString
  ]
  var physicalDevice: VkPhysicalDevice!
  var device: VkDevice!
  var graphicsQueue: VkQueue!
  var presentQueue: VkQueue!

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
    createSurface()
    pickPhysicalDevice()
    createLogicalDevice()
  }

  func checkDeviceExtensionSupport(_ device: VkPhysicalDevice) -> Bool {
    var extensionCount = UInt32()
    vkEnumerateDeviceExtensionProperties(device, nil, &extensionCount, nil)
    var availableExtensions = Array(repeating: VkExtensionProperties(), count: Int(extensionCount))
    vkEnumerateDeviceExtensionProperties(device, nil, &extensionCount, &availableExtensions)

    let requiredExtensionNames = Set(self.deviceExtensions.map { $0!.string })
    let availableExtensionsNames = Set(
      availableExtensions.map {
        withUnsafePointer(to: $0.extensionName) {
          $0.withMemoryRebound(to: CChar.self, capacity: Int(VK_MAX_EXTENSION_NAME_SIZE)) {
            String(cString: $0)
          }
        }
      })

    return requiredExtensionNames.subtracting(availableExtensionsNames).isEmpty
  }

  func isDeviceSuitable(_ device: VkPhysicalDevice) -> Bool {
    // var deviceProperties = VkPhysicalDeviceProperties()
    // vkGetPhysicalDeviceProperties(device, &deviceProperties)

    // var deviceFeatures = VkPhysicalDeviceFeatures()
    // vkGetPhysicalDeviceFeatures(device, &deviceFeatures)

    let indices = findQueueFamilies(device)

    let extensionsSupported = checkDeviceExtensionSupport(device)

    return indices.isComplete && extensionsSupported
  }

  // temp
  // func rateDeviceSuitability(_ device: VkPhysicalDevice) -> Int {
  //   var deviceProperties = VkPhysicalDeviceProperties();
  //   vkGetPhysicalDeviceProperties(device, &deviceProperties)

  //   var deviceFeatures = VkPhysicalDeviceFeatures()
  //   vkGetPhysicalDeviceFeatures(device, &deviceFeatures)

  //   var score: Int = 0

  //   if deviceProperties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU {
  //     score += 1000
  //   }

  //   score += Int(deviceProperties.limits.maxImageDimension2D)

  //   return score
  // }

  struct QueueFamilyIndices {
    var graphicsFamily: UInt32?
    var presentFamily: UInt32?

    var isComplete: Bool {
      graphicsFamily != nil && graphicsFamily != nil
    }
  }

  func findQueueFamilies(_ device: VkPhysicalDevice) -> QueueFamilyIndices {
    var indices = QueueFamilyIndices()

    var queueFamilyCount: UInt32 = 0
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, nil)

    var queueFamilies = Array(repeating: VkQueueFamilyProperties(), count: Int(queueFamilyCount))
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, &queueFamilies)

    for (index, queueFamily) in queueFamilies.enumerated() {
      if (queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT.rawValue) != 0 {
        indices.graphicsFamily = UInt32(index)
      }

      var presentSupport = UInt32()
      vkGetPhysicalDeviceSurfaceSupportKHR(device, UInt32(index), self.surface, &presentSupport)
      if presentSupport != 0 {
        indices.presentFamily = UInt32(index)
      }

      if indices.isComplete {
        break
      }
    }

    return indices
  }

  func pickPhysicalDevice() {
    var deviceCount: UInt32 = 0
    vkEnumeratePhysicalDevices(instance, &deviceCount, nil)
    if deviceCount == 0 {
      fatalError("Failed to find GPUs with Vulkan support!")
    }

    var devices = Array(repeating: VkPhysicalDevice(bitPattern: 0), count: Int(deviceCount))
    vkEnumeratePhysicalDevices(instance, &deviceCount, &devices)
    var physicalDevice: VkPhysicalDevice?

    for device in devices {
      if isDeviceSuitable(device!) {
        physicalDevice = device
        break
      }
    }

    if physicalDevice == nil {
      fatalError("Failed to find a suitable GPU!")
    }

    self.physicalDevice = physicalDevice
    print("physicalDevice:", physicalDevice!)
  }

  func createLogicalDevice() {
    let indices = findQueueFamilies(self.physicalDevice!)

    var queueCreateInfos: [VkDeviceQueueCreateInfo] = []
    let uniqueQueueFamilies: Set<UInt32> = [indices.graphicsFamily!, indices.presentFamily!]
    let queuePriority = Float(1)

    for queueFamily in uniqueQueueFamilies {
      var queueCreateInfo = VkDeviceQueueCreateInfo()
      queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
      queueCreateInfo.queueFamilyIndex = queueFamily
      queueCreateInfo.queueCount = 1
      queueCreateInfo.pQueuePriorities = queuePriority.unsafePointer()

      queueCreateInfos.append(queueCreateInfo)
    }

    var deviceFeatures = VkPhysicalDeviceFeatures()

    var extensionCount = UInt32()
    vkEnumerateDeviceExtensionProperties(self.physicalDevice, nil, &extensionCount, nil)
    var deviceExtensions = Array(repeating: VkExtensionProperties(), count: Int(extensionCount))
    vkEnumerateDeviceExtensionProperties(
      self.physicalDevice, nil, &extensionCount, &deviceExtensions)
    var requiredDeviceExtensions: [UnsafePointer<CChar>?] = self.deviceExtensions

    print("Device extensions:", deviceExtensions.count)
    // Print the available extensions
    for i in 0..<Int(extensionCount) {
      let extensionName = withUnsafePointer(to: &deviceExtensions[i].extensionName) {
        $0.withMemoryRebound(to: CChar.self, capacity: Int(VK_MAX_EXTENSION_NAME_SIZE)) {
          String(cString: $0)
        }
      }
      // print("  \(i + 1): \(extensionName)")

      if extensionName == "VK_KHR_portability_subset" {
        requiredDeviceExtensions.append("VK_KHR_portability_subset".cString)
      }
    }

    print("Required device extensions: \(requiredDeviceExtensions.count)")
    for (index, elem) in requiredDeviceExtensions.enumerated() {
      print("  \(index + 1): \(elem!.string)")
    }

    var createInfo = VkDeviceCreateInfo()
    createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    createInfo.pQueueCreateInfos = queueCreateInfos.withUnsafeBufferPointer { $0 }.baseAddress
    createInfo.queueCreateInfoCount = UInt32(queueCreateInfos.count)

    createInfo.pEnabledFeatures = withUnsafePointer(to: &deviceFeatures) { $0 }
    createInfo.ppEnabledExtensionNames =
      requiredDeviceExtensions.withUnsafeBufferPointer { $0 }.baseAddress
    createInfo.enabledExtensionCount = UInt32(requiredDeviceExtensions.count)

    if self.enableValidationLayers {
      createInfo.enabledLayerCount = UInt32(self.validationLayers.count)
      createInfo.ppEnabledLayerNames =
        self.validationLayers.withUnsafeBufferPointer { $0 }.baseAddress
    } else {
      createInfo.enabledLayerCount = 0
    }

    if vkCreateDevice(self.physicalDevice, &createInfo, nil, &self.device) != VK_SUCCESS {
      fatalError("Failed to create logical device!")
    }

    vkGetDeviceQueue(device, indices.graphicsFamily!, 0, &self.graphicsQueue)
    vkGetDeviceQueue(device, indices.presentFamily!, 0, &self.presentQueue)
    print("Graphics queue: \(String(describing: self.graphicsQueue))")
    print("Present queue:  \(String(describing: self.presentQueue))")
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

        if item == layerName!.string {
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
      VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME.cString,
      "VK_KHR_get_physical_device_properties2".cString,
    ]

    for i in 0..<Int(glfwExtensionCount) {
      if let cString = glfwExtensions[i] {
        requiredExtensions.append(cString)
        print("  \(i + 1): " + cString.string)
      }
    }

    print("Required instance extensions:")
    for (i, cString) in requiredExtensions.enumerated() {
      if let cString = cString {
        print("  \(i + 1):\(cString.string)")
      }
    }

    var createInfo = VkInstanceCreateInfo()
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    createInfo.pApplicationInfo = withUnsafePointer(to: &appInfo) { $0 }
    createInfo.enabledExtensionCount = UInt32(requiredExtensions.count)

    createInfo.ppEnabledExtensionNames =
      requiredExtensions.withUnsafeBufferPointer { $0 }.baseAddress
    createInfo.flags |= VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR.rawValue
    if self.enableValidationLayers {
      createInfo.enabledLayerCount = UInt32(self.validationLayers.count)
      createInfo.ppEnabledLayerNames =
        self.validationLayers.withUnsafeBufferPointer { $0 }.baseAddress
    } else {
      createInfo.enabledLayerCount = 0
    }

    let result = vkCreateInstance(&createInfo, nil, &self.instance)
    if result != VK_SUCCESS {
      fatalError("Failed to create Vulkan instance: \(result)")
    }

    // Query the number of available instance extensions
    var extensionCount: UInt32 = 0
    vkEnumerateInstanceExtensionProperties(nil, &extensionCount, nil)

    print("Instance extension count: \(extensionCount)")

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

  func createSurface() {
    if glfwCreateWindowSurface(self.instance, self.window, nil, &self.surface) != VK_SUCCESS {
      fatalError("Failed to create window surface!")
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
    vkDestroyDevice(self.device, nil)
    vkDestroySurfaceKHR(self.instance, self.surface, nil)
    vkDestroyInstance(self.instance, nil)
    glfwDestroyWindow(self.window)

    glfwTerminate()
  }
}
