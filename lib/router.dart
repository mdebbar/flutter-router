import 'dart:async';

import 'package:flutter/widgets.dart';

typedef RouteBuilder = Widget Function();

String join(String a, String b) {
  if (a.endsWith('/') && b.startsWith('/')) {
    return '$a${b.substring(1)}';
  }
  if (!a.endsWith('/') && !b.startsWith('/')) {
    return '$a/$b';
  }
  return '$a$b';
}

final RegExp slashes = RegExp(r"^(/)+|(/)+$");
String trimPath(String path) {
  if (path.startsWith('/') || path.endsWith('/')) {
    return path.replaceAll(slashes, '');
  }
  return path;
}

String _stateToString(NavigationState state) {
  final StringBuffer buffer = StringBuffer();

  int depth = 0;
  String indent() => ' ' * depth * 2;

  void addLine(String line) {
    buffer.writeln('${indent()}$line');
  }

  var addEntry;
  var addStack;

  addEntry = (NavigationEntry entry) {
    if (entry.isLeaf) {
      addLine(entry == state.activeEntry ? '/${entry.path} **' : '/${entry.path}');
    } else {
      addLine('/${entry.path}: [');
      addStack(entry.subStack);
      addLine(']');
    }
  };

  addStack = (NavigationStack stack) {
    depth++;
    for (final NavigationEntry entry in stack.entries) {
      addEntry(entry);
    }
    depth--;
  };

  addLine('[');
  addStack(state.rootStack);
  addLine(']');

  return buffer.toString();
}

////////////////////////
/// NAVIGATION STATE ///
////////////////////////

class NavigationState {
  NavigationState({@required this.onChange}) : assert(onChange != null);

  final VoidCallback onChange;

  // TODO(mdebbar): add a change listener to the navigation stack.
  final NavigationStack rootStack = NavigationStack._root();

  bool hasChanged = false;

  NavigationEntry get activeEntry => _activeEntry;
  NavigationEntry _activeEntry;
  set activeEntry(NavigationEntry entry) {
    _activeEntry = entry;
    _scheduleOnChange();
  }

  /// An entry is considered "visible" if its position in the stack precedes that
  /// of the [NavigationState.activeEntry].
  ///
  /// i.e. an entry is considered "visible" if it hasn't been popped.
  NavigationEntry getLastVisibleEntry(NavigationStack stack) {
    // Start from the active entry (which is a leaf entry by design), and go up
    // until we either reach the given [stack] or the root of stacks.
    NavigationEntry entry = activeEntry;
    while (entry != null && entry.stack != stack) {
      entry = entry.parentEntry;
    }
    return entry ?? stack.entries.last;
  }

  void _scheduleOnChange() {
    if (hasChanged) return;
    hasChanged = true;
    scheduleMicrotask(() {
      hasChanged = false;
      onChange();
    });
  }

  bool get isEmpty => rootStack.isEmpty;

  @override
  String toString() {
    return _stateToString(this);
  }
}

class NavigationStack {
  NavigationStack._root() : parent = null;
  NavigationStack({@required this.parent}) : assert(parent != null);

  final List<NavigationEntry> entries = <NavigationEntry>[];
  final NavigationEntry parent;

  bool get isEmpty => entries.isEmpty;

  NavigationEntry createEntry(String path) =>
      NavigationEntry(stack: this, path: path);
}

class NavigationEntry {
  NavigationEntry({@required this.stack, @required String path})
      : assert(stack != null),
        assert(path != null),
        path = trimPath(path);

  final NavigationStack stack;
  final String path;

  NavigationStack subStack;

  int get index => stack.entries.indexOf(this);
  bool get isFirst => stack.entries.first == this;
  bool get isLast => stack.entries.last == this;

  bool get isLeaf => subStack == null;

  NavigationEntry get parentEntry => stack.parent;
  String get fullPath =>
      parentEntry == null ? path : join(parentEntry.fullPath, path);

  NavigationEntry get previous {
    NavigationEntry prevEntry = isFirst
        // If this is the first entry in the stack, go to the parent stack.
        ? parentEntry?.previous
        // Otherwise, return the previous entry in this stack.
        : stack.entries[index - 1];

    return prevEntry?.lastLeafChild;
  }

  NavigationEntry get next {
    NavigationEntry nextEntry = isLast
        // If this is the last entry in the stack, go to the parent stack.
        ? parentEntry?.next
        // Otherwise, return the next entry in this stack.
        : stack.entries[index + 1];

    return nextEntry?.firstLeafChild;
  }

  NavigationEntry get firstLeafChild {
    NavigationEntry entry = this;
    while (!entry.isLeaf) {
      entry = entry.subStack.entries.first;
    }
    return entry;
  }

  NavigationEntry get lastLeafChild {
    NavigationEntry entry = this;
    while (!entry.isLeaf) {
      entry = entry.subStack.entries.last;
    }
    return entry;
  }

  bool isDescendantOf(NavigationEntry otherEntry) {
    NavigationEntry entry = this;
    while (entry != null) {
      if (entry == otherEntry) {
        return true;
      }
      entry = entry.parentEntry;
    }
    return false;
  }

  NavigationStack _ensureSubStack() {
    if (subStack == null) {
      subStack = NavigationStack(parent: this);
    }
    return subStack;
  }
}

//////////////
/// ROUTER ///
//////////////

class Router extends StatefulWidget {
  Router({
    String defaultPath = '',
    @required this.child,
  }) : defaultPath = trimPath(defaultPath);

  final String defaultPath;
  final Widget child;

  static ContextualRouter of(BuildContext context) {
    return ContextualRouter._(
      inheritedRouter: context.inheritFromWidgetOfExactType(_InheritedRouter),
      inheritedEntry:
          context.inheritFromWidgetOfExactType(_InheritedNavigationEntry),
    );
  }

  @override
  _RouterState createState() => _RouterState();
}

class _RouterState extends State<Router> {
  NavigationState state;

  @override
  initState() {
    super.initState();
    state = NavigationState(onChange: _onNavigationStateChange);
  }

  _onNavigationStateChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedRouter(
      state: state,
      child: _InheritedRouteMatch(
        result: RouteMatchingResult(
          matched: '', // At the Router level, nothing has been matched yet.
          remaining: widget.defaultPath,
        ),
        child: NavigationBoundary(
          child: widget.child,
        ),
      ),
    );
  }
}

class _InheritedRouter extends InheritedWidget {
  _InheritedRouter({
    @required this.state,
    @required Widget child,
  }) : super(child: child);

  final NavigationState state;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    return true;
  }
}

/// This is the main API surface used by developers when manipulating or
/// inquiring about the navigation state.
///
/// It can be obtained by doing `Router.of(context)`.
class ContextualRouter {
  ContextualRouter._({
    @required _InheritedRouter inheritedRouter,
    @required _InheritedNavigationEntry inheritedEntry,
  })  : _inheritedRouter = inheritedRouter,
        _inheritedEntry = inheritedEntry;

  final _InheritedRouter _inheritedRouter;
  final _InheritedNavigationEntry _inheritedEntry;

  NavigationState get state => _inheritedRouter.state;
  NavigationEntry get currentEntry => _inheritedEntry?.entry;
  NavigationStack get currentStack => currentEntry?.stack;
  String get currentPath => currentEntry?.path;

  void push(String path) {
    final List<NavigationEntry> entries = currentStack.entries;
    // TODO(mdebbar): Should we remove forward entries from parent stacks too?
    if (!currentEntry.isLast) {
      entries.removeRange(currentEntry.index + 1, entries.length);
    }

    state.activeEntry = currentEntry.stack.createEntry(path);
    entries.add(state.activeEntry);
  }

  void replace(String path) {
    final List<NavigationEntry> entries = currentStack.entries;
    final NavigationEntry newEntry = currentEntry.stack.createEntry(path);
    state.activeEntry = entries[currentEntry.index] = newEntry;
  }

  bool back() {
    final NavigationEntry previousEntry = currentEntry.previous;
    if (previousEntry == null) {
      // TODO(mdebbar): Call SystemNavigator.pop().
      print('SystemNavigator.pop()');
      return false;
    } else {
      state.activeEntry = previousEntry;
      return true;
    }
  }

  bool forward() {
    final NavigationEntry nextEntry = currentEntry.next;
    if (nextEntry == null) {
      // TODO(mdebbar): What to do here?
      print('SystemNavigator.forward()');
      return false;
    } else {
      state.activeEntry = nextEntry;
      return true;
    }
  }
}

///////////////////////////
/// NAVIGATION BOUNDARY ///
///////////////////////////

class NavigationBoundary extends StatelessWidget {
  NavigationBoundary({
    String defaultPath = '',
    @required this.child,
  }) : defaultPath = trimPath(defaultPath);

  final String defaultPath;
  final Widget child;

  NavigationStack _getStack(BuildContext context) {
    final ContextualRouter router = Router.of(context);

    final NavigationState state = router.state;
    final NavigationEntry entry = router.currentEntry;

    // This is either a nested boundary or a root boundary. In the case it's
    // nested, `entry` would be non-null, and we should use its sub stack.
    //
    // In the case it's a root boundary, `entry` would be null, and we should
    // use the root stack.
    final NavigationStack stack = entry?._ensureSubStack() ?? state.rootStack;

    // Populate the stack if it's empty.
    if (stack.isEmpty) {
      // TODO(mdebbar): the path of the new entry depends on what the next `MatchRoute` consumes.
      final NavigationEntry newEntry =
          stack.createEntry(_getRemainingPath(context));
      stack.entries.add(newEntry);

      // The new entry should become the active entry in the following cases:
      //
      // 1. There's currently no active entry `state.activeEntry == null`.
      // 2. The current active entry is an ancestor of the new entry.
      if (state.activeEntry == null ||
          newEntry.isDescendantOf(state.activeEntry)) {
        state.activeEntry = newEntry;
      }
    }

    return stack;
  }

  /// Get the part of the path that hasn't been consumed yet by a [MatchRoute]
  /// widget up the tree.
  String _getRemainingPath(BuildContext context) {
    final _InheritedRouteMatch match =
        context.inheritFromWidgetOfExactType(_InheritedRouteMatch);
    String remaining = match.result.remaining;
    if (remaining == null || remaining.isEmpty) {
      return defaultPath;
    }
    return remaining;
  }

  Iterable<NavigationEntry> _getVisibleEntriesOfStack(
    BuildContext context,
    NavigationStack stack,
  ) {
    final NavigationState state = Router.of(context).state;
    final NavigationEntry lastVisibleEntry = state.getLastVisibleEntry(stack);
    if (lastVisibleEntry.isLast) {
      // There are no invisible entries in this stack, so return all entries.
      return stack.entries;
    }
    return stack.entries.getRange(0, lastVisibleEntry.index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final NavigationStack stack = _getStack(context);

    num offset = 0.0;
    return Stack(
      children: _getVisibleEntriesOfStack(context, stack)
          .map(
            (e) => Opacity(
              opacity: 0.9,
              child: Transform.translate(
                offset: Offset(15, 20) * offset++,
                child: _InheritedNavigationEntry(entry: e, child: child),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InheritedNavigationEntry extends InheritedWidget {
  _InheritedNavigationEntry({@required this.entry, @required Widget child})
      : super(child: child);

  final NavigationEntry entry;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    return true;
  }
}

//////////////
/// ROUTES ///
//////////////

class Route {
  Route(String path, this._builder) : _path = trimPath(path);

  final String _path;
  final RouteBuilder _builder;

  RouteMatchingResult match(String path) {
    if (path.startsWith(_path)) {
      return RouteMatchingResult(
        matched: _path,
        remaining: path.substring(_path.length),
      );
    }
    return null;
  }

  Widget build(RouteMatchingResult match) {
    return _builder();
  }
}

class RouteMatchingResult {
  RouteMatchingResult({
    @required String matched,
    @required String remaining,
  })  : assert(matched != null),
        assert(remaining != null),
        matched = trimPath(matched),
        remaining = trimPath(remaining);

  /// The part of the path that was matched by a given route.
  final String matched;

  /// The part of the path that remains to be matched further.
  final String remaining;
}

class RouteMatchingException implements Exception {
  RouteMatchingException({@required this.entry});

  final NavigationEntry entry;
}

class MatchRoute extends StatelessWidget {
  const MatchRoute({this.routes});

  final List<Route> routes;

  @override
  Widget build(BuildContext context) {
    final NavigationEntry entry = Router.of(context).currentEntry;
    for (int i = 0; i < routes.length; i++) {
      final Route route = routes[i];
      // QUESTION: what if more than one route match? throw a warning in dev mode?
      final RouteMatchingResult result = route.match(entry.path);
      if (result != null) {
        return _InheritedRouteMatch(result: result, child: route.build(result));
      }
    }
    print('Could not match route: "${entry.path}"');
    throw RouteMatchingException(entry: entry);
  }
}

class _InheritedRouteMatch extends InheritedWidget {
  _InheritedRouteMatch({@required this.result, @required child})
      : super(child: child);

  final RouteMatchingResult result;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    return true;
  }
}
