import AppKit
import SceneKit
import simd

/// Builds a lit, shaded 3D propeller plane (procedural geometry, no external assets)
/// towing a text banner, and animates it flying across the screen.
@MainActor
struct PlaneScene {
    let aspect: CGFloat
    /// How long the fly-through lasts, in seconds.
    let duration: TimeInterval = 30.0

    /// Overall on-screen size of the plane + banner. Smaller = less intrusive.
    private let flightScale: Float = 0.5

    func makeScene(message: String, completion: @escaping () -> Void) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = nil   // transparent — window shows through

        addCamera(to: scene)
        addLights(to: scene)

        // Everything that flies lives under one node we translate across X.
        let flight = SCNNode()
        scene.rootNode.addChildNode(flight)

        let body = buildPlaneBody()
        flight.addChildNode(body)

        let (banner, ropeAnchor) = buildBanner(message: message)
        flight.addChildNode(banner)
        flight.addChildNode(ropeAnchor)

        animate(flight: flight, body: body, completion: completion)
        return scene
    }

    // MARK: - Camera & lights

    private func addCamera(to scene: SCNScene) {
        let cam = SCNCamera()
        cam.fieldOfView = 42
        cam.zNear = 0.1
        cam.zFar = 200
        let node = SCNNode()
        node.camera = cam
        node.position = SCNVector3(0, 3, 26)

        let look = SCNLookAtConstraint(target: {
            let t = SCNNode(); t.position = SCNVector3(0, 0, 0); scene.rootNode.addChildNode(t); return t
        }())
        look.isGimbalLockEnabled = true
        node.constraints = [look]
        scene.rootNode.addChildNode(node)
    }

    private func addLights(to scene: SCNScene) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 350
        ambient.color = NSColor(calibratedWhite: 1, alpha: 1)
        let ambientNode = SCNNode(); ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 950
        key.castsShadow = false
        let keyNode = SCNNode(); keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 450
        let fillNode = SCNNode(); fillNode.light = fill
        fillNode.position = SCNVector3(6, 8, 12)
        scene.rootNode.addChildNode(fillNode)
    }

    // MARK: - Materials

    private func metal(_ color: NSColor, metalness: CGFloat = 0.55, roughness: CGFloat = 0.35) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.metalness.contents = metalness
        m.roughness.contents = roughness
        return m
    }

    // MARK: - Plane geometry (nose points toward +X, wings span Z)

    private func buildPlaneBody() -> SCNNode {
        let body = SCNNode()

        let fuselageColor = NSColor(calibratedRed: 0.92, green: 0.93, blue: 0.96, alpha: 1)
        let accent = NSColor(calibratedRed: 0.86, green: 0.18, blue: 0.20, alpha: 1)

        // Fuselage (capsule laid along X)
        let fuselage = SCNCapsule(capRadius: 0.55, height: 5.2)
        fuselage.materials = [metal(fuselageColor)]
        let fuselageNode = SCNNode(geometry: fuselage)
        fuselageNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        body.addChildNode(fuselageNode)

        // Nose cone
        let nose = SCNCone(topRadius: 0, bottomRadius: 0.55, height: 1.2)
        nose.materials = [metal(accent, metalness: 0.2, roughness: 0.5)]
        let noseNode = SCNNode(geometry: nose)
        noseNode.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        noseNode.position = SCNVector3(3.2, 0, 0)
        body.addChildNode(noseNode)

        // Cockpit canopy
        let canopy = SCNSphere(radius: 0.5)
        let glass = SCNMaterial()
        glass.lightingModel = .physicallyBased
        glass.diffuse.contents = NSColor(calibratedRed: 0.28, green: 0.5, blue: 0.62, alpha: 1)
        glass.metalness.contents = 0.9
        glass.roughness.contents = 0.05
        canopy.materials = [glass]
        let canopyNode = SCNNode(geometry: canopy)
        canopyNode.scale = SCNVector3(1.5, 0.7, 0.9)
        canopyNode.position = SCNVector3(0.9, 0.5, 0)
        body.addChildNode(canopyNode)

        // Main wings (span along Z)
        let wing = SCNBox(width: 1.8, height: 0.14, length: 7.6, chamferRadius: 0.06)
        wing.materials = [metal(accent, metalness: 0.3, roughness: 0.45)]
        let wingNode = SCNNode(geometry: wing)
        wingNode.position = SCNVector3(0.2, -0.05, 0)
        body.addChildNode(wingNode)

        // Vertical stabilizer (tail fin)
        let fin = SCNBox(width: 1.2, height: 1.3, length: 0.14, chamferRadius: 0.05)
        fin.materials = [metal(accent, metalness: 0.3, roughness: 0.45)]
        let finNode = SCNNode(geometry: fin)
        finNode.position = SCNVector3(-2.3, 0.65, 0)
        body.addChildNode(finNode)

        // Horizontal stabilizers
        let hStab = SCNBox(width: 1.0, height: 0.12, length: 2.8, chamferRadius: 0.05)
        hStab.materials = [metal(fuselageColor)]
        let hStabNode = SCNNode(geometry: hStab)
        hStabNode.position = SCNVector3(-2.4, 0.15, 0)
        body.addChildNode(hStabNode)

        // Spinning propeller at the nose
        body.addChildNode(buildPropeller(at: SCNVector3(3.9, 0, 0)))

        // Exhaust smoke trailing out the tail
        let smokeNode = SCNNode()
        smokeNode.position = SCNVector3(-2.9, -0.05, 0)
        smokeNode.addParticleSystem(buildSmoke())
        body.addChildNode(smokeNode)

        return body
    }

    /// A soft white smoke plume that streams from the tail. Particles are born in the
    /// scene's coordinate space, so they hang in the air and trail behind the plane.
    private func buildSmoke() -> SCNParticleSystem {
        let smoke = SCNParticleSystem()
        smoke.emitterShape = nil
        smoke.birthRate = 80
        smoke.particleLifeSpan = 2.0
        smoke.particleLifeSpanVariation = 0.6
        smoke.particleVelocity = 0.5
        smoke.particleVelocityVariation = 0.3
        smoke.emittingDirection = SCNVector3(-1, 0, 0)   // out the back (local −X)
        smoke.spreadingAngle = 9
        smoke.particleSize = 0.25
        smoke.particleSizeVariation = 0.1
        smoke.particleColor = NSColor(calibratedWhite: 0.96, alpha: 0.55)
        smoke.blendMode = .alpha
        smoke.isLightingEnabled = false
        smoke.isAffectedByGravity = false
        smoke.particleImage = Self.puffImage()
        smoke.particleAngularVelocity = 1.5
        smoke.particleAngularVelocityVariation = 2.5

        // Puffs expand as they age…
        let grow = CABasicAnimation()
        grow.fromValue = 0.12
        grow.toValue = 0.9
        smoke.propertyControllers = [.size: SCNParticlePropertyController(animation: grow)]

        // …and fade in then dissipate.
        let fade = CAKeyframeAnimation()
        fade.values = [0.0, 0.55, 0.0]
        fade.keyTimes = [0.0, 0.15, 1.0]
        smoke.propertyControllers?[.opacity] = SCNParticlePropertyController(animation: fade)

        return smoke
    }

    /// A soft radial-gradient puff used as the smoke particle texture.
    static func puffImage() -> NSImage {
        let side = 64
        let img = NSImage(size: NSSize(width: side, height: side))
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            let colors = [NSColor(calibratedWhite: 1, alpha: 1).cgColor,
                          NSColor(calibratedWhite: 1, alpha: 0).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 1]) {
                let c = CGPoint(x: side / 2, y: side / 2)
                ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                       endCenter: c, endRadius: CGFloat(side) / 2, options: [])
            }
        }
        img.unlockFocus()
        return img
    }

    private func buildPropeller(at position: SCNVector3) -> SCNNode {
        let prop = SCNNode()
        prop.position = position

        let hub = SCNSphere(radius: 0.2)
        hub.materials = [metal(NSColor.darkGray, metalness: 0.8, roughness: 0.3)]
        prop.addChildNode(SCNNode(geometry: hub))

        let bladeMat = metal(NSColor(calibratedWhite: 0.12, alpha: 1), metalness: 0.4, roughness: 0.6)
        // Two blades crossed in the Y-Z plane (perpendicular to the flight/prop axis).
        let bladeY = SCNBox(width: 0.06, height: 2.4, length: 0.22, chamferRadius: 0.03)
        bladeY.materials = [bladeMat]
        prop.addChildNode(SCNNode(geometry: bladeY))

        let bladeZ = SCNBox(width: 0.06, height: 0.22, length: 2.4, chamferRadius: 0.03)
        bladeZ.materials = [bladeMat]
        prop.addChildNode(SCNNode(geometry: bladeZ))

        // Spin fast about the X (flight) axis, forever.
        prop.runAction(.repeatForever(.rotate(by: .pi * 2, around: SCNVector3(1, 0, 0), duration: 0.12)))
        return prop
    }

    // MARK: - Banner

    /// Returns the banner node (trailing behind, on the −X side) and a thin rope node
    /// linking it to the tail.
    private func buildBanner(message: String) -> (SCNNode, SCNNode) {
        let (image, imageAspect) = Self.bannerImage(message)
        // Keep the banner within a sane on-screen width regardless of message length.
        let maxWidth: CGFloat = 13
        var height: CGFloat = 2.4
        var width = height * imageAspect
        if width > maxWidth {
            let scale = maxWidth / width
            width *= scale
            height *= scale
        }
        let gap: CGFloat = 1.0

        // Build one single-sided face; the text reads correctly only from its +Z side.
        func makeFace() -> SCNNode {
            let plane = SCNPlane(width: width, height: height)
            let mat = SCNMaterial()
            mat.diffuse.contents = image
            mat.isDoubleSided = false            // no mirrored back face
            mat.lightingModel = .constant        // stays legible regardless of lighting
            mat.transparencyMode = .aOne         // use the image's real alpha channel
            plane.materials = [mat]
            return SCNNode(geometry: plane)
        }

        // Two back-to-back faces: `front` reads when the plane flies right, `back`
        // (flipped 180° about Y) reads when the plane has turned to fly left. Whichever
        // side faces the camera always shows unmirrored text.
        let bannerNode = SCNNode()
        let front = makeFace()
        let back = makeFace()
        back.eulerAngles = SCNVector3(0, Float.pi, 0)
        bannerNode.addChildNode(front)
        bannerNode.addChildNode(back)

        // Right edge sits just left of the tail.
        let centerX = -(2.6 + gap + width / 2)
        bannerNode.position = SCNVector3(Float(centerX), 0, 0)

        // Rope from tail (~ -2.6) to banner's right edge.
        let tailX: CGFloat = -2.6
        let bannerRightX = centerX + width / 2
        let ropeLen = tailX - bannerRightX
        let rope = SCNCylinder(radius: 0.03, height: ropeLen)
        rope.materials = [metal(NSColor(calibratedWhite: 0.15, alpha: 1), metalness: 0, roughness: 1)]
        let ropeNode = SCNNode(geometry: rope)
        ropeNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)   // lay along X
        ropeNode.position = SCNVector3(Float(bannerRightX + ropeLen / 2), 0, 0)

        return (bannerNode, ropeNode)
    }

    /// Render the message to an NSImage used as the banner texture. Returns (image, width/height).
    static func bannerImage(_ text: String) -> (NSImage, CGFloat) {
        let font = NSFont.systemFont(ofSize: 72, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let padX: CGFloat = 70, padY: CGFloat = 46
        let w = ceil(textSize.width + padX * 2)
        let h = ceil(textSize.height + padY * 2)

        let img = NSImage(size: NSSize(width: w, height: h))
        img.lockFocus()
        let full = NSRect(x: 0, y: 0, width: w, height: h)
        let banner = NSBezierPath(roundedRect: full.insetBy(dx: 8, dy: 8), xRadius: 28, yRadius: 28)
        NSColor(calibratedRed: 0.86, green: 0.18, blue: 0.20, alpha: 0.96).setFill()
        banner.fill()
        NSColor.white.setStroke()
        banner.lineWidth = 10
        banner.stroke()
        (text as NSString).draw(at: NSPoint(x: padX, y: padY), withAttributes: attrs)
        img.unlockFocus()
        return (img, w / h)
    }

    // MARK: - Animation

    private func animate(flight: SCNNode, body: SCNNode, completion: @escaping () -> Void) {
        // Shrink the whole rig so it stays unobtrusive.
        flight.scale = SCNVector3(flightScale, flightScale, flightScale)
        body.eulerAngles = SCNVector3(0, 0, 0)   // orientation is driven dynamically below

        // Visible half-extents at the flight plane (z = 0), derived from the camera
        // geometry, so the plane stays fully on screen the whole time.
        let camDistance = 26.0
        let halfH = tan((42.0 / 2) * .pi / 180) * camDistance
        let halfW = halfH * Double(aspect)

        // A smooth, banked circuit in the horizontal plane (X across, Z depth) with a
        // gentle altitude weave — the plane loops around like a real banner plane.
        let total = duration
        let laps = 2.0
        let ampX = Float(halfW * 0.34)     // horizontal reach (kept inside the frame)
        let depthAmp: Float = 5            // how far it swings toward / away from camera
        let depthMid: Float = -3           // stay behind the z = 0 plane
        let altMid = Float(halfH * 0.06)
        let altAmp = Float(halfH * 0.16)   // climb / descend twice per lap

        // Parametric flight path P(s), s = arc phase in radians.
        let path: (Float) -> SIMD3<Float> = { s in
            SIMD3(ampX * sinf(s),
                  altMid + altAmp * sinf(2 * s),
                  depthMid + depthAmp * cosf(s))
        }

        // Physics-flavoured orientation: nose along velocity, pitch into climb/dive,
        // bank into turns. Derived per frame from finite differences of the path.
        let bankGain: Float = 1.6, maxBank: Float = 0.65
        let pitchGain: Float = 1.1, maxPitch: Float = 0.5
        let up = SIMD3<Float>(0, 1, 0)
        let noseAxis = SIMD3<Float>(1, 0, 0)
        let wingAxis = SIMD3<Float>(0, 0, 1)

        let fly = SCNAction.customAction(duration: total) { node, elapsed in
            let s = Float(elapsed / total) * Float(laps) * 2 * .pi
            let ds: Float = 0.02
            let pPrev = path(s - ds), p0 = path(s), pNext = path(s + ds)
            node.simdPosition = p0

            let v = (pNext - pPrev) / (2 * ds)          // velocity
            let a = (pNext - 2 * p0 + pPrev) / (ds * ds) // acceleration
            let hSpeed = max(1e-4, sqrtf(v.x * v.x + v.z * v.z))

            let yaw = atan2f(-v.z, v.x)                                 // heading about vertical
            let pitch = max(-maxPitch, min(maxPitch, atan2f(v.y, hSpeed) * pitchGain))
            let curv = (v.x * a.z - v.z * a.x) / (hSpeed * hSpeed)      // signed horizontal turn
            let roll = max(-maxBank, min(maxBank, bankGain * curv))     // bank into the turn

            let qYaw = simd_quatf(angle: yaw, axis: up)
            let qPitch = simd_quatf(angle: pitch, axis: qYaw.act(wingAxis))
            let fwd = (qPitch * qYaw).act(noseAxis)
            let qRoll = simd_quatf(angle: roll, axis: fwd)
            node.simdOrientation = qRoll * qPitch * qYaw
        }

        flight.simdPosition = path(0)
        flight.runAction(fly) {
            // SceneKit calls this off the main thread.
            Task { @MainActor in completion() }
        }
    }
}
