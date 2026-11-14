import 'dart:math' as math;
import 'rational.dart';

/// 3D Vector for G.C.E. A/L Combined Maths and Physics mechanics.
class Vector3D {
  const Vector3D(this.x, this.y, [this.z = 0.0]);

  final double x;
  final double y;
  final double z;

  static const Vector3D zero = Vector3D(0.0, 0.0, 0.0);

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  Vector3D get unit {
    final mag = magnitude;
    if (mag == 0.0) throw const CalcException('division_by_zero');
    return Vector3D(x / mag, y / mag, z / mag);
  }

  Vector3D operator +(Vector3D o) => Vector3D(x + o.x, y + o.y, z + o.z);
  Vector3D operator -(Vector3D o) => Vector3D(x - o.x, y - o.y, z - o.z);
  Vector3D operator -() => Vector3D(-x, -y, -z);
  Vector3D operator *(double scalar) => Vector3D(x * scalar, y * scalar, z * scalar);

  /// Dot (scalar) product: u · v = x1*x2 + y1*y2 + z1*z2.
  double dot(Vector3D o) => x * o.x + y * o.y + z * o.z;

  /// Cross (vector) product: u × v.
  Vector3D cross(Vector3D o) {
    return Vector3D(
      y * o.z - z * o.y,
      z * o.x - x * o.z,
      x * o.y - y * o.x,
    );
  }

  /// Angle between two vectors in radians.
  double angleWith(Vector3D o) {
    final m1 = magnitude;
    final m2 = o.magnitude;
    if (m1 == 0.0 || m2 == 0.0) throw const CalcException('division_by_zero');
    final cosTheta = (dot(o) / (m1 * m2)).clamp(-1.0, 1.0);
    return math.acos(cosTheta);
  }

  /// Angle between two vectors in degrees.
  double angleWithDegrees(Vector3D o) => angleWith(o) * 180.0 / math.pi;

  @override
  String toString([int decimals = 3]) {
    String f(double v) => v.toStringAsFixed(decimals).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    return '(${f(x)}î + ${f(y)}ĵ + ${f(z)}k̂)';
  }
}

/// Matrix representation for 2x2 and 3x3 matrices.
class Matrix {
  Matrix(this.rows) {
    if (rows.isEmpty || rows[0].isEmpty) {
      throw const CalcException('syntax_error');
    }
    final cols = rows[0].length;
    for (final r in rows) {
      if (r.length != cols) throw const CalcException('syntax_error');
    }
  }

  final List<List<double>> rows;

  int get rowCount => rows.length;
  int get colCount => rows[0].length;
  bool get isSquare => rowCount == colCount;

  static Matrix identity(int n) {
    return Matrix(List.generate(n, (i) => List.generate(n, (j) => i == j ? 1.0 : 0.0)));
  }

  Matrix operator +(Matrix o) {
    if (rowCount != o.rowCount || colCount != o.colCount) throw const CalcException('dimension_mismatch');
    return Matrix(List.generate(rowCount, (r) => List.generate(colCount, (c) => rows[r][c] + o.rows[r][c])));
  }

  Matrix operator -(Matrix o) {
    if (rowCount != o.rowCount || colCount != o.colCount) throw const CalcException('dimension_mismatch');
    return Matrix(List.generate(rowCount, (r) => List.generate(colCount, (c) => rows[r][c] - o.rows[r][c])));
  }

  Matrix operator *(Matrix o) {
    if (colCount != o.rowCount) throw const CalcException('dimension_mismatch');
    final res = List.generate(rowCount, (r) => List.generate(o.colCount, (c) {
      var sum = 0.0;
      for (var k = 0; k < colCount; k++) {
        sum += rows[r][k] * o.rows[k][c];
      }
      return sum;
    }));
    return Matrix(res);
  }

  Matrix scalarMultiply(double s) {
    return Matrix(List.generate(rowCount, (r) => List.generate(colCount, (c) => rows[r][c] * s)));
  }

  Matrix get transpose {
    return Matrix(List.generate(colCount, (c) => List.generate(rowCount, (r) => rows[r][c])));
  }

  /// Calculates the determinant of a square matrix.
  double get determinant {
    if (!isSquare) throw const CalcException('dimension_mismatch');
    if (rowCount == 1) return rows[0][0];
    if (rowCount == 2) {
      return rows[0][0] * rows[1][1] - rows[0][1] * rows[1][0];
    }
    if (rowCount == 3) {
      return rows[0][0] * (rows[1][1] * rows[2][2] - rows[1][2] * rows[2][1]) -
             rows[0][1] * (rows[1][0] * rows[2][2] - rows[1][2] * rows[2][0]) +
             rows[0][2] * (rows[1][0] * rows[2][1] - rows[1][1] * rows[2][0]);
    }
    throw const CalcException('unsupported_dimension');
  }

  /// Calculates the inverse matrix A^-1.
  Matrix get inverse {
    final det = determinant;
    if (det.abs() < 1e-12) throw const CalcException('singular_matrix');

    if (rowCount == 2) {
      final invDet = 1.0 / det;
      return Matrix([
        [rows[1][1] * invDet, -rows[0][1] * invDet],
        [-rows[1][0] * invDet, rows[0][0] * invDet],
      ]);
    }

    if (rowCount == 3) {
      // Adjugate matrix
      final adj = List.generate(3, (r) => List.filled(3, 0.0));
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final minor = _minor(r, c);
          final sign = ((r + c) % 2 == 0) ? 1.0 : -1.0;
          adj[c][r] = (sign * minor.determinant) / det; // Transposed cofactor
        }
      }
      return Matrix(adj);
    }

    throw const CalcException('unsupported_dimension');
  }

  Matrix _minor(int skipRow, int skipCol) {
    final sub = <List<double>>[];
    for (var r = 0; r < rowCount; r++) {
      if (r == skipRow) continue;
      final row = <double>[];
      for (var c = 0; c < colCount; c++) {
        if (c == skipCol) continue;
        row.add(rows[r][c]);
      }
      sub.add(row);
    }
    return Matrix(sub);
  }
}
