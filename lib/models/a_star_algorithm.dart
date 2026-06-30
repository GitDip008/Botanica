import 'dart:collection';
import 'dart:math';

class PathNode {
  final String id;
  final double x, y;
  final List<PathEdge> edges = [];
  PathNode({required this.id, required this.x, required this.y});
}

class PathEdge {
  final PathNode target;
  final double weight;
  PathEdge({required this.target, required this.weight});
}

class AStarAlgorithm  {
  List<PathNode> findPath(PathNode start, PathNode goal) {
  // f(n) = g(n) + h(n)
  final gScore = <String, double>{start.id: 0};
  final cameFrom = <String, PathNode>{};

  // Priority queue: sort fScore
  final openSet = SplayTreeMap<double, List<PathNode>>();

  void addToOpen(PathNode node, double f) {
    openSet.putIfAbsent(f, () => []).add(node);
  }

  PathNode? popBest() {
    if (openSet.isEmpty) return null;
    final first = openSet.firstKey()!;
    final list = openSet[first]!;
    final node = list.removeLast();
    if (list.isEmpty) openSet.remove(first);
    return node;
  }

  double heuristic(PathNode a, PathNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  addToOpen(start, heuristic(start, goal));

  while (openSet.isNotEmpty) {
    final current = popBest()!;

    if (current.id == goal.id) {
      // Reconstruct path
      final path = <PathNode>[];
      PathNode? node = goal;
      while (node != null) {
        path.insert(0, node);
        node = cameFrom[node.id];
      }
      return path;
    }

    for (final edge in current.edges) {
      final neighbor = edge.target;
      final tentativeG = gScore[current.id]! + edge.weight;

      if (tentativeG < (gScore[neighbor.id] ?? double.infinity)) {
        cameFrom[neighbor.id] = current;
        gScore[neighbor.id] = tentativeG;
        final f = tentativeG + heuristic(neighbor, goal);
        addToOpen(neighbor, f);
      }
    }
  }

  return [];
}
}