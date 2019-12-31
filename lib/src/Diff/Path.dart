part of Diff;

/// The results from a traversal through the cost matrix.
class _TraverseResult {
  /// The cost to take this path.
  int cost;

  /// The path through the cost matrix.
  List<StepType> path;

  /// Creates a new traverse result.
  _TraverseResult(this.cost, this.path);
}

/// The levenshtein path builder used for diffing 
class _Path {
  
  /// The source comparable to create the path for.
  DiffComparable _comp;

  /// The container for the levenshtein costs.
  List<List<int>> _costs;

  /// Creates a new path builder.
  _Path(DiffComparable comp) {
    this._comp = comp;
    this._costs = null;
  }

  /// Path gets the difference path for the two given items.
  List<StepGroup> createPath() {
    List<StepGroup> result = new List<StepGroup>();
    final int aLength = this._comp.aLength;
    final int bLength = this._comp.bLength;
    this.levenshteinDistance(aLength, bLength);
    _TraverseResult trav = this.traverseLevenshteinDistance(aLength, bLength);

    int addRun = 0;
    Function() insertAdd = () {
      if (addRun > 0) {
        print('> added $addRun');
        result.add(new StepGroup(StepType.Added, addRun));    
        addRun = 0;
      }
    };
    
    int removeRun = 0;
    Function() insertRemove = () {
      if (removeRun > 0) {
        print('> removed $removeRun');
        result.add(new StepGroup(StepType.Removed, removeRun));    
        removeRun = 0;
      }
    };
    
    int equalRun = 0;
    Function() insertEqual = () {
      if (equalRun > 0) {
        print('> equal $equalRun');
        result.add(new StepGroup(StepType.Equal, equalRun));    
        equalRun = 0;
      }
    };

    for (StepType step in trav.path) {
      switch (step) {
        case StepType.Equal:
          insertAdd();
          insertRemove();
          equalRun++;
          break;
        case StepType.Added:
          insertEqual();
          addRun++;
          break;
        case StepType.Removed:
          insertEqual();
          removeRun++;
          break;
      }
    }
  
    insertEqual();
    insertAdd();
    insertRemove();
    return result;
  }

  /// Sets the cost of a path point.
  void setCost(int aIndex, int bIndex, int cost) =>
    this._costs[aIndex-1][bIndex-1] = cost;

  /// Gets the cost at a path point.
  int getCost(int aIndex, int bIndex) {
    if (aIndex <= 0) return bIndex;
    if (bIndex <= 0) return aIndex;
    return this._costs[aIndex-1][bIndex-1];
  }

  void setNewCost(int aIndex, int bIndex) {
    // skips any cost for equal values in the inputs
    int skipCost = this._comp.equals(aIndex-1, bIndex-1)? 0: 1;

    // get the minimum of entry skip entry from a, skip entry from b, and skip entry from both
    int costA = this.getCost(aIndex-1, bIndex)   + 1;
    int costB = this.getCost(aIndex,   bIndex-1) + 1;
    int costC = this.getCost(aIndex-1, bIndex-1) + skipCost;

    // calculate the minimum path cost and set cost
    int minCost = this.min(costA, costB, costC);
    this.setCost(aIndex, bIndex, minCost);
  }

  /// Determines the minimum of the three values.
  int min(int a, int b, int c) => math.min(math.min(a, b), c);

  /// levenshteinDistance gets cost matrix of levenshtein distances.
  /// This filles out the cost matrix.
  /// See https://en.wikipedia.org/wiki/Levenshtein_distance
  void levenshteinDistance(int aLength, int bLength) {
    this._costs = new List<List<int>>.generate(aLength, (_) =>
      new List<int>.filled(bLength, 0));

    for (int aIndex = 1; aIndex <= aLength; aIndex++) {
      for (int bIndex = 1; bIndex <= bLength; bIndex++) {
        this.setNewCost(aIndex, bIndex);
      }
    }
  }
  
  /// Gets the path with the lowest cost.
  _TraverseResult traverseLevenshteinDistance(int aIndex, int bIndex) {
    // base case when one of the inputs are empty
    if (aIndex <= 0) return new _TraverseResult(bIndex, new List<StepType>.filled(bIndex, StepType.Added, growable: true));
    if (bIndex <= 0) return new _TraverseResult(aIndex, new List<StepType>.filled(aIndex, StepType.Removed, growable: true));

	  // get the minimum of entry skip entry from a, skip entry from b, and skip entry from both
    int costA = this.getCost(aIndex-1, bIndex);
    int costB = this.getCost(aIndex,   bIndex-1);
    int costC = this.getCost(aIndex-1, bIndex-1);
    int minCost = this.min(costA, costB, costC);

    // calculate the minimum path cost and set cost
    int minPathCost = minCost + 2;
    List<StepType> minPath = new List<StepType>();

    if (costA <= minCost) {
      // costA is minimum
      _TraverseResult result = traverseLevenshteinDistance(aIndex-1, bIndex);
      int cost = result.cost + 1;
      if (cost < minPathCost) {
        minPathCost = cost;
        minPath = result.path..add(StepType.Removed);
      }
    }

    if (costB <= minCost) {
      // costB is minimum
      _TraverseResult result = traverseLevenshteinDistance(aIndex, bIndex-1);
      int cost = result.cost + 1;
      if (cost < minPathCost) {
        minPathCost = cost;
        minPath = result.path..add(StepType.Added);
      }
    }

    if (costC <= minCost) {
      if (this._comp.equals(aIndex-1, bIndex-1)) {
        // costC is minimum and entries equal
        _TraverseResult result = traverseLevenshteinDistance(aIndex-1, bIndex-1);
        // Do not add to cost since the values are equal
        if (result.cost < minPathCost) {
          minPathCost = result.cost;
          minPath = result.path..add(StepType.Equal);
        }
      } else {
        // costC is minimum and entries different
        _TraverseResult result = traverseLevenshteinDistance(aIndex-1, bIndex-1);
        int cost = result.cost + 1;
        if (cost < minPathCost) {
          minPathCost = cost;
          minPath = result.path..add(StepType.Removed)..add(StepType.Added);
        }
      }
    }

    return new _TraverseResult(minPathCost, minPath);
  }
}
