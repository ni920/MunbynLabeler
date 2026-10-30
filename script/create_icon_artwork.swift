import AppKit
import Foundation

// Original, deterministic vector artwork. No font glyphs, stock symbols or raster source.
struct Shape {
    enum Command { case move(CGFloat, CGFloat), line(CGFloat, CGFloat), curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat), close }
    var commands: [Command]
    var path: CGPath {
        let p = CGMutablePath()
        for command in commands {
            switch command {
            case let .move(x,y): p.move(to: CGPoint(x:x,y:y))
            case let .line(x,y): p.addLine(to: CGPoint(x:x,y:y))
            case let .curve(x1,y1,x2,y2,x,y): p.addCurve(to: CGPoint(x:x,y:y), control1: CGPoint(x:x1,y:y1), control2: CGPoint(x:x2,y:y2))
            case .close: p.closeSubpath()
            }
        }
        return p
    }
    var svgPath: String {
        commands.map { command in
            switch command {
            case let .move(x,y): "M\(x) \(y)"
            case let .line(x,y): "L\(x) \(y)"
            case let .curve(a,b,c,d,x,y): "C\(a) \(b) \(c) \(d) \(x) \(y)"
            case .close: "Z"
            }
        }.joined(separator: " ")
    }
}
let paper = Shape(commands: [
    .move(244,286), .line(780,286), .curve(806.5,286,828,307.5,828,334),
    .line(828,616), .line(708,738), .line(244,738),
    .curve(217.5,738,196,716.5,196,690), .line(196,334),
    .curve(196,307.5,217.5,286,244,286), .close
])
let peel = Shape(commands: [
    .move(708,738), .line(708,664), .curve(708,637.5,729.5,616,756,616),
    .line(828,616), .close
])
func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Shape {
    let k: CGFloat = 0.5522847498
    return Shape(commands: [
        .move(x+r,y),.line(x+w-r,y),.curve(x+w-r+k*r,y,x+w,y+r-k*r,x+w,y+r),
        .line(x+w,y+h-r),.curve(x+w,y+h-r+k*r,x+w-r+k*r,y+h,x+w-r,y+h),
        .line(x+r,y+h),.curve(x+r-k*r,y+h,x,y+h-r+k*r,x,y+h-r),
        .line(x,y+r),.curve(x,y+r-k*r,x+r-k*r,y,x+r,y),.close
    ])
}
let ink = [roundedRect(280,394,336,30,15), roundedRect(280,464,272,30,15), roundedRect(280,534,188,30,15)]
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Resources/IconArtwork")
let previews = root.appendingPathComponent("Resources/IconPreviews")
try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)

func writeSVG(_ name: String, shapes: [Shape]) throws {
    let paths = shapes.map { "  <path d=\"\($0.svgPath)\" fill=\"#FFFFFF\"/>" }.joined(separator: "\n")
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    \(paths)
    </svg>
    """
    try (svg + "\n").write(to: source.appendingPathComponent(name), atomically: true, encoding: .utf8)
}
try writeSVG("label.svg", shapes: [paper])
try writeSVG("peel.svg", shapes: [peel])
try writeSVG("address.svg", shapes: ink)

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1)
}
struct Palette {
    var top: UInt32; var bottom: UInt32; var paper: UInt32; var peel: UInt32; var ink: UInt32
}
let palettes: [(String, Palette)] = [
    ("default", Palette(top: 0x367CE6, bottom: 0x1854B2, paper: 0xFFFFFF, peel: 0xBDD4F5, ink: 0x29476F)),
    ("dark", Palette(top: 0x19385F, bottom: 0x0B1D36, paper: 0xD5E1F2, peel: 0x7D9FC9, ink: 0x203B60)),
    ("mono", Palette(top: 0x4D5664, bottom: 0x252E3C, paper: 0xF0F1F4, peel: 0xAFB7C4, ink: 0x303B4B))
]
func render(size: Int, palette: Palette, url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:0,space:space,
                            bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x:0,y:CGFloat(size));context.scaleBy(x:CGFloat(size)/1024,y:-CGFloat(size)/1024)
    context.setAllowsAntialiasing(true);context.setShouldAntialias(true)
    // A classic macOS ICNS fallback uses an inset backplate. The .icon SVG layers
    // themselves remain unmasked; Icon Composer supplies its system enclosure.
    let plate = roundedRect(100,100,824,824,185)
    context.saveGState();context.addPath(plate.path);context.clip()
    let gradient = CGGradient(colorsSpace:space,colors:[color(palette.top),color(palette.bottom)] as CFArray,locations:[0,1])!
    context.drawLinearGradient(gradient,start:CGPoint(x:512,y:100),end:CGPoint(x:512,y:924),options:[])
    context.restoreGState()
    context.saveGState();context.translateBy(x:100,y:100);context.scaleBy(x:824/1024,y:824/1024)
    context.saveGState();context.setShadow(offset:CGSize(width:0,height:7),blur:16,color:CGColor(gray:0,alpha:0.14))
    context.setFillColor(color(palette.paper));context.addPath(paper.path);context.fillPath();context.restoreGState()
    context.setFillColor(color(palette.peel));context.addPath(peel.path);context.fillPath()
    context.setFillColor(color(palette.ink));for line in ink { context.addPath(line.path);context.fillPath() }
    context.restoreGState()
    let image = context.makeImage()!
    let data = NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
    try data.write(to:url,options:.atomic)
}
for (name,palette) in palettes {
    try render(size:1024,palette:palette,url:previews.appendingPathComponent("\(name)-1024.png"))
    for size in [16,32,64,128,256] { try render(size:size,palette:palette,url:previews.appendingPathComponent("\(name)-\(size).png")) }
}
try Data(contentsOf:previews.appendingPathComponent("default-1024.png")).write(to:source.appendingPathComponent("fallback-1024.png"),options:.atomic)
print("Original SVG layers and compatible previews generated.")

func colorString(_ value: UInt32) -> String {
    String(format: "srgb:%.6f,%.6f,%.6f,1.000000", Double((value >> 16) & 255)/255, Double((value >> 8) & 255)/255, Double(value & 255)/255)
}
func fills(_ base: UInt32, _ dark: UInt32, _ mono: UInt32) -> [[String: Any]] {
    [["value": ["solid": colorString(base)]], ["appearance": "dark", "value": ["solid": colorString(dark)]], ["appearance": "tinted", "value": ["solid": colorString(mono)]]]
}
let document: [String: Any] = [
    "color-space-for-untagged-svg-colors": "srgb",
    "fill-specializations": [
        ["value": ["linear-gradient": [colorString(palettes[0].1.top), colorString(palettes[0].1.bottom)]]],
        ["appearance": "dark", "value": ["linear-gradient": [colorString(palettes[1].1.top), colorString(palettes[1].1.bottom)]]],
        ["appearance": "tinted", "value": "automatic"]
    ],
    "groups": [
        ["name": "Address", "lighting": "individual", "specular": false,
         "shadow": ["kind": "none", "opacity": 0], "translucency": ["enabled": false, "value": 0],
         "layers": [["name": "Address lines", "image-name": "address.svg", "glass": false,
                     "fill-specializations": fills(palettes[0].1.ink, palettes[1].1.ink, palettes[2].1.ink)]]],
        ["name": "Peel", "lighting": "individual", "specular": true,
         "shadow": ["kind": "neutral", "opacity": 0.12], "translucency": ["enabled": true, "value": 0.15],
         "layers": [["name": "Peeled corner", "image-name": "peel.svg", "glass": true,
                     "fill-specializations": fills(palettes[0].1.peel, palettes[1].1.peel, palettes[2].1.peel)]]],
        ["name": "Label", "lighting": "individual", "specular": true,
         "shadow": ["kind": "neutral", "opacity": 0.18], "translucency": ["enabled": true, "value": 0.08],
         "layers": [["name": "Shipping label", "image-name": "label.svg", "glass": true,
                     "fill-specializations": fills(palettes[0].1.paper, palettes[1].1.paper, palettes[2].1.paper)]]]
    ],
    "supported-platforms": ["squares": "shared"]
]
let json = try JSONSerialization.data(withJSONObject:document,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
try (json + Data("\n".utf8)).write(to:source.appendingPathComponent("icon-document.json"),options:.atomic)
print("Icon Composer document prepared (1.x and 2.x compatible).")
