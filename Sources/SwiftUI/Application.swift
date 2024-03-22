import CGLFW3
import CVulkan
import Foundation
import SwiftGLM

struct UniformBufferObject {
  var model = mat4()
  var view = mat4()
  var proj = mat4()
}

struct Vertex {
  var pos = vec2<Float>(0, 0)
  var color = vec3<Float>(0, 0, 0)

  static func getBindingDescription() -> VkVertexInputBindingDescription {
    var bindingDescription = VkVertexInputBindingDescription()
    bindingDescription.binding = 0
    bindingDescription.stride = UInt32(MemoryLayout<Vertex>.stride)
    bindingDescription.inputRate = VK_VERTEX_INPUT_RATE_VERTEX

    return bindingDescription
  }

  static func getAttributeDescriptions() -> [VkVertexInputAttributeDescription] {
    var attributeDescriptions = Array(repeating: VkVertexInputAttributeDescription(), count: 2)

    attributeDescriptions[0].binding = 0
    attributeDescriptions[0].location = 0
    attributeDescriptions[0].format = VK_FORMAT_R32G32_SFLOAT
    attributeDescriptions[0].offset = UInt32(MemoryLayout<Vertex>.offset(of: \.pos)!)

    attributeDescriptions[1].binding = 0
    attributeDescriptions[1].location = 1
    attributeDescriptions[1].format = VK_FORMAT_R32G32B32_SFLOAT
    attributeDescriptions[1].offset = UInt32(MemoryLayout<Vertex>.offset(of: \.color)!)

    return attributeDescriptions
  }
}

let vertices: [Vertex] = [
  Vertex(pos: vec2<Float>(-0.5, -0.5), color: vec3<Float>(1, 0, 0)),
  Vertex(pos: vec2<Float>(0.5, -0.5), color: vec3<Float>(0, 1, 0)),
  Vertex(pos: vec2<Float>(0.5, 0.5), color: vec3<Float>(0, 0, 1)),
  Vertex(pos: vec2<Float>(-0.5, 0.5), color: vec3<Float>(1, 1, 1)),
]

let indices: [UInt16] = [
  0, 1, 2, 2, 3, 0,
]

class Application {
  let MAX_FRAMES_IN_FLIGHT: Int = 2
  var currentFrame: UInt32 = 0
  var framebufferResized = false
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
  var swapChain: VkSwapchainKHR!
  var swapChainImages: [VkImage?] = []
  var swapChainImageFormat: VkFormat!
  var swapChainExtent: VkExtent2D!
  var swapChainImageViews: [VkImageView?] = []
  var renderPass: VkRenderPass!
  var descriptorSetLayout: VkDescriptorSetLayout!
  var pipelineLayout: VkPipelineLayout!
  var graphicsPipeline: VkPipeline!
  var swapChainFramebuffers: [VkFramebuffer?] = []
  var commandPool: VkCommandPool!
  var commandBuffers: [VkCommandBuffer?] = []
  var imageAvailableSemaphores: [VkSemaphore?] = []
  var renderFinishedSemaphores: [VkSemaphore?] = []
  var inFlightFences: [VkFence?] = []
  var vertexBuffer: VkBuffer!
  var vertexBufferMemory: VkDeviceMemory!
  var indexBuffer: VkBuffer!
  var indexBufferMemory: VkDeviceMemory!

  var uniformBuffers: [VkBuffer?] = []
  var uniformBuffersMemory: [VkDeviceMemory?] = []
  var uniformBuffersMapped: [UnsafeMutableRawPointer?] = []

  var descriptorPool: VkDescriptorPool!
  var descriptorSets: [VkDescriptorSet?] = []

  #if DEBUG
    var enableValidationLayers = true
  #else
    var enableValidationLayers = false
  #endif

  func run() {
    self.initWindow()
    self.initVulkan()
    self.mainLoop()
    self.cleanup()
  }

  func initVulkan() {
    self.createInstance()
    self.createSurface()
    self.pickPhysicalDevice()
    self.createLogicalDevice()
    self.createSwapChain()
    self.createImageViews()
    self.createRenderPass()
    self.createDescriptorSetLayout()
    self.createGraphicsPipeline()
    self.createFrameBuffers()
    self.createCommandPool()
    self.createVertexBuffer()
    self.createIndexBuffer()
    self.createUniformBuffers()
    self.createDescriptorPool()
    self.createDescriptorSets()
    self.createCommandBuffers()
    self.createSyncObjects()
  }

  func cleanup() {
    self.cleanupSwapChain()

    for i in 0..<MAX_FRAMES_IN_FLIGHT {
      vkDestroyBuffer(self.device, self.uniformBuffers[i], nil)
      vkFreeMemory(self.device, self.uniformBuffersMemory[i], nil)
    }

    vkDestroyDescriptorPool(self.device, self.descriptorPool, nil)
    vkDestroyDescriptorSetLayout(self.device, self.descriptorSetLayout, nil)

    vkDestroyBuffer(self.device, self.indexBuffer, nil)
    vkFreeMemory(self.device, self.indexBufferMemory, nil)

    vkDestroyBuffer(self.device, self.vertexBuffer, nil)
    vkFreeMemory(self.device, self.vertexBufferMemory, nil)

    vkDestroyPipeline(self.device, self.graphicsPipeline, nil)
    vkDestroyPipelineLayout(self.device, self.pipelineLayout, nil)

    vkDestroyRenderPass(self.device, self.renderPass, nil)

    for i in 0..<self.MAX_FRAMES_IN_FLIGHT {
      vkDestroySemaphore(self.device, self.imageAvailableSemaphores[i], nil)
      vkDestroySemaphore(self.device, self.renderFinishedSemaphores[i], nil)
      vkDestroyFence(self.device, self.inFlightFences[i], nil)
    }

    vkDestroyCommandPool(self.device, self.commandPool, nil)

    vkDestroyDevice(self.device, nil)

    vkDestroySurfaceKHR(self.instance, self.surface, nil)
    vkDestroyInstance(self.instance, nil)

    glfwDestroyWindow(self.window)

    glfwTerminate()
  }

  func mainLoop() {
    while glfwWindowShouldClose(window) == GLFW_FALSE {
      glfwPollEvents()
      self.drawFrame()
    }

    vkDeviceWaitIdle(self.device)
  }

  func drawFrame() {
    let currentFrame = Int(self.currentFrame)

    vkWaitForFences(self.device, 1, &self.inFlightFences[currentFrame], VK_TRUE, UINT64_MAX)

    var imageIndex = UInt32()
    var result = vkAcquireNextImageKHR(
      self.device, self.swapChain, UINT64_MAX, self.imageAvailableSemaphores[currentFrame], nil,
      &imageIndex)
    if result == VK_ERROR_OUT_OF_DATE_KHR {
      print("recreateSwapChain after vkAcquireNextImageKHR")
      // ?? self.framebufferResized = false;
      self.recreateSwapChain()
      return
    } else if result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR {
      fatalError("Failed to acquire swap chain image!")
    }

    // Only reset the fence if we are submitting work
    vkResetFences(self.device, 1, &self.inFlightFences[currentFrame])

    vkResetCommandBuffer(self.commandBuffers[currentFrame], 0)
    recordCommandBuffer(self.commandBuffers[currentFrame]!, imageIndex)

    self.updateUniformBuffer(currentFrame)

    var submitInfo = VkSubmitInfo()
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO

    let waitSemaphores: [VkSemaphore?] = [self.imageAvailableSemaphores[currentFrame]]
    let waitStages: [VkPipelineStageFlags] = [
      UInt32(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue)
    ]
    submitInfo.waitSemaphoreCount = 1
    submitInfo.pWaitSemaphores = waitSemaphores.withUnsafeBufferPointer { $0.baseAddress! }
    submitInfo.pWaitDstStageMask = waitStages.withUnsafeBufferPointer { $0.baseAddress! }

    submitInfo.commandBufferCount = 1
    submitInfo.pCommandBuffers = withUnsafePointer(to: &self.commandBuffers[currentFrame]) { $0 }

    let signalSemaphores: [VkSemaphore?] = [renderFinishedSemaphores[currentFrame]]
    submitInfo.signalSemaphoreCount = 1
    submitInfo.pSignalSemaphores = signalSemaphores.withUnsafeBufferPointer { $0.baseAddress! }

    if vkQueueSubmit(self.graphicsQueue, 1, &submitInfo, self.inFlightFences[currentFrame])
      != VK_SUCCESS
    {
      fatalError("Failed to submit draw command buffer!")
    }

    var presentInfo = VkPresentInfoKHR()
    presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
    presentInfo.waitSemaphoreCount = 1
    presentInfo.pWaitSemaphores = signalSemaphores.withUnsafeBufferPointer { $0.baseAddress! }

    let swapChains: [VkSwapchainKHR?] = [swapChain]
    presentInfo.swapchainCount = 1
    presentInfo.pSwapchains = swapChains.withUnsafeBufferPointer { $0.baseAddress! }
    presentInfo.pImageIndices = withUnsafePointer(to: &imageIndex) { $0 }
    presentInfo.pResults = nil

    result = vkQueuePresentKHR(self.presentQueue, &presentInfo)
    if result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || self.framebufferResized
    {
      print("recreateSwapChain after vkQueuePresentKHR")
      self.framebufferResized = false
      self.recreateSwapChain()
    } else if result != VK_SUCCESS {
      fatalError("Failed to present swap chain image!")
    }

    self.currentFrame = (self.currentFrame + 1) % UInt32(self.MAX_FRAMES_IN_FLIGHT)
  }

  func createDescriptorSets() {
    let layouts: [VkDescriptorSetLayout?] = Array(
      repeating: self.descriptorSetLayout, count: self.MAX_FRAMES_IN_FLIGHT
    )

    var allocInfo = VkDescriptorSetAllocateInfo()
    allocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
    allocInfo.descriptorPool = self.descriptorPool
    allocInfo.descriptorSetCount = UInt32(self.MAX_FRAMES_IN_FLIGHT)
    allocInfo.pSetLayouts = layouts.withUnsafeBufferPointer { $0.baseAddress! }

    self.descriptorSets = Array(repeating: nil, count: self.MAX_FRAMES_IN_FLIGHT)
    if vkAllocateDescriptorSets(self.device, &allocInfo, &self.descriptorSets) != VK_SUCCESS {
      fatalError("Failed to allocate descriptor sets!")
    }

    for i in 0..<self.MAX_FRAMES_IN_FLIGHT {
      var bufferInfo = VkDescriptorBufferInfo()
      bufferInfo.buffer = self.uniformBuffers[i]
      bufferInfo.offset = 0
      bufferInfo.range = UInt64(MemoryLayout<UniformBufferObject>.stride)

      var descriptorWrite = VkWriteDescriptorSet()
      descriptorWrite.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
      descriptorWrite.dstSet = self.descriptorSets[i]
      descriptorWrite.dstBinding = 0
      descriptorWrite.dstArrayElement = 0

      descriptorWrite.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
      descriptorWrite.descriptorCount = 1

      descriptorWrite.pBufferInfo = withUnsafePointer(to: &bufferInfo) { $0 }
      descriptorWrite.pImageInfo = nil  // Optional
      descriptorWrite.pTexelBufferView = nil  // Optional

      vkUpdateDescriptorSets(self.device, 1, &descriptorWrite, 0, nil)
    }
  }

  func createDescriptorPool() {
    var poolSize = VkDescriptorPoolSize()
    poolSize.type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
    poolSize.descriptorCount = UInt32(MAX_FRAMES_IN_FLIGHT)

    var poolInfo = VkDescriptorPoolCreateInfo()
    poolInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
    poolInfo.poolSizeCount = 1
    poolInfo.pPoolSizes = withUnsafePointer(to: &poolSize) { $0 }
    poolInfo.maxSets = UInt32(MAX_FRAMES_IN_FLIGHT)

    if vkCreateDescriptorPool(self.device, &poolInfo, nil, &self.descriptorPool) != VK_SUCCESS {
      fatalError("Failed to create descriptor pool!")
    }
  }

  var startTime = mach_absolute_time()
  func updateUniformBuffer(_ currentImage: Int) {
    var timebaseInfo = mach_timebase_info_data_t()
    mach_timebase_info(&timebaseInfo)

    let currentTime = mach_absolute_time()

    let elapsedNanoseconds =
      (currentTime - self.startTime) * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
    let seconds = Double(elapsedNanoseconds) / 1_000_000_000.0  // Convert to seconds
    let time = Float(seconds)

    var ubo = UniformBufferObject()
    ubo.model = rotateZ(radians(time * 90))
    ubo.view = lookAt(eye: vec3f(2, 2, 2), center: vec3f(0, 0, 0), up: .forward)
    ubo.proj = perspective(
      fov: radians(45), near: 0.1, far: 10,
      aspect: Float(swapChainExtent.width) / Float(swapChainExtent.height)
    )
    ubo.proj[1][1] *= -1;

    withUnsafeBytes(of: &ubo) { src in
      self.uniformBuffersMapped[currentImage]!.copyMemory(
        from: src.baseAddress!, byteCount: src.count)
    }
  }

  func createUniformBuffers() {
    let bufferSize: VkDeviceSize = UInt64(MemoryLayout<UniformBufferObject>.stride)

    self.uniformBuffers = Array(repeating: nil, count: MAX_FRAMES_IN_FLIGHT)
    self.uniformBuffersMemory = Array(repeating: nil, count: MAX_FRAMES_IN_FLIGHT)
    self.uniformBuffersMapped = Array(repeating: nil, count: MAX_FRAMES_IN_FLIGHT)

    for i in 0..<MAX_FRAMES_IN_FLIGHT {
      createBuffer(
        bufferSize, UInt32(VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT.rawValue),
        UInt32(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue)
          | UInt32(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue), &self.uniformBuffers[i],
        &self.uniformBuffersMemory[i]
      )
      vkMapMemory(
        self.device, self.uniformBuffersMemory[i], 0, bufferSize, 0, &self.uniformBuffersMapped[i])
    }
  }

  func createDescriptorSetLayout() {
    var uboLayoutBinding = VkDescriptorSetLayoutBinding()
    uboLayoutBinding.binding = 0
    uboLayoutBinding.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
    uboLayoutBinding.descriptorCount = 1
    uboLayoutBinding.stageFlags = UInt32(VK_SHADER_STAGE_VERTEX_BIT.rawValue)
    uboLayoutBinding.pImmutableSamplers = nil  // Optional

    var layoutInfo = VkDescriptorSetLayoutCreateInfo()
    layoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
    layoutInfo.bindingCount = 1
    layoutInfo.pBindings = withUnsafePointer(to: &uboLayoutBinding) { $0 }

    if vkCreateDescriptorSetLayout(self.device, &layoutInfo, nil, &self.descriptorSetLayout)
      != VK_SUCCESS
    {
      fatalError("Failed to create descriptor set layout!")
    }
  }

  func findMemoryType(_ typeFilter: UInt32, _ properties: VkMemoryPropertyFlags) -> UInt32 {
    var memProperties = VkPhysicalDeviceMemoryProperties()
    vkGetPhysicalDeviceMemoryProperties(self.physicalDevice, &memProperties)
    let memoryTypes = Mirror(reflecting: memProperties.memoryTypes).children.map {
      $0.value as! VkMemoryType
    }

    for i in 0..<memProperties.memoryTypeCount {
      if (typeFilter & (1 << i)) != 0
        && (memoryTypes[Int(i)].propertyFlags & properties) == properties
      {
        return i
      }
    }

    fatalError("Failed to find suitable memory type!")
  }

  func copyBuffer(_ srcBuffer: VkBuffer, _ dstBuffer: VkBuffer, _ size: VkDeviceSize) {
    var allocInfo = VkCommandBufferAllocateInfo()
    allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
    allocInfo.commandPool = self.commandPool
    allocInfo.commandBufferCount = 1

    var commandBuffer: VkCommandBuffer?
    vkAllocateCommandBuffers(self.device, &allocInfo, &commandBuffer)

    var beginInfo = VkCommandBufferBeginInfo()
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
    beginInfo.flags = UInt32(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.rawValue)

    vkBeginCommandBuffer(commandBuffer, &beginInfo)

    var copyRegion = VkBufferCopy()
    copyRegion.srcOffset = 0  // Optional
    copyRegion.dstOffset = 0  // Optional
    copyRegion.size = size
    vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion)

    vkEndCommandBuffer(commandBuffer)

    var submitInfo = VkSubmitInfo()
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
    submitInfo.commandBufferCount = 1
    submitInfo.pCommandBuffers = withUnsafePointer(to: &commandBuffer) { $0 }

    vkQueueSubmit(self.graphicsQueue, 1, &submitInfo, nil)
    vkQueueWaitIdle(self.graphicsQueue)

    vkFreeCommandBuffers(self.device, self.commandPool, 1, &commandBuffer)
  }

  func createBuffer(
    _ size: VkDeviceSize, _ usage: VkBufferUsageFlags, _ properties: VkMemoryPropertyFlags,
    _ buffer: inout VkBuffer?, _ bufferMemory: inout VkDeviceMemory?
  ) {
    var bufferInfo = VkBufferCreateInfo()
    bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO
    bufferInfo.size = size
    bufferInfo.usage = usage
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE

    if vkCreateBuffer(self.device, &bufferInfo, nil, &buffer) != VK_SUCCESS {
      fatalError("Failed to create vertex buffer!")
    }

    var memRequirements = VkMemoryRequirements()
    vkGetBufferMemoryRequirements(self.device, buffer, &memRequirements)

    var allocInfo = VkMemoryAllocateInfo()
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
    allocInfo.allocationSize = memRequirements.size
    allocInfo.memoryTypeIndex = self.findMemoryType(
      memRequirements.memoryTypeBits,
      properties
    )

    if vkAllocateMemory(self.device, &allocInfo, nil, &bufferMemory) != VK_SUCCESS {
      fatalError("Failed to allocate vertex buffer memory!")
    }

    vkBindBufferMemory(self.device, buffer, bufferMemory, 0)
  }

  func createIndexBuffer() {
    let bufferSize: VkDeviceSize = UInt64(MemoryLayout<UInt16>.stride * indices.count)

    var stagingBuffer: VkBuffer?
    var stagingBufferMemory: VkDeviceMemory?

    self.createBuffer(
      bufferSize, UInt32(VK_BUFFER_USAGE_TRANSFER_SRC_BIT.rawValue),
      UInt32(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue)
        | UInt32(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue), &stagingBuffer,
      &stagingBufferMemory)

    let data = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 0)
    vkMapMemory(self.device, stagingBufferMemory, 0, bufferSize, 0, data)
    indices.withUnsafeBytes { src in
      data.pointee!.copyMemory(from: src.baseAddress!, byteCount: src.count)
    }
    vkUnmapMemory(self.device, stagingBufferMemory)

    self.createBuffer(
      bufferSize,
      UInt32(VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue)
        | UInt32(VK_BUFFER_USAGE_INDEX_BUFFER_BIT.rawValue),
      UInt32(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT.rawValue), &self.indexBuffer,
      &self.indexBufferMemory)

    copyBuffer(stagingBuffer!, self.indexBuffer, bufferSize)

    vkDestroyBuffer(self.device, stagingBuffer, nil)
    vkFreeMemory(self.device, stagingBufferMemory, nil)
  }

  func createVertexBuffer() {
    let bufferSize: VkDeviceSize = UInt64(MemoryLayout<Vertex>.stride * vertices.count)

    var stagingBuffer: VkBuffer?
    var stagingBufferMemory: VkDeviceMemory?

    self.createBuffer(
      bufferSize, UInt32(VK_BUFFER_USAGE_TRANSFER_SRC_BIT.rawValue),
      UInt32(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue)
        | UInt32(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue), &stagingBuffer,
      &stagingBufferMemory)

    let data = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 0)
    vkMapMemory(self.device, stagingBufferMemory, 0, bufferSize, 0, data)
    vertices.withUnsafeBytes { src in
      data.pointee!.copyMemory(from: src.baseAddress!, byteCount: src.count)
    }
    vkUnmapMemory(self.device, stagingBufferMemory)

    self.createBuffer(
      bufferSize,
      UInt32(VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue)
        | UInt32(VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue),
      UInt32(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT.rawValue), &self.vertexBuffer,
      &self.vertexBufferMemory)

    copyBuffer(stagingBuffer!, self.vertexBuffer, bufferSize)

    vkDestroyBuffer(self.device, stagingBuffer, nil)
    vkFreeMemory(self.device, stagingBufferMemory, nil)
  }

  func createSyncObjects() {
    self.imageAvailableSemaphores = Array(repeating: nil, count: self.MAX_FRAMES_IN_FLIGHT)
    self.renderFinishedSemaphores = Array(repeating: nil, count: self.MAX_FRAMES_IN_FLIGHT)
    self.inFlightFences = Array(repeating: nil, count: self.MAX_FRAMES_IN_FLIGHT)

    var semaphoreInfo = VkSemaphoreCreateInfo()
    semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO

    var fenceInfo = VkFenceCreateInfo()
    fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
    fenceInfo.flags = UInt32(VK_FENCE_CREATE_SIGNALED_BIT.rawValue)

    for i in 0..<self.MAX_FRAMES_IN_FLIGHT {
      if vkCreateSemaphore(self.device, &semaphoreInfo, nil, &self.imageAvailableSemaphores[i])
        != VK_SUCCESS
      {
        fatalError("Failed to create imageAvailableSemaphore!")
      }

      if vkCreateSemaphore(self.device, &semaphoreInfo, nil, &self.renderFinishedSemaphores[i])
        != VK_SUCCESS
      {
        fatalError("Failed to create renderFinishedSemaphore!")
      }

      if vkCreateFence(self.device, &fenceInfo, nil, &self.inFlightFences[i]) != VK_SUCCESS {
        fatalError("Failed to create inFlightFence!")
      }
    }
  }

  func recordCommandBuffer(_ commandBuffer: VkCommandBuffer, _ imageIndex: UInt32) {
    var beginInfo = VkCommandBufferBeginInfo()
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
    beginInfo.flags = 0  // Optional
    beginInfo.pInheritanceInfo = nil  // Optional

    if vkBeginCommandBuffer(commandBuffer, &beginInfo) != VK_SUCCESS {
      fatalError("Failed to begin recording command buffer!")
    }

    var renderPassInfo = VkRenderPassBeginInfo()
    renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
    renderPassInfo.renderPass = self.renderPass
    renderPassInfo.framebuffer = self.swapChainFramebuffers[Int(imageIndex)]
    renderPassInfo.renderArea.offset = VkOffset2D(x: 0, y: 0)
    renderPassInfo.renderArea.extent = self.swapChainExtent

    var clearColor = VkClearValue(color: VkClearColorValue(float32: (0, 0, 0, 1)))
    renderPassInfo.clearValueCount = 1
    renderPassInfo.pClearValues = withUnsafePointer(to: &clearColor) { $0 }

    vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE)

    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicsPipeline)

    var viewport = VkViewport()
    viewport.x = 0
    viewport.y = 0
    viewport.width = Float(self.swapChainExtent.width)
    viewport.height = Float(self.swapChainExtent.height)
    viewport.minDepth = 0
    viewport.maxDepth = 1
    vkCmdSetViewport(commandBuffer, 0, 1, &viewport)

    var scissor = VkRect2D()
    scissor.offset = VkOffset2D(x: 0, y: 0)
    scissor.extent = self.swapChainExtent
    vkCmdSetScissor(commandBuffer, 0, 1, &scissor)

    let vertexBuffers: [VkBuffer?] = [self.vertexBuffer]
    let offsets: [VkDeviceSize] = [0]
    vkCmdBindVertexBuffers(commandBuffer, 0, 1, vertexBuffers, offsets)
    vkCmdBindIndexBuffer(commandBuffer, self.indexBuffer, 0, VK_INDEX_TYPE_UINT16)

    vkCmdBindDescriptorSets(
      commandBuffer,
      VK_PIPELINE_BIND_POINT_GRAPHICS,
      self.pipelineLayout,
      0,
      1,
      &descriptorSets[Int(currentFrame)],
      0,
      nil
    )

    vkCmdDrawIndexed(commandBuffer, UInt32(indices.count), 1, 0, 0, 0)

    vkCmdEndRenderPass(commandBuffer)

    if vkEndCommandBuffer(commandBuffer) != VK_SUCCESS {
      fatalError("failed to record command buffer!")
    }
  }

  func createCommandBuffers() {
    self.commandBuffers = Array(repeating: nil, count: self.MAX_FRAMES_IN_FLIGHT)

    var allocInfo = VkCommandBufferAllocateInfo()
    allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
    allocInfo.commandPool = self.commandPool
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
    allocInfo.commandBufferCount = UInt32(self.commandBuffers.count)

    if vkAllocateCommandBuffers(self.device, &allocInfo, &self.commandBuffers) != VK_SUCCESS {
      fatalError("Failed to allocate command buffers!")
    }
  }

  func createCommandPool() {
    let queueFamilyIndices = findQueueFamilies(physicalDevice)

    var poolInfo = VkCommandPoolCreateInfo()
    poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
    poolInfo.flags = UInt32(VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT.rawValue)
    poolInfo.queueFamilyIndex = queueFamilyIndices.graphicsFamily!

    if vkCreateCommandPool(self.device, &poolInfo, nil, &self.commandPool) != VK_SUCCESS {
      fatalError("failed to create command pool!")
    }
  }

  func createFrameBuffers() {
    self.swapChainFramebuffers = Array(repeating: nil, count: self.swapChainImageViews.count)

    for (i, _) in self.swapChainImageViews.enumerated() {
      let attachments: [VkImageView?] = [
        self.swapChainImageViews[i]
      ]

      var framebufferInfo = VkFramebufferCreateInfo()
      framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
      framebufferInfo.renderPass = self.renderPass
      framebufferInfo.attachmentCount = 1
      framebufferInfo.pAttachments = attachments.withUnsafeBufferPointer { $0.baseAddress! }
      framebufferInfo.width = self.swapChainExtent.width
      framebufferInfo.height = self.swapChainExtent.height
      framebufferInfo.layers = 1

      if vkCreateFramebuffer(self.device, &framebufferInfo, nil, &self.swapChainFramebuffers[i])
        != VK_SUCCESS
      {
        fatalError("Failed to create framebuffer!")
      }
    }
  }

  func createRenderPass() {
    var dependency = VkSubpassDependency()
    dependency.srcSubpass = VK_SUBPASS_EXTERNAL
    dependency.dstSubpass = 0
    dependency.srcStageMask = UInt32(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue)
    dependency.srcAccessMask = 0
    dependency.dstStageMask = UInt32(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue)
    dependency.dstAccessMask = UInt32(VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT.rawValue)

    var colorAttachment = VkAttachmentDescription()
    colorAttachment.format = swapChainImageFormat
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR

    var colorAttachmentRef = VkAttachmentReference()
    colorAttachmentRef.attachment = 0
    colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

    var subpass = VkSubpassDescription()
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
    subpass.colorAttachmentCount = 1
    subpass.pColorAttachments = withUnsafePointer(to: &colorAttachmentRef) { $0 }

    var renderPassInfo = VkRenderPassCreateInfo()
    renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
    renderPassInfo.attachmentCount = 1
    renderPassInfo.pAttachments = withUnsafePointer(to: &colorAttachment) { $0 }
    renderPassInfo.subpassCount = 1
    renderPassInfo.pSubpasses = withUnsafePointer(to: &subpass) { $0 }
    renderPassInfo.dependencyCount = 1
    renderPassInfo.pDependencies = withUnsafePointer(to: &dependency) { $0 }

    if vkCreateRenderPass(self.device, &renderPassInfo, nil, &self.renderPass) != VK_SUCCESS {
      fatalError("Failed to create render pass!")
    }
  }

  func createGraphicsPipeline() {
    let defaultVert = ShaderUtils.compile("default.vert")!
    let defaultFrag = ShaderUtils.compile("default.frag")!

    let vertShaderModule = createShaderModule(defaultVert)
    let fragShaderModule = createShaderModule(defaultFrag)

    let funcName = "main".utf8CString
    var vertShaderStageInfo = VkPipelineShaderStageCreateInfo()
    vertShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
    vertShaderStageInfo.stage = VK_SHADER_STAGE_VERTEX_BIT
    vertShaderStageInfo.module = vertShaderModule
    vertShaderStageInfo.pName = funcName.cString

    var fragShaderStageInfo = VkPipelineShaderStageCreateInfo()
    fragShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
    fragShaderStageInfo.stage = VK_SHADER_STAGE_FRAGMENT_BIT
    fragShaderStageInfo.module = fragShaderModule
    fragShaderStageInfo.pName = funcName.cString

    let shaderStages: [VkPipelineShaderStageCreateInfo] = [
      vertShaderStageInfo, fragShaderStageInfo,
    ]

    var bindingDescription = Vertex.getBindingDescription()
    let attributeDescriptions = Vertex.getAttributeDescriptions()

    var vertexInputInfo = VkPipelineVertexInputStateCreateInfo()
    vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
    vertexInputInfo.vertexBindingDescriptionCount = 1
    vertexInputInfo.pVertexBindingDescriptions = withUnsafePointer(to: &bindingDescription) { $0 }
    vertexInputInfo.vertexAttributeDescriptionCount = UInt32(attributeDescriptions.count)
    vertexInputInfo.pVertexAttributeDescriptions = attributeDescriptions.withUnsafeBufferPointer {
      $0.baseAddress!
    }

    let dynamicStates: [VkDynamicState] = [
      VK_DYNAMIC_STATE_VIEWPORT,
      VK_DYNAMIC_STATE_SCISSOR,
    ]

    var dynamicState = VkPipelineDynamicStateCreateInfo()
    dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO
    dynamicState.dynamicStateCount = UInt32(dynamicStates.count)
    dynamicState.pDynamicStates = dynamicStates.withUnsafeBufferPointer { $0 }.baseAddress

    var inputAssembly = VkPipelineInputAssemblyStateCreateInfo()
    inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
    inputAssembly.primitiveRestartEnable = VK_FALSE

    var viewport = VkViewport()
    viewport.x = 0
    viewport.y = 0
    viewport.width = Float(self.swapChainExtent.width)
    viewport.height = Float(self.swapChainExtent.height)
    viewport.minDepth = 0
    viewport.maxDepth = 1

    var scissor = VkRect2D()
    scissor.offset = VkOffset2D(x: 0, y: 0)
    scissor.extent = self.swapChainExtent

    var viewportState = VkPipelineViewportStateCreateInfo()
    viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
    viewportState.viewportCount = 1
    viewportState.pViewports = withUnsafePointer(to: &viewport) { $0 }
    viewportState.scissorCount = 1
    viewportState.pScissors = withUnsafePointer(to: &scissor) { $0 }

    var rasterizer = VkPipelineRasterizationStateCreateInfo()
    rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
    rasterizer.depthClampEnable = VK_FALSE
    rasterizer.rasterizerDiscardEnable = VK_FALSE
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL
    rasterizer.lineWidth = 1
    rasterizer.cullMode = UInt32(VK_CULL_MODE_BACK_BIT.rawValue)
    rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE
    rasterizer.depthBiasEnable = VK_FALSE
    rasterizer.depthBiasConstantFactor = 0  // Optional
    rasterizer.depthBiasClamp = 0  // Optional
    rasterizer.depthBiasSlopeFactor = 0  // Optional

    var multisampling = VkPipelineMultisampleStateCreateInfo()
    multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
    multisampling.sampleShadingEnable = VK_FALSE
    multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
    multisampling.minSampleShading = 1  // Optional
    multisampling.pSampleMask = nil  // Optional
    multisampling.alphaToCoverageEnable = VK_FALSE  // Optional
    multisampling.alphaToOneEnable = VK_FALSE  // Optional

    var colorBlendAttachment = VkPipelineColorBlendAttachmentState()
    colorBlendAttachment.colorWriteMask =
      UInt32(VK_COLOR_COMPONENT_R_BIT.rawValue) | UInt32(VK_COLOR_COMPONENT_G_BIT.rawValue)
      | UInt32(VK_COLOR_COMPONENT_B_BIT.rawValue)
      | UInt32(VK_COLOR_COMPONENT_A_BIT.rawValue)
    colorBlendAttachment.blendEnable = VK_TRUE
    colorBlendAttachment.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA
    colorBlendAttachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
    colorBlendAttachment.colorBlendOp = VK_BLEND_OP_ADD
    colorBlendAttachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE
    colorBlendAttachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO
    colorBlendAttachment.alphaBlendOp = VK_BLEND_OP_ADD

    var colorBlending = VkPipelineColorBlendStateCreateInfo()
    colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
    colorBlending.logicOpEnable = VK_FALSE
    colorBlending.logicOp = VK_LOGIC_OP_COPY  // Optional
    colorBlending.attachmentCount = 1
    colorBlending.pAttachments = withUnsafePointer(to: &colorBlendAttachment) { $0 }
    colorBlending.blendConstants.0 = 0  // Optional
    colorBlending.blendConstants.1 = 0  // Optional
    colorBlending.blendConstants.2 = 0  // Optional
    colorBlending.blendConstants.3 = 0  // Optional

    var pipelineLayoutInfo = VkPipelineLayoutCreateInfo()
    pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
    pipelineLayoutInfo.setLayoutCount = 1
    pipelineLayoutInfo.pSetLayouts = withUnsafePointer(to: &self.descriptorSetLayout) { $0 }
    pipelineLayoutInfo.pushConstantRangeCount = 0  // Optional
    pipelineLayoutInfo.pPushConstantRanges = nil  // Optional

    if vkCreatePipelineLayout(self.device, &pipelineLayoutInfo, nil, &self.pipelineLayout)
      != VK_SUCCESS
    {
      fatalError("Failed to create pipeline layout!")
    }

    var pipelineInfo = VkGraphicsPipelineCreateInfo()
    pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
    pipelineInfo.stageCount = 2
    pipelineInfo.pStages = shaderStages.withUnsafeBufferPointer { $0 }.baseAddress
    pipelineInfo.pVertexInputState = withUnsafePointer(to: &vertexInputInfo) { $0 }
    pipelineInfo.pInputAssemblyState = withUnsafePointer(to: &inputAssembly) { $0 }
    pipelineInfo.pViewportState = withUnsafePointer(to: &viewportState) { $0 }
    pipelineInfo.pRasterizationState = withUnsafePointer(to: &rasterizer) { $0 }
    pipelineInfo.pMultisampleState = withUnsafePointer(to: &multisampling) { $0 }
    pipelineInfo.pDepthStencilState = nil  // Optional
    pipelineInfo.pColorBlendState = withUnsafePointer(to: &colorBlending) { $0 }
    pipelineInfo.pDynamicState = withUnsafePointer(to: &dynamicState) { $0 }

    pipelineInfo.layout = self.pipelineLayout

    pipelineInfo.renderPass = self.renderPass
    pipelineInfo.subpass = 0
    pipelineInfo.basePipelineHandle = nil  // Optional
    pipelineInfo.basePipelineIndex = -1  // Optional

    if vkCreateGraphicsPipelines(self.device, nil, 1, &pipelineInfo, nil, &self.graphicsPipeline)
      != VK_SUCCESS
    {
      fatalError("Failed to create graphics pipeline!")
    }

    vkDestroyShaderModule(self.device, fragShaderModule, nil)
    vkDestroyShaderModule(self.device, vertShaderModule, nil)
  }

  func createShaderModule(_ code: Data) -> VkShaderModule {
    var createInfo = VkShaderModuleCreateInfo()
    createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
    createInfo.codeSize = code.count
    createInfo.pCode = code.withUnsafeBytes { $0.bindMemory(to: UInt32.self).baseAddress! }

    var shaderModule: VkShaderModule? = nil
    if vkCreateShaderModule(self.device, &createInfo, nil, &shaderModule) != VK_SUCCESS {
      fatalError("Failed to create shader module!")
    }

    return shaderModule!
  }

  func createImageViews() {
    self.swapChainImageViews = Array(repeating: nil, count: self.swapChainImages.count)

    for (i, image) in self.swapChainImages.enumerated() {
      var createInfo = VkImageViewCreateInfo()
      createInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
      createInfo.image = image
      createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D
      createInfo.format = swapChainImageFormat

      createInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY
      createInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY
      createInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY
      createInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY

      createInfo.subresourceRange.aspectMask = UInt32(VK_IMAGE_ASPECT_COLOR_BIT.rawValue)
      createInfo.subresourceRange.baseMipLevel = 0
      createInfo.subresourceRange.levelCount = 1
      createInfo.subresourceRange.baseArrayLayer = 0
      createInfo.subresourceRange.layerCount = 1

      if vkCreateImageView(self.device, &createInfo, nil, &swapChainImageViews[i]) != VK_SUCCESS {
        fatalError("Failed to create image views!")
      }
    }

    print("swapChainImageViews: \(self.swapChainImageViews)")
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

    var swapChainAdequate = false
    if extensionsSupported {
      let swapChainSupport = querySwapChainSupport(device)
      swapChainAdequate =
        !swapChainSupport.formats.isEmpty && !swapChainSupport.presentModes.isEmpty
    }

    return indices.isComplete && extensionsSupported && swapChainAdequate
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

  func chooseSwapPresentMode(_ availablePresentModes: inout [VkPresentModeKHR]) -> VkPresentModeKHR
  {
    for availablePresentMode in availablePresentModes {
      if availablePresentMode == VK_PRESENT_MODE_MAILBOX_KHR {
        return availablePresentMode
      }
    }

    return VK_PRESENT_MODE_FIFO_KHR
  }

  func chooseSwapSurfaceFormat(_ availableFormats: inout [VkSurfaceFormatKHR]) -> VkSurfaceFormatKHR
  {
    for availableFormat in availableFormats {
      if availableFormat.format == VK_FORMAT_B8G8R8A8_SRGB
        && availableFormat.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
      {
        return availableFormat
      }
    }

    return availableFormats[0]
  }

  func chooseSwapExtent(_ capabilities: inout VkSurfaceCapabilitiesKHR) -> VkExtent2D {
    if capabilities.currentExtent.width != UINT32_MAX {
      return capabilities.currentExtent
    } else {
      var width = Int32()
      var height = Int32()
      glfwGetFramebufferSize(window, &width, &height)

      var actualExtent = VkExtent2D(width: UInt32(width), height: UInt32(height))
      actualExtent.width = actualExtent.width.clamp(
        capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
      actualExtent.height = actualExtent.height.clamp(
        capabilities.minImageExtent.height, capabilities.maxImageExtent.height)

      return actualExtent
    }
  }

  func cleanupSwapChain() {
    for i in 0..<self.swapChainFramebuffers.count {
      vkDestroyFramebuffer(self.device, self.swapChainFramebuffers[i], nil)
    }
    for i in 0..<self.swapChainImageViews.count {
      vkDestroyImageView(self.device, self.swapChainImageViews[i], nil)
    }

    vkDestroySwapchainKHR(self.device, self.swapChain, nil)
  }

  func recreateSwapChain() {
    // handle minimization
    var width: Int32 = 0
    var height: Int32 = 0
    glfwGetFramebufferSize(self.window, &width, &height)
    while width == 0 || height == 0 {
      glfwGetFramebufferSize(self.window, &width, &height)
      glfwWaitEvents()
    }

    vkDeviceWaitIdle(self.device)

    self.cleanupSwapChain()

    self.createSwapChain()
    self.createImageViews()
    self.createFrameBuffers()
  }

  func createSwapChain() {
    var swapChainSupport = querySwapChainSupport(self.physicalDevice)

    let surfaceFormat: VkSurfaceFormatKHR = chooseSwapSurfaceFormat(&swapChainSupport.formats)
    let presentMode: VkPresentModeKHR = chooseSwapPresentMode(&swapChainSupport.presentModes)
    let extent: VkExtent2D = chooseSwapExtent(&swapChainSupport.capabilities)

    var imageCount = swapChainSupport.capabilities.minImageCount + 1
    if swapChainSupport.capabilities.maxImageCount > 0
      && imageCount > swapChainSupport.capabilities.maxImageCount
    {
      imageCount = swapChainSupport.capabilities.maxImageCount
    }

    var createInfo = VkSwapchainCreateInfoKHR()
    createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
    createInfo.surface = self.surface

    createInfo.minImageCount = imageCount
    createInfo.imageFormat = surfaceFormat.format
    createInfo.imageColorSpace = surfaceFormat.colorSpace
    createInfo.imageExtent = extent
    createInfo.imageArrayLayers = 1
    createInfo.imageUsage = UInt32(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue)

    let indices = findQueueFamilies(self.physicalDevice)
    let queueFamilyIndices: [UInt32] = [indices.graphicsFamily!, indices.presentFamily!]
    if indices.graphicsFamily! != indices.presentFamily! {
      createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT
      createInfo.queueFamilyIndexCount = 2
      createInfo.pQueueFamilyIndices = queueFamilyIndices.withUnsafeBufferPointer { $0 }.baseAddress
    } else {
      createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
      createInfo.queueFamilyIndexCount = 0  // Optional
      createInfo.pQueueFamilyIndices = nil  // Optional
    }

    createInfo.preTransform = swapChainSupport.capabilities.currentTransform
    createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
    createInfo.presentMode = presentMode
    createInfo.clipped = VK_TRUE
    createInfo.oldSwapchain = nil

    if vkCreateSwapchainKHR(self.device, &createInfo, nil, &self.swapChain) != VK_SUCCESS {
      fatalError("Failed to create swap chain!")
    }
    print("Swap chain: \(self.swapChain!)")

    vkGetSwapchainImagesKHR(self.device, self.swapChain, &imageCount, nil)
    self.swapChainImages = Array(repeating: nil, count: Int(imageCount))
    vkGetSwapchainImagesKHR(device, swapChain, &imageCount, &self.swapChainImages)
    print("swapChainImages: \(self.swapChainImages)")

    self.swapChainImageFormat = surfaceFormat.format
    self.swapChainExtent = extent

    print("swapChainImageFormat: \(self.swapChainImageFormat!)")
    print("swapChainExtent: \(self.swapChainExtent!)")
  }

  struct SwapChainSupportDetails {
    var capabilities = VkSurfaceCapabilitiesKHR()
    var formats: [VkSurfaceFormatKHR] = []
    var presentModes: [VkPresentModeKHR] = []
  }

  func querySwapChainSupport(_ device: VkPhysicalDevice) -> SwapChainSupportDetails {
    var details = SwapChainSupportDetails()

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, self.surface, &details.capabilities)

    var formatCount = UInt32()
    vkGetPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &formatCount, nil)

    if formatCount != 0 {
      details.formats = Array(repeating: VkSurfaceFormatKHR(), count: Int(formatCount))
      vkGetPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &formatCount, &details.formats)
    } else {
      fatalError("Failed to find suitable swap chain format")
    }

    var presentModeCount = UInt32()
    vkGetPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &presentModeCount, nil)

    if presentModeCount != 0 {
      details.presentModes = Array(
        repeating: VkPresentModeKHR(VK_PRESENT_MODE_IMMEDIATE_KHR.rawValue),
        count: Int(presentModeCount))
      vkGetPhysicalDeviceSurfacePresentModesKHR(
        device, self.surface, &presentModeCount, &details.presentModes)
    } else {
      fatalError("Failed to find suitable swap chain present mode")
    }

    return details
  }

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
      if (queueFamily.queueFlags & UInt32(VK_QUEUE_GRAPHICS_BIT.rawValue)) != 0 {
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
    let pApplicationName = "Hello Vulkan".utf8CString
    appInfo.pApplicationName = pApplicationName.cString
    appInfo.applicationVersion = vkMakeVersion(1, 0, 0)
    let pEngineName = "No Engine".utf8CString
    appInfo.pEngineName = pEngineName.cString
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
        print("  \(i + 1): \(cString.string)")
      }
    }

    var createInfo = VkInstanceCreateInfo()
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    createInfo.pApplicationInfo = withUnsafePointer(to: &appInfo) { $0 }
    createInfo.enabledExtensionCount = UInt32(requiredExtensions.count)

    createInfo.ppEnabledExtensionNames =
      requiredExtensions.withUnsafeBufferPointer { $0 }.baseAddress
    createInfo.flags |= UInt32(VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR.rawValue)
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

    self.window = glfwCreateWindow(self.WIDTH, self.HEIGHT, "Vulkan", nil, nil)
    let app = Unmanaged.passUnretained(self).toOpaque()
    glfwSetWindowUserPointer(window, app)
    print("framebufferResizeCallback app: \(app)")
    glfwSetFramebufferSizeCallback(self.window, framebufferResizeCallback)
  }
}

func framebufferResizeCallback(_ window: OpaquePointer?, _ width: Int32, _ height: Int32) {
  print("framebufferResizeCallback width:\(width), height: \(height)")
  let appPointer = glfwGetWindowUserPointer(window)!
  let app = Unmanaged<Application>.fromOpaque(appPointer).takeUnretainedValue()
  app.framebufferResized = true
}
