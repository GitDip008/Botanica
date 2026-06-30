// ============================================================
// FULL GRAPH DATA + A* INTEGRATION
// ============================================================

// 1. Định nghĩa tất cả nodes với ID
import 'dart:math';

import 'package:botanica_ar/models/a_star_algorithm.dart';

final List<PathNode> graphPathNodes = [
  PathNode(id: '1',  x: -161.16, y: -10.59),
  PathNode(id: '2',  x: -160.84, y: -10.83),
  PathNode(id: '3',  x: -160.42, y: -11.18),
  PathNode(id: '4',  x: -160.04, y: -11.50),
  PathNode(id: '5',  x: -160.02, y: -12.00),
  PathNode(id: '6',  x: -160.28, y: -11.87),
  PathNode(id: '7',  x: -153.88, y: -3.44),
  PathNode(id: '8',  x: -152.35, y: -4.27),
  PathNode(id: '9',  x: -153.41, y: -3.77),
  PathNode(id: '10', x: -161.26, y: -7.74),
  PathNode(id: '11', x: -161.45, y: -7.11),
  PathNode(id: '12', x: -161.78, y: -6.56),
  PathNode(id: '13', x: -162.93, y: -5.82),
  PathNode(id: '14', x: -165.59, y: -5.70),
  PathNode(id: '15', x: -164.35, y: -5.70),
  PathNode(id: '16', x: -159.68, y: -3.45),
  PathNode(id: '17', x: -160.07, y: -4.30),
  PathNode(id: '18', x: -159.48, y: -4.03),
  PathNode(id: '19', x: -156.85, y:  8.55),
  PathNode(id: '20', x: -156.85, y:  7.51),
  PathNode(id: '21', x: -156.85, y:  6.55),
  PathNode(id: '22', x: -156.85, y:  5.41),
  PathNode(id: '23', x: -156.85, y:  4.37),
  PathNode(id: '24', x: -156.85, y:  3.32),
  PathNode(id: '25', x: -156.84, y:  2.46),
  PathNode(id: '26', x: -155.82, y:  1.41),
  PathNode(id: '27', x: -154.77, y:  1.41),
  PathNode(id: '28', x: -153.68, y:  1.41),
  PathNode(id: '29', x: -152.98, y:  0.71),
  PathNode(id: '30', x: -152.98, y: -0.61),
  PathNode(id: '31', x: -153.45, y: -1.55),
  PathNode(id: '32', x: -154.27, y: -2.27),
  PathNode(id: '33', x: -155.05, y: -3.14),
  PathNode(id: '34', x: -155.55, y: -4.01),
  PathNode(id: '35', x: -155.55, y: -4.74),
  PathNode(id: '36', x: -155.55, y: -5.74),
  PathNode(id: '37', x: -155.55, y: -6.54),
  PathNode(id: '38', x: -154.46, y: -6.54),
  PathNode(id: '39', x: -153.55, y: -6.93),
  PathNode(id: '40', x: -153.14, y: -7.89),
  PathNode(id: '41', x: -153.00, y: -8.92),
  PathNode(id: '42', x: -153.17, y: -10.08),
  PathNode(id: '43', x: -153.85, y: -10.97),
  PathNode(id: '44', x: -155.00, y: -11.32),
  PathNode(id: '45', x: -156.11, y: -11.32),
  PathNode(id: '46', x: -157.06, y: -10.81),
  PathNode(id: '47', x: -157.71, y: -9.87),
  PathNode(id: '48', x: -158.16, y: -8.82),
  PathNode(id: '49', x: -159.44, y: -8.82),
  PathNode(id: '50', x: -160.60, y: -8.82),
  PathNode(id: '51', x: -161.58, y: -9.28),
  PathNode(id: '52', x: -162.25, y: -9.90),
  PathNode(id: '53', x: -162.83, y: -10.43),
  PathNode(id: '54', x: -163.70, y: -11.21),
  PathNode(id: '55', x: -164.89, y: -11.21),
  PathNode(id: '56', x: -165.59, y: -10.32),
  PathNode(id: '57', x: -165.59, y: -9.24),
  PathNode(id: '58', x: -165.59, y: -8.19),
  PathNode(id: '59', x: -165.59, y: -7.11),
  PathNode(id: '60', x: -165.59, y: -5.87),
  PathNode(id: '61', x: -165.59, y: -4.84),
  PathNode(id: '62', x: -165.59, y: -3.55),
  PathNode(id: '63', x: -165.59, y: -2.41),
  PathNode(id: '64', x: -164.40, y: -2.41),
  PathNode(id: '65', x: -163.24, y: -2.41),
  PathNode(id: '66', x: -162.01, y: -2.41),
  PathNode(id: '67', x: -160.84, y: -2.41),
  PathNode(id: '68', x: -159.84, y: -1.93),
  PathNode(id: '69', x: -159.84, y: -0.81),
  PathNode(id: '70', x: -159.84, y:  0.29),
  PathNode(id: '71', x: -159.84, y:  1.53),
  PathNode(id: '72', x: -156.83, y:  1.41),
  PathNode(id: '73', x: -158.25, y:  1.53),
];

// 2. Hàm build edges từ graph data
void buildGraphEdges(List<PathNode> nodes) {
  // Map id -> node để lookup nhanh
  final map = {for (final n in nodes) n.id: n};

  double dist(PathNode a, PathNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  void connect(String idA, String idB) {
    final a = map[idA]!;
    final b = map[idB]!;
    final w = dist(a, b);
    a.edges.add(PathEdge(target: b, weight: w));
    b.edges.add(PathEdge(target: a, weight: w)); // 2 chiều
  }

  // Edges từ graph data
  connect('1',  '2');  connect('1',  '52');
  connect('2',  '3');
  connect('3',  '4');
  connect('4',  '6');
  connect('5',  '6');
  connect('7',  '9');  connect('7',  '33');
  connect('8',  '9');
  connect('10', '11'); connect('10', '50');
  connect('11', '12');
  connect('12', '13');
  connect('13', '15');
  connect('14', '15');
  connect('16', '18'); connect('16', '68');
  connect('17', '18');
  connect('19', '20');
  connect('20', '21');
  connect('21', '22');
  connect('22', '23');
  connect('23', '24');
  connect('24', '25');
  connect('25', '72');
  connect('26', '72'); connect('26', '27');
  connect('27', '28');
  connect('28', '29');
  connect('29', '30');
  connect('30', '31');
  connect('31', '32');
  connect('32', '33');
  connect('33', '34'); connect('33', '7');
  connect('34', '35');
  connect('35', '36');
  connect('36', '37');
  connect('37', '38');
  connect('38', '39');
  connect('39', '40');
  connect('40', '41');
  connect('41', '42');
  connect('42', '43');
  connect('43', '44');
  connect('44', '45');
  connect('45', '46');
  connect('46', '47');
  connect('47', '48');
  connect('48', '49');
  connect('49', '50');
  connect('50', '51'); connect('50', '10');
  connect('51', '52');
  connect('52', '53'); connect('52', '1');
  connect('53', '54');
  connect('54', '55');
  connect('55', '56');
  connect('56', '57');
  connect('57', '58');
  connect('58', '59');
  connect('59', '60');
  connect('60', '61');
  connect('61', '62');
  connect('62', '63');
  connect('63', '64');
  connect('64', '65');
  connect('65', '66');
  connect('66', '67');
  connect('67', '68'); connect('67', '16');
  connect('68', '69');
  connect('69', '70');
  connect('70', '71');
  connect('71', '73');
  connect('72', '73'); connect('72', '26');
  connect('73', '71');
}