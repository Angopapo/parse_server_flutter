part of flutter_parse_sdk_flutter;

/// A widget that displays a live grid of Parse objects.
///
/// The `ParseLiveGridWidget` is initialized with a `query` that retrieves the
/// objects to display in the grid. The `gridDelegate` is used to specify the
/// layout of the grid, and the `itemBuilder` function is used to specify how
/// each object in the grid should be displayed.
///
/// The `ParseLiveGridWidget` also provides support for error handling and
/// refreshing the live list of objects.
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
    this.shrinkWrap = true,
    this.limit = 5,
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
  final int limit;

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

  @override
  State<ParseLiveGridWidget<T>> createState() => _ParseLiveGridWidgetState<T>();

  static Widget defaultChildBuilder<T extends sdk.ParseObject>(
      BuildContext context, sdk.ParseLiveListElementSnapshot<T> snapshot) {
    Widget child;
    if (snapshot.failed) {
      child = const Text('something went wrong!');
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
  final int itemsPerPage = 10; // Adjust the value according to your needs
  int currentPage = 0;
  int totalCount = 0;

  @override
  void initState() {
    loadGridData();
    super.initState();
  }

  Future<void> loadGridData({sdk.QueryBuilder<T>? query}) async {
    sdk.QueryBuilder<T>? initialQuery = widget.query..setLimit(widget.limit)..setAmountToSkip(currentPage * itemsPerPage);

    if(query != null) {
      initialQuery = query;
    }

    final totalCountQuery = await initialQuery.count();
    if (totalCountQuery.count > 0) {
      setState(() {
        noData = false;
        totalCount = totalCountQuery.count;
      });
    } else {
      setState(() {
        noData = true;
      });
    }

    sdk.ParseLiveList.create(
      initialQuery,
      listenOnAllSubItems: widget.listenOnAllSubItems,
      listeningIncludes: widget.listeningIncludes,
      lazyLoading: widget.lazyLoading,
      preloadedColumns: widget.preloadedColumns,
    ).then((sdk.ParseLiveList<T> value) {
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

  Widget buildAnimatedGrid(sdk.ParseLiveList<T> liveGrid) {
    Animation<double> boxAnimation;
    boxAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        // TODO: AnimationController is always null, so this breaks
        parent: widget.animationController!,
        curve: const Interval(
          0,
          0.5,
          curve: Curves.decelerate,
        ),
      ),
    );
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            reverse: widget.reverse,
            padding: widget.padding,
            physics: widget.scrollPhysics,
            controller: widget.scrollController,
            scrollDirection: widget.scrollDirection,
            shrinkWrap: widget.shrinkWrap,
            itemCount: liveGrid.size,
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
              return ParseLiveListElementWidget<T>(
                key: ValueKey<String>(liveGrid.getIdentifier(index)),
                stream: () => liveGrid.getAt(index),
                loadedData: () => liveGrid.getLoadedAt(index)!,
                preLoadedData: () => liveGrid.getPreLoadedAt(index)!,
                sizeFactor: boxAnimation,
                duration: widget.duration,
                childBuilder:
                widget.childBuilder ?? ParseLiveGridWidget.defaultChildBuilder,
              );
            },
          ),
        ),
        Visibility(
          visible: isAtEnd() && !isLastPage(),
          child: ElevatedButton(
            onPressed: loadNextPage,
            child: const Text('Load More', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),),
          ),
        ),
      ],
    );
  }

  bool isAtEnd() {
    if (!widget.scrollController!.hasClients) return false;

    final maxScrollExtent = widget.scrollController!.position.maxScrollExtent;
    final currentScrollPosition = widget.scrollController!.position.pixels;
    const threshold = 0.0; // A small threshold to account for rounding errors

    return currentScrollPosition >= (maxScrollExtent - threshold);
  }

  Future<void> loadNextPage() async {
    if (_liveGrid != null && !isLastPage()) {
      setState(() {
        currentPage++;
      });
      final nextPageItems = await widget.query..setLimit(widget.limit)..setAmountToSkip(currentPage * itemsPerPage)..find();
      //_liveGrid!.addAll(nextPageItems);
      //loadGridData(query: nextPageItems);
      loadGridData();

    }
  }

  bool isLastPage() {
    return currentPage * itemsPerPage >= totalCount;
  }

  @override
  void dispose() {
    _liveGrid?.dispose();
    _liveGrid = null;
    super.dispose();
  }
}