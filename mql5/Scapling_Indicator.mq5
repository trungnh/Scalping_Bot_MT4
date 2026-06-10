//+------------------------------------------------------------------+
//| XAUUSD Price Action Scalping Indicator v1.0                      |
//| Port 100% từ Pine Script v1.43 — bao gồm toàn bộ chart drawing  |
//| Bỏ: stats table. Dùng để kiểm tra logic vs TradingView.          |
//+------------------------------------------------------------------+
#property copyright "XAUUSD PA Scalping Indicator"
#property version   "1.0"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot 1 — ATR Trailing Stop (đường màu xanh)
#property indicator_label1  "ATR Stop"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
#property indicator_style1  STYLE_SOLID

// Plot 2 — ATR Buy confirm (mũi tên lên)
#property indicator_label2  "ATR Buy"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  C'8,153,129'

// Plot 3 — ATR Sell confirm (mũi tên xuống)
#property indicator_label3  "ATR Sell"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  C'242,54,69'

//=================================================================
// INPUTS
//=================================================================
input int             InpSwingLen    = 5;          // Swing Length (TF hiện tại)
input int             InpSwingLenHTF = 5;          // Swing Length HTF
input ENUM_TIMEFRAMES InpHigherTF    = PERIOD_M5;  // Khung Higher TF (bias)
input int             InpMaxBOS      = 3;          // Số BOS HTF tối đa mỗi chu kỳ

input bool            InpOBMitigClose   = true;    // OB Mitigation = Close (false = High/Low)
input int             InpObCount        = 5;       // Số OB TF hiện tại hiển thị

input double          InpAtrKey    = 1.0;          // ATR Key Value
input int             InpAtrPeriod = 10;           // ATR Period
input bool            InpUseHA     = true;         // Dùng Heikin Ashi

input int             InpTpTicks   = 5000;         // Take Profit (ticks)
input int             InpSlTicks   = 50000;        // Stop Loss dự phòng (ticks)
input int             InpSlMode    = 1;            // SL Mode: 0=CHoCH HTF, 1=BOS/CHoCH, 2=Ticks
input bool            InpCloseOnHTF     = true;    // Đóng lệnh khi HTF CHoCH ngược
input bool            InpSpecialEntry   = false;   // Cho phép lệnh đặc biệt ★

input bool            InpEnableTimeFilter = true;  // Bật lọc khung giờ
input string          InpTZ  = "UTC+7";            // Timezone
input bool            InpEnS1 = true;              // London
input string          InpS1   = "1515-1815";       // London session
input bool            InpEnS2 = true;              // New York
input string          InpS2   = "2030-0045";       // New York session
input bool            InpEnS3 = true;              // Phiên Á
input string          InpS3   = "0730-0900";       // Phiên Á session
input bool            InpEnS4 = true;              // Tùy chỉnh
input string          InpS4   = "1030-1315";       // Tùy chỉnh session

input bool  InpShowTFStruct   = true;   // Hiện CHoCH/BOS TF hiện tại
input bool  InpShowHTFStruct  = true;   // Hiện CHoCH/BOS HTF
input bool  InpShowTFOBs      = true;   // Hiện OB TF hiện tại
input bool  InpShowHTFOBs     = true;   // Hiện S/R HTF
input bool  InpShowATRSignal  = false;  // Hiện ATR Confirm signals
input bool  InpShowBoxes      = true;   // Hiện Box TP/SL
input bool  InpShowSessionBox = true;   // Vẽ box phiên

//=================================================================
// CONSTANTS + COLORS
//=================================================================
#define BULLISH      1
#define BEARISH     -1
#define BULLISH_LEG  1
#define BEARISH_LEG  0
#define MAX_OB      100
#define MAX_SR       20
#define MAX_PARSED  10000
#define MAX_TRADE    50
#define OBJ_PFX     "XAUIPA_"

// Pine Script color equivalents
#define C_GREEN      ((color)0x819908)   // #089981 R=8 G=153 B=129
#define C_RED        ((color)0x4536F2)   // #F23645 R=242 G=54 B=69
#define C_PINK       ((color)0x631EE9)   // #E91E63
#define C_CYAN       ((color)0xD4BC00)   // #00BCD4
#define C_BULL_OB    ((color)0xF57931)   // #3179F5
#define C_BEAR_OB    ((color)0x807CF7)   // #F77C80
#define C_SESS1      ((color)0xF39621)   // #2196F3
#define C_SESS2      ((color)0x0098FF)   // #FF9800
#define C_SESS3      ((color)0x50AF4C)   // #4CAF50
#define C_SESS4      ((color)0xB0279C)   // #9C27B0
#define C_HTF_BULL_C clrWhite
#define C_HTF_BEAR_C clrWhite
#define C_HTF_BULL_B ((color)0x50AF4C)   // #4CAF50
#define C_HTF_BEAR_B ((color)0x2257FF)   // #FF5722

//=================================================================
// STRUCTS
//=================================================================
struct SPivot
{
    double   currentLevel;
    double   lastLevel;
    bool     crossed;
    datetime barTime;
    int      barIndex;
};

struct SOrderBlock
{
    double   barHigh;
    double   barLow;
    datetime barTime;
    int      bias;
    bool     active;
    string   boxName;
};

struct SSRLevel
{
    double   level;
    datetime startTime;
    bool     active;
    string   lineName;
    string   lblName;
};

struct STradeVisual
{
    string   nameEntLbl;
    string   nameBoxTP;
    string   nameBoxSL;
    string   nameEntLn;
    string   nameLblTP;
    string   nameLblSL;
    double   ep, tp, sl;
    int      direction;
    string   src;
    bool     active;
};

//=================================================================
// INDICATOR BUFFERS
//=================================================================
double g_atrStopBuf[];
double g_atrBuyBuf[];
double g_atrSellBuf[];

//=================================================================
// GLOBAL STATE (same as EA)
//=================================================================
int    g_state          = 0;
int    g_bias           = 0;
int    g_bosCount       = 0;
bool   g_pendingLong    = false;
bool   g_pendingShort   = false;
bool   g_bosSeen        = false;
bool   g_chochTradeOpen = false;
bool   g_bosTradeUsed   = false;
int    g_tfBosCount     = 0;
bool   g_tfBosLimitHit  = false;
bool   g_chochAtrFired  = false;
double g_tfSweepBullLevel = 0;
double g_tfSweepBearLevel = 0;
double g_cycleSL          = 0;
double g_cycleSL_choch    = 0;
string g_pendingSrc       = "choch";

bool   g_execLong    = false;
bool   g_execShort   = false;
bool   g_execSpLong  = false;
bool   g_execSpShort = false;
string g_execSrc     = "choch";

bool   g_spArmed       = false;
double g_spCH          = 0;
double g_spCL          = 0;
double g_spCBodyTop    = 0;
double g_spCBodyBot    = 0;
int    g_spBias        = 0;
int    g_spBarsAfter   = 0;
bool   g_pendingSpLong  = false;
bool   g_pendingSpShort = false;

// TF structure
SPivot g_tfHigh      = {0,0,false,0,0};
SPivot g_tfLow       = {0,0,false,0,0};
int    g_tfTrendBias = 0;
int    g_tfLegState  = BEARISH_LEG;

// HTF structure
SPivot g_m5High      = {0,0,false,0,0};
SPivot g_m5Low       = {0,0,false,0,0};
int    g_m5TrendBias = 0;
int    g_m5LegState  = BEARISH_LEG;

bool   g_m5_chochBull = false;
bool   g_m5_chochBear = false;
bool   g_m5_bosBull   = false;
bool   g_m5_bosBear   = false;
double g_m5_highVal   = 0;
double g_m5_lowVal    = 0;

bool   g_tf_chochBull = false;
bool   g_tf_chochBear = false;
bool   g_tf_bosBull   = false;
bool   g_tf_bosBear   = false;

// ATR state
double g_xATRStop  = 0;
double g_srcPrice  = 0;
double g_srcPrice1 = 0;
double g_haOpen    = 0;
double g_haClose   = 0;
bool   g_atrBuy    = false;
bool   g_atrSell   = false;

// HTF SR sweep
bool g_srBreakBull    = false;
int  g_srBreakBullIdx = -1;
bool g_srBreakBear    = false;
int  g_srBreakBearIdx = -1;

// parsedHighs/parsedLows (Luxalgo HVB adjusted)
double   g_parsedHighs[MAX_PARSED];
double   g_parsedLows[MAX_PARSED];
datetime g_obTimes[MAX_PARSED];
int      g_parsedCount = 0;
// actual highs/lows for SR level calculation (not HVB adjusted)
double   g_actualHighs[MAX_PARSED];
double   g_actualLows[MAX_PARSED];

// TF OBs
SOrderBlock g_tfOBs[MAX_OB];
int         g_tfOBCount = 0;

// HTF SR levels
SSRLevel g_resistanceLevels[MAX_SR];
SSRLevel g_supportLevels[MAX_SR];
int      g_resistCount = 0;
int      g_supportCount = 0;

// Trade visuals
STradeVisual g_tradeVisuals[MAX_TRADE];
int          g_tradeVisCount = 0;

// Bar tracking
int      g_barIndex         = 0;
datetime g_lastM5BarTime    = 0;
int      g_lastProcessedM5Idx = -1;
bool     g_initialized      = false;
int      g_objCounter       = 0;

// Session tracking
bool     g_sessWas[4]    = {false,false,false,false};
double   g_sessH[4]      = {0,0,0,0};
double   g_sessL[4]      = {0,0,0,0};
string   g_sessBoxName[4]= {"","","",""};
string   g_sessLblName[4]= {"","","",""};

// ATR indicator handles
int g_atrHandle    = INVALID_HANDLE;
int g_atr200Handle = INVALID_HANDLE;

// M5 cache for historical processing
MqlRates g_m5Cache[];
int      g_m5CacheCount = 0;

// Info table name prefix
string g_infoTblPrefix = OBJ_PFX + "INFO_";

//=================================================================
// OBJECT HELPERS
//=================================================================
string NewObjName(string tag)
{
    g_objCounter++;
    return OBJ_PFX + tag + "_" + IntegerToString(g_objCounter);
}

void DelObj(string name)
{
    if(name != "" && ObjectFind(0, name) >= 0)
        ObjectDelete(0, name);
}

void CreateLine(string name, datetime t1, double p1, datetime t2, double p2,
                color col, int style, int width, bool rayRight=false)
{
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     col);
    ObjectSetInteger(0, name, OBJPROP_STYLE,     style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH,     width);
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, rayRight);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
}

void CreateText(string name, datetime t, double price, string txt,
                color col, int fontSize, int anchor=ANCHOR_LOWER)
{
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
    ObjectSetString( 0, name, OBJPROP_TEXT,      txt);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     col);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fontSize);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR,    anchor);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
}

void CreateBox(string name, datetime t1, double top, datetime t2, double bot,
               color bgCol, color borderCol, int borderWidth=1)
{
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, top, t2, bot);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     borderCol);
    ObjectSetInteger(0, name, OBJPROP_STYLE,     STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH,     borderWidth);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,   bgCol);
    ObjectSetInteger(0, name, OBJPROP_FILL,      true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
}

void BoxSetRight(string name, datetime t2)
{
    if(name != "" && ObjectFind(0, name) >= 0)
        ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
}

void BoxSetTop(string name, double top)
{
    if(name != "" && ObjectFind(0, name) >= 0)
        ObjectSetDouble(0, name, OBJPROP_PRICE, 0, top);
}

void BoxSetBottom(string name, double bot)
{
    if(name != "" && ObjectFind(0, name) >= 0)
        ObjectSetDouble(0, name, OBJPROP_PRICE, 1, bot);
}

void BoxSetBgColor(string name, color col)
{
    if(name != "" && ObjectFind(0, name) >= 0)
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, col);
}

void TextSetXY(string name, datetime t, double price)
{
    if(name != "" && ObjectFind(0, name) >= 0)
    {
        ObjectSetInteger(0, name, OBJPROP_TIME,  0, t);
        ObjectSetDouble( 0, name, OBJPROP_PRICE, 0, price);
    }
}

void TextSetText(string name, string txt)
{
    if(name != "" && ObjectFind(0, name) >= 0)
        ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

void LineSetX2(string name, datetime t2)
{
    if(name != "" && ObjectFind(0, name) >= 0)
        ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
}

color ColorWithAlpha(color col, int alpha) // alpha 0=opaque, 100=transparent (approx)
{
    // MQL5 doesn't support true transparency for objects, return darkened version
    // For boxes with transparency we use the bgcolor directly
    return col;
}

int LineStyleFromStr(string s)
{
    if(s == "Solid")  return STYLE_SOLID;
    if(s == "Dotted") return STYLE_DOT;
    return STYLE_DASH;
}

int FontSizeFromStr(string s)
{
    if(s == "Small")  return 8;
    if(s == "Normal") return 10;
    if(s == "Large")  return 12;
    return 7; // Tiny
}

//=================================================================
// CLEAN UP ALL OBJECTS
//=================================================================
void DeleteAllObjects()
{
    ObjectsDeleteAll(0, OBJ_PFX);
}

//=================================================================
// SESSION HELPER
//=================================================================
int GetUTCOffsetSec(string tz)
{
    int plusPos  = StringFind(tz, "+");
    int minusPos = StringFind(tz, "-", 3);
    if(plusPos >= 0)
    {
        string rest = StringSubstr(tz, plusPos + 1);
        int colonPos = StringFind(rest, ":");
        if(colonPos >= 0)
        {
            int h = (int)StringToInteger(StringSubstr(rest, 0, colonPos));
            int m = (int)StringToInteger(StringSubstr(rest, colonPos + 1));
            return h * 3600 + m * 60;
        }
        return (int)StringToInteger(rest) * 3600;
    }
    else if(minusPos >= 0)
    {
        string rest = StringSubstr(tz, minusPos + 1);
        int colonPos = StringFind(rest, ":");
        if(colonPos >= 0)
        {
            int h = (int)StringToInteger(StringSubstr(rest, 0, colonPos));
            int m = (int)StringToInteger(StringSubstr(rest, colonPos + 1));
            return -(h * 3600 + m * 60);
        }
        return -(int)StringToInteger(rest) * 3600;
    }
    return 0;
}

bool InSessionAt(datetime barTime, bool en, string sess)
{
    if(!en) return false;
    int dashPos = StringFind(sess, "-");
    if(dashPos < 0) return false;

    string startStr = StringSubstr(sess, 0, dashPos);
    string endStr   = StringSubstr(sess, dashPos + 1);
    int startH = (int)StringToInteger(StringSubstr(startStr, 0, 2));
    int startM = (int)StringToInteger(StringSubstr(startStr, 2, 2));
    int endH   = (int)StringToInteger(StringSubstr(endStr, 0, 2));
    int endM   = (int)StringToInteger(StringSubstr(endStr, 2, 2));

    int utcOff = GetUTCOffsetSec(InpTZ);
    datetime localTime = barTime + utcOff;
    MqlDateTime dt;
    TimeToStruct(localTime, dt);
    int nowMin   = dt.hour * 60 + dt.min;
    int startMin = startH * 60 + startM;
    int endMin   = endH   * 60 + endM;

    if(startMin <= endMin)
        return (nowMin >= startMin && nowMin < endMin);
    else
        return (nowMin >= startMin || nowMin < endMin);
}

bool SessionOKAt(datetime barTime)
{
    if(!InpEnableTimeFilter) return true;
    return InSessionAt(barTime, InpEnS1, InpS1) ||
           InSessionAt(barTime, InpEnS2, InpS2) ||
           InSessionAt(barTime, InpEnS3, InpS3) ||
           InSessionAt(barTime, InpEnS4, InpS4);
}

//=================================================================
// SESSION BOX DRAWING
//=================================================================
string g_sessNames[] = {"London","New York","Phien A","Tuy chinh"};
color  g_sessColors[] = {C_SESS1, C_SESS2, C_SESS3, C_SESS4};

void UpdateSessionBoxes(datetime barTime, double barHigh, double barLow,
                         int periodSec)
{
    if(!InpShowSessionBox) return;

    bool sessNow[4];
    sessNow[0] = InSessionAt(barTime, InpEnS1, InpS1);
    sessNow[1] = InSessionAt(barTime, InpEnS2, InpS2);
    sessNow[2] = InSessionAt(barTime, InpEnS3, InpS3);
    sessNow[3] = InSessionAt(barTime, InpEnS4, InpS4);

    datetime extRight = barTime + (datetime)(periodSec * 21);

    for(int s = 0; s < 4; s++)
    {
        if(sessNow[s] && !g_sessWas[s])
        {
            // Session start — create new box
            g_sessH[s] = barHigh;
            g_sessL[s] = barLow;
            g_sessBoxName[s] = NewObjName("SESS" + IntegerToString(s));
            g_sessLblName[s] = NewObjName("SESSL" + IntegerToString(s));

            color col   = g_sessColors[s];
            // Very dark tint for box background (approximates Pine Script 95% transparency)
            color bgcol;
            switch(s)
            {
                case 0: bgcol = (color)0x020A12; break; // dark blue
                case 1: bgcol = (color)0x120A02; break; // dark orange
                case 2: bgcol = (color)0x020C02; break; // dark green
                default:bgcol = (color)0x080214; break; // dark purple
            }
            CreateBox(g_sessBoxName[s], barTime, barHigh, extRight, barLow, bgcol, col, 1);
            CreateText(g_sessLblName[s], barTime, barHigh, g_sessNames[s], col, 10, ANCHOR_LOWER);
        }
        if(sessNow[s] && g_sessBoxName[s] != "")
        {
            // Update box during session
            if(barHigh > g_sessH[s]) g_sessH[s] = barHigh;
            if(barLow  < g_sessL[s]) g_sessL[s] = barLow;
            BoxSetTop(  g_sessBoxName[s], g_sessH[s]);
            BoxSetBottom(g_sessBoxName[s], g_sessL[s]);
            BoxSetRight( g_sessBoxName[s], extRight);
            TextSetXY(  g_sessLblName[s], barTime, g_sessH[s]);
        }
        if(!sessNow[s] && g_sessWas[s] && g_sessBoxName[s] != "")
        {
            // Session ended — close box right edge
            BoxSetRight(g_sessBoxName[s], barTime);
        }
        g_sessWas[s] = sessNow[s];
    }
}

//=================================================================
// DRAW STRUCTURE (Luxalgo style: line + text label)
//=================================================================
void DrawStructure(SPivot &pivot, string tag, color col, int lineStyle,
                   int fontSize, datetime curTime)
{
    if(pivot.currentLevel <= 0) return;

    string lnName  = NewObjName("STR");
    string txtName = NewObjName("STRT");

    // Line from pivot bar time to current bar time
    CreateLine(lnName, pivot.barTime, pivot.currentLevel,
               curTime, pivot.currentLevel, col, lineStyle, 1, false);

    // Text at midpoint
    datetime midTime = pivot.barTime + (curTime - pivot.barTime) / 2;
    CreateText(txtName, midTime, pivot.currentLevel, tag, col, fontSize, ANCHOR_LOWER);
}

//=================================================================
// HTF SR LINE MANAGEMENT
//=================================================================
void ClearSRDraw(SSRLevel &arr[], int &count)
{
    for(int i = 0; i < count; i++)
    {
        DelObj(arr[i].lineName);
        DelObj(arr[i].lblName);
    }
    count = 0;
}

void AddSRLevel(SSRLevel &arr[], int &count, double level, datetime startTime, bool isRes)
{
    if(count >= MAX_SR) return;

    color col = isRes ? C_PINK : C_CYAN;
    string txt = isRes ? "HTF R" : "HTF S";

    string lnName  = "";
    string lblName = "";

    if(InpShowHTFOBs)
    {
        lnName  = NewObjName(isRes ? "SRRL" : "SRSL");
        lblName = NewObjName(isRes ? "SRRT" : "SRST");

        // Horizontal line extending right
        CreateLine(lnName, startTime, level, startTime + 86400 * 365, level,
                   col, STYLE_SOLID, 2, true);
        CreateText(lblName, startTime, level, txt, col, 7, ANCHOR_LOWER);
    }

    arr[count].level     = level;
    arr[count].startTime = startTime;
    arr[count].active    = true;
    arr[count].lineName  = lnName;
    arr[count].lblName   = lblName;
    count++;
}

void RemoveSR(SSRLevel &arr[], int &count, int idx)
{
    if(idx < 0 || idx >= count) return;
    DelObj(arr[idx].lineName);
    DelObj(arr[idx].lblName);
    for(int i = idx; i < count - 1; i++) arr[i] = arr[i+1];
    count--;
}

//=================================================================
// HELPER: CalcBkFromTime (same as EA)
//=================================================================
int CalcBkFromTime(datetime startTime)
{
    for(int i = g_parsedCount - 1; i >= 0; i--)
    {
        if(g_obTimes[i] < startTime)
            return g_barIndex - i - 1;
    }
    return g_barIndex;
}

//=================================================================
// HELPER: Parsed highs/lows (Luxalgo HVB filter)
//=================================================================
void UpdateParsed(double h, double l, double atr200, datetime t)
{
    bool hvb = (h - l) >= 2.0 * atr200;
    double pH = hvb ? l : h;
    double pL = hvb ? h : l;
    if(g_parsedCount < MAX_PARSED)
    {
        g_parsedHighs[g_parsedCount] = pH;
        g_parsedLows[g_parsedCount]  = pL;
        g_actualHighs[g_parsedCount] = h;
        g_actualLows[g_parsedCount]  = l;
        g_obTimes[g_parsedCount]     = t;
        g_parsedCount++;
    }
}

//=================================================================
// TF ORDER BLOCK MANAGEMENT + DRAWING
//=================================================================
void StoreTFOrderBlock(int pivotBarIndex, int obBias)
{
    if(pivotBarIndex < 0 || pivotBarIndex >= g_parsedCount) return;

    int parsedIdx = -1;
    if(obBias == BEARISH)
    {
        double maxV = -1e15;
        for(int i = pivotBarIndex; i < g_parsedCount; i++)
            if(g_parsedHighs[i] > maxV) { maxV = g_parsedHighs[i]; parsedIdx = i; }
    }
    else
    {
        double minV = 1e15;
        for(int i = pivotBarIndex; i < g_parsedCount; i++)
            if(g_parsedLows[i] < minV) { minV = g_parsedLows[i]; parsedIdx = i; }
    }
    if(parsedIdx < 0) return;

    // Unshift
    if(g_tfOBCount < MAX_OB) g_tfOBCount++;
    for(int i = g_tfOBCount - 1; i > 0; i--)
        g_tfOBs[i] = g_tfOBs[i-1];

    g_tfOBs[0].barHigh = g_parsedHighs[parsedIdx];
    g_tfOBs[0].barLow  = g_parsedLows[parsedIdx];
    g_tfOBs[0].barTime = g_obTimes[parsedIdx];
    g_tfOBs[0].bias    = obBias;
    g_tfOBs[0].active  = true;
    g_tfOBs[0].boxName = ""; // will be drawn in DrawTFOrderBlocks
}

void DeleteMitigatedTFOBs(double curClose, double curHigh, double curLow)
{
    double bearMitig = InpOBMitigClose ? curClose : curHigh;
    double bullMitig = InpOBMitigClose ? curClose : curLow;

    for(int i = 0; i < g_tfOBCount; i++)
    {
        if(!g_tfOBs[i].active) continue;
        bool crossed = false;
        if(g_tfOBs[i].bias == BEARISH && bearMitig > g_tfOBs[i].barHigh) crossed = true;
        if(g_tfOBs[i].bias == BULLISH && bullMitig < g_tfOBs[i].barLow)  crossed = true;
        if(crossed)
        {
            if(g_tfOBs[i].boxName != "")
                DelObj(g_tfOBs[i].boxName);
            g_tfOBs[i].active = false;
        }
    }
}

void DrawTFOrderBlocks(datetime rightTime)
{
    if(!InpShowTFOBs) return;

    int drawn = 0;
    for(int i = 0; i < g_tfOBCount && drawn < InpObCount; i++)
    {
        if(!g_tfOBs[i].active) continue;

        color col = g_tfOBs[i].bias == BEARISH
                    ? C_BEAR_OB : C_BULL_OB;

        if(g_tfOBs[i].boxName == "")
        {
            // Create new box
            g_tfOBs[i].boxName = NewObjName("TFOB");
            CreateBox(g_tfOBs[i].boxName,
                      g_tfOBs[i].barTime, g_tfOBs[i].barHigh,
                      rightTime, g_tfOBs[i].barLow,
                      col, clrNONE, 0);
        }
        else
        {
            // Update right edge
            BoxSetRight(g_tfOBs[i].boxName, rightTime);
        }
        drawn++;
    }
}

//=================================================================
// HELPER: Rates highest/lowest
//=================================================================
double RatesHighest(const MqlRates &rates[], int fromIdx, int count)
{
    double h = -1e15;
    int total = ArraySize(rates);
    for(int i = fromIdx; i < fromIdx + count && i < total; i++)
        if(rates[i].high > h) h = rates[i].high;
    return h;
}
double RatesLowest(const MqlRates &rates[], int fromIdx, int count)
{
    double l = 1e15;
    int total = ArraySize(rates);
    for(int i = fromIdx; i < fromIdx + count && i < total; i++)
        if(rates[i].low < l) l = rates[i].low;
    return l;
}

//=================================================================
// TF STRUCTURE UPDATE + DRAWING
//=================================================================
void UpdateTFStructure(const MqlRates &rates[], datetime curTime)
{
    int n     = InpSwingLen;
    int total = ArraySize(rates);
    if(total < n + 2) return;

    bool legIsHigh = (rates[n].high > RatesHighest(rates, 0, n));
    bool legIsLow  = (rates[n].low  < RatesLowest(rates,  0, n));

    int newLeg = legIsHigh ? BEARISH_LEG : (legIsLow ? BULLISH_LEG : g_tfLegState);

    if(newLeg != g_tfLegState)
    {
        if(newLeg == BEARISH_LEG)
        {
            g_tfHigh.lastLevel    = g_tfHigh.currentLevel;
            g_tfHigh.currentLevel = rates[n].high;
            g_tfHigh.crossed      = false;
            g_tfHigh.barTime      = rates[n].time;
            g_tfHigh.barIndex     = g_barIndex - n;
        }
        else
        {
            g_tfLow.lastLevel    = g_tfLow.currentLevel;
            g_tfLow.currentLevel = rates[n].low;
            g_tfLow.crossed      = false;
            g_tfLow.barTime      = rates[n].time;
            g_tfLow.barIndex     = g_barIndex - n;
        }
        g_tfLegState = newLeg;
    }

    g_tf_chochBull = false; g_tf_bosBull = false;
    g_tf_chochBear = false; g_tf_bosBear = false;

    double curClose  = rates[0].close;
    double prevClose = rates[1].close;

    // Bullish break
    if(g_tfHigh.currentLevel > 0 && !g_tfHigh.crossed)
    {
        bool extra = (g_tfHigh.currentLevel != g_tfLow.currentLevel);
        if(curClose > g_tfHigh.currentLevel && prevClose <= g_tfHigh.currentLevel && extra)
        {
            g_tfHigh.crossed = true;
            if(g_tfTrendBias == BEARISH) g_tf_chochBull = true;
            else                         g_tf_bosBull   = true;
            g_tfTrendBias = BULLISH;

            if(InpShowTFStruct)
            {
                string tag = g_tf_chochBull ? "CHoCH" : "BOS";
                color  col = g_tf_chochBull ? C_GREEN : C_GREEN;
                DrawStructure(g_tfHigh, tag, col, STYLE_DASH, 7, curTime);
            }

            StoreTFOrderBlock(g_tfHigh.barIndex, BULLISH);
            if(g_tfOBCount > 0 && g_tfOBs[0].bias == BULLISH)
                g_tfSweepBearLevel = g_tfOBs[0].barLow;
        }
    }

    // Bearish break
    if(g_tfLow.currentLevel > 0 && !g_tfLow.crossed)
    {
        bool extra = (g_tfLow.currentLevel != g_tfHigh.currentLevel);
        if(curClose < g_tfLow.currentLevel && prevClose >= g_tfLow.currentLevel && extra)
        {
            g_tfLow.crossed = true;
            if(g_tfTrendBias == BULLISH) g_tf_chochBear = true;
            else                         g_tf_bosBear   = true;
            g_tfTrendBias = BEARISH;

            if(InpShowTFStruct)
            {
                string tag = g_tf_chochBear ? "CHoCH" : "BOS";
                color  col = g_tf_chochBear ? C_RED : C_RED;
                DrawStructure(g_tfLow, tag, col, STYLE_DASH, 7, curTime);
            }

            StoreTFOrderBlock(g_tfLow.barIndex, BEARISH);
            if(g_tfOBCount > 0 && g_tfOBs[0].bias == BEARISH)
                g_tfSweepBullLevel = g_tfOBs[0].barHigh;
        }
    }
}

//=================================================================
// HTF STRUCTURE UPDATE (M5 cache based)
//=================================================================
// Find index in g_m5Cache of the last closed M5 bar before m1BarTime
int FindLastClosedM5Idx(datetime m1BarTime)
{
    int m5PeriodSec = PeriodSeconds(InpHigherTF);
    int lo = 0, hi = g_m5CacheCount - 1, result = -1;
    while(lo <= hi)
    {
        int mid = (lo + hi) / 2;
        // M5 bar is closed when its open_time + period <= m1BarTime
        if((datetime)(g_m5Cache[mid].time + m5PeriodSec) <= m1BarTime)
        {
            result = mid;
            lo = mid + 1;
        }
        else hi = mid - 1;
    }
    return result;
}

void UpdateHTFStructureAt(int m5Idx, datetime m1BarTime)
{
    // m5Idx = index in g_m5Cache of the current "last closed" M5 bar
    // g_m5Cache[m5Idx] = m5[1] in Pine Script (bar vừa đóng)
    int n = InpSwingLenHTF;
    if(m5Idx < n + 2) return;

    g_m5_highVal = g_m5Cache[m5Idx].high;
    g_m5_lowVal  = g_m5Cache[m5Idx].low;

    // Pivot: g_m5Cache[m5Idx - n] vs max/min of g_m5Cache[m5Idx-n+1 .. m5Idx]
    // (equivalent to m5[n+1] vs max/min of m5[1..n] in series order)
    double pivHigh = g_m5Cache[m5Idx - n].high;
    double pivLow  = g_m5Cache[m5Idx - n].low;
    datetime pivTime = g_m5Cache[m5Idx - n].time;

    double maxH = -1e15, minL = 1e15;
    for(int i = m5Idx - n + 1; i <= m5Idx; i++)
    {
        if(g_m5Cache[i].high > maxH) maxH = g_m5Cache[i].high;
        if(g_m5Cache[i].low  < minL) minL = g_m5Cache[i].low;
    }

    bool legH = (pivHigh > maxH);
    bool legL = (pivLow  < minL);
    int newLeg = legH ? BEARISH_LEG : (legL ? BULLISH_LEG : g_m5LegState);

    if(newLeg != g_m5LegState)
    {
        if(newLeg == BEARISH_LEG)
        {
            g_m5High.lastLevel    = g_m5High.currentLevel;
            g_m5High.currentLevel = pivHigh;
            g_m5High.crossed      = false;
            g_m5High.barTime      = pivTime;
            g_m5High.barIndex     = g_barIndex;
        }
        else
        {
            g_m5Low.lastLevel    = g_m5Low.currentLevel;
            g_m5Low.currentLevel = pivLow;
            g_m5Low.crossed      = false;
            g_m5Low.barTime      = pivTime;
            g_m5Low.barIndex     = g_barIndex;
        }
        g_m5LegState = newLeg;
    }

    g_m5_chochBull = false; g_m5_bosBull = false;
    g_m5_chochBear = false; g_m5_bosBear = false;

    double curClose  = g_m5Cache[m5Idx].close;
    double prevClose = g_m5Cache[m5Idx - 1].close;

    if(g_m5High.currentLevel > 0 && !g_m5High.crossed)
    {
        if(curClose > g_m5High.currentLevel && prevClose <= g_m5High.currentLevel)
        {
            g_m5High.crossed = true;
            if(g_m5TrendBias == BEARISH) g_m5_chochBull = true;
            else                         g_m5_bosBull   = true;
            g_m5TrendBias = BULLISH;

            if(InpShowHTFStruct)
            {
                string tag = g_m5_chochBull
                    ? (EnumToString(InpHigherTF) + " CHoCH")
                    : (EnumToString(InpHigherTF) + " BOS");
                color col = g_m5_chochBull ? C_HTF_BULL_C : C_HTF_BULL_B;
                DrawStructure(g_m5High, tag, col, STYLE_SOLID, 7, m1BarTime);
            }
        }
    }

    if(g_m5Low.currentLevel > 0 && !g_m5Low.crossed)
    {
        if(curClose < g_m5Low.currentLevel && prevClose >= g_m5Low.currentLevel)
        {
            g_m5Low.crossed = true;
            if(g_m5TrendBias == BULLISH) g_m5_chochBear = true;
            else                         g_m5_bosBear   = true;
            g_m5TrendBias = BEARISH;

            if(InpShowHTFStruct)
            {
                string tag = g_m5_chochBear
                    ? (EnumToString(InpHigherTF) + " CHoCH")
                    : (EnumToString(InpHigherTF) + " BOS");
                color col = g_m5_chochBear ? C_HTF_BEAR_C : C_HTF_BEAR_B;
                DrawStructure(g_m5Low, tag, col, STYLE_SOLID, 7, m1BarTime);
            }
        }
    }

    // cycleSL (BƯỚC 5)
    if(g_m5_chochBull) { g_cycleSL_choch = g_m5Low.currentLevel;  g_cycleSL = g_cycleSL_choch; }
    if(g_m5_chochBear) { g_cycleSL_choch = g_m5High.currentLevel; g_cycleSL = g_cycleSL_choch; }
    if(InpSlMode == 1)
    {
        if(g_m5_bosBull) g_cycleSL = g_m5Low.currentLevel;
        if(g_m5_bosBear) g_cycleSL = g_m5High.currentLevel;
    }

    // HTF SR level collection (BƯỚC 6)
    // Dùng g_actualHighs/g_actualLows (đã tích lũy từng bar) thay vì CopyRates
    // để đảm bảo đúng dữ liệu lịch sử khi indicator process historical bars
    if(g_m5_chochBear)
    {
        ClearSRDraw(g_resistanceLevels, g_resistCount);
        int bk = CalcBkFromTime(g_m5Low.barTime);
        int startIdx = MathMax(0, g_parsedCount - 1 - bk);
        double maxH = g_actualHighs[g_parsedCount - 1];
        for(int i = startIdx; i < g_parsedCount; i++)
            if(g_actualHighs[i] > maxH) maxH = g_actualHighs[i];
        AddSRLevel(g_resistanceLevels, g_resistCount, maxH, g_m5Low.barTime, true);
    }
    if(g_m5_chochBull)
    {
        ClearSRDraw(g_supportLevels, g_supportCount);
        int bk = CalcBkFromTime(g_m5High.barTime);
        int startIdx = MathMax(0, g_parsedCount - 1 - bk);
        double minL = g_actualLows[g_parsedCount - 1];
        for(int i = startIdx; i < g_parsedCount; i++)
            if(g_actualLows[i] < minL) minL = g_actualLows[i];
        AddSRLevel(g_supportLevels, g_supportCount, minL, g_m5High.barTime, false);
    }
    if(g_m5_bosBear)
    {
        int bk = CalcBkFromTime(g_m5Low.barTime);
        int startIdx = MathMax(0, g_parsedCount - 1 - bk);
        double maxH = g_actualHighs[g_parsedCount - 1];
        for(int i = startIdx; i < g_parsedCount; i++)
            if(g_actualHighs[i] > maxH) maxH = g_actualHighs[i];
        AddSRLevel(g_resistanceLevels, g_resistCount, maxH, g_m5Low.barTime, true);
    }
    if(g_m5_bosBull)
    {
        int bk = CalcBkFromTime(g_m5High.barTime);
        int startIdx = MathMax(0, g_parsedCount - 1 - bk);
        double minL = g_actualLows[g_parsedCount - 1];
        for(int i = startIdx; i < g_parsedCount; i++)
            if(g_actualLows[i] < minL) minL = g_actualLows[i];
        AddSRLevel(g_supportLevels, g_supportCount, minL, g_m5High.barTime, false);
    }

    // HTF SR Sweep detection (BƯỚC 7)
    g_srBreakBull = false; g_srBreakBullIdx = -1;
    g_srBreakBear = false; g_srBreakBearIdx = -1;

    bool doBull = (g_state == 1 && g_bias == BULLISH) || (g_state == 0 && g_m5_chochBull);
    if(doBull)
        for(int i = 0; i < g_resistCount; i++)
            if(g_resistanceLevels[i].active && g_m5_highVal >= g_resistanceLevels[i].level)
                { g_srBreakBull = true; g_srBreakBullIdx = i; break; }

    bool doBear = (g_state == 1 && g_bias == BEARISH) || (g_state == 0 && g_m5_chochBear);
    if(doBear)
        for(int i = 0; i < g_supportCount; i++)
            if(g_supportLevels[i].active && g_m5_lowVal <= g_supportLevels[i].level)
                { g_srBreakBear = true; g_srBreakBearIdx = i; break; }
}

//=================================================================
// GET SL
//=================================================================
double GetSL(double ep, int dir)
{
    if(InpSlMode == 2)
        return dir == 1 ? ep - InpSlTicks * _Point : ep + InpSlTicks * _Point;

    double refSL = (InpSlMode == 0) ? g_cycleSL_choch : g_cycleSL;
    if(dir == 1)
        return (refSL > 0 && refSL < ep) ? refSL : ep - InpSlTicks * _Point;
    else
        return (refSL > 0 && refSL > ep) ? refSL : ep + InpSlTicks * _Point;
}

//=================================================================
// TRADE VISUAL MANAGEMENT
//=================================================================
void DrawTrade(datetime barTime, double ep, double tp, double sl, int dir, string src)
{
    if(g_tradeVisCount >= MAX_TRADE) return;

    string star = (src == "sp_choch") ? " *" : "";
    string entTxt = (dir == 1)
        ? "Long" + star + " @ " + DoubleToString(ep, _Digits)
        : "Short" + star + " @ " + DoubleToString(ep, _Digits);
    color colEntry = (dir == 1) ? C_GREEN : C_RED;

    STradeVisual tv;
    tv.ep = ep; tv.tp = tp; tv.sl = sl;
    tv.direction = dir; tv.src = src; tv.active = true;

    // Entry label
    tv.nameEntLbl = NewObjName("TVEL");
    CreateText(tv.nameEntLbl, barTime, ep, entTxt, colEntry, 9,
               dir == 1 ? ANCHOR_RIGHT_LOWER : ANCHOR_RIGHT_UPPER);

    // Entry line (horizontal, dashed)
    tv.nameEntLn = NewObjName("TVENL");
    CreateLine(tv.nameEntLn, barTime, ep, barTime, ep, C'200,200,200', STYLE_DASH, 1, false);

    // TP/SL boxes
    tv.nameBoxTP = ""; tv.nameBoxSL = "";
    if(InpShowBoxes)
    {
        color bgTP = C'20,60,40';
        color bgSL = C'60,20,20';
        datetime t2 = barTime + 86400; // placeholder, updated each bar

        if(dir == 1)
        {
            tv.nameBoxTP = NewObjName("TVBTP");
            CreateBox(tv.nameBoxTP, barTime, tp, t2, ep, bgTP, C_GREEN, 1);
            tv.nameBoxSL = NewObjName("TVBSL");
            CreateBox(tv.nameBoxSL, barTime, ep, t2, sl, bgSL, C_RED, 1);
        }
        else
        {
            tv.nameBoxTP = NewObjName("TVBTP");
            CreateBox(tv.nameBoxTP, barTime, ep, t2, tp, bgTP, C_GREEN, 1);
            tv.nameBoxSL = NewObjName("TVBSL");
            CreateBox(tv.nameBoxSL, barTime, sl, t2, ep, bgSL, C_RED, 1);
        }
    }

    // TP label
    tv.nameLblTP = NewObjName("TVLTP");
    CreateText(tv.nameLblTP, barTime, tp,
               "TP " + DoubleToString(NormalizeDouble(tp, 2), 2),
               C_GREEN, 8, ANCHOR_LEFT_LOWER);

    // SL label
    tv.nameLblSL = NewObjName("TVLSL");
    CreateText(tv.nameLblSL, barTime, sl,
               "SL " + DoubleToString(NormalizeDouble(sl, 2), 2),
               C_RED, 8, ANCHOR_LEFT_UPPER);

    g_tradeVisuals[g_tradeVisCount] = tv;
    g_tradeVisCount++;
}

void UpdateTradeVisuals(datetime curTime, double curHigh, double curLow,
                        bool m5_chochBull, bool m5_chochBear)
{
    for(int i = 0; i < g_tradeVisCount; i++)
    {
        if(!g_tradeVisuals[i].active) continue;
        STradeVisual tv = g_tradeVisuals[i];

        // Force close on HTF CHoCH against direction
        bool htfAgainst = (tv.direction ==  1 && m5_chochBear) ||
                          (tv.direction == -1 && m5_chochBull);
        bool m5Rev = (g_bias == BULLISH && m5_chochBear) ||
                     (g_bias == BEARISH && m5_chochBull);
        bool forceClose = InpCloseOnHTF && (m5Rev || htfAgainst);

        if(forceClose)
        {
            // Close at current price
            BoxSetRight(tv.nameBoxTP, curTime);
            BoxSetRight(tv.nameBoxSL, curTime);
            LineSetX2(tv.nameEntLn, curTime);
            DelObj(tv.nameLblTP);
            TextSetXY(tv.nameLblSL, curTime, curLow);
            TextSetText(tv.nameLblSL, "SL (HTF)");

            if(tv.src == "choch") g_chochTradeOpen = false;
            else                  g_bosTradeUsed   = false;
            g_tradeVisuals[i].active = false;
            continue;
        }

        bool isTP = (tv.direction ==  1) ? curHigh >= tv.tp : curLow  <= tv.tp;
        bool isSL = (tv.direction ==  1) ? curLow  <= tv.sl : curHigh >= tv.sl;

        if(isTP || isSL)
        {
            BoxSetRight(tv.nameBoxTP, curTime);
            BoxSetRight(tv.nameBoxSL, curTime);
            LineSetX2(tv.nameEntLn, curTime);
            if(isTP)
            {
                BoxSetBgColor(tv.nameBoxTP, C'20,80,40');
                BoxSetBgColor(tv.nameBoxSL, C'40,10,10');
                TextSetXY(tv.nameLblTP, curTime, tv.tp);
                DelObj(tv.nameLblSL);
            }
            else
            {
                BoxSetBgColor(tv.nameBoxTP, C'10,30,20');
                BoxSetBgColor(tv.nameBoxSL, C'80,20,20');
                DelObj(tv.nameLblTP);
                TextSetXY(tv.nameLblSL, curTime, tv.sl);
            }
            if(tv.src == "choch") g_chochTradeOpen = false;
            // (bos TP: bosTradeUsed stays true, choch TP: chochTradeOpen = false)
            g_tradeVisuals[i].active = false;
        }
        else
        {
            // Trade still active — extend right edges
            BoxSetRight(tv.nameBoxTP, curTime + 60);
            BoxSetRight(tv.nameBoxSL, curTime + 60);
            LineSetX2(tv.nameEntLn, curTime);
            TextSetXY(tv.nameLblTP, curTime, tv.tp);
            TextSetXY(tv.nameLblSL, curTime, tv.sl);
        }
    }
}

//=================================================================
// FULL RESET
//=================================================================
void FullReset(bool clearSR)
{
    g_state          = 0;  g_bias = 0;  g_bosCount = 0;
    g_cycleSL        = 0;  g_cycleSL_choch = 0;
    g_chochTradeOpen = false; g_bosTradeUsed = false; g_bosSeen = false;
    g_pendingLong    = false; g_pendingShort = false;
    g_tfBosCount     = 0;  g_tfBosLimitHit = false; g_chochAtrFired = false;
    g_spArmed        = false; g_pendingSpLong = false; g_pendingSpShort = false;
    g_tfSweepBullLevel = 0;  g_tfSweepBearLevel = 0;
    if(clearSR)
    {
        ClearSRDraw(g_resistanceLevels, g_resistCount);
        ClearSRDraw(g_supportLevels, g_supportCount);
    }
}

//=================================================================
// ATR UPDATE (incremental, forward-time bar i)
//=================================================================
void UpdateATR(double o, double h, double l, double c, double nLoss)
{
    // HA close
    double haClose = (o + h + l + c) / 4.0;
    double haOpen  = (g_haOpen == 0) ? (o + c) / 2.0 : (g_haOpen + g_haClose) / 2.0;
    g_haOpen  = haOpen;
    g_haClose = haClose;
    double src = InpUseHA ? haClose : c;

    double prevStop = g_xATRStop;
    double prevSrc  = g_srcPrice1;

    if(prevStop == 0)
        g_xATRStop = src - nLoss;
    else if(src > prevStop && prevSrc > prevStop)
        g_xATRStop = MathMax(prevStop, src - nLoss);
    else if(src < prevStop && prevSrc < prevStop)
        g_xATRStop = MathMin(prevStop, src + nLoss);
    else if(src > prevStop)
        g_xATRStop = src - nLoss;
    else
        g_xATRStop = src + nLoss;

    if(g_initialized)
    {
        g_atrBuy  = (prevSrc <= prevStop) && (src > g_xATRStop);
        g_atrSell = (prevSrc >= prevStop) && (src < g_xATRStop);
    }
    else
    {
        g_atrBuy  = false;
        g_atrSell = false;
    }

    g_srcPrice1 = src;
    g_srcPrice  = src;
}

//=================================================================
// HELPER: HasActiveVisual — tương đương array.size(activeVisuals) == 0 trong Pine Script
//=================================================================
bool HasActiveVisual()
{
    for(int i = 0; i < g_tradeVisCount; i++)
        if(g_tradeVisuals[i].active) return true;
    return false;
}

//=================================================================
// STATE MACHINE (identical to EA)
//=================================================================
void RunStateMachine(double curClose, double curHigh, double curLow, double curOpen,
                     datetime curTime, bool sessionOK)
{
    bool noActiveVisual = !HasActiveVisual(); // tương đương array.size(activeVisuals) == 0

    double bearMitig = InpOBMitigClose ? curClose : curHigh;
    double bullMitig = InpOBMitigClose ? curClose : curLow;

    bool tfOBSweepBull = (g_tfSweepBullLevel > 0) && (bearMitig >= g_tfSweepBullLevel);
    bool tfOBSweepBear = (g_tfSweepBearLevel > 0) && (bullMitig <= g_tfSweepBearLevel);

    bool m5Reversed = (g_bias == BULLISH && g_m5_chochBear) ||
                      (g_bias == BEARISH && g_m5_chochBull);

    // BƯỚC 2: Reset khi HTF đảo chiều
    if(m5Reversed)
    {
        FullReset(false);
        g_srBreakBull = false; g_srBreakBullIdx = -1;
        g_srBreakBear = false; g_srBreakBearIdx = -1;
        if(g_m5_chochBull)
            for(int i = 0; i < g_resistCount; i++)
                if(g_resistanceLevels[i].active && curHigh >= g_resistanceLevels[i].level)
                    { g_srBreakBull = true; g_srBreakBullIdx = i; break; }
        if(g_m5_chochBear)
            for(int i = 0; i < g_supportCount; i++)
                if(g_supportLevels[i].active && curLow <= g_supportLevels[i].level)
                    { g_srBreakBear = true; g_srBreakBearIdx = i; break; }
    }

    // BƯỚC 3
    if(g_bias == BULLISH && g_m5_bosBull) g_bosCount++;
    if(g_bias == BEARISH && g_m5_bosBear) g_bosCount++;

    // BƯỚC 4
    if(g_bosCount >= InpMaxBOS && g_state >= 1) { FullReset(true); return; }

    int stateSnap = g_state;

    // Per-M1-bar SR sweep check (state 1) — fix for running M5 high
    if(stateSnap == 1 && g_bias == BULLISH && !g_srBreakBull)
        for(int i = 0; i < g_resistCount; i++)
            if(g_resistanceLevels[i].active && curHigh >= g_resistanceLevels[i].level)
                { g_srBreakBull = true; g_srBreakBullIdx = i; break; }
    if(stateSnap == 1 && g_bias == BEARISH && !g_srBreakBear)
        for(int i = 0; i < g_supportCount; i++)
            if(g_supportLevels[i].active && curLow <= g_supportLevels[i].level)
                { g_srBreakBear = true; g_srBreakBearIdx = i; break; }

    // 0 → 1 (→ 2 → 3)
    if(stateSnap == 0)
    {
        if(g_m5_chochBull)
        {
            g_state = 1; g_bias = BULLISH; g_bosCount = 0;
            if(g_srBreakBull) { RemoveSR(g_resistanceLevels, g_resistCount, g_srBreakBullIdx); g_state = 2; }
            if(g_state == 2 && g_tf_chochBear) g_state = 3;
        }
        else if(g_m5_chochBear)
        {
            g_state = 1; g_bias = BEARISH; g_bosCount = 0;
            if(g_srBreakBear) { RemoveSR(g_supportLevels, g_supportCount, g_srBreakBearIdx); g_state = 2; }
            if(g_state == 2 && g_tf_chochBull) g_state = 3;
        }
    }

    // 1 → 2 (→ 3)
    if(stateSnap == 1)
    {
        if(g_srBreakBull)
        {
            RemoveSR(g_resistanceLevels, g_resistCount, g_srBreakBullIdx);
            g_state = 2;
            if(g_tf_chochBear) g_state = 3;
        }
        else if(g_srBreakBear)
        {
            RemoveSR(g_supportLevels, g_supportCount, g_srBreakBearIdx);
            g_state = 2;
            if(g_tf_chochBull) g_state = 3;
        }
    }

    // 2 → 3
    if(stateSnap == 2)
    {
        if(g_bias == BULLISH && g_tf_chochBear) g_state = 3;
        else if(g_bias == BEARISH && g_tf_chochBull) g_state = 3;
    }

    // 3 → 4 (→ 5)
    if(stateSnap == 3)
    {
        if(g_bias == BULLISH && g_tf_chochBull)
            { g_state = 4; if(tfOBSweepBull) g_state = 5; }
        else if(g_bias == BEARISH && g_tf_chochBear)
            { g_state = 4; if(tfOBSweepBear) g_state = 5; }
    }

    // 4 → 5
    if(stateSnap == 4)
    {
        if(g_bias == BULLISH && tfOBSweepBull)       g_state = 5;
        else if(g_bias == BEARISH && tfOBSweepBear)  g_state = 5;
        else if(g_bias == BULLISH && g_tf_chochBear) g_state = 3;
        else if(g_bias == BEARISH && g_tf_chochBull) g_state = 3;
    }

    // TF BOS count
    if(g_bias == BULLISH && g_tf_bosBull) g_tfBosCount++;
    if(g_bias == BEARISH && g_tf_bosBear) g_tfBosCount++;
    if(g_tfBosCount >= 2) g_tfBosLimitHit = true;

    // 5 → 6: ATR confirm
    if(stateSnap == 5)
    {
        if(g_bias == BULLISH && g_atrBuy && !g_chochAtrFired)
        {
            g_chochAtrFired = true; g_state = 6;
            if(!g_chochTradeOpen && !g_tfBosLimitHit && sessionOK && noActiveVisual)
            {
                g_pendingLong = true; g_pendingSrc = "choch";
                if(g_tfBosCount >= 2) g_tfBosLimitHit = true;
            }
        }
        else if(g_bias == BEARISH && g_atrSell && !g_chochAtrFired)
        {
            g_chochAtrFired = true; g_state = 6;
            if(!g_chochTradeOpen && !g_tfBosLimitHit && sessionOK && noActiveVisual)
            {
                g_pendingShort = true; g_pendingSrc = "choch";
                if(g_tfBosCount >= 2) g_tfBosLimitHit = true;
            }
        }
        else if(g_bias == BULLISH && g_tf_chochBear) g_state = 3;
        else if(g_bias == BEARISH && g_tf_chochBull) g_state = 3;
    }

    // 6: trong xu hướng
    if(stateSnap == 6)
    {
        if(g_bias == BULLISH && g_tf_chochBear)
            { g_state = 3; g_bosSeen = false; g_bosTradeUsed = false; }
        else if(g_bias == BEARISH && g_tf_chochBull)
            { g_state = 3; g_bosSeen = false; g_bosTradeUsed = false; }
        else
        {
            if(g_bias == BULLISH && g_tf_bosBull)
                { if(g_bosSeen) g_bosTradeUsed = true; g_bosSeen = true; }
            if(g_bias == BEARISH && g_tf_bosBear)
                { if(g_bosSeen) g_bosTradeUsed = true; g_bosSeen = true; }
            if(g_bosSeen)
            {
                if(g_bias == BULLISH && g_atrBuy && !g_bosTradeUsed && !g_tfBosLimitHit)
                {
                    g_bosTradeUsed = true;
                    if(sessionOK && noActiveVisual)
                        { g_pendingLong = true; g_pendingSrc = "bos"; g_bosSeen = false; g_tfBosLimitHit = true; }
                }
                else if(g_bias == BEARISH && g_atrSell && !g_bosTradeUsed && !g_tfBosLimitHit)
                {
                    g_bosTradeUsed = true;
                    if(sessionOK && noActiveVisual)
                        { g_pendingShort = true; g_pendingSrc = "bos"; g_bosSeen = false; g_tfBosLimitHit = true; }
                }
            }
        }
    }

    if(g_state == 3 && stateSnap != 3) { g_tfBosCount = 0; g_tfBosLimitHit = false; }
    if(g_state == 5 && stateSnap != 5) g_chochAtrFired = false;

    // Special Entry ★
    if(g_state == 0) { g_spArmed = false; g_pendingSpLong = false; g_pendingSpShort = false; }

    if(g_spArmed)
    {
        g_spBarsAfter++;
        double bodySize    = MathAbs(curClose - curOpen);
        double candleRange = curHigh - curLow;
        bool   strongBody  = (candleRange > 0 && bodySize >= 0.5 * candleRange);

        if(g_spBarsAfter == 1)
        {
            if(g_spBias == BULLISH)
            {
                if(curClose > g_spCH)          { if(strongBody && noActiveVisual) g_pendingSpLong  = true; g_spArmed = false; }
                else if(curClose < g_spCBodyBot) g_spArmed = false;
            }
            else
            {
                if(curClose < g_spCL)          { if(strongBody && noActiveVisual) g_pendingSpShort = true; g_spArmed = false; }
                else if(curClose > g_spCBodyTop) g_spArmed = false;
            }
        }
        else if(g_spBarsAfter == 2)
        {
            if(g_spBias == BULLISH && curClose > g_spCH && noActiveVisual)  g_pendingSpLong  = true;
            if(g_spBias == BEARISH && curClose < g_spCL && noActiveVisual)  g_pendingSpShort = true;
            g_spArmed = false;
        }
        else g_spArmed = false;
    }

    // Trigger ★
    if(stateSnap == 3 && g_state == 5 && InpSpecialEntry && !g_tfBosLimitHit && sessionOK)
    {
        g_spArmed    = true; g_spBarsAfter = 0;
        g_spCH       = curHigh; g_spCL = curLow;
        g_spCBodyTop = MathMax(curOpen, curClose);
        g_spCBodyBot = MathMin(curOpen, curClose);
        g_spBias     = g_bias;
    }
}

//=================================================================
// INFO TABLE (bottom-right, updated each last bar)
//=================================================================
void UpdateInfoTable()
{
    string stateStr;
    switch(g_state)
    {
        case 0: stateStr = "B1 Wait HTF CHoCH"; break;
        case 1: stateStr = "B2 Wait HTF OB Sweep"; break;
        case 2: stateStr = "B3 Wait TF CHoCH opp"; break;
        case 3: stateStr = "B4 Wait TF CHoCH same"; break;
        case 4: stateStr = "B4.5 Wait TF OB Sweep"; break;
        case 5: stateStr = "B5 Wait ATR confirm"; break;
        case 6: stateStr = "B6 In Trend"; break;
        default: stateStr = "?";
    }
    string biasStr  = g_bias == BULLISH ? "BULL" : g_bias == BEARISH ? "BEAR" : "--";
    string bosStr   = IntegerToString(g_bosCount) + "/" + IntegerToString(InpMaxBOS);
    string tfBosStr = IntegerToString(g_tfBosCount) + (g_tfBosLimitHit ? " BLOCKED" : "");
    string slStr    = g_cycleSL > 0 ? DoubleToString(NormalizeDouble(g_cycleSL, 2), 2) : "--";

    Comment(
        "=== XAUUSD PA Scalping ===\n"
        "State : " + stateStr + "\n"
        "Bias  : " + biasStr + "\n"
        "HTF BOS: " + bosStr + "\n"
        "TF BOS : " + tfBosStr + "\n"
        "Cycle SL: " + slStr + "\n"
        "TF PivH : " + DoubleToString(NormalizeDouble(g_tfHigh.currentLevel, 2), 2) + "\n"
        "TF PivL : " + DoubleToString(NormalizeDouble(g_tfLow.currentLevel,  2), 2)
    );
}

//=================================================================
// PROCESS ONE BAR (forward-time, rates[] in series order from this bar)
//=================================================================
void ProcessBar(const MqlRates &rates[], int totalRates,
                double atrVal, double atr200Val,
                int m5IdxForThisBar)
{
    g_barIndex++;

    double o = rates[0].open;
    double h = rates[0].high;
    double l = rates[0].low;
    double c = rates[0].close;
    datetime t = rates[0].time;

    // Update parsed highs/lows
    UpdateParsed(h, l, atr200Val, t);

    // Update ATR
    double nLoss = InpAtrKey * atrVal;
    UpdateATR(o, h, l, c, nLoss);

    // HTF Structure — check if new M5 bar closed since last check
    if(m5IdxForThisBar >= 0 && m5IdxForThisBar != g_lastProcessedM5Idx)
    {
        // Process each new M5 bar in order
        for(int mi = g_lastProcessedM5Idx + 1; mi <= m5IdxForThisBar; mi++)
        {
            g_lastProcessedM5Idx = mi;
            UpdateHTFStructureAt(mi, t);
        }
    }

    // TF Structure
    UpdateTFStructure(rates, t);

    // Update trade visuals
    UpdateTradeVisuals(t, h, l, g_m5_chochBull, g_m5_chochBear);

    // Execute pending entries (1-bar delay)
    if(g_execLong)
    {
        double ep = o;
        double tp = ep + InpTpTicks * _Point;
        double sl = GetSL(ep, 1);
        g_chochTradeOpen = (g_execSrc == "choch");
        if(g_execSrc != "choch") g_bosTradeUsed = true;
        DrawTrade(t, ep, tp, sl, 1, g_execSrc);
        g_execLong = false;
    }
    if(g_execShort)
    {
        double ep = o;
        double tp = ep - InpTpTicks * _Point;
        double sl = GetSL(ep, -1);
        g_chochTradeOpen = (g_execSrc == "choch");
        if(g_execSrc != "choch") g_bosTradeUsed = true;
        DrawTrade(t, ep, tp, sl, -1, g_execSrc);
        g_execShort = false;
    }
    if(g_execSpLong)
    {
        double ep = o;
        DrawTrade(t, ep, ep + InpTpTicks * _Point, GetSL(ep, 1), 1, "sp_choch");
        g_execSpLong = false;
    }
    if(g_execSpShort)
    {
        double ep = o;
        DrawTrade(t, ep, ep - InpTpTicks * _Point, GetSL(ep, -1), -1, "sp_choch");
        g_execSpShort = false;
    }

    // Reset pending before state machine
    g_pendingLong    = false; g_pendingShort   = false;
    g_pendingSpLong  = false; g_pendingSpShort = false;

    bool sessionOK = SessionOKAt(t);

    // State machine
    RunStateMachine(c, h, l, o, t, sessionOK);

    // Delete mitigated TF OBs
    DeleteMitigatedTFOBs(c, h, l);

    // Promote pending → exec queue
    if(g_pendingLong)    { g_execLong   = true; g_execSrc = g_pendingSrc; g_pendingLong    = false; }
    if(g_pendingShort)   { g_execShort  = true; g_execSrc = g_pendingSrc; g_pendingShort   = false; }
    if(g_pendingSpLong)  { g_execSpLong  = true; g_pendingSpLong  = false; }
    if(g_pendingSpShort) { g_execSpShort = true; g_pendingSpShort = false; }

    // Session boxes
    int periodSec = PeriodSeconds();
    UpdateSessionBoxes(t, h, l, periodSec);

    // TF OB draw (update right edges)
    DrawTFOrderBlocks(t + periodSec);

    g_initialized = true;
}

//=================================================================
// OnInit
//=================================================================
int OnInit()
{
    // Bind buffers
    SetIndexBuffer(0, g_atrStopBuf, INDICATOR_DATA);
    SetIndexBuffer(1, g_atrBuyBuf,  INDICATOR_DATA);
    SetIndexBuffer(2, g_atrSellBuf, INDICATOR_DATA);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

    PlotIndexSetString( 0, PLOT_LABEL, "ATR Stop");
    PlotIndexSetString( 1, PLOT_LABEL, "ATR Buy");
    PlotIndexSetString( 2, PLOT_LABEL, "ATR Sell");
    PlotIndexSetInteger(1, PLOT_ARROW, 233);   // up arrow
    PlotIndexSetInteger(2, PLOT_ARROW, 234);   // down arrow

    // ATR indicator handles
    g_atrHandle    = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
    g_atr200Handle = iATR(_Symbol, PERIOD_CURRENT, 200);
    if(g_atrHandle == INVALID_HANDLE || g_atr200Handle == INVALID_HANDLE)
    {
        Print("ERROR: Cannot create ATR handles");
        return INIT_FAILED;
    }

    // Pre-load M5 (HTF) data cache
    MqlRates tempM5[];
    ArraySetAsSeries(tempM5, true);
    int n = CopyRates(_Symbol, InpHigherTF, 0, 100000, tempM5);
    if(n <= 0)
    {
        Print("WARNING: Cannot load HTF data, will retry on calculate");
    }
    else
    {
        ArraySetAsSeries(g_m5Cache, false);
        ArrayResize(g_m5Cache, n);
        for(int i = 0; i < n; i++)
            g_m5Cache[i] = tempM5[n - 1 - i]; // reverse to forward-time order
        g_m5CacheCount = n;
    }

    ArrayInitialize(g_parsedHighs, 0);
    ArrayInitialize(g_parsedLows,  0);
    ArrayInitialize(g_actualHighs, 0);
    ArrayInitialize(g_actualLows,  0);

    Print("XAUUSD PA Scalping Indicator initialized. HTF=", EnumToString(InpHigherTF),
          " M5Cache=", g_m5CacheCount, " bars");
    return INIT_SUCCEEDED;
}

//=================================================================
// OnDeinit
//=================================================================
void OnDeinit(const int reason)
{
    DeleteAllObjects();
    Comment("");
    if(g_atrHandle    != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
    if(g_atr200Handle != INVALID_HANDLE) IndicatorRelease(g_atr200Handle);
    ChartRedraw(0);
}

//=================================================================
// OnCalculate — main loop
//=================================================================
int OnCalculate(const int      rates_total,
                const int      prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
    // Need at least swingLen + atrPeriod + 5 bars
    int minBars = MathMax(InpSwingLen, InpAtrPeriod) + 205;
    if(rates_total < minBars) return 0;

    // Reload M5 cache if empty
    if(g_m5CacheCount == 0)
    {
        MqlRates tempM5[];
        ArraySetAsSeries(tempM5, true);
        int n = CopyRates(_Symbol, InpHigherTF, 0, 100000, tempM5);
        if(n > 0)
        {
            ArraySetAsSeries(g_m5Cache, false);
            ArrayResize(g_m5Cache, n);
            for(int i = 0; i < n; i++)
                g_m5Cache[i] = tempM5[n - 1 - i];
            g_m5CacheCount = n;
        }
    }

    // On full recalculation: reset state and delete all objects
    if(prev_calculated == 0)
    {
        DeleteAllObjects();

        // Reset all state
        g_state=0; g_bias=0; g_bosCount=0;
        g_cycleSL=0; g_cycleSL_choch=0;
        g_chochTradeOpen=false; g_bosTradeUsed=false; g_bosSeen=false;
        g_pendingLong=false; g_pendingShort=false;
        g_tfBosCount=0; g_tfBosLimitHit=false; g_chochAtrFired=false;
        g_spArmed=false; g_pendingSpLong=false; g_pendingSpShort=false;
        g_tfSweepBullLevel=0; g_tfSweepBearLevel=0;
        g_resistCount=0; g_supportCount=0;
        g_tfOBCount=0;
        g_parsedCount=0;
        g_barIndex=0;
        g_lastProcessedM5Idx=-1;
        g_initialized=false;
        g_xATRStop=0; g_srcPrice=0; g_srcPrice1=0; g_haOpen=0; g_haClose=0;
        g_atrBuy=false; g_atrSell=false;
        g_execLong=false; g_execShort=false; g_execSpLong=false; g_execSpShort=false;
        g_tradeVisCount=0;
        g_tfHigh.currentLevel=0; g_tfHigh.crossed=false;
        g_tfLow.currentLevel=0;  g_tfLow.crossed=false;
        g_m5High.currentLevel=0; g_m5High.crossed=false;
        g_m5Low.currentLevel=0;  g_m5Low.crossed=false;
        g_tfTrendBias=0; g_tfLegState=BEARISH_LEG;
        g_m5TrendBias=0; g_m5LegState=BEARISH_LEG;
        for(int s=0;s<4;s++) { g_sessWas[s]=false; g_sessBoxName[s]=""; g_sessLblName[s]=""; }

        ArrayInitialize(g_atrStopBuf,  0.0);
        ArrayInitialize(g_atrBuyBuf,   0.0);
        ArrayInitialize(g_atrSellBuf,  0.0);
        ArrayInitialize(g_parsedHighs, 0.0);
        ArrayInitialize(g_parsedLows,  0.0);
        ArrayInitialize(g_actualHighs, 0.0);
        ArrayInitialize(g_actualLows,  0.0);
    }

    // Copy full ATR buffers (series order: [0]=latest)
    double atrBuf[], atr200Buf[];
    ArraySetAsSeries(atrBuf,    true);
    ArraySetAsSeries(atr200Buf, true);
    int nAtr    = CopyBuffer(g_atrHandle,    0, 0, rates_total, atrBuf);
    int nAtr200 = CopyBuffer(g_atr200Handle, 0, 0, rates_total, atr200Buf);

    // Determine start bar
    int start = (prev_calculated == 0) ? InpAtrPeriod + 1 : MathMax(0, prev_calculated - 1);

    // Process bars from start to rates_total-2 (skip forming bar)
    int lookback = MathMax(InpSwingLen, InpAtrPeriod) + 5;

    for(int i = start; i < rates_total - 1; i++)
    {
        // Build rates array in series order for this bar
        // [0]=current bar, [1]=prev bar, etc.
        int avail = MathMin(lookback, i + 1);
        MqlRates rates[];
        ArraySetAsSeries(rates, false);
        ArrayResize(rates, avail);
        for(int k = 0; k < avail; k++)
        {
            int srcIdx = i - k;  // forward index
            rates[k].open  = open[srcIdx];
            rates[k].high  = high[srcIdx];
            rates[k].low   = low[srcIdx];
            rates[k].close = close[srcIdx];
            rates[k].time  = time[srcIdx];
        }

        // Get ATR values for bar i (series offset = rates_total-1-i)
        int seriesOffset = rates_total - 1 - i;
        double atrVal    = (seriesOffset < nAtr    && nAtr    > 0) ? atrBuf[seriesOffset]    : 0;
        double atr200Val = (seriesOffset < nAtr200 && nAtr200 > 0) ? atr200Buf[seriesOffset] : 0;

        // Find M5 bar index for this M1 bar time
        int m5Idx = FindLastClosedM5Idx(time[i]);

        // Process
        ProcessBar(rates, avail, atrVal, atr200Val, m5Idx);

        // Write buffers
        g_atrStopBuf[i]  = g_xATRStop;
        g_atrBuyBuf[i]   = (g_atrBuy  && InpShowATRSignal) ? low[i]  - atrVal * 0.5 : 0.0;
        g_atrSellBuf[i]  = (g_atrSell && InpShowATRSignal) ? high[i] + atrVal * 0.5 : 0.0;
    }

    // Update info table on last bar
    UpdateInfoTable();
    ChartRedraw(0);

    return rates_total;
}