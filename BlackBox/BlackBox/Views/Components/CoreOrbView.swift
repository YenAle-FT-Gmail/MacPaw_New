import SwiftUI
import MetalKit

// MARK: - Metal Core Orb View
struct CoreOrbView: NSViewRepresentable {
    let appState: AppState
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.layer?.isOpaque = false
        mtkView.drawableSize = CGSize(width: 400, height: 400)
        context.coordinator.setupPipeline(device: mtkView.device!)
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.appState = appState
    }
    
    func makeCoordinator() -> OrbRenderer {
        OrbRenderer(appState: appState)
    }
}

class OrbRenderer: NSObject, MTKViewDelegate {
    var appState: AppState
    private var pipelineState: MTLRenderPipelineState?
    private var commandQueue: MTLCommandQueue?
    private var startTime: Date = Date()
    
    init(appState: AppState) {
        self.appState = appState
        super.init()
    }
    
    func setupPipeline(device: MTLDevice) {
        commandQueue = device.makeCommandQueue()
        
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.main) else {
            print("Failed to create Metal library — falling back to inline shaders")
            do {
                let lib = try device.makeLibrary(source: OrbRenderer.shaderSource, options: nil)
                buildPipeline(device: device, library: lib)
            } catch {
                print("Metal shader compilation failed: \(error)")
            }
            return
        }
        buildPipeline(device: device, library: library)
    }
    
    private func buildPipeline(device: MTLDevice, library: MTLLibrary) {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "coreOrbVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "coreOrbFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        var time = Float(Date().timeIntervalSince(startTime))
        var color = stateColor
        var pulseRate = statePulseRate
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD3<Float>>.size, index: 1)
        encoder.setFragmentBytes(&pulseRate, length: MemoryLayout<Float>.size, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private var stateColor: SIMD3<Float> {
        switch appState {
        case .idle:         return SIMD3<Float>(0.3, 0.4, 0.6)    // Muted blue
        case .auditing:     return SIMD3<Float>(0.2, 0.6, 1.0)    // Scanning blue
        case .exposed:      return SIMD3<Float>(1.0, 0.15, 0.15)  // Neon red
        case .neutralizing: return SIMD3<Float>(1.0, 0.7, 0.0)    // Amber
        case .cloaked:      return SIMD3<Float>(0.1, 1.0, 0.4)    // Neon green
        }
    }
    
    private var statePulseRate: Float {
        switch appState {
        case .idle:         return 1.0
        case .auditing:     return 3.5
        case .exposed:      return 5.0    // Fast, irregular
        case .neutralizing: return 2.5
        case .cloaked:      return 0.8    // Slow, steady
        }
    }
    
    // Fallback inline shader source if .metal file can't be loaded
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; float2 uv; };
    vertex VertexOut coreOrbVertex(uint vertexID [[vertex_id]]) {
        float2 positions[6] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(-1,1), float2(1,-1), float2(1,1) };
        VertexOut out; out.position = float4(positions[vertexID], 0.0, 1.0); out.uv = (positions[vertexID] + 1.0) * 0.5; return out;
    }
    fragment float4 coreOrbFragment(VertexOut in [[stage_in]], constant float &time [[buffer(0)]], constant float3 &baseColor [[buffer(1)]], constant float &pulseRate [[buffer(2)]]) {
        float2 uv = in.uv * 2.0 - 1.0; float dist = length(uv);
        float sphere = 1.0 - smoothstep(0.35, 0.42, dist);
        float pulse = sin(time * pulseRate) * 0.5 + 0.5;
        float innerGlow = exp(-dist * 3.5) * (0.7 + 0.3 * pulse);
        float outerGlow = exp(-dist * 1.8) * 0.35 * (0.8 + 0.2 * pulse);
        float rim = smoothstep(0.15, 0.4, dist) * sphere;
        float3 core = baseColor * innerGlow * sphere;
        float3 halo = baseColor * outerGlow;
        float3 finalColor = core + baseColor * 1.3 * rim * 0.3 + halo;
        return float4(finalColor, max(sphere, outerGlow * 0.6));
    }
    """
}

// MARK: - SwiftUI Orb Wrapper (with glow effects)
struct CoreOrbSection: View {
    let appState: AppState
    let scanProgress: Double
    
    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(glowColor.opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
            
            // Metal rendered orb
            CoreOrbView(appState: appState)
                .frame(width: 250, height: 250)
                .clipShape(Circle())
            
            // Progress ring (during scan)
            if appState == .auditing {
                Circle()
                    .trim(from: 0, to: scanProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.cyan, .blue, .cyan],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: scanProgress)
            }
            
            // State label
            VStack(spacing: 4) {
                Text(stateLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(glowColor)
                
                if appState == .auditing {
                    Text("\(Int(scanProgress * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .offset(y: 145)
        }
    }
    
    private var stateLabel: String {
        switch appState {
        case .idle: return "STANDING BY"
        case .auditing: return "SCANNING"
        case .exposed: return "ITEMS FOUND"
        case .neutralizing: return "NEUTRALIZING"
        case .cloaked: return "PROTECTED"
        }
    }
    
    private var glowColor: Color {
        switch appState {
        case .idle: return .gray
        case .auditing: return .cyan
        case .exposed: return Color(hex: "FF2D2D")
        case .neutralizing: return .orange
        case .cloaked: return Color(hex: "00FF66")
        }
    }
}
