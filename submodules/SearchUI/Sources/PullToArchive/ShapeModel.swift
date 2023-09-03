import UIKit

extension PullToArchiveView {
    
    struct LineModel {
        let startPoint: CGPoint
        let endPoint: CGPoint
    }

    struct ShapeModel {
        let firstLine: LineModel
        let secondLine: LineModel
        let thirdLine: LineModel

        var path: UIBezierPath {

            let path = UIBezierPath()

            path.move(to: firstLine.startPoint)
            path.addLine(to: firstLine.endPoint)
            path.addLine(to: secondLine.endPoint)

            path.move(to: thirdLine.startPoint)
            path.addLine(to: thirdLine.endPoint)

            return path
        }
    }
}
