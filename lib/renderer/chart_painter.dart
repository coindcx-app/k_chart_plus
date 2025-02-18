import 'dart:async' show StreamSink;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:k_chart_plus/utils/number_util.dart';
import '../entity/info_window_entity.dart';
import '../entity/k_line_entity.dart';
import '../utils/date_format_util.dart';
import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'base_dimension.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';
import 'vol_renderer.dart';

class TrendLine {
  final Offset p1;
  final Offset p2;
  final double maxHeight;
  final double scale;

  TrendLine(this.p1, this.p2, this.maxHeight, this.scale);
}

double? trendLineX;

double getTrendLineX() {
  return trendLineX ?? 0;
}

class ChartPainter extends BaseChartPainter {
  final List<TrendLine> lines; //For TrendLine
  final bool isTrendLine; //For TrendLine
  bool isrecordingCord = false; //For TrendLine
  final double selectY; //For TrendLine
  static get maxScrollX => BaseChartPainter.maxScrollX;
  late BaseChartRenderer mMainRenderer;
  BaseChartRenderer? mVolRenderer;
  Set<BaseChartRenderer> mSecondaryRendererList = {};
  StreamSink<InfoWindowEntity?> sink;
  Color? upColor, dnColor;
  Color? ma5Color, ma10Color, ma30Color;
  Color? volColor;
  Color? macdColor, difColor, deaColor, jColor;
  int fixedLength;
  List<int> maDayList;
  final ChartColors chartColors;
  late Paint selectPointPaint, selectorBorderPaint, nowPricePaint;
  final ChartStyle chartStyle;
  final bool hideGrid;
  final bool showNowPrice;
  final VerticalTextAlignment verticalTextAlignment;
  final VerticalTextAlignment priveNowVerticalTextAlignment;
  final BaseDimension baseDimension;
  Function({required double chartMinValue, required double chartMaxValue})? onChartMinMaxUpdates;

  ChartPainter(
    this.chartStyle,
    this.chartColors, {
    required this.lines, //For TrendLine
    required this.isTrendLine, //For TrendLine
    required this.selectY, //For TrendLine
    required this.sink,
    required datas,
    required scaleX,
    required scrollX,
    required isLongPass,
    required selectX,
    required xFrontPadding,
    required this.baseDimension,
    isOnTap,
    super.chartMaxValue,
    super.chartMinValue,
    isTapShowInfoDialog,
    required this.verticalTextAlignment,
    required this.priveNowVerticalTextAlignment,
    mainState,
    volHidden,
    secondaryStateLi,
    bool isLine = false,
    this.onChartMinMaxUpdates,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
  }) : super(chartStyle,
            datas: datas,
            scaleX: scaleX,
            scrollX: scrollX,
            isLongPress: isLongPass,
            baseDimension: baseDimension,
            isOnTap: isOnTap,
            isTapShowInfoDialog: isTapShowInfoDialog,
            selectX: selectX,
            mainState: mainState,
            volHidden: volHidden,
            secondaryStateLi: secondaryStateLi,
            xFrontPadding: xFrontPadding,
            isLine: isLine) {
    selectPointPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..color = this.chartColors.selectFillColor;
    selectorBorderPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..color = this.chartColors.selectBorderColor;
    nowPricePaint = Paint()
      ..strokeWidth = this.chartStyle.nowPriceLineWidth
      ..isAntiAlias = true;
  }

  @override
  void initChartRenderer() {
    if (datas != null && datas!.isNotEmpty) {
      var t = datas![0];
      fixedLength =
          NumberUtil.getMaxDecimalLength(t.open, t.close, t.high, t.low);
    }
    mMainRenderer = MainRenderer(
      mMainRect,
      mMainMaxValue,
      mMainMinValue,
      mTopPadding,
      mainState,
      isLine,
      fixedLength,
      this.chartStyle,
      this.chartColors,
      this.scaleX,
      verticalTextAlignment,
      maDayList,
    );
    if (onChartMinMaxUpdates != null) {
      onChartMinMaxUpdates!(
          chartMaxValue: mMainMinValue, chartMinValue: mMainMaxValue);
    }
    if (mVolRect != null) {
      mVolRenderer = VolRenderer(mVolRect!, mVolMaxValue, mVolMinValue,
          mChildPadding, fixedLength, this.chartStyle, this.chartColors);
    }
    mSecondaryRendererList.clear();
    for (int i = 0; i < mSecondaryRectList.length; ++i) {
      mSecondaryRendererList.add(SecondaryRenderer(
        mSecondaryRectList[i].mRect,
        mSecondaryRectList[i].mMaxValue,
        mSecondaryRectList[i].mMinValue,
        mChildPadding,
        secondaryStateLi.elementAt(i),
        fixedLength,
        chartStyle,
        chartColors,
      ));
    }
  }

  @override
  void drawBg(Canvas canvas, Size size) {
    Paint mBgPaint = Paint()..color = chartColors.bgColor;
    Rect mainRect =
        Rect.fromLTRB(0, 0, mMainRect.width, mMainRect.height + mTopPadding);
    canvas.drawRect(mainRect, mBgPaint);

    if (mVolRect != null) {
      Rect volRect = Rect.fromLTRB(
          0, mVolRect!.top - mChildPadding, mVolRect!.width, mVolRect!.bottom);
      canvas.drawRect(volRect, mBgPaint);
    }

    for (int i = 0; i < mSecondaryRectList.length; ++i) {
      Rect? mSecondaryRect = mSecondaryRectList[i].mRect;
      Rect secondaryRect = Rect.fromLTRB(0, mSecondaryRect.top - mChildPadding,
          mSecondaryRect.width, mSecondaryRect.bottom);
      canvas.drawRect(secondaryRect, mBgPaint);
    }
    Rect dateRect =
        Rect.fromLTRB(0, size.height - mBottomPadding, size.width, size.height);
    canvas.drawRect(dateRect, mBgPaint);
  }

  @override
  void drawGrid(canvas) {
    if (!hideGrid) {
      mMainRenderer.drawGrid(canvas, mGridRows, mGridColumns);
      mVolRenderer?.drawGrid(canvas, mGridRows, mGridColumns);
      mSecondaryRendererList.forEach((element) {
        element.drawGrid(canvas, mGridRows, mGridColumns);
      });
    }
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(mTranslateX * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);
    for (int i = mStartIndex; datas != null && i <= mStopIndex; i++) {
      KLineEntity? curPoint = datas?[i];
      if (curPoint == null) continue;
      KLineEntity lastPoint = i == 0 ? curPoint : datas![i - 1];
      double curX = getX(i);
      double lastX = i == 0 ? curX : getX(i - 1);

      mMainRenderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mVolRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mSecondaryRendererList.forEach((element) {
        element.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      });
    }

    if ((isLongPress == true || (isTapShowInfoDialog && isOnTap)) &&
        isTrendLine == false) {
      drawCrossLine(canvas, size);
    }
    if (isTrendLine == true) drawTrendLines(canvas, size);
    canvas.restore();
  }

  @override
  void drawVerticalText(canvas) {
    var textStyle = getTextStyle(this.chartColors.defaultTextColor);
    if (!hideGrid) {
      mMainRenderer.drawVerticalText(canvas, textStyle, mGridRows);
    }
    mVolRenderer?.drawVerticalText(canvas, textStyle, mGridRows);
    mSecondaryRendererList.forEach((element) {
      element.drawVerticalText(canvas, textStyle, mGridRows);
    });
  }

  @override
  void drawDate(Canvas canvas, Size size) {
    if (datas == null) return;

    double columnSpace = size.width / mGridColumns;
    double startX = getX(mStartIndex) - mPointWidth / 2;
    double stopX = getX(mStopIndex) + mPointWidth / 2;
    double x = 0.0;
    double y = 0.0;
    for (var i = 0; i <= mGridColumns; ++i) {
      double translateX = xToTranslateX(columnSpace * i);

      if (translateX >= startX && translateX <= stopX) {
        int index = indexOfTranslateX(translateX);

        if (datas?[index] == null) continue;
        TextPainter tp = getTextPainter(getDateBasedOnTime(datas, index), null);
        y = size.height - (mBottomPadding - tp.height) / 2 - tp.height;
        x = columnSpace * i - tp.width / 2;
        // Prevent date text out of canvas
        if (x < 0) x = 10;
        if (x > size.width - tp.width) x = size.width - tp.width;
        tp.paint(canvas, Offset(x, y));
      }
    }

    // Determine the width for the vertical price area
    double priceLabelWidth = 50.0; // Adjust this width as needed

// Get the height of the canvas
    double height = size.height;

// Draw the background rectangle for the price area
    Paint backgroundPaint = Paint()
      ..color = this.chartColors.bgColor // Set the desired background color
      ..style = PaintingStyle.fill;

// Draw the background on the right side of the chart
    canvas.drawRect(
        Rect.fromLTRB(size.width - priceLabelWidth, size.height - 20,
            size.width, height), // Adjust the x-coordinate and width as needed
        backgroundPaint);

//    double translateX = xToTranslateX(0);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStartIndex].id));
//      tp.paint(canvas, Offset(0, y));
//    }
//    translateX = xToTranslateX(size.width);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStopIndex].id));
//      tp.paint(canvas, Offset(size.width - tp.width, y));
//    }
  }

  /// draw the cross line. when user focus
  @override
  void drawCrossLineText(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);

    TextPainter tp = getTextPainter(point.close, chartColors.crossTextColor);
    double textHeight = tp.height;
    double textWidth = tp.width;

    double w1 = 5;
    double w2 = 3;
    double r = textHeight / 2 + w2;
    double y = getMainY(point.close);
    double x;
    bool isLeft = false;
    // if (translateXtoX(getX(index)) < mWidth / 2) {
    //   isLeft = false;
    //   x = 1;
    //   Path path = new Path();
    //   path.moveTo(x, y - r);
    //   path.lineTo(x, y + r);
    //   path.lineTo(textWidth + 2 * w1, y + r);
    //   path.lineTo(textWidth + 2 * w1 + w2, y);
    //   path.lineTo(textWidth + 2 * w1, y - r);
    //   path.close();
    //   canvas.drawPath(path, selectPointPaint);
    //   canvas.drawPath(path, selectorBorderPaint);
    //   tp.paint(canvas, Offset(x + w1, y - textHeight / 2));
    // } else {
    //   isLeft = true;
    //   x = mWidth - textWidth - 1 - 2 * w1 - w2;
    //   Path path = new Path();
    //   path.moveTo(x, y);
    //   path.lineTo(x + w2, y + r);
    //   path.lineTo(mWidth - 2, y + r);
    //   path.lineTo(mWidth - 2, y - r);
    //   path.lineTo(x + w2, y - r);
    //   path.close();
    //   canvas.drawPath(path, selectPointPaint);
    //   canvas.drawPath(path, selectorBorderPaint);
    //   tp.paint(canvas, Offset(x + w1 + w2, y - textHeight / 2));
    // }
    isLeft = true;
    x = mWidth - textWidth - 1 - 2 * w1 - w2;
    Path path = new Path();
    path.moveTo(x, y);
    path.lineTo(x + w2, y + r);
    path.lineTo(mWidth - 2, y + r);
    path.lineTo(mWidth - 2, y - r);
    path.lineTo(x + w2, y - r);
    path.close();
    canvas.drawPath(path, selectPointPaint);
    canvas.drawPath(path, selectorBorderPaint);
    tp.paint(canvas, Offset(x + w1 + w2, y - textHeight / 2));

    TextPainter dateTp =
        getTextPainter(getDate(point.time), chartColors.crossTextColor);
    textWidth = dateTp.width;
    r = textHeight / 2;
    x = translateXtoX(getX(index));
    y = size.height - mBottomPadding;

    if (x < textWidth + 2 * w1) {
      x = 1 + textWidth / 2 + w1;
    } else if (mWidth - x < textWidth + 2 * w1) {
      x = mWidth - 1 - textWidth / 2 - w1;
    }
    double baseLine = textHeight / 2;
    canvas.drawRect(
        Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
            y + baseLine + r),
        selectPointPaint);
    canvas.drawRect(
        Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
            y + baseLine + r),
        selectorBorderPaint);

    dateTp.paint(canvas, Offset(x - textWidth / 2, y));
    //Long press to display the details of this data
    sink.add(InfoWindowEntity(point, isLeft: isLeft));
  }

  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {
    //Long press to display the data in the press
    if (isLongPress || (isTapShowInfoDialog && isOnTap)) {
      var index = calculateSelectedX(selectX);
      data = getItem(index);
    }
    //Release to display the last data
    mMainRenderer.drawText(canvas, data, x);
    mVolRenderer?.drawText(canvas, data, x);
    mSecondaryRendererList.forEach((element) {
      element.drawText(canvas, data, x);
    });
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (isLine == true) return;
    //plot maxima and minima
    double x = translateXtoX(getX(mMainMinIndex));

    double y = getMainY(mMainLowMinValue);

    const double padding = 2.0;

    ///new code for low
    Paint maxPricePaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = this.chartStyle.nowPriceLineWidth
      ..color = this.chartColors.highLowPriceBackgroundColor;
    // low text
    TextPainter lowTp =
        getTextPainter('Low', this.chartColors.highLowPriceForegroundColor);

    // checking if low and nowPrice might overlap
    double _nowPrice = datas!.last.close;
    double _nowPriceY = getMainY(_nowPrice);
    if ((_nowPriceY - y).abs() < 10) {
      if (_nowPrice > mMainLowMinValue) {
        y = y + (lowTp.height + padding * 2);
      } else {
        y = y - (lowTp.height + padding * 2);
      }
    }

    double top = y - lowTp.height / 2 - padding;
    double lowTextOffsetX = mWidth - lowTp.width - 55;
    canvas.drawRect(
        Rect.fromLTRB(lowTextOffsetX - 4, top, lowTextOffsetX + lowTp.width + 4,
            top + lowTp.height + padding * 2),
        maxPricePaint);
    lowTp.paint(canvas, Offset(lowTextOffsetX, top + padding));
    // low value
    TextPainter tp = getTextPainter(
        mMainLowMinValue.toStringAsFixed(fixedLength),
        this.chartColors.highLowPriceForegroundColor);

    double offsetX = mWidth - 45;
    canvas.drawRect(
        Rect.fromLTRB(offsetX - 4, top, offsetX + tp.width + 4,
            top + tp.height + padding * 2),
        maxPricePaint);
    tp.paint(canvas, Offset(offsetX, top + padding));

    ///new code for high
    // high text
    y = getMainY(mMainHighMaxValue);
    TextPainter highTp =
        getTextPainter('High', this.chartColors.highLowPriceForegroundColor);

    // checking if High and nowPrice might overlap
    _nowPrice = datas!.last.close;
    _nowPriceY = getMainY(_nowPrice);
    if ((_nowPriceY - y).abs() < 10) {
      if (_nowPrice > mMainHighMaxValue) {
        y = y + (highTp.height + padding * 2);
      } else {
        y = y - (highTp.height + padding * 2);
      }
    }

    double highTop = y - highTp.height / 2 - padding;

    double highTextOffsetX = mWidth - highTp.width - 55;
    canvas.drawRect(
        Rect.fromLTRB(
            highTextOffsetX - 4,
            highTop,
            highTextOffsetX + highTp.width + 4,
            highTop + highTp.height + padding * 2),
        maxPricePaint);
    highTp.paint(canvas, Offset(highTextOffsetX, highTop + padding));

    // high value
    TextPainter highValueTp = getTextPainter(
        mMainHighMaxValue.toStringAsFixed(fixedLength),
        this.chartColors.highLowPriceForegroundColor);
    double highOffsetX = mWidth - 45;
    canvas.drawRect(
        Rect.fromLTRB(
            highOffsetX - 4,
            highTop,
            highOffsetX + highValueTp.width + 4,
            highTop + highValueTp.height + padding * 2),
        maxPricePaint);
    highValueTp.paint(canvas, Offset(highOffsetX, highTop + padding));
  }

  @override
  void drawNowPrice(Canvas canvas) {
    if (!this.showNowPrice) {
      return;
    }

    if (datas == null) {
      return;
    }

    double value = datas!.last.close;
    double y = getMainY(value);

    //view display area boundary value drawing
    if (y > getMainY(mMainLowMinValue)) {
      y = getMainY(mMainLowMinValue);
    }

    if (y < getMainY(mMainHighMaxValue)) {
      y = getMainY(mMainHighMaxValue);
    }

    nowPricePaint
      ..color = value >= datas!.last.open
          ? this.chartColors.nowPriceUpColor
          : this.chartColors.nowPriceDnColor;
    //first draw the horizontal line
    double startX = 0;
    final max = -mTranslateX + mWidth / scaleX;
    final space =
        this.chartStyle.nowPriceLineSpan + this.chartStyle.nowPriceLineLength;
    while (startX < max) {
      canvas.drawLine(
          Offset(startX, y),
          Offset(startX + this.chartStyle.nowPriceLineLength, y),
          nowPricePaint);
      startX += space;
    }
    //repaint the background and text
    TextPainter tp = getTextPainter(
      value.toStringAsFixed(fixedLength),
      this.chartColors.nowPriceTextColor,
    );

    double offsetX = mWidth - 55;
    switch (priveNowVerticalTextAlignment) {
      case VerticalTextAlignment.right:
        offsetX = mWidth - 45;
        break;
      case VerticalTextAlignment.left:
        offsetX = 0;
        break;
    }

    double padding = 2.0;
    double top = y - tp.height / 2 - padding;
    canvas.drawRect(
        Rect.fromLTRB(offsetX - 4, top, offsetX + tp.width + 4,
            top + tp.height + padding * 2),
        nowPricePaint);
    tp.paint(canvas, Offset(offsetX - 2, top + padding));
  }

  //For TrendLine
  void drawTrendLines(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    Paint paintY = Paint()
      ..color = chartColors.trendLineColor
      ..strokeWidth = 1
      ..isAntiAlias = true;
    double x = getX(index);
    trendLineX = x;

    double y = selectY;
    // getMainY(point.close);

    // K-line chart vertical line
    canvas.drawLine(Offset(x, mTopPadding),
        Offset(x, size.height - mBottomPadding), paintY);
    Paint paintX = Paint()
      ..color = chartColors.trendLineColor
      ..strokeWidth = 1
      ..isAntiAlias = true;
    Paint paint = Paint()
      ..color = chartColors.trendLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-mTranslateX, y),
        Offset(-mTranslateX + mWidth / scaleX, y), paintX);
    if (scaleX >= 1) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y), height: 15.0 * scaleX, width: 15.0),
        paint,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y), height: 10.0, width: 10.0 / scaleX),
        paint,
      );
    }
    if (lines.isNotEmpty) {
      lines.forEach((element) {
        var y1 = -((element.p1.dy - 35) / element.scale) + element.maxHeight;
        var y2 = -((element.p2.dy - 35) / element.scale) + element.maxHeight;
        var a = (trendLineMax! - y1) * trendLineScale! + trendLineContentRec!;
        var b = (trendLineMax! - y2) * trendLineScale! + trendLineContentRec!;
        var p1 = Offset(element.p1.dx, a);
        var p2 = Offset(element.p2.dx, b);
        canvas.drawLine(
            p1,
            element.p2 == Offset(-1, -1) ? Offset(x, y) : p2,
            Paint()
              ..color = Colors.yellow
              ..strokeWidth = 2);
      });
    }
  }

  ///draw cross lines
  void drawCrossLine(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);
    Paint paintY = Paint()
      ..color = this.chartColors.vCrossColor
      ..strokeWidth = this.chartStyle.vCrossWidth
      ..isAntiAlias = true;
    double x = getX(index);
    double y = getMainY(point.close);
    // K-line chart vertical line
    // canvas.drawLine(Offset(x, mTopPadding),
    //     Offset(x, size.height - mBottomPadding), paintY);
    // K-line chart vertical dashed line
    final double dashWidth =
        this.chartStyle.nowPriceLineLength; // Width of each dash
    final double dashSpace = this.chartStyle.nowPriceLineSpan +
        this.chartStyle.nowPriceLineLength; // Space between dashes

    double startY = mTopPadding;
    // Calculate the total height of the line to draw
    double totalHeight = size.height - mTopPadding;

    while (startY < totalHeight) {
      // Draw a dash
      canvas.drawLine(Offset(x, startY), Offset(x, startY + dashWidth), paintY);
      startY += dashWidth + dashSpace; // Move to the start of the next dash
    }

    Paint paintX = Paint()
      ..color = this.chartColors.hCrossColor
      ..strokeWidth = this.chartStyle.hCrossWidth
      ..isAntiAlias = true;
    // K-line chart horizontal line
    // canvas.drawLine(Offset(-mTranslateX, y),
    //     Offset(-mTranslateX + mWidth / scaleX, y), paintX);

    // K-line chart horizontal dashed line
    double startX = 0;
    final max = -mTranslateX + mWidth / scaleX;
    while (startX < max) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paintX);
      startX += dashWidth + dashSpace;
    }
    if (scaleX >= 1) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), height: 2.0 * scaleX, width: 2.0),
        paintX,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), height: 2.0, width: 2.0 / scaleX),
        paintX,
      );
    }
  }

  TextPainter getTextPainter(text, color) {
    if (color == null) {
      color = this.chartColors.defaultTextColor;
    }
    TextSpan span = TextSpan(text: "$text", style: getTextStyle(color));
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  String getDate(int? date) {
    intl.DateFormat dateFormat = intl.DateFormat("dd MMM ''yy   HH:mm");
    String formattedDate = dateFormat.format(
        DateTime.fromMillisecondsSinceEpoch(
            date ?? DateTime.now().millisecondsSinceEpoch));
    return formattedDate;
  }

  double getMainY(double y) => mMainRenderer.getY(y);

  /// Whether the point is in the SecondaryRect
  // bool isInSecondaryRect(Offset point) {
  //   // return mSecondaryRect.contains(point) == true);
  //   return false;
  // }

  /// Whether the point is in MainRect
  bool isInMainRect(Offset point) {
    return mMainRect.contains(point);
  }

  String getDateBasedOnTime(List<KLineEntity>? data, int index) {
    // if (data == null || index < 0 || index >= data.length) {
    //   return '';
    // }
    //
    // final currentItem = data[index];
    // DateTime currentTime = DateTime.fromMillisecondsSinceEpoch(currentItem.time!);
    //
    // // If there's no previous item, we can only return the current item's date.
    // if (index == 0) {
    //   return DateFormat('HH:mm').format(currentTime);
    // }
    //
    // final previousItem = data[index - 1];
    // DateTime previousTime = DateTime.fromMillisecondsSinceEpoch(previousItem.time!);
    //
    // // Calculate the time difference
    // Duration difference = currentTime.difference(previousTime);
    //
    // // Check for date changes
    // if (currentTime.year != previousTime.year) {
    //   return DateFormat('yyyy').format(currentTime);
    // }
    // if (currentTime.month != previousTime.month) {
    //   return DateFormat('MMM').format(currentTime);
    // }
    // if (currentTime.day != previousTime.day) {
    //   return DateFormat('d').format(currentTime);
    // }
    //
    // // If time difference is less than an hour
    // if (difference.inMinutes < 60) {
    //   return DateFormat('HH:mm').format(currentTime);
    // }
    //
    // // If time difference is greater than or equal to an hour
    // return DateFormat('d').format(currentTime);

    if (data == null || index < 0 || index >= data.length) {
      return '';
    }

    final currentItem = data[index];
    DateTime currentTime =
        DateTime.fromMillisecondsSinceEpoch(currentItem.time!);

    if (index == 0) {
      return '${currentTime.day.toString()}-${currentTime.month.toString()}-${currentTime.year.toString()} ${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
    }
    int minusCol = 16;
    int _previousIndex = index - minusCol;
    _previousIndex = _previousIndex < 0 ? 0 : _previousIndex;
    final previousItem = data[_previousIndex];
    DateTime previousTime =
        DateTime.fromMillisecondsSinceEpoch(previousItem.time!);

    Duration difference = currentTime.difference(previousTime);
    // print("index: $index, prev index: ${index - minusCol}, currt time: ${currentTime}, prev index time: ${previousTime}, diff: $difference");
    if (currentTime.year != previousTime.year) {
      return currentTime.year.toString();
    }
    if (currentTime.month != previousTime.month) {
      return monthShort[currentTime.month - 1];
    }
    if (currentTime.day != previousTime.day) {
      return currentTime.day.toString();
    }

    if (difference.inMinutes < 60 || currentTime.day == previousTime.day) {
      return '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
    }

    return currentTime.day.toString();
  }
}
