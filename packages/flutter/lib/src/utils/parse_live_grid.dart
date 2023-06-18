part of flutter_parse_sdk_flutter;

/// A widget that displays a live grid of Parse objects with pagination support.
class ParseLiveGridWidget<T extends sdk.ParseObject> extends StatefulWidget {
  const ParseLiveGridWidget({
    Key? key,
    required this.query,
    this.gridLoadingElement,
    this.queryEmptyElement,
    this.duration = const Duration(milliseconds: 300),
    this.scrollPhysics,
    this.scrollController,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.primary,
    this.reverse = false,
    this.childBuilder,
    this.shrinkWrap = false,
    this.removedItemBuilder,
    this.listenOnAllSubItems,
    this.listeningIncludes,
    this.lazyLoading = true,
    this.preloadedColumns,
    this.animationController,
    this.crossAxisCount = 3,
    this.crossAxisSpacing = 5.0,
    this.mainAxisSpacing = 5.0,
    this.childAspectRatio = 0.80,
    this.limit = 20, // Default limit per page
    this.initialSkip = 0, // Initial skip value
  }) : super(key: key);

  final sdk.QueryBuilder<T> query;
  final Widget? gridLoadingElement;
  final Widget? queryEmptyElement;
  final Duration duration;
  final ScrollPhysics? scrollPhysics;
  final ScrollController? scrollController;

  final Axis scrollDirection;
  final EdgeInsetsGeometry? padding;
  final bool? primary;
  final bool reverse;
  final bool shrinkWrap;

  final ChildBuilder<T>? childBuilder;
  final ChildBuilder<T>? removedItemBuilder;

  final bool? listenOnAllSubItems;
  final List<String>? listeningIncludes;

  final bool lazyLoading;
  final List<String>? preloadedColumns;

  final AnimationController? animationController;

  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  final int limit;
  final int initialSkip;

  @override
  State<ParseLiveGridWidget<T>> createState() => _ParseLiveGridWidgetState<T>();

  static Widget defaultChildBuilder<T extends sdk.ParseObject>(
      BuildContext context,
      sdk.ParseLiveListElementSnapshot<T> snapshot,
      ) {
    Widget child;
    if (snapshot.failed) {
      child = const Text('Something went wrong!');
    } else if (snapshot.hasData) {
      child = ListTile(
        title: Text(
          snapshot.loadedData!.get<String>(sdk.keyVarObjectId)!,
        ),
      );
    } else {
      child = const ListTile(
        leading: CircularProgressIndicator(),
      );
    }
    return child;
  }
}

class _ParseLiveGridWidgetState<T extends sdk.ParseObject>
    extends State<ParseLiveGridWidget<T>> {
  sdk.ParseLiveList<T>? _liveGrid;
  bool noData = true;
  int skip = 0;

  @override
  void initState() {
    super.initState();
    fetchGridData();
  }

  @override
  void dispose() {
    _liveGrid?.dispose();
    _liveGrid = null;
    super.dispose();
  }

  void fetchGridData() {
    sdk.QueryBuilder<T> modifiedQuery = widget.query
      ..setLimit(widget.limit)
      ..setAmountToSkip(skip);

    sdk.ParseLiveList.create(
      modifiedQuery,
      listenOnAllSubItems: widget.listenOnAllSubItems,
      listeningIncludes: widget.listeningIncludes,
      lazyLoading: widget.lazyLoading,
      preloadedColumns: widget.preloadedColumns,
    ).then((sdk.ParseLiveList<T> value) {
      if (value.size > 0) {
        setState(() {
          noData = false;
        });
      } else {
        setState(() {
          noData = true;
        });
      }
      setState(() {
        _liveGrid = value;
        _liveGrid!.stream.listen((sdk.ParseLiveListEvent<sdk.ParseObject> event) {
          if (mounted) {
            setState(() {});
          }
        });
      });
    });
  }

  void loadMoreData() {
    skip += widget.limit;
    fetchGridData();
  }

  @override
  Widget build(BuildContext context) {
    if (_liveGrid == null) {
      return widget.gridLoadingElement ?? Container();
    }
    if (noData) {
      return widget.queryEmptyElement ?? Container();
    }
    return buildAnimatedGrid(_liveGrid!);
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  Widget buildAnimatedGrid(sdk.ParseLiveList<T> liveGrid) {
    Animation<double> boxAnimation;
    boxAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: widget.animationController!,
        curve: const Interval(
          0,
          0.5,
          curve: Curves.decelerate,
        ),
      ),
    );
    return GridView.builder(
      reverse: widget.reverse,
      padding: widget.padding,
      physics: widget.scrollPhysics,
      controller: widget.scrollController,
      scrollDirection: widget.scrollDirection,
      shrinkWrap: widget.shrinkWrap,
      itemCount: liveGrid.size, // Use totalSize for pagination
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: widget.crossAxisSpacing,
        mainAxisSpacing: widget.mainAxisSpacing,
        childAspectRatio: widget.childAspectRatio,
      ),
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        if (index < liveGrid.size) {
          return ParseLiveListElementWidget<T>(
            key: ValueKey<String>(liveGrid.getIdentifier(index)),
            stream: () => liveGrid.getAt(index),
            loadedData: () => liveGrid.getLoadedAt(index)!,
            preLoadedData: () => liveGrid.getPreLoadedAt(index)!,
            sizeFactor: boxAnimation,
            duration: widget.duration,
            childBuilder: widget.childBuilder ?? ParseLiveGridWidget.defaultChildBuilder,
          );
        } else {
          // Return a loading indicator or any widget to indicate loading more data.
          // This will be displayed when the user scrolls to the end of the grid.
          return CircularProgressIndicator();
        }
      },
    );
  }
}
