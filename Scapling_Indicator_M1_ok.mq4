//+------------------------------------------------------------------+
//| XAUUSD Price Action Scalping Indicator M1                        |
//| Converted to MQL4 from Scapling_Indicator.mq5                    |
//+------------------------------------------------------------------+
#property copyright "XAUUSD PA Scalping Indicator"
#property version   "1.0"
#property indicator_chart_window
#property indicator_buffers 9

// Plot 1 — ATR Trailing Stop (đường màu xanh)
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
#property indicator_style1  STYLE_SOLID

// Plot 2 — ATR Buy confirm (mũi tên lên)
#property indicator_color2  C'8,153,129'

// Plot 3 — ATR Sell confirm (mũi tên xuống)
#property indicator_color3  C'242,54,69'

//=================================================================
// INPUTS
//=================================================================
input int             InpSwingLen    = 5;          // Swing Length (TF hiện tại)

input bool            InpOBMitigClose   = true;    // OB Mitigation = Close (false = High/Low)
input int             InpObCount        = 5;       // Số OB TF hiện tại hiển thị

input double          InpAtrKey    = 1.0;          // ATR Key Value
input int             InpAtrPeriod = 10;           // ATR Period
input bool            InpUseHA     = true;         // Dùng Heikin Ashi

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
input bool  InpShowTFOBs      = true;   // Hiện OB TF hiện tại
input bool  InpShowATRSignal  = false;  // Hiện ATR Confirm signals
input bool  InpShowSessionBox = true;   // Vẽ box phiên

//=================================================================
// CONSTANTS + COLORS
//=================================================================
#define BULLISH      1
#define BEARISH     -1
#define BULLISH_LEG  1
#define BEARISH_LEG  0
#define MAX_OB      100
#define MAX_PARSED  10000
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

//=================================================================
// INDICATOR BUFFERS
//=================================================================
double g_atrStopBuf[];
double g_atrBuyBuf[];
double g_atrSellBuf[];

// EA Signal Buffers
double g_chochBuf[];
double g_bosBuf[];
double g_atrSigBuf[];
double g_lastStructTypeBuf[];
double g_lastStructCountBuf[];
double g_atrCountBuf[];

//=================================================================
// SESSION BOX DRAWING
//=================================================================
string g_sessNames[4] = {"London","New York","Phien A","Tuy chinh"};
color  g_sessColors[4] = {C_SESS1, C_SESS2, C_SESS3, C_SESS4};

//=================================================================
// GLOBAL STATE
//=================================================================
int    g_state          = 0;
int    g_bias           = 0;
bool   g_bosSeen        = false;
int    g_tfBosCount     = 0;
bool   g_tfBosLimitHit  = false;
bool   g_chochAtrFired  = false;
double g_tfSweepBullLevel = 0;
double g_tfSweepBearLevel = 0;
double g_cycleSL          = 0;
double g_cycleSL_choch    = 0;

// TF structure
SPivot g_tfHigh;
SPivot g_tfLow;
int    g_tfTrendBias = 0;
int    g_tfLegState  = BEARISH_LEG;

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

// parsedHighs/parsedLows (Luxalgo HVB adjusted)
double   g_parsedHighs[MAX_PARSED];
double   g_parsedLows[MAX_PARSED];
datetime g_obTimes[MAX_PARSED];
int      g_parsedCount = 0;
double   g_actualHighs[MAX_PARSED];
double   g_actualLows[MAX_PARSED];

// TF OBs
SOrderBlock g_tfOBs[MAX_OB];
int         g_tfOBCount = 0;

// Bar tracking
int      g_barIndex         = 0;
bool     g_initialized      = false;
int      g_objCounter       = 0;

// Session tracking
bool     g_sessWas[4]    = {false,false,false,false};
double   g_sessH[4]      = {0,0,0,0};
double   g_sessL[4]      = {0,0,0,0};
string   g_sessBoxName[4]= {"","","",""};
string   g_sessLblName[4]= {"","","",""};

// EA Signal state tracking
int      g_currentBOSCount = 0;
int      g_currentATRCount = 0;
int      g_lastStructureType = 0; // 0=None, 1=CHOCH, 2=BOS
int      g_lastStructureDirection = 0; // 1=Bullish, -1=Bearish
int      g_lastStructureCount = 0;

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
    if(name != "" && ObjectFind(name) >= 0)
        ObjectDelete(name);
}

void CreateLine(string name, datetime t1, double p1, datetime t2, double p2,
                color col, int style, int width, bool rayRight=false)
{
    if(ObjectFind(name) < 0)
        ObjectCreate(name, OBJ_TREND, 0, t1, p1, t2, p2);
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
    if(ObjectFind(name) < 0)
        ObjectCreate(name, OBJ_TEXT, 0, t, price);
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
    if(ObjectFind(name) < 0)
        ObjectCreate(name, OBJ_RECTANGLE, 0, t1, top, t2, bot);
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
    if(name != "" && ObjectFind(name) >= 0)
        ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
}

void BoxSetTop(string name, double top)
{
    if(name != "" && ObjectFind(name) >= 0)
        ObjectSetDouble(0, name, OBJPROP_PRICE, 0, top);
}

void BoxSetBottom(string name, double bot)
{
    if(name != "" && ObjectFind(name) >= 0)
        ObjectSetDouble(0, name, OBJPROP_PRICE, 1, bot);
}

void BoxSetBgColor(string name, color col)
{
    if(name != "" && ObjectFind(name) >= 0)
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, col);
}

void TextSetXY(string name, datetime t, double price)
{
    if(name != "" && ObjectFind(name) >= 0)
    {
        ObjectSetInteger(0, name, OBJPROP_TIME,  0, t);
        ObjectSetDouble( 0, name, OBJPROP_PRICE, 0, price);
    }
}

void TextSetText(string name, string txt)
{
    if(name != "" && ObjectFind(name) >= 0)
        ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

void LineSetX2(string name, datetime t2)
{
    if(name != "" && ObjectFind(name) >= 0)
        ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
}

void DeleteAllObjects()
{
    ObjectsDeleteAll(0, OBJ_PFX);
}

//=================================================================
// MATH HELPERS
//=================================================================
double RatesHighest(const MqlRates &rates[], int fromIdx, int count)
{
    int i = 0;
    double h = -1e15;
    int total = ArraySize(rates);
    for(i = fromIdx; i < fromIdx + count && i < total; i++)
        if(rates[i].high > h) h = rates[i].high;
    return h;
}

double RatesLowest(const MqlRates &rates[], int fromIdx, int count)
{
    int i = 0;
    double l = 1e15;
    int total = ArraySize(rates);
    for(i = fromIdx; i < fromIdx + count && i < total; i++)
        if(rates[i].low < l) l = rates[i].low;
    return l;
}

//=================================================================
// SESSION HELPER
//=================================================================
int GetUTCOffsetSec(string tz)
{
    int plusPos  = StringFind(tz, "+");
    int minusPos = StringFind(tz, "-", 3);
    string rest = "";
    int colonPos = -1;
    int h = 0, m = 0;
    
    if(plusPos >= 0)
    {
        rest = StringSubstr(tz, plusPos + 1);
        colonPos = StringFind(rest, ":");
        if(colonPos >= 0)
        {
            h = (int)StringToInteger(StringSubstr(rest, 0, colonPos));
            m = (int)StringToInteger(StringSubstr(rest, colonPos + 1));
            return h * 3600 + m * 60;
        }
        return (int)StringToInteger(rest) * 3600;
    }
    else if(minusPos >= 0)
    {
        rest = StringSubstr(tz, minusPos + 1);
        colonPos = StringFind(rest, ":");
        if(colonPos >= 0)
        {
            h = (int)StringToInteger(StringSubstr(rest, 0, colonPos));
            m = (int)StringToInteger(StringSubstr(rest, colonPos + 1));
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
    int s = 0;

    for(s = 0; s < 4; s++)
    {
        if(sessNow[s] && !g_sessWas[s])
        {
            g_sessH[s] = barHigh;
            g_sessL[s] = barLow;
            g_sessBoxName[s] = NewObjName("SESS" + IntegerToString(s));
            g_sessLblName[s] = NewObjName("SESSL" + IntegerToString(s));

            color col   = g_sessColors[s];
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
            if(barHigh > g_sessH[s]) g_sessH[s] = barHigh;
            if(barLow  < g_sessL[s]) g_sessL[s] = barLow;
            BoxSetTop(  g_sessBoxName[s], g_sessH[s]);
            BoxSetBottom(g_sessBoxName[s], g_sessL[s]);
            BoxSetRight( g_sessBoxName[s], extRight);
            TextSetXY(  g_sessLblName[s], barTime, g_sessH[s]);
        }
        if(!sessNow[s] && g_sessWas[s] && g_sessBoxName[s] != "")
        {
            BoxSetRight(g_sessBoxName[s], barTime);
        }
        g_sessWas[s] = sessNow[s];
    }
}

//=================================================================
// STRUCTURE DRAWING
//=================================================================
void DrawStructure(SPivot &pivot, string tag, color col, int lineStyle,
                   int fontSize, datetime curTime)
{
    if(pivot.currentLevel <= 0) return;

    string lnName  = NewObjName("STR");
    string txtName = NewObjName("STRT");

    CreateLine(lnName, pivot.barTime, pivot.currentLevel,
               curTime, pivot.currentLevel, col, lineStyle, 1, false);

    datetime midTime = pivot.barTime + (curTime - pivot.barTime) / 2;
    CreateText(txtName, midTime, pivot.currentLevel, tag, col, fontSize, ANCHOR_LOWER);
}

//=================================================================
// SR MANAGEMENT
//=================================================================


//=================================================================
// GENERAL STATEMACHINE HELPERS
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

void StoreTFOrderBlock(int pivotBarIndex, int obBias)
{
    int i = 0;
    if(pivotBarIndex < 0 || pivotBarIndex >= g_parsedCount) return;

    int parsedIdx = -1;
    if(obBias == BEARISH)
    {
        double maxV = -1e15;
        for(i = pivotBarIndex; i < g_parsedCount; i++)
            if(g_parsedHighs[i] > maxV) { maxV = g_parsedHighs[i]; parsedIdx = i; }
    }
    else
    {
        double minV = 1e15;
        for(i = pivotBarIndex; i < g_parsedCount; i++)
            if(g_parsedLows[i] < minV) { minV = g_parsedLows[i]; parsedIdx = i; }
    }
    if(parsedIdx < 0) return;

    if(g_tfOBCount < MAX_OB) g_tfOBCount++;
    for(i = g_tfOBCount - 1; i > 0; i--)
        g_tfOBs[i] = g_tfOBs[i-1];

    g_tfOBs[0].barHigh = g_parsedHighs[parsedIdx];
    g_tfOBs[0].barLow  = g_parsedLows[parsedIdx];
    g_tfOBs[0].barTime = g_obTimes[parsedIdx];
    g_tfOBs[0].bias    = obBias;
    g_tfOBs[0].active  = true;
    g_tfOBs[0].boxName = "";
}

void DeleteMitigatedTFOBs(double curClose, double curHigh, double curLow)
{
    int i = 0;
    double bearMitig = InpOBMitigClose ? curClose : curHigh;
    double bullMitig = InpOBMitigClose ? curClose : curLow;

    for(i = 0; i < g_tfOBCount; i++)
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
    int i = 0;
    if(!InpShowTFOBs) return;

    int drawn = 0;
    for(i = 0; i < g_tfOBCount && drawn < InpObCount; i++)
    {
        if(!g_tfOBs[i].active) continue;

        color col = g_tfOBs[i].bias == BEARISH
                    ? C_BEAR_OB : C_BULL_OB;

        if(g_tfOBs[i].boxName == "")
        {
            g_tfOBs[i].boxName = NewObjName("TFOB");
            CreateBox(g_tfOBs[i].boxName,
                      g_tfOBs[i].barTime, g_tfOBs[i].barHigh,
                      rightTime, g_tfOBs[i].barLow,
                      col, clrNONE, 0);
        }
        else
        {
            BoxSetRight(g_tfOBs[i].boxName, rightTime);
        }
        drawn++;
    }
}

//=================================================================
// STRUCTURE UPDATES
//=================================================================
void UpdateTFStructure(const MqlRates &rates[], datetime curTime, bool &chochBull, bool &chochBear, bool &bosBull, bool &bosBear)
{
    int n     = InpSwingLen;
    int total = ArraySize(rates);
    bool extra = false;
    string tag = "";
    color col = clrNONE;
    
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

    chochBull = false; bosBull = false;
    chochBear = false; bosBear = false;

    double curClose  = rates[0].close;
    double prevClose = rates[1].close;

    // Bullish break
    if(g_tfHigh.currentLevel > 0 && !g_tfHigh.crossed)
    {
        extra = (g_tfHigh.currentLevel != g_tfLow.currentLevel);
        if(curClose > g_tfHigh.currentLevel && prevClose <= g_tfHigh.currentLevel && extra)
        {
            g_tfHigh.crossed = true;
            if(g_tfTrendBias == BEARISH) chochBull = true;
            else                         bosBull   = true;
            g_tfTrendBias = BULLISH;

            if(InpShowTFStruct)
            {
                tag = chochBull ? "CHoCH" : "BOS";
                col = chochBull ? C_GREEN : C_GREEN;
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
        extra = (g_tfLow.currentLevel != g_tfHigh.currentLevel);
        if(curClose < g_tfLow.currentLevel && prevClose >= g_tfLow.currentLevel && extra)
        {
            g_tfLow.crossed = true;
            if(g_tfTrendBias == BULLISH) chochBear = true;
            else                         bosBear   = true;
            g_tfTrendBias = BEARISH;

            if(InpShowTFStruct)
            {
                tag = chochBear ? "CHoCH" : "BOS";
                col = chochBear ? C_RED : C_RED;
                DrawStructure(g_tfLow, tag, col, STYLE_DASH, 7, curTime);
            }

            StoreTFOrderBlock(g_tfLow.barIndex, BEARISH);
            if(g_tfOBCount > 0 && g_tfOBs[0].bias == BEARISH)
                g_tfSweepBullLevel = g_tfOBs[0].barHigh;
        }
    }

    g_tf_chochBull = chochBull;
    g_tf_chochBear = chochBear;
    g_tf_bosBull   = bosBull;
    g_tf_bosBear   = bosBear;
}

void FullReset()
{
    g_state          = 0;  g_bias = 0;
    g_cycleSL        = 0;  g_cycleSL_choch = 0;
    g_bosSeen        = false;
    g_tfBosCount     = 0;  g_tfBosLimitHit = false; g_chochAtrFired = false;
    g_tfSweepBullLevel = 0;  g_tfSweepBearLevel = 0;
}

//=================================================================
// ATR CALCULATION
//=================================================================
void UpdateATR(double o, double h, double l, double c, double nLoss)
{
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
// STATE MACHINE
//=================================================================
void RunStateMachine(double curClose, double curHigh, double curLow, double curOpen,
                      datetime curTime, bool sessionOK)
{
    double bearMitig = InpOBMitigClose ? curClose : curHigh;
    double bullMitig = InpOBMitigClose ? curClose : curLow;

    bool tfOBSweepBull = (g_tfSweepBullLevel > 0) && (bearMitig >= g_tfSweepBullLevel);
    bool tfOBSweepBear = (g_tfSweepBearLevel > 0) && (bullMitig <= g_tfSweepBearLevel);

    bool reversed = (g_bias == BULLISH && g_tf_chochBear) ||
                    (g_bias == BEARISH && g_tf_chochBull);

    if(reversed)
    {
        g_state = 1; 
        g_bias = (g_bias == BULLISH) ? BEARISH : BULLISH;
        g_tfBosCount = 0;
        g_tfBosLimitHit = false;
        g_chochAtrFired = false;
        g_bosSeen = false;
        return;
    }

    if(g_state == 0)
    {
        if(g_tf_chochBull)
        {
            g_state = 1; g_bias = BULLISH; g_tfBosCount = 0; g_tfBosLimitHit = false; g_chochAtrFired = false; g_bosSeen = false;
        }
        else if(g_tf_chochBear)
        {
            g_state = 1; g_bias = BEARISH; g_tfBosCount = 0; g_tfBosLimitHit = false; g_chochAtrFired = false; g_bosSeen = false;
        }
    }

    int stateSnap = g_state;

    // State 1: Wait TF OB Sweep
    if(stateSnap == 1)
    {
        if(g_bias == BULLISH && tfOBSweepBear)
        {
            g_state = 2; // Move to wait ATR
        }
        else if(g_bias == BEARISH && tfOBSweepBull)
        {
            g_state = 2; // Move to wait ATR
        }
    }

    // State 2: Wait ATR confirm
    if(stateSnap == 2)
    {
        if(g_bias == BULLISH && g_atrBuy)
        {
            g_state = 3; // In Trend
            g_chochAtrFired = true;
        }
        else if(g_bias == BEARISH && g_atrSell)
        {
            g_state = 3; // In Trend
            g_chochAtrFired = true;
        }
    }

    // State 3: In Trend (Continuation mode)
    if(stateSnap == 3)
    {
        if(g_bias == BULLISH && g_tf_bosBull)
        {
            g_bosSeen = true;
        }
        else if(g_bias == BEARISH && g_tf_bosBear)
        {
            g_bosSeen = true;
        }

        if(g_bosSeen)
        {
            if(g_bias == BULLISH && g_atrBuy)
            {
                g_bosSeen = false;
            }
            else if(g_bias == BEARISH && g_atrSell)
            {
                g_bosSeen = false;
            }
        }
    }
}

//=================================================================
// INFO TABLE
//=================================================================
void UpdateInfoTable()
{
    string stateStr;
    switch(g_state)
    {
        case 0: stateStr = "Wait TF CHoCH"; break;
        case 1: stateStr = "Wait TF OB Sweep"; break;
        case 2: stateStr = "Wait ATR confirm"; break;
        case 3: stateStr = "In Trend"; break;
        default: stateStr = "?";
    }
    string biasStr  = g_bias == BULLISH ? "BULL" : g_bias == BEARISH ? "BEAR" : "--";
    string tfBosStr = IntegerToString(g_tfBosCount) + (g_tfBosLimitHit ? " BLOCKED" : "");
    string slStr    = g_cycleSL > 0 ? DoubleToString(NormalizeDouble(g_cycleSL, 2), 2) : "--";

    Comment(
        "=== XAUUSD PA Scalping ===\n",
        "State : ", stateStr, "\n",
        "Bias  : ", biasStr, "\n",
        "TF BOS : ", tfBosStr, "\n",
        "Cycle SL: ", slStr, "\n",
        "TF PivH : ", DoubleToString(NormalizeDouble(g_tfHigh.currentLevel, 2), 2), "\n",
        "TF PivL : ", DoubleToString(NormalizeDouble(g_tfLow.currentLevel,  2), 2), "\n",
        "Last Signal Structure: ", (g_lastStructureType == 1 ? "CHOCH " : g_lastStructureType == 2 ? "BOS " : "None"), 
        (g_lastStructureType > 0 ? (g_lastStructureDirection == 1 ? "Bullish" : "Bearish") : ""), 
        (g_lastStructureType == 2 ? " #" + IntegerToString(g_lastStructureCount) : ""), "\n",
        "Current ATR Count: ", IntegerToString(g_currentATRCount)
    );
}

//=================================================================
// PROCESS ONE BAR
//=================================================================
void ProcessBar(const MqlRates &rates[], int totalRates,
                double atrVal, double atr200Val,
                bool printLog,
                bool &isChoch, bool &isBos, bool &isAtr)
{
    g_barIndex++;

    double o = rates[0].open;
    double h = rates[0].high;
    double l = rates[0].low;
    double c = rates[0].close;
    datetime t = rates[0].time;
    double nLoss = 0;
    bool tfChochBull = false, tfChochBear = false, tfBosBull = false, tfBosBear = false;
    string structStr = "";

    isChoch = false;
    isBos   = false;
    isAtr   = false;

    UpdateParsed(h, l, atr200Val, t);

    nLoss = InpAtrKey * atrVal;
    UpdateATR(o, h, l, c, nLoss);

    UpdateTFStructure(rates, t, tfChochBull, tfChochBear, tfBosBull, tfBosBear);

    // 1. Process CHOCH / BOS signals
    if(tfChochBull)
    {
        g_currentBOSCount = 0;
        g_currentATRCount = 0;
        g_lastStructureType = 1; // CHOCH
        g_lastStructureDirection = 1; // Bullish
        g_lastStructureCount = 0;
        isChoch = true;
        if(printLog)
            Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] CHOCH Bullish confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
    }
    else if(tfChochBear)
    {
        g_currentBOSCount = 0;
        g_currentATRCount = 0;
        g_lastStructureType = 1; // CHOCH
        g_lastStructureDirection = -1; // Bearish
        g_lastStructureCount = 0;
        isChoch = true;
        if(printLog)
            Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] CHOCH Bearish confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
    }

    if(tfBosBull)
    {
        g_currentBOSCount++;
        g_currentATRCount = 0;
        g_lastStructureType = 2; // BOS
        g_lastStructureDirection = 1; // Bullish
        g_lastStructureCount = g_currentBOSCount;
        isBos = true;
        if(printLog)
            Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] BOS Bullish #", g_currentBOSCount, " confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
    }
    else if(tfBosBear)
    {
        g_currentBOSCount++;
        g_currentATRCount = 0;
        g_lastStructureType = 2; // BOS
        g_lastStructureDirection = -1; // Bearish
        g_lastStructureCount = g_currentBOSCount;
        isBos = true;
        if(printLog)
            Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] BOS Bearish #", g_currentBOSCount, " confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
    }

    // 2. Process ATR signals (must check against structure bias)
    if(g_tfTrendBias == BULLISH && g_atrBuy)
    {
        g_currentATRCount++;
        isAtr = true;
        structStr = (g_lastStructureType == 1) ? "CHOCH Bullish" : ("BOS Bullish #" + IntegerToString(g_lastStructureCount));
        if(printLog)
            Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] ATR Bullish #", g_currentATRCount, " of ", structStr, " confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
    }
    else if(g_tfTrendBias == BEARISH && g_atrSell)
    {
        g_currentATRCount++;
        isAtr = true;
        structStr = (g_lastStructureType == 1) ? "CHOCH Bearish" : ("BOS Bearish #" + IntegerToString(g_lastStructureCount));
        if(printLog)
            Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] ATR Bearish #", g_currentATRCount, " of ", structStr, " confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
    }

    bool sessionOK = SessionOKAt(t);
    RunStateMachine(c, h, l, o, t, sessionOK);

    DeleteMitigatedTFOBs(c, h, l);

    int periodSec = PeriodSeconds();
    UpdateSessionBoxes(t, h, l, periodSec);

    DrawTFOrderBlocks(t + periodSec);

    g_initialized = true;
}

//=================================================================
// OnInit
//=================================================================
int OnInit()
{
    SetIndexBuffer(0, g_atrStopBuf);
    SetIndexBuffer(1, g_atrBuyBuf);
    SetIndexBuffer(2, g_atrSellBuf);
    SetIndexBuffer(3, g_chochBuf);
    SetIndexBuffer(4, g_bosBuf);
    SetIndexBuffer(5, g_atrSigBuf);
    SetIndexBuffer(6, g_lastStructTypeBuf);
    SetIndexBuffer(7, g_lastStructCountBuf);
    SetIndexBuffer(8, g_atrCountBuf);

    SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 1, clrDodgerBlue);
    SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, 1, C'8,153,129');
    SetIndexArrow(1, 233); // up arrow
    SetIndexStyle(2, DRAW_ARROW, STYLE_SOLID, 1, C'242,54,69');
    SetIndexArrow(2, 234); // down arrow

    SetIndexStyle(3, DRAW_NONE);
    SetIndexStyle(4, DRAW_NONE);
    SetIndexStyle(5, DRAW_NONE);
    SetIndexStyle(6, DRAW_NONE);
    SetIndexStyle(7, DRAW_NONE);
    SetIndexStyle(8, DRAW_NONE);

    SetIndexEmptyValue(0, 0.0);
    SetIndexEmptyValue(1, 0.0);
    SetIndexEmptyValue(2, 0.0);
    SetIndexEmptyValue(3, 0.0);
    SetIndexEmptyValue(4, 0.0);
    SetIndexEmptyValue(5, 0.0);
    SetIndexEmptyValue(6, 0.0);
    SetIndexEmptyValue(7, 0.0);
    SetIndexEmptyValue(8, 0.0);

    SetIndexLabel(0, "ATR Stop");
    SetIndexLabel(1, "ATR Buy");
    SetIndexLabel(2, "ATR Sell");
    SetIndexLabel(3, "CHOCH Signal");
    SetIndexLabel(4, "BOS Signal");
    SetIndexLabel(5, "ATR Signal");
    SetIndexLabel(6, "Last Struct Type");
    SetIndexLabel(7, "Last Struct Count");
    SetIndexLabel(8, "ATR Count");

    ArrayInitialize(g_parsedHighs, 0);
    ArrayInitialize(g_parsedLows,  0);
    ArrayInitialize(g_actualHighs, 0);
    ArrayInitialize(g_actualLows,  0);

    Print("XAUUSD PA Scalping Indicator M1 initialized.");
    return INIT_SUCCEEDED;
}

//=================================================================
// OnDeinit
//=================================================================
void OnDeinit(const int reason)
{
    DeleteAllObjects();
    Comment("");
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
    int minBars = MathMax(InpSwingLen, InpAtrPeriod) + 205;
    int i = 0, k = 0, s = 0;
    
    if(rates_total < minBars) return 0;

    ArraySetAsSeries(time,  false);
    ArraySetAsSeries(open,  false);
    ArraySetAsSeries(high,  false);
    ArraySetAsSeries(low,   false);
    ArraySetAsSeries(close, false);

    ArraySetAsSeries(g_atrStopBuf,  false);
    ArraySetAsSeries(g_atrBuyBuf,   false);
    ArraySetAsSeries(g_atrSellBuf,  false);
    ArraySetAsSeries(g_chochBuf,    false);
    ArraySetAsSeries(g_bosBuf,      false);
    ArraySetAsSeries(g_atrSigBuf,   false);
    ArraySetAsSeries(g_lastStructTypeBuf,  false);
    ArraySetAsSeries(g_lastStructCountBuf, false);
    ArraySetAsSeries(g_atrCountBuf,  false);

    if(prev_calculated == 0)
    {
        DeleteAllObjects();

        g_state=0; g_bias=0;
        g_cycleSL=0; g_cycleSL_choch=0;
        g_bosSeen=false;
        g_tfBosCount=0; g_tfBosLimitHit=false; g_chochAtrFired=false;
        g_tfSweepBullLevel=0; g_tfSweepBearLevel=0;
        g_tfOBCount=0;
        g_parsedCount=0;
        g_barIndex=0;
        g_initialized=false;
        g_xATRStop=0; g_srcPrice=0; g_srcPrice1=0; g_haOpen=0; g_haClose=0;
        g_atrBuy=false; g_atrSell=false;
        g_tfHigh.currentLevel=0; g_tfHigh.crossed=false;
        g_tfLow.currentLevel=0;  g_tfLow.crossed=false;
        g_tfTrendBias=0; g_tfLegState=BEARISH_LEG;
        
        g_currentBOSCount = 0;
        g_currentATRCount = 0;
        g_lastStructureType = 0;
        g_lastStructureDirection = 0;
        g_lastStructureCount = 0;

        for(s=0;s<4;s++) { g_sessWas[s]=false; g_sessBoxName[s]=""; g_sessLblName[s]=""; }

        ArrayInitialize(g_atrStopBuf,  0.0);
        ArrayInitialize(g_atrBuyBuf,   0.0);
        ArrayInitialize(g_atrSellBuf,  0.0);
        ArrayInitialize(g_chochBuf,    0.0);
        ArrayInitialize(g_bosBuf,      0.0);
        ArrayInitialize(g_atrSigBuf,   0.0);
        ArrayInitialize(g_lastStructTypeBuf, 0.0);
        ArrayInitialize(g_lastStructCountBuf, 0.0);
        ArrayInitialize(g_atrCountBuf, 0.0);
        
        ArrayInitialize(g_parsedHighs, 0.0);
        ArrayInitialize(g_parsedLows,  0.0);
        ArrayInitialize(g_actualHighs, 0.0);
        ArrayInitialize(g_actualLows,  0.0);
    }

    int start = (prev_calculated == 0) ? InpAtrPeriod + 1 : MathMax(0, prev_calculated - 1);
    int lookback = MathMax(InpSwingLen, InpAtrPeriod) + 5;

    for(i = start; i < rates_total - 1; i++)
    {
        int avail = MathMin(lookback, i + 1);
        MqlRates rates[];
        ArraySetAsSeries(rates, false);
        ArrayResize(rates, avail);
        for(k = 0; k < avail; k++)
        {
            int srcIdx = i - k;
            rates[k].open  = open[srcIdx];
            rates[k].high  = high[srcIdx];
            rates[k].low   = low[srcIdx];
            rates[k].close = close[srcIdx];
            rates[k].time  = time[srcIdx];
        }

        int shift = rates_total - 1 - i;
        double atrVal    = iATR(NULL, 0, InpAtrPeriod, shift);
        double atr200Val = iATR(NULL, 0, 200, shift);

        bool isChoch = false;
        bool isBos = false;
        bool isAtr = false;

        ProcessBar(rates, avail, atrVal, atr200Val, (i >= rates_total - 3), isChoch, isBos, isAtr);

        g_atrStopBuf[i]  = g_xATRStop;
        g_atrBuyBuf[i]   = (g_atrBuy  && InpShowATRSignal) ? low[i]  - atrVal * 0.5 : 0.0;
        g_atrSellBuf[i]  = (g_atrSell && InpShowATRSignal) ? high[i] + atrVal * 0.5 : 0.0;
        
        g_chochBuf[i]            = (isChoch) ? (double)g_lastStructureDirection : 0.0;
        g_bosBuf[i]              = (isBos)   ? (double)(g_lastStructureDirection * g_currentBOSCount) : 0.0;
        g_atrSigBuf[i]           = (isAtr)   ? (double)(g_lastStructureDirection * g_currentATRCount) : 0.0;
        g_lastStructTypeBuf[i]   = (double)g_lastStructureType;
        g_lastStructCountBuf[i]  = (double)g_lastStructureCount;
        g_atrCountBuf[i]         = (double)g_currentATRCount;
    }

    UpdateInfoTable();
    ChartRedraw(0);

    return rates_total;
}
