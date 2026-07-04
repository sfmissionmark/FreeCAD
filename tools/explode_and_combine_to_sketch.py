import FreeCAD
import FreeCADGui
import Draft
import Sketcher

def collect_wires(obj, wires):
    # Recursively collect wires from object
    if hasattr(obj, "Shape"):
        if obj.Shape.Wires:
            wires.extend(obj.Shape.Wires)
    # Recurse into groups/compounds
    if hasattr(obj, "OutList"):
        for child in obj.OutList:
            collect_wires(child, wires)

def main():
    doc = FreeCAD.ActiveDocument
    sel = FreeCADGui.Selection.getSelection()
    if not sel:
        print("Select objects to explode and combine.")
        return
    wires = []
    for obj in sel:
        collect_wires(obj, wires)
    if not wires:
        print("No wires found.")
        return
    # Create new sketch
    sketch = doc.addObject('Sketcher::SketchObject', 'CombinedSketch')
    import Part
    import Sketcher
    def edge_to_sketch_geom(edge):
        t = edge.Curve.TypeId
        if t == 'Part::GeomLineSegment':
            return [Part.LineSegment(edge.Vertexes[0].Point, edge.Vertexes[1].Point)]
        elif t == 'Part::GeomCircle':
            (p1, p2) = (edge.Vertexes[0].Point, edge.Vertexes[1].Point)
            center = edge.Curve.Center
            radius = edge.Curve.Radius
            angle1 = edge.Curve.parameterAt(p1)
            angle2 = edge.Curve.parameterAt(p2)
            if edge.isClosed():
                return [Sketcher.Circle(center, edge.Curve.Axis, radius)]
            else:
                return [Sketcher.ArcOfCircle(center, radius, angle1, angle2)]
        elif t == 'Part::GeomEllipse':
            center = edge.Curve.Center
            major = edge.Curve.MajorRadius
            minor = edge.Curve.MinorRadius
            axis = edge.Curve.Axis
            if edge.isClosed():
                return [Sketcher.Ellipse(center, axis, major, minor)]
            else:
                print("Ellipse arcs not supported, skipping.")
                return []
        elif t in ('Part::GeomBezierCurve', 'Part::GeomBSplineCurve'):
            # Discretize curve into line segments (coarser for speed)
            pts = edge.discretize(Deflection=1.0)
            lines = []
            for i in range(len(pts)-1):
                lines.append(Part.LineSegment(pts[i], pts[i+1]))
            return lines
        else:
            print(f"Unsupported edge type: {t}, skipping.")
            return []

    count = 0
    for wire in wires:
        for edge in wire.Edges:
            geoms = edge_to_sketch_geom(edge)
            for geom in geoms:
                sketch.addGeometry(geom, False)
                count += 1
                if count % 500 == 0:
                    print(f"Added {count} lines to sketch so far...")
    # Delete originals
    for obj in sel:
        doc.removeObject(obj.Name)
    doc.recompute()
    print(f"Combined {len(wires)} wires into one sketch: {sketch.Name}")

main()