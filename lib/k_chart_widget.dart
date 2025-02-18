import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:k_chart_plus/chart_translations.dart';
import 'package:k_chart_plus/components/popup_info_view.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'renderer/base_dimension.dart';

enum MainState { MA, BOLL, NONE }

// enum SecondaryState { MACD, KDJ, RSI, WR, CCI, NONE }
enum SecondaryState { MACD, KDJ, RSI, WR, CCI } //no support NONE

class TimeFormat {
  static const List<String> YEAR_MONTH_DAY = [yyyy, '-', mm, '-', dd];
  static const List<String> YEAR_MONTH_DAY_WITH_HOUR = [
    yyyy,
    '-',
    mm,
    '-',
    dd,
    ' ',
    HH,
    ':',
    nn
  ];
}

class KChartWidget extends StatefulWidget {
  final List<KLineEntity>? datas;
  final MainState mainState;
  final bool volHidden;
  final Set<SecondaryState> secondaryStateLi;
  // final Function()? onSecondaryTap;
  final bool isLine;
  final bool
      isTapShowInfoDialog; //Whether to enable click to display detailed data
  final bool hideGrid;
  final bool showNowPrice;
  final bool showInfoDialog;
  final bool materialInfoDialog; // Material Style Information Popup
  final ChartTranslations chartTranslations;
  final List<String> timeFormat;
  final double mBaseHeight;

  // It will be called when the screen scrolls to the end.
  // If true, it will be scrolled to the end of the right side of the screen.
  // If it is false, it will be scrolled to the end of the left side of the screen.
  final Function(bool)? onLoadMore;

  final int fixedLength;
  final List<int> maDayList;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final ChartColors chartColors;
  final ChartStyle chartStyle;
  final VerticalTextAlignment verticalTextAlignment;
  final VerticalTextAlignment priveNowVerticalTextAlignment;
  final bool isTrendLine;
  final double xFrontPadding;

  final Widget? resetIcon;
  final Widget? scrollToEndChartIcon;

  KChartWidget(
    this.datas,
    this.chartStyle,
    this.chartColors, {
    required this.isTrendLine,
    this.xFrontPadding = 100,
    this.mainState = MainState.MA,
    this.secondaryStateLi = const <SecondaryState>{},
    // this.onSecondaryTap,
    this.volHidden = false,
    this.isLine = false,
    this.isTapShowInfoDialog = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.showInfoDialog = true,
    this.materialInfoDialog = true,
    this.chartTranslations = const ChartTranslations(),
    this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.onLoadMore,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.verticalTextAlignment = VerticalTextAlignment.left,
    this.priveNowVerticalTextAlignment = VerticalTextAlignment.right,
    this.mBaseHeight = 360,
    this.resetIcon,
    this.scrollToEndChartIcon,
  });

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget>
    with TickerProviderStateMixin {
  final StreamController<InfoWindowEntity?> mInfoWindowStream =
      StreamController<InfoWindowEntity?>();
  double _defaultScale = 0.8;
  double mScaleX = 0.8, mScrollX = 0.0, mSelectX = 0.0, mScaleY = 1.0;
  double? chartMinValue, chartMaxValue;
  double actualChartMinValue = 0, actualChartMaxValue = 0;
  double mHeight = 0, mWidth = 0;
  AnimationController? _controller;
  Animation<double>? aniX;

  //For TrendLine
  List<TrendLine> lines = [];
  double? changeinXposition;
  double? changeinYposition;
  double mSelectY = 0.0;
  bool waitingForOtherPairofCords = false;
  bool enableCordRecord = false;

  //for sclaing
  bool showScalingControls = false;
  Timer? _showScalingControlsTimer;

  double getMinScrollX() {
    return mScaleX;
  }

  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false, isOnTap = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  bool isUpdatingChart = false;

  @override
  void dispose() {
    mInfoWindowStream.sink.close();
    mInfoWindowStream.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datas != null && widget.datas!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = _defaultScale;
    }
    final BaseDimension baseDimension = BaseDimension(
      mBaseHeight: widget.mBaseHeight,
      volHidden: widget.volHidden,
      secondaryStateLi: widget.secondaryStateLi,
    );
    final _painter = ChartPainter(
      widget.chartStyle,
      widget.chartColors,
      baseDimension: baseDimension,
      lines: lines, //For TrendLine
      sink: mInfoWindowStream.sink,
      xFrontPadding: widget.xFrontPadding,
      isTrendLine: widget.isTrendLine, //For TrendLine
      selectY: mSelectY, //For TrendLine
      datas: widget.datas,
      scaleX: mScaleX,
      chartMaxValue: chartMaxValue,
      chartMinValue: chartMinValue,
      onChartMinMaxUpdates: ({required chartMaxValue, required chartMinValue}) {
        Future.delayed(Duration(seconds: 1), () {
          if (chartMinValue != actualChartMinValue) {
            print("HelloRP : updated $chartMinValue");
            actualChartMinValue = chartMinValue;
            notifyChanged();
          }
          if (chartMaxValue != actualChartMaxValue) {
            actualChartMaxValue = chartMaxValue;
            notifyChanged();
          }
        });
      },
      scrollX: mScrollX,
      selectX: mSelectX,
      isLongPass: isLongPress,
      isOnTap: isOnTap,
      isTapShowInfoDialog: widget.isTapShowInfoDialog,
      mainState: widget.mainState,
      volHidden: widget.volHidden,
      secondaryStateLi: widget.secondaryStateLi,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      fixedLength: widget.fixedLength,
      maDayList: widget.maDayList,
      verticalTextAlignment: widget.verticalTextAlignment,
      priveNowVerticalTextAlignment: widget.priveNowVerticalTextAlignment,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        mHeight = constraints.maxHeight;
        mWidth = constraints.maxWidth;
        return SizedBox(
          height: mHeight,
          child: GestureDetector(
            onTapUp: (details) {
              // if (!widget.isTrendLine && widget.onSecondaryTap != null && _painter.isInSecondaryRect(details.localPosition)) {
              //   widget.onSecondaryTap!();
              // }
              isLongPress = false;
              _showScalingControls();

              if (!widget.isTrendLine &&
                  _painter.isInMainRect(details.localPosition)) {
                isOnTap = true;
                if (mSelectX != details.localPosition.dx &&
                    widget.isTapShowInfoDialog) {
                  mSelectX = details.localPosition.dx;
                  notifyChanged();
                }
              }
              if (widget.isTrendLine && !isLongPress && enableCordRecord) {
                enableCordRecord = false;
                Offset p1 = Offset(getTrendLineX(), mSelectY);
                if (!waitingForOtherPairofCords) {
                  lines.add(TrendLine(
                      p1, Offset(-1, -1), trendLineMax!, trendLineScale!));
                }

                if (waitingForOtherPairofCords) {
                  var a = lines.last;
                  lines.removeLast();
                  lines
                      .add(TrendLine(a.p1, p1, trendLineMax!, trendLineScale!));
                  waitingForOtherPairofCords = false;
                } else {
                  waitingForOtherPairofCords = true;
                }
                notifyChanged();
              }
            },
            onHorizontalDragDown: (details) {
              Future.delayed(Duration(milliseconds: 500), () {
                if (isScale) {
                  isOnTap = false;
                  _stopAnimation();
                  _onDragChanged(true);
                }
              });
            },
            onHorizontalDragUpdate: (details) {
              // if (isScale || isLongPress) return;
              mScrollX = ((details.primaryDelta ?? 0) / mScaleX + mScrollX)
                  .clamp(0.0, ChartPainter.maxScrollX)
                  .toDouble();
              notifyChanged();
            },
            onHorizontalDragEnd: (DragEndDetails details) {
              var velocity = details.velocity.pixelsPerSecond.dx;
              print('onHorizontalDragEnd: velocity: $velocity');
              _onFling(velocity);
            },
            onHorizontalDragCancel: () => _onDragChanged(false),
            onLongPressStart: (details) {
              isOnTap = false;
              isLongPress = true;
              if ((mSelectX != details.localPosition.dx ||
                      mSelectY != details.globalPosition.dy) &&
                  !widget.isTrendLine) {
                mSelectX = details.localPosition.dx;
                notifyChanged();
              }
              //For TrendLine
              if (widget.isTrendLine && changeinXposition == null) {
                mSelectX = changeinXposition = details.localPosition.dx;
                mSelectY = changeinYposition = details.globalPosition.dy;
                notifyChanged();
              }
              //For TrendLine
              if (widget.isTrendLine && changeinXposition != null) {
                changeinXposition = details.localPosition.dx;
                changeinYposition = details.globalPosition.dy;
                notifyChanged();
              }
            },
            onLongPressMoveUpdate: (details) {
              if ((mSelectX != details.localPosition.dx ||
                      mSelectY != details.globalPosition.dy) &&
                  !widget.isTrendLine) {
                mSelectX = details.localPosition.dx;
                mSelectY = details.localPosition.dy;
                notifyChanged();
              }
              if (widget.isTrendLine) {
                mSelectX =
                    mSelectX + (details.localPosition.dx - changeinXposition!);
                changeinXposition = details.localPosition.dx;
                mSelectY =
                    mSelectY + (details.globalPosition.dy - changeinYposition!);
                changeinYposition = details.globalPosition.dy;
                notifyChanged();
              }
            },
            onLongPressEnd: (details) {
              // isLongPress = false;
              enableCordRecord = true;
              mInfoWindowStream.sink.add(null);
              notifyChanged();
            },
            child: GestureDetector(
              onScaleStart: (_) {
                print('zoom in: onscaleStart');
                isScale = true;
              },
              onScaleUpdate: (details) {
                print('zoom in: onScaleUpdate linw 243');
                if (isDrag || isLongPress) return;
                print('zoom in: onScaleUpdate linw 245 ${details.scale}');
                // mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
                // print('onScaleUpdate $mScaleX');
                if (mScaleX != _defaultScale) {
                  mScaleX = _lastScale / 1.25;
                  if (mScaleX < _defaultScale) {
                    mScaleX = _defaultScale;
                  }
                  _lastScale = mScaleX;
                  notifyChanged();
                }
                // notifyChanged();
              },
              onScaleEnd: (_) {
                print('zoom in: onScaleEnd linw 251');
                isScale = false;
                _lastScale = mScaleX;
              },
              onVerticalDragStart: (details) {
                print('on vertical drag start');
                if (isScale || isLongPress) return;
                isScale = true;
              },
              onVerticalDragDown: (details) {
                print('on vertical drag down');
              },
              onVerticalDragUpdate: (details) {
                double distance = details.delta.dy;
                print("HelloRP : onVerticalDragUpdate distance $distance");
                double rowSpace = mHeight / 8;
                if (chartMinValue != null) {
                  chartMinValue = chartMinValue! + distance * rowSpace;
                } else {
                  chartMinValue = actualChartMinValue;
                }
                if (chartMaxValue != null) {
                  chartMaxValue = chartMaxValue! + distance * rowSpace;
                } else {
                  chartMaxValue = actualChartMaxValue;
                }
                Future.delayed(Duration.zero, () {
                  notifyChanged();
                });
                // if (isUpdatingChart) {
                //   return;
                // }
                // isUpdatingChart = true;
                // Future.delayed(Duration(seconds: 1), () {
                //   isUpdatingChart = true;
                //   print("HelloRP : vertical drag x:" +
                //       details.globalPosition.dx.toString() +
                //       " & y:" +
                //       details.globalPosition.dy.toString());
                //   if (chartMinValue != null) {
                //     chartMinValue = chartMinValue! + 600;
                //   } else {
                //     chartMinValue = actualChartMaxValue;
                //   }
                //   notifyChanged();
                //   isUpdatingChart = false;
                // });
              },
              onVerticalDragCancel: () {
                print('on vertical drag cancel');
              },
              onVerticalDragEnd: (details) {
                print('on vertical drag end');
              },
              child: Stack(
                children: <Widget>[
                  CustomPaint(
                    size: Size(double.infinity, baseDimension.mDisplayHeight),
                    painter: _painter,
                  ),
                  if (widget.showInfoDialog) _buildInfoDialog(),
                  if (mScrollX > 30.0) _buildResetScrollButton(),
                  if (mScaleX != _defaultScale) _buildResetZoomButton(),
                  if (showScalingControls) _buildScalingControlsButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      _onDragChanged(false);
      if (needNotify) {
        notifyChanged();
      }
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    if (widget.isOnDrag != null) {
      widget.isOnDrag!(isDrag);
    }
  }

  void _onFling(double x) {
    _controller = AnimationController(
        duration: Duration(milliseconds: widget.flingTime), vsync: this);
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(CurvedAnimation(
            parent: _controller!.view, curve: widget.flingCurve));
    aniX!.addListener(() {
      mScrollX = aniX!.value;
      if (mScrollX <= 0) {
        mScrollX = 0;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(true);
        }
        _stopAnimation();
      } else if (mScrollX >= ChartPainter.maxScrollX) {
        mScrollX = ChartPainter.maxScrollX;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(false);
        }
        _stopAnimation();
      }
      notifyChanged();
    });
    aniX!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });
    _controller!.forward();
  }

  void notifyChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  late List<String> infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
      stream: mInfoWindowStream.stream,
      builder: (context, snapshot) {
        if ((!isLongPress && !isOnTap) ||
            widget.isLine == true ||
            !snapshot.hasData ||
            snapshot.data?.kLineEntity == null) return SizedBox();
        KLineEntity entity = snapshot.data!.kLineEntity;
        final dialogWidth = mWidth / 3;
        if (snapshot.data!.isLeft) {
          return Positioned(
            top: 25,
            left: 10.0,
            child: PopupInfoView(
              entity: entity,
              width: dialogWidth,
              chartColors: widget.chartColors,
              chartTranslations: widget.chartTranslations,
              materialInfoDialog: widget.materialInfoDialog,
              timeFormat: widget.timeFormat,
              fixedLength: widget.fixedLength,
            ),
          );
        }
        return Positioned(
          top: 25,
          right: 10.0,
          child: PopupInfoView(
            entity: entity,
            width: dialogWidth,
            chartColors: widget.chartColors,
            chartTranslations: widget.chartTranslations,
            materialInfoDialog: widget.materialInfoDialog,
            timeFormat: widget.timeFormat,
            fixedLength: widget.fixedLength,
          ),
        );
      },
    );
  }

  Widget _buildResetScrollButton() {
    return Positioned(
        bottom: 65.0,
        right: 100.0,
        child: Semantics(
          attributedLabel: AttributedString("resetScrollingMiniChart"),
          child: GestureDetector(
            onTap: () {
              mScrollX = 0.0;
              notifyChanged();
            },
            child: Material(
              elevation: 2.0,
              borderRadius: BorderRadius.circular(4),
              color: widget.chartColors.resetReloadBackgroundColor,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: widget.scrollToEndChartIcon ??
                    Icon(
                      Icons.fast_forward,
                      size: 16.0,
                      color: widget.chartColors.resetReloadForegroundColor,
                    ),
              ),
            ),
          ),
        ));
  }

  Widget _buildResetZoomButton() {
    return Positioned(
      bottom: 65.0,
      right: mWidth / 2,
      child: Semantics(
        attributedLabel: AttributedString("resetScalingMiniChart"),
        child: GestureDetector(
          onTap: () {
            mScrollX = 0.0;
            mScaleX = _defaultScale;
            _lastScale = _defaultScale;
            isScale = false;
            notifyChanged();
          },
          child: Material(
            elevation: 2.0,
            borderRadius: BorderRadius.circular(4),
            color: widget.chartColors.resetReloadBackgroundColor,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: widget.resetIcon ??
                  Icon(
                    Icons.refresh,
                    size: 16.0,
                    color: widget.chartColors.resetReloadForegroundColor,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScalingControlsButtons() {
    return Positioned(
      bottom: 8,
      left: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            attributedLabel: AttributedString("scaleOutMiniChart"),
            child: GestureDetector(
              onTap: () {
                if (mScaleX != _defaultScale) {
                  mScaleX = _lastScale / 1.25;
                  if (mScaleX < _defaultScale) {
                    mScaleX = _defaultScale;
                  }
                  _lastScale = mScaleX;
                  notifyChanged();
                }
              },
              child: Material(
                  color: widget.chartColors.scalingControlsBackgroundColor,
                  elevation: 2.0,
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 28,
                    width: 28,
                    child: Icon(Icons.remove,
                        color:
                            widget.chartColors.scalingControlsForegroundColor),
                  )),
            ),
          ),
          SizedBox(
            width: 4.0,
          ),
          Semantics(
            attributedLabel: AttributedString("scaleInMiniChart"),
            child: GestureDetector(
              onTap: () {
                mScaleX = _lastScale * 1.25;
                _lastScale = mScaleX;
                notifyChanged();
              },
              child: Material(
                color: widget.chartColors.scalingControlsBackgroundColor,
                elevation: 2.0,
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: Icon(
                    Icons.add,
                    color: widget.chartColors.scalingControlsForegroundColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScalingControls() {
    showScalingControls = !showScalingControls;
    notifyChanged();
    _showScalingControlsTimer?.cancel();
    _showScalingControlsTimer = Timer(Duration(seconds: 5), () {
      if (showScalingControls) {
        showScalingControls = false;
        notifyChanged();
      }
    });
  }
}
