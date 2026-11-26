import SwiftUI
import SudokuCore

struct GridLines: Shape {
    var boxesOnly = false
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = rect.width / 9
        for i in 0...9 where !boxesOnly || i % 3 == 0 {
            if boxesOnly == false && i % 3 == 0 { continue }
            let x = CGFloat(i) * step
            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rect.height))
            p.move(to: CGPoint(x: 0, y: x)); p.addLine(to: CGPoint(x: rect.width, y: x))
        }
        return p
    }
}
