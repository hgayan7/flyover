import AppKit
@preconcurrency import SceneKit
import simd

/// Builds a lit, shaded 3D propeller plane (procedural geometry, no external assets)
/// towing a text banner, and animates it flying across the screen.
@MainActor
struct PlaneScene {
    let aspect: CGFloat
    let vehicle: Vehicle
    
    var duration: TimeInterval {
        return vehicle == .rocket ? 12.0 : 30.0
    }

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

        let body = buildVehicleBody()
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

    private func buildVehicleBody() -> SCNNode {
        switch vehicle {
        case .propellerPlane:
            return buildPropellerPlane()
        case .paperAirplane:
            return buildPaperAirplane()
        case .ufo:
            return buildUFO()
        case .rocket:
            return buildRocket()
        }
    }

    private func buildPropellerPlane() -> SCNNode {
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

    private func buildPaperAirplane() -> SCNNode {
        let body = SCNNode()

        // Vertices for a paper plane (facing +X)
        let vertices: [SCNVector3] = [
            SCNVector3(2.0, 0.0, 0.0),       // 0: Nose
            SCNVector3(-2.2, 0.2, 0.0),      // 1: Tail center fold top
            SCNVector3(-2.2, -0.6, 0.0),     // 2: Tail center fold bottom
            SCNVector3(-2.2, 0.5, -1.8),     // 3: Left wingtip
            SCNVector3(-2.2, 0.5, 1.8)       // 4: Right wingtip
        ]

        let indices: [Int32] = [
            0, 2, 1, // Keel left
            0, 1, 2, // Keel right
            0, 1, 3, // Left wing
            0, 4, 1  // Right wing
        ]

        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [source], elements: [element])

        let paperMat = SCNMaterial()
        paperMat.lightingModel = .physicallyBased
        paperMat.diffuse.contents = NSColor(calibratedWhite: 0.96, alpha: 1.0)
        paperMat.roughness.contents = 0.8
        paperMat.metalness.contents = 0.0
        paperMat.isDoubleSided = true
        geo.materials = [paperMat]

        let airplaneNode = SCNNode(geometry: geo)
        body.addChildNode(airplaneNode)

        let trailNode = SCNNode()
        trailNode.position = SCNVector3(-2.2, 0.1, 0)
        trailNode.addParticleSystem(buildStardust())
        body.addChildNode(trailNode)

        return body
    }

    private func buildStardust() -> SCNParticleSystem {
        let stars = SCNParticleSystem()
        stars.emitterShape = nil
        stars.birthRate = 25
        stars.particleLifeSpan = 1.5
        stars.particleLifeSpanVariation = 0.4
        stars.particleVelocity = 0.3
        stars.particleVelocityVariation = 0.1
        stars.emittingDirection = SCNVector3(-1, 0, 0)
        stars.spreadingAngle = 5
        stars.particleSize = 0.08
        stars.particleSizeVariation = 0.04
        stars.particleColor = NSColor(calibratedRed: 0.98, green: 0.9, blue: 0.5, alpha: 0.75)
        stars.blendMode = .screen
        stars.isLightingEnabled = false
        stars.isAffectedByGravity = false
        stars.particleImage = Self.puffImage()

        let fade = CAKeyframeAnimation()
        fade.values = [0.0, 0.8, 0.0]
        fade.keyTimes = [0.0, 0.15, 1.0]
        stars.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]

        return stars
    }

    private func buildUFO() -> SCNNode {
        let body = SCNNode()

        let metalMat = metal(NSColor(calibratedWhite: 0.72, alpha: 1.0), metalness: 0.9, roughness: 0.2)

        // Main saucer disk (squashed sphere)
        let disk = SCNSphere(radius: 2.0)
        disk.materials = [metalMat]
        let diskNode = SCNNode(geometry: disk)
        diskNode.scale = SCNVector3(1.0, 0.18, 1.0)
        body.addChildNode(diskNode)

        // Cockpit dome (glass sphere on top)
        let dome = SCNSphere(radius: 0.85)
        let glass = SCNMaterial()
        glass.lightingModel = .physicallyBased
        glass.diffuse.contents = NSColor(calibratedRed: 0.1, green: 0.6, blue: 0.8, alpha: 0.7)
        glass.metalness.contents = 0.9
        glass.roughness.contents = 0.05
        glass.transparencyMode = .dualLayer
        dome.materials = [glass]
        let domeNode = SCNNode(geometry: dome)
        domeNode.scale = SCNVector3(1.0, 0.6, 1.0)
        domeNode.position = SCNVector3(0, 0.22, 0)
        body.addChildNode(domeNode)

        // Small alien inside
        let pilot = SCNSphere(radius: 0.22)
        let alienMat = SCNMaterial()
        alienMat.diffuse.contents = NSColor.green
        pilot.materials = [alienMat]
        let pilotNode = SCNNode(geometry: pilot)
        pilotNode.position = SCNVector3(0, 0.3, 0)
        body.addChildNode(pilotNode)

        // Glowing rim lights
        let lightColors: [NSColor] = [.cyan, .yellow, .magenta, .orange, .green]
        for i in 0..<8 {
            let angle = Float(i) * Float.pi / 4.0
            let r: Float = 1.95
            let rimLight = SCNSphere(radius: 0.12)
            let lightMat = SCNMaterial()
            lightMat.lightingModel = .constant
            let color = lightColors[i % lightColors.count]
            lightMat.diffuse.contents = color
            lightMat.emission.contents = color
            rimLight.materials = [lightMat]

            let lightNode = SCNNode(geometry: rimLight)
            lightNode.position = SCNVector3(r * cos(angle), 0, r * sin(angle))
            body.addChildNode(lightNode)

            // Make them pulse
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.2, duration: 0.2),
                .fadeOpacity(to: 1.0, duration: 0.2)
            ])
            let wait = SCNAction.wait(duration: Double(i) * 0.05)
            lightNode.runAction(.sequence([wait, .repeatForever(pulse)]))
        }

        // Tractor beam underneath
        let beam = SCNCone(topRadius: 0.2, bottomRadius: 1.8, height: 5.5)
        let beamMat = SCNMaterial()
        beamMat.lightingModel = .constant
        beamMat.diffuse.contents = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.4, alpha: 0.2)
        beamMat.transparencyMode = .aOne
        beam.materials = [beamMat]
        let beamNode = SCNNode(geometry: beam)
        beamNode.position = SCNVector3(0, -2.8, 0)
        body.addChildNode(beamNode)

        // Exhaust plasma trail
        let plasmaNode = SCNNode()
        plasmaNode.position = SCNVector3(-1.9, 0, 0)
        plasmaNode.addParticleSystem(buildPlasmaTrail())
        body.addChildNode(plasmaNode)

        return body
    }

    private func buildPlasmaTrail() -> SCNParticleSystem {
        let plasma = SCNParticleSystem()
        plasma.emitterShape = nil
        plasma.birthRate = 90
        plasma.particleLifeSpan = 1.2
        plasma.particleLifeSpanVariation = 0.3
        plasma.particleVelocity = 0.6
        plasma.particleVelocityVariation = 0.2
        plasma.emittingDirection = SCNVector3(-1, 0, 0)
        plasma.spreadingAngle = 12
        plasma.particleSize = 0.16
        plasma.particleSizeVariation = 0.06
        plasma.particleColor = NSColor(calibratedRed: 0.0, green: 0.8, blue: 1.0, alpha: 0.7)
        plasma.blendMode = .screen
        plasma.isLightingEnabled = false
        plasma.isAffectedByGravity = false
        plasma.particleImage = Self.puffImage()
        plasma.particleAngularVelocity = 2.0

        let shrink = CABasicAnimation()
        shrink.fromValue = 0.16
        shrink.toValue = 0.02
        plasma.propertyControllers = [.size: SCNParticlePropertyController(animation: shrink)]

        let fade = CAKeyframeAnimation()
        fade.values = [0.0, 0.8, 0.0]
        fade.keyTimes = [0.0, 0.15, 1.0]
        plasma.propertyControllers?[.opacity] = SCNParticlePropertyController(animation: fade)

        return plasma
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
        let (image, imageAspect) = Self.bannerImage(message, for: vehicle)
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

        // Rope or laser from tail (~ -2.6) to banner's right edge.
        let tailX: CGFloat = -2.6
        let bannerRightX = centerX + width / 2
        let ropeLen = tailX - bannerRightX
        let rope = SCNCylinder(radius: 0.03, height: ropeLen)
        
        let ropeMat = SCNMaterial()
        if vehicle == .ufo {
            ropeMat.lightingModel = .constant
            let greenColor = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.4, alpha: 0.95)
            ropeMat.diffuse.contents = greenColor
            ropeMat.emission.contents = greenColor
        } else {
            ropeMat.lightingModel = .physicallyBased
            ropeMat.diffuse.contents = NSColor(calibratedWhite: 0.15, alpha: 1)
            ropeMat.metalness.contents = 0.0
            ropeMat.roughness.contents = 1.0
        }
        rope.materials = [ropeMat]
        
        let ropeNode = SCNNode(geometry: rope)
        ropeNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)   // lay along X
        ropeNode.position = SCNVector3(Float(bannerRightX + ropeLen / 2), 0, 0)

        return (bannerNode, ropeNode)
    }

    /// Render the message to an NSImage used as the banner texture. Returns (image, width/height).
    static func bannerImage(_ text: String, for vehicle: Vehicle) -> (NSImage, CGFloat) {
        let font = NSFont.systemFont(ofSize: 72, weight: .heavy)
        let foregroundColor: NSColor
        switch vehicle {
        case .paperAirplane:
            foregroundColor = NSColor.darkGray
        case .ufo:
            foregroundColor = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.4, alpha: 1.0)
        default:
            foregroundColor = NSColor.white
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: foregroundColor
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let padX: CGFloat = 70, padY: CGFloat = 46
        let w = ceil(textSize.width + padX * 2)
        let h = ceil(textSize.height + padY * 2)

        let img = NSImage(size: NSSize(width: w, height: h))
        img.lockFocus()
        let full = NSRect(x: 0, y: 0, width: w, height: h)
        let banner = NSBezierPath(roundedRect: full.insetBy(dx: 8, dy: 8), xRadius: 28, yRadius: 28)
        
        if vehicle == .paperAirplane {
            NSColor(calibratedWhite: 0.95, alpha: 0.96).setFill()
            banner.fill()
            NSColor.darkGray.setStroke()
            banner.lineWidth = 6
            banner.stroke()
        } else if vehicle == .ufo {
            NSColor(calibratedRed: 0.05, green: 0.15, blue: 0.05, alpha: 0.75).setFill()
            banner.fill()
            NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.4, alpha: 0.9).setStroke()
            banner.lineWidth = 8
            banner.stroke()
        } else {
            NSColor(calibratedRed: 0.86, green: 0.18, blue: 0.20, alpha: 0.96).setFill()
            banner.fill()
            NSColor.white.setStroke()
            banner.lineWidth = 10
            banner.stroke()
        }
        (text as NSString).draw(at: NSPoint(x: padX, y: padY), withAttributes: attrs)
        img.unlockFocus()
        return (img, w / h)
    }

    private func buildRocket() -> SCNNode {
        let rocket = SCNNode()
        
        let metalMat = metal(NSColor(calibratedRed: 0.88, green: 0.15, blue: 0.15, alpha: 1.0), metalness: 0.7, roughness: 0.3)
        let trimMat = metal(NSColor(calibratedWhite: 0.9, alpha: 1.0), metalness: 0.8, roughness: 0.2)
        
        let bodyGeo = SCNCylinder(radius: 0.5, height: 3.0)
        bodyGeo.materials = [trimMat]
        let bodyNode = SCNNode(geometry: bodyGeo)
        bodyNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        rocket.addChildNode(bodyNode)
        
        let noseGeo = SCNCone(topRadius: 0, bottomRadius: 0.5, height: 1.2)
        noseGeo.materials = [metalMat]
        let noseNode = SCNNode(geometry: noseGeo)
        noseNode.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        noseNode.position = SCNVector3(2.1, 0, 0)
        rocket.addChildNode(noseNode)
        
        let nozzleGeo = SCNCone(topRadius: 0.5, bottomRadius: 0.3, height: 0.5)
        nozzleGeo.materials = [metal(NSColor.darkGray, metalness: 0.9, roughness: 0.5)]
        let nozzleNode = SCNNode(geometry: nozzleGeo)
        nozzleNode.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        nozzleNode.position = SCNVector3(-1.75, 0, 0)
        rocket.addChildNode(nozzleNode)
        
        for i in 0..<3 {
            let angle = Float(i) * 2 * Float.pi / 3.0
            let finGeo = SCNBox(width: 0.8, height: 0.8, length: 0.08, chamferRadius: 0.04)
            finGeo.materials = [metalMat]
            let finNode = SCNNode(geometry: finGeo)
            
            let r: Float = 0.5
            finNode.position = SCNVector3(-1.2, r * cos(angle), r * sin(angle))
            finNode.eulerAngles = SCNVector3(-angle, 0, Float.pi / 4)
            rocket.addChildNode(finNode)
        }
        
        let fireNode = SCNNode()
        fireNode.position = SCNVector3(-2.1, 0, 0)
        fireNode.addParticleSystem(buildRocketFire())
        rocket.addChildNode(fireNode)
        
        return rocket
    }

    private func buildRocketFire() -> SCNParticleSystem {
        let fire = SCNParticleSystem()
        fire.emitterShape = nil
        fire.birthRate = 120
        fire.particleLifeSpan = 0.8
        fire.particleLifeSpanVariation = 0.2
        fire.particleVelocity = 3.5
        fire.particleVelocityVariation = 0.8
        fire.emittingDirection = SCNVector3(-1, 0, 0)
        fire.spreadingAngle = 8
        fire.particleSize = 0.35
        fire.particleSizeVariation = 0.15
        fire.particleColor = NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.0, alpha: 0.8)
        fire.blendMode = .additive
        fire.isLightingEnabled = false
        fire.isAffectedByGravity = false
        fire.particleImage = Self.puffImage()
        
        let shrink = CABasicAnimation()
        shrink.fromValue = 0.35
        shrink.toValue = 0.05
        fire.propertyControllers = [.size: SCNParticlePropertyController(animation: shrink)]
        
        let colorShift = CAKeyframeAnimation()
        colorShift.values = [
            NSColor.white.cgColor,
            NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.0, alpha: 0.9).cgColor,
            NSColor(calibratedRed: 1.0, green: 0.3, blue: 0.0, alpha: 0.7).cgColor,
            NSColor(calibratedWhite: 0.2, alpha: 0.0).cgColor
        ]
        colorShift.keyTimes = [0.0, 0.2, 0.6, 1.0]
        fire.propertyControllers?[.color] = SCNParticlePropertyController(animation: colorShift)
        
        return fire
    }

    // MARK: - Animation

    private func animate(flight: SCNNode, body: SCNNode, completion: @escaping () -> Void) {
        flight.scale = SCNVector3(flightScale, flightScale, flightScale)
        body.eulerAngles = SCNVector3(0, 0, 0)

        let camDistance = 26.0
        let halfH = tan((42.0 / 2) * .pi / 180) * camDistance
        let halfW = halfH * Double(aspect)

        let total = duration
        let laps = 2.0
        let ampX = Float(halfW * 0.34)
        let depthAmp: Float = 5
        let depthMid: Float = -3
        let altMid = Float(halfH * 0.06)
        let altAmp = Float(halfH * 0.16)

        let path: (Float) -> SIMD3<Float> = { s in
            SIMD3(ampX * sinf(s),
                  altMid + altAmp * sinf(2 * s),
                  depthMid + depthAmp * cosf(s))
        }

        let up = SIMD3<Float>(0, 1, 0)
        let noseAxis = SIMD3<Float>(1, 0, 0)
        let wingAxis = SIMD3<Float>(0, 0, 1)

        let fly = SCNAction.customAction(duration: total) { node, elapsed in
            let t = Float(elapsed / total)
            
            if vehicle == .rocket {
                let x = Float(-halfW * 1.5) + t * Float(halfW * 3.0)
                let y = Float(-halfH * 1.1) + Float(halfH * 2.3) * (t * t)
                let z = Float(-10) + t * 15.0
                node.simdPosition = SIMD3(x, y, z)
                
                let dt: Float = 0.01
                let nextY = Float(-halfH * 1.1) + Float(halfH * 2.3) * ((t + dt) * (t + dt))
                let nextX = Float(-halfW * 1.5) + (t + dt) * Float(halfW * 3.0)
                let nextZ = Float(-10) + (t + dt) * 15.0
                let v = SIMD3(nextX - x, nextY - y, nextZ - z)
                let hSpeed = max(1e-4, sqrtf(v.x * v.x + v.z * v.z))
                
                let yaw = atan2f(-v.z, v.x)
                let pitch = atan2f(v.y, hSpeed)
                
                let qYaw = simd_quatf(angle: yaw, axis: up)
                let qPitch = simd_quatf(angle: pitch, axis: qYaw.act(wingAxis))
                node.simdOrientation = qPitch * qYaw
                body.simdOrientation = simd_quatf(angle: 0, axis: up)
                
            } else if vehicle == .ufo {
                let s = t * Float(laps) * 2 * .pi
                let stepCount: Float = 6.0
                let step = floorf(s * stepCount / (2 * .pi))
                let phase = (s * stepCount / (2 * .pi)) - step
                
                let tStep = phase < 0.65 ? (phase / 0.65) : 1.0
                let smoothT = tStep * tStep * (3 - 2 * tStep)
                let sDiscrete1 = (step) * 2 * .pi / stepCount
                let sDiscrete2 = (step + 1) * 2 * .pi / stepCount
                let sInterpolated = sDiscrete1 + (sDiscrete2 - sDiscrete1) * smoothT
                
                var p = path(sInterpolated)
                
                if phase >= 0.65 {
                    let hoverPhase = (phase - 0.65) / 0.35
                    p.y += sinf(hoverPhase * .pi * 2) * 0.15
                }
                node.simdPosition = p
                
                let ds: Float = 0.02
                let pPrev = path(sInterpolated - ds), pNext = path(sInterpolated + ds)
                let v = pNext - pPrev
                let baseYaw = atan2f(-v.z, v.x)
                
                // Keep the flight rig oriented towards heading so the banner trails stably
                node.simdOrientation = simd_quatf(angle: baseYaw, axis: up)
                
                // Spin only the UFO body disc
                let spin = Float(elapsed) * 4.5
                body.simdOrientation = simd_quatf(angle: spin, axis: up)
                
            } else {
                let s = t * Float(laps) * 2 * .pi
                let ds: Float = 0.02
                
                var pPrev = path(s - ds), p0 = path(s), pNext = path(s + ds)
                
                if vehicle == .paperAirplane {
                    let windFreq = s * 7.5
                    let drift = SIMD3<Float>(
                        sinf(windFreq) * 0.08,
                        cosf(windFreq * 0.8) * 0.07,
                        sinf(windFreq * 1.2) * 0.06
                    )
                    p0 += drift
                    pPrev += drift
                    pNext += drift
                }
                
                node.simdPosition = p0
                
                let v = (pNext - pPrev) / (2 * ds)
                let a = (pNext - 2 * p0 + pPrev) / (ds * ds)
                let hSpeed = max(1e-4, sqrtf(v.x * v.x + v.z * v.z))
                
                let yaw = atan2f(-v.z, v.x)
                var pitch = max(-0.5, min(0.5, atan2f(v.y, hSpeed) * 1.1))
                let curv = (v.x * a.z - v.z * a.x) / (hSpeed * hSpeed)
                var roll = max(-0.65, min(0.65, 1.6 * curv))
                
                if vehicle == .paperAirplane {
                    pitch += sinf(s * 15.0) * 0.05
                    roll += cosf(s * 12.0) * 0.07
                }
                
                let qYaw = simd_quatf(angle: yaw, axis: up)
                let qPitch = simd_quatf(angle: pitch, axis: qYaw.act(wingAxis))
                let fwd = (qPitch * qYaw).act(noseAxis)
                let qRoll = simd_quatf(angle: roll, axis: fwd)
                node.simdOrientation = qRoll * qPitch * qYaw
                body.simdOrientation = simd_quatf(angle: 0, axis: up)
            }
        }

        if vehicle == .rocket {
            let startX = Float(-halfW * 1.5)
            let startY = Float(-halfH * 1.1)
            let startZ = Float(-10)
            flight.simdPosition = SIMD3(startX, startY, startZ)
        } else {
            flight.simdPosition = path(0)
        }
        
        flight.runAction(fly) {
            Task { @MainActor in completion() }
        }
    }
}
