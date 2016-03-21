//
//  Delaunay.swift
//  DelaunayTriangulationSwift
//
//  Created by Alex Littlejohn on 2016/01/08.
//  Copyright © 2016 zero. All rights reserved.
//

import Darwin

public class Delaunay {
    
    public init() { }
    
    /* Generates a supertraingle containing all other triangles */
    private func supertriangle(vertices: [Vertice]) -> [Vertice] {
        var xmin = Double(Int32.max)
        var ymin = Double(Int32.max)
        var xmax = -Double(Int32.max)
        var ymax = -Double(Int32.max)
        
        for i in 0..<vertices.count {
            if vertices[i].x < xmin { xmin = vertices[i].x }
            if vertices[i].x > xmax { xmax = vertices[i].x }
            if vertices[i].y < ymin { ymin = vertices[i].y }
            if vertices[i].y > ymax { ymax = vertices[i].y }
        }
        
        let dx = xmax - xmin
        let dy = ymax - ymin
        let dmax = max(dx, dy)
        let xmid = xmin + dx * 0.5
        let ymid = ymin + dy * 0.5
        
        return [
            Vertice(x: xmid - 20 * dmax, y: ymid - dmax),
            Vertice(x: xmid, y: ymid + 20 * dmax),
            Vertice(x: xmid + 20 * dmax, y: ymid - dmax)
        ]
    }
    
    /* Calculate a circumcircle for a set of 3 vertices */
    private func circumcircle(vertices: [Vertice], i: Int, j: Int, k: Int) throws -> CircumCircle {
        let x1 = vertices[i].x
        let y1 = vertices[i].y
        let x2 = vertices[j].x
        let y2 = vertices[j].y
        let x3 = vertices[k].x
        let y3 = vertices[k].y
        let xc: Double
        let yc: Double
        
        let fabsy1y2 = abs(y1 - y2)
        let fabsy2y3 = abs(y2 - y3)
        
        if fabsy1y2 < DBL_EPSILON && fabsy2y3 < DBL_EPSILON {
            throw DelaunayError.CoincidentPoints
        }
        
        if fabsy1y2 < DBL_EPSILON {
            let m2 = -((x3 - x2) / (y3 - y2))
            let mx2 = (x2 + x3) / 2
            let my2 = (y2 + y3) / 2
            xc = (x2 + x1) / 2
            yc = m2 * (xc - mx2) + my2
        } else if fabsy2y3 < DBL_EPSILON {
            let m1 = -((x2 - x1) / (y2 - y1))
            let mx1 = (x1 + x2) / 2
            let my1 = (y1 + y2) / 2
            xc = (x3 + x2) / 2
            yc = m1 * (xc - mx1) + my1
        } else {
            let m1 = -((x2 - x1) / (y2 - y1))
            let m2 = -((x3 - x2) / (y3 - y2))
            let mx1 = (x1 + x2) / 2
            let mx2 = (x2 + x3) / 2
            let my1 = (y1 + y2) / 2
            let my2 = (y2 + y3) / 2
            xc = (m1 * mx1 - m2 * mx2 + my2 - my1) / (m1 - m2)
            
            if fabsy1y2 > fabsy2y3 {
                yc = m1 * (xc - mx1) + my1
            } else {
                yc = m2 * (xc - mx2) + my2
            }
        }
        
        let dx = x2 - xc
        let dy = y2 - yc
        let rsqr = dx * dx + dy * dy
        
        return CircumCircle(i: i, j: j, k: k, x: xc, y: yc, rsqr: rsqr)
    }
    
    private func dedup(edges: [Int]) -> [Int] {
        
        var e = edges
        var a: Int, b: Int, m: Int, n: Int
        
        var j = e.count
        while j > 0 {
            --j
            b = j < e.count ? e[j] : -1
            --j
            a = j < e.count ? e[j] : -1
            
            var i = j
            while i > 0 {
                n = e[--i]
                m = e[--i]
                
                if (a == m && b == n) || (a == n && b == m) {
                    
                    e.removeRange(j..<j+2)
                    e.removeRange(i..<i+2)
                    break
                }
            }
        }
        
        return e
    }
    
    public func triangulate(vertices: [Vertice]) -> [Triangle] {
        
        let n = vertices.count
        var indices = [Int](count: n, repeatedValue: 0)
        var open = [CircumCircle]()
        var completed = [CircumCircle]()
        var edges = [Int]()
        var _vertices = vertices
        
        if n < 3 {
            return [Triangle]()
        }
        
        /* Make an array of indices into the vertex array, sorted by the
        * vertices' x-position. */
        for i in 0..<n {
            indices[i] = i
        }
        
        indices.sortInPlace { (i, j) -> Bool in
            return _vertices[j].x > _vertices[i].x
        }
        
        /* Next, find the vertices of the supertriangle (which contains all other
        * triangles), and append them onto the end of a (copy of) the vertex
        * array. */
        _vertices += supertriangle(_vertices)
        
        /* Initialize the open list (containing the supertriangle and nothing
        * else) and the closed list (which is empty since we havn't processed
        * any triangles yet). */
        open.append(try! circumcircle(_vertices, i: n + 0, j: n + 1, k: n + 2))
        
        /* Incrementally add each vertex to the mesh. */
        for i in (0..<n).reverse() {
            let c = indices[i]
            
            edges.removeAll()
            
            /* For each open triangle, check to see if the current point is
            * inside it's circumcircle. If it is, remove the triangle and add
            * it's edges to an edge list. */
            for j in (0..<open.count).reverse() {
                
                /* If this point is to the right of this triangle's circumcircle,
                * then this triangle should never get checked again. Remove it
                * from the open list, add it to the closed list, and skip. */
                let dx = _vertices[c].x - open[j].x
                
                if dx > 0 && dx * dx > open[j].rsqr {
                    completed.append(open.removeAtIndex(j))
                    continue
                }
                
                /* If we're outside the circumcircle, skip this triangle. */
                let dy = _vertices[c].y - open[j].y
                
                if dx * dx + dy * dy - open[j].rsqr > DBL_EPSILON {
                    continue
                }
                
                /* Remove the triangle and add it's edges to the edge list. */
                edges += [open[j].i, open[j].j, open[j].j, open[j].k, open[j].k, open[j].i]
                
                open.removeAtIndex(j)
            }
            
            /* Remove any doubled edges. */
            edges = dedup(edges)
            
            /* Add a new triangle for each edge. */
            var j = edges.count
            while j > 0 {
                let b = edges[--j]
                let a = edges[--j]
                open.append(try! circumcircle(_vertices, i: a, j: b, k: c))
            }
        }
        
        /* Copy any remaining open triangles to the closed list, and then
        * remove any triangles that share a vertex with the supertriangle,
        * building a list of triplets that represent triangles. */
        completed += open
        
        let results = completed.flatMap { (circumCircle) -> Triangle? in
            
            guard circumCircle.i < n && circumCircle.j < n && circumCircle.k < n else {
                return nil
            }
            
            let vertice1 = _vertices[circumCircle.i]
            let vertice2 = _vertices[circumCircle.j]
            let vertice3 = _vertices[circumCircle.k]
            let triangle = Triangle(vertice1: vertice1, vertice2: vertice2, vertice3: vertice3)
            return triangle
        }
        
        /* Yay, we're done! */
        return results
    }
}
