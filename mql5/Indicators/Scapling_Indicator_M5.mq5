//+------------------------------------------------------------------+
//| XAUUSD Price Action Scalping Indicator M5                        |
//| Converted to MQL4 from Scapling_Indicator.mq5                    |
//+------------------------------------------------------------------+
#property copyright "XAUUSD PA Scalping Indicator"
#property version   "1.0"
#property indicator_chart_window
#property indicator_buffers 9
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
input bool            InpUseHA     = false;         // Dùng Heikin Ashi

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
input bool  InpShowATRSignal  = true;  // Hiện ATR Confirm signals
input bool  InpShowSessionBox = false;   // Vẽ box phiên

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

#define C_GREEN      ((color)0x819908)   // #089981 R=8 G=153 B=129
#define C_RED        ((color)0x4536F2)   // #F23645 R=242 G=54 B=69
#define C_COBALT     C'0,71,171'
#define C_YELLOW     clrYellow
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
// ATR handles for MT5
int g_atrHandle = INVALID_HANDLE;
int g_atr200Handle = INVALID_HANDLE;

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
bool   g_chochPending   = false;
int    g_chochPendingDirection = 0;
double g_chochPendingOBLevel = 0.0;
bool   g_tfTrendBiasConfirmed = false;
string g_pendingChochLineObj = "";
string g_pendingChochTextObj = "";

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
double   g_parsedHighs[];
double   g_parsedLows[];
datetime g_obTimes[];
double   g_actualHighs[];
double   g_actualLows[];

// TF OBs
SOrderBlock g_tfOBs[MAX_OB];
int         g_tfOBCount = 0;

// Bar tracking
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

struct SOBArray
{
    SOrderBlock ob[100];
    int count;
};

SOBArray g_tfOBsHistory[];
int    g_currentBOSCountHistory[];
bool   g_chochPendingHistory[];
int    g_chochPendingDirectionHistory[];
double g_chochPendingOBLevelHistory[];
int    g_tfTrendBiasHistory[];
int    g_lastStructureTypeHistory[];
int    g_lastStructureDirectionHistory[];
int    g_lastStructureCountHistory[];
int    g_currentATRCountHistory[];
SPivot g_tfHighHistory[];
SPivot g_tfLowHistory[];
int    g_tfLegStateHistory[];
double g_xATRStopHistory[];
double g_srcPrice1History[];
double g_haOpenHistory[];
double g_haCloseHistory[];
int    g_stateHistory[];
int    g_biasHistory[];
bool   g_bosSeenHistory[];
bool   g_tfBosLimitHitHistory[];
bool   g_chochAtrFiredHistory[];
double g_tfSweepBullLevelHistory[];
double g_tfSweepBearLevelHistory[];
double g_cycleSLHistory[];
double g_cycleSL_chochHistory[];
bool   g_tfTrendBiasConfirmedHistory[];

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
                   int fontSize, datetime curTime, bool isChoch = false)
{
    if(pivot.currentLevel <= 0) return;

    string lnName  = NewObjName("STR");
    string txtName = NewObjName("STRT");

    CreateLine(lnName, pivot.barTime, pivot.currentLevel,
               curTime, pivot.currentLevel, col, lineStyle, 1, false);

    datetime midTime = pivot.barTime + (curTime - pivot.barTime) / 2;
    CreateText(txtName, midTime, pivot.currentLevel, tag, col, fontSize, ANCHOR_LOWER);

    if(isChoch)
    {
        g_pendingChochLineObj = lnName;
        g_pendingChochTextObj = txtName;
    }
}

//=================================================================
// SR MANAGEMENT
//=================================================================


//=================================================================
// GENERAL STATEMACHINE HELPERS
//=================================================================
void UpdateParsed(double h, double l, double atr200, datetime t, int barIdx)
{
    bool hvb = (h - l) >= 2.0 * atr200;
    double pH = hvb ? l : h;
    double pL = hvb ? h : l;
    g_parsedHighs[barIdx] = pH;
    g_parsedLows[barIdx]  = pL;
    g_actualHighs[barIdx] = h;
    g_actualLows[barIdx]  = l;
    g_obTimes[barIdx]     = t;
}

void StoreTFOrderBlock(int pivotBarIndex, int obBias, int currentBarIdx)
{
    int k = 0;
    if(pivotBarIndex < 0 || pivotBarIndex > currentBarIdx) return;

    int parsedIdx = -1;
    if(obBias == BEARISH)
    {
        double maxV = -1e15;
        for(k = pivotBarIndex; k <= currentBarIdx; k++)
        {
            if(g_parsedHighs[k] > maxV) { maxV = g_parsedHighs[k]; parsedIdx = k; }
        }
    }
    else
    {
        double minV = 1e15;
        for(k = pivotBarIndex; k <= currentBarIdx; k++)
        {
            if(g_parsedLows[k] < minV) { minV = g_parsedLows[k]; parsedIdx = k; }
        }
    }
    if(parsedIdx < 0) return;

    if(g_tfOBCount < MAX_OB) g_tfOBCount++;
    for(k = g_tfOBCount - 1; k > 0; k--)
        g_tfOBs[k] = g_tfOBs[k-1];

    g_tfOBs[0].barHigh = g_actualHighs[parsedIdx];
    g_tfOBs[0].barLow  = g_actualLows[parsedIdx];
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
void UpdateTFStructure(const MqlRates &rates[], datetime curTime, bool &chochBull, bool &chochBear, bool &bosBull, bool &bosBear, int barIdx)
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
            g_tfHigh.barIndex     = barIdx - n;
        }
        else
        {
            g_tfLow.lastLevel    = g_tfLow.currentLevel;
            g_tfLow.currentLevel = rates[n].low;
            g_tfLow.crossed      = false;
            g_tfLow.barTime      = rates[n].time;
            g_tfLow.barIndex     = barIdx - n;
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
            if((g_tfTrendBias == BEARISH && !(g_chochPending && g_chochPendingDirection == 1)) || (g_chochPending && g_chochPendingDirection == -1)) 
            {
                chochBull = true;
                g_tfLow.crossed = false;
            }
            else                         
            {
                bosBull   = true;
                g_tfTrendBias = BULLISH;
            }

            if(InpShowTFStruct)
            {
                tag = chochBull ? "5CHoCH" : "5BOS";
                col = chochBull ? C_COBALT : C_GREEN;
                DrawStructure(g_tfHigh, tag, col, STYLE_DASH, 7, curTime, chochBull);
            }

            StoreTFOrderBlock(g_tfLow.barIndex, BULLISH, barIdx);
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
            if((g_tfTrendBias == BULLISH && !(g_chochPending && g_chochPendingDirection == -1)) || (g_chochPending && g_chochPendingDirection == 1)) 
            {
                chochBear = true;
                g_tfHigh.crossed = false;
            }
            else                         
            {
                bosBear   = true;
                g_tfTrendBias = BEARISH;
            }

            if(InpShowTFStruct)
            {
                tag = chochBear ? "5CHoCH" : "5BOS";
                col = chochBear ? C_YELLOW : C_RED;
                DrawStructure(g_tfLow, tag, col, STYLE_DASH, 7, curTime, chochBear);
            }

            StoreTFOrderBlock(g_tfHigh.barIndex, BEARISH, barIdx);
            if(g_tfOBCount > 0 && g_tfOBs[0].bias == BEARISH)
                g_tfSweepBullLevel = g_tfOBs[0].barHigh;
        }
    }
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

void CreateLabel(string name, int x, int y, string text, color col, int fontSize, int corner = CORNER_LEFT_LOWER)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    }
    ObjectSetInteger(0, name, OBJPROP_CORNER,     corner);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
    ObjectSetString( 0, name, OBJPROP_TEXT,       text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,      col);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fontSize);
    ObjectSetString( 0, name, OBJPROP_FONT,       "Calibri Bold");
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

//=================================================================
// INFO TABLE
//=================================================================
double GetLatestActiveOBLevel(int obBias)
{
    for(int i = 0; i < g_tfOBCount; i++)
    {
        if(g_tfOBs[i].active && g_tfOBs[i].bias == obBias)
        {
            return (obBias == BULLISH) ? g_tfOBs[i].barLow : g_tfOBs[i].barHigh;
        }
    }
    return 0.0;
}

void UpdateInfoTable()
{
    Comment(""); // Clear standard chart comment

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
    string tfBosStr = g_chochPending ? "0" : IntegerToString(g_currentBOSCount);
    string slStr    = g_cycleSL > 0 ? DoubleToString(NormalizeDouble(g_cycleSL, 2), 2) : "--";

    // Get active OB levels
    double obBullVal = GetLatestActiveOBLevel(BULLISH);
    double obBearVal = GetLatestActiveOBLevel(BEARISH);
    string obBullStr = obBullVal > 0 ? DoubleToString(NormalizeDouble(obBullVal, 2), 2) : "--";
    string obBearStr = obBearVal > 0 ? DoubleToString(NormalizeDouble(obBearVal, 2), 2) : "--";
    color obBullColor = obBullVal > 0 ? clrLime : clrYellow;
    color obBearColor = obBearVal > 0 ? clrRed : clrYellow;

    string entryPermStr = "Entry Allowed (BOS <= 2)";
    color entryPermColor = clrLime;
    if(g_chochPending)
    {
        entryPermStr = "No Entry (CHOCH Pending)";
        entryPermColor = clrRed;
    }
    else if(g_currentBOSCount >= 3)
    {
        entryPermStr = "No Entry (BOS >= 3)";
        entryPermColor = clrRed;
    }

    int x = 20;
    int yStart = 20;
    int yStep = 18;
    int line = 0;
    string pfx = OBJ_PFX + "PANEL_";

    CreateLabel(pfx + "0", x, yStart + (line++) * yStep, "Current ATR Count: " + IntegerToString(g_currentATRCount), clrYellow, 10);
    
    string structName;
    string structDir;
    string structCount;
    if(g_chochPending)
    {
        structName = "CHOCH ";
        structDir = (g_chochPendingDirection == 1 ? "Bullish" : "Bearish") + " (Pending)";
        structCount = "";
    }
    else
    {
        structName = (g_lastStructureType == 1 ? "CHOCH " : g_lastStructureType == 2 ? "BOS " : "None");
        structDir = (g_lastStructureType > 0 ? (g_lastStructureDirection == 1 ? "Bullish" : "Bearish") : "");
        structCount = (g_lastStructureType == 2 ? " #" + IntegerToString(g_lastStructureCount) : "");
    }
    CreateLabel(pfx + "1", x, yStart + (line++) * yStep, "Last Signal Struct: " + structName + structDir + structCount, clrYellow, 10);
    
    CreateLabel(pfx + "2", x, yStart + (line++) * yStep, "TF PivL : " + DoubleToString(NormalizeDouble(g_tfLow.currentLevel,  2), 2), clrYellow, 10);
    CreateLabel(pfx + "3", x, yStart + (line++) * yStep, "TF PivH : " + DoubleToString(NormalizeDouble(g_tfHigh.currentLevel, 2), 2), clrYellow, 10);
    
    // Display OB levels
    CreateLabel(pfx + "OB_BULL", x, yStart + (line++) * yStep, "TF OB_Bull: " + obBullStr, obBullColor, 10);
    CreateLabel(pfx + "OB_BEAR", x, yStart + (line++) * yStep, "TF OB_Bear: " + obBearStr, obBearColor, 10);
    
    CreateLabel(pfx + "4", x, yStart + (line++) * yStep, "Cycle SL: " + slStr, clrYellow, 10);
    CreateLabel(pfx + "5", x, yStart + (line++) * yStep, "TF BOS  : " + tfBosStr, clrYellow, 10);
    CreateLabel(pfx + "6", x, yStart + (line++) * yStep, "Bias    : " + biasStr, clrYellow, 10);
    CreateLabel(pfx + "7", x, yStart + (line++) * yStep, "State   : " + stateStr, clrYellow, 10);
    CreateLabel(pfx + "8", x, yStart + (line++) * yStep, "Status  : " + entryPermStr, entryPermColor, 10);
    CreateLabel(pfx + "9", x, yStart + (line++) * yStep, "=== M5 PA Scalping ===", clrYellow, 10);
}


double GetMostRecentOppositeOBLevel(int chochBias)
{
    int targetBias = (chochBias == BEARISH) ? BULLISH : BEARISH;
    for(int i = 0; i < g_tfOBCount; i++)
    {
        if(g_tfOBs[i].active && g_tfOBs[i].bias == targetBias)
        {
            return (targetBias == BULLISH) ? g_tfOBs[i].barLow : g_tfOBs[i].barHigh;
        }
    }
    return 0.0;
}


//=================================================================
// PROCESS ONE BAR
//=================================================================
void ProcessBar(const MqlRates &rates[], int totalRates,
                double atrVal, double atr200Val,
                bool printLog,
                bool &isChoch, bool &isBos, bool &isAtr,
                int barIdx)
{
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

    UpdateParsed(h, l, atr200Val, t, barIdx);

    nLoss = InpAtrKey * atrVal;
    UpdateATR(o, h, l, c, nLoss);

    UpdateTFStructure(rates, t, tfChochBull, tfChochBear, tfBosBull, tfBosBear, barIdx);

    // 1. Process CHOCH / BOS signals
    if(tfChochBull)
    {
        g_chochPending = true;
        g_chochPendingDirection = 1;
        g_chochPendingOBLevel = GetMostRecentOppositeOBLevel(1);
        g_tfTrendBiasConfirmed = false;
        if(g_chochPendingOBLevel == 0.0)
        {
            g_chochPending = false;
            g_tfTrendBias = BULLISH;
            g_tfTrendBiasConfirmed = true;
            g_currentBOSCount = 0;
            g_currentATRCount = 0;
            g_lastStructureType = 1; // CHOCH
            g_lastStructureDirection = 1; // Bullish
            g_lastStructureCount = 0;
            isChoch = true;
            if(printLog)
                Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] CHOCH Bullish XIN (Immediate) confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
            if(g_pendingChochLineObj != "" && ObjectFind(0, g_pendingChochLineObj) >= 0)
                ObjectSetInteger(0, g_pendingChochLineObj, OBJPROP_COLOR, C_GREEN);
            if(g_pendingChochTextObj != "" && ObjectFind(0, g_pendingChochTextObj) >= 0)
                ObjectSetInteger(0, g_pendingChochTextObj, OBJPROP_COLOR, C_GREEN);
            g_pendingChochLineObj = "";
            g_pendingChochTextObj = "";
        }
    }
    else if(tfChochBear)
    {
        g_chochPending = true;
        g_chochPendingDirection = -1;
        g_chochPendingOBLevel = GetMostRecentOppositeOBLevel(-1);
        g_tfTrendBiasConfirmed = false;
        if(g_chochPendingOBLevel == 0.0)
        {
            g_chochPending = false;
            g_tfTrendBias = BEARISH;
            g_tfTrendBiasConfirmed = true;
            g_currentBOSCount = 0;
            g_currentATRCount = 0;
            g_lastStructureType = 1; // CHOCH
            g_lastStructureDirection = -1; // Bearish
            g_lastStructureCount = 0;
            isChoch = true;
            if(printLog)
                Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] CHOCH Bearish XIN (Immediate) confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
            if(g_pendingChochLineObj != "" && ObjectFind(0, g_pendingChochLineObj) >= 0)
                ObjectSetInteger(0, g_pendingChochLineObj, OBJPROP_COLOR, C_RED);
            if(g_pendingChochTextObj != "" && ObjectFind(0, g_pendingChochTextObj) >= 0)
                ObjectSetInteger(0, g_pendingChochTextObj, OBJPROP_COLOR, C_RED);
            g_pendingChochLineObj = "";
            g_pendingChochTextObj = "";
        }
    }

    if(g_chochPending)
    {
        if(g_chochPendingDirection == 1) // Bullish
        {
            if(c > g_chochPendingOBLevel)
            {
                g_chochPending = false;
                g_tfTrendBias = BULLISH;
                g_tfTrendBiasConfirmed = true;
                g_currentBOSCount = 0;
                g_currentATRCount = 0;
                g_lastStructureType = 1; // CHOCH
                g_lastStructureDirection = 1; // Bullish
                g_lastStructureCount = 0;
                isChoch = true;
                if(printLog)
                    Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] CHOCH Bullish XIN confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));

                if(g_pendingChochLineObj != "" && ObjectFind(0, g_pendingChochLineObj) >= 0)
                    ObjectSetInteger(0, g_pendingChochLineObj, OBJPROP_COLOR, C_GREEN);
                if(g_pendingChochTextObj != "" && ObjectFind(0, g_pendingChochTextObj) >= 0)
                    ObjectSetInteger(0, g_pendingChochTextObj, OBJPROP_COLOR, C_GREEN);
                g_pendingChochLineObj = "";
                g_pendingChochTextObj = "";
            }
        }
        else if(g_chochPendingDirection == -1) // Bearish
        {
            if(c < g_chochPendingOBLevel)
            {
                g_chochPending = false;
                g_tfTrendBias = BEARISH;
                g_tfTrendBiasConfirmed = true;
                g_currentBOSCount = 0;
                g_currentATRCount = 0;
                g_lastStructureType = 1; // CHOCH
                g_lastStructureDirection = -1; // Bearish
                g_lastStructureCount = 0;
                isChoch = true;
                if(printLog)
                    Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] CHOCH Bearish XIN confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));

                if(g_pendingChochLineObj != "" && ObjectFind(0, g_pendingChochLineObj) >= 0)
                    ObjectSetInteger(0, g_pendingChochLineObj, OBJPROP_COLOR, C_RED);
                if(g_pendingChochTextObj != "" && ObjectFind(0, g_pendingChochTextObj) >= 0)
                    ObjectSetInteger(0, g_pendingChochTextObj, OBJPROP_COLOR, C_RED);
                g_pendingChochLineObj = "";
                g_pendingChochTextObj = "";
            }
        }
    }

    if(!g_chochPending && !g_tfTrendBiasConfirmed)
    {
        if(g_tfTrendBias == BULLISH)
        {
            if(c > g_chochPendingOBLevel && g_chochPendingOBLevel > 0)
            {
                g_tfTrendBiasConfirmed = true;
                g_currentBOSCount = 0;
                g_currentATRCount = 0;
                g_lastStructureType = 1; // CHOCH
                g_lastStructureDirection = 1; // Bullish
                g_lastStructureCount = 0;
                isChoch = true;
                
                if(printLog)
                    Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] Trend Bias BULLISH confirmed by breaking OB at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
                
                if(g_pendingChochLineObj != "" && ObjectFind(0, g_pendingChochLineObj) >= 0)
                    ObjectSetInteger(0, g_pendingChochLineObj, OBJPROP_COLOR, C_GREEN);
                if(g_pendingChochTextObj != "" && ObjectFind(0, g_pendingChochTextObj) >= 0)
                    ObjectSetInteger(0, g_pendingChochTextObj, OBJPROP_COLOR, C_GREEN);
                g_pendingChochLineObj = "";
                g_pendingChochTextObj = "";
            }
        }
        else if(g_tfTrendBias == BEARISH)
        {
            if(c < g_chochPendingOBLevel && g_chochPendingOBLevel > 0)
            {
                g_tfTrendBiasConfirmed = true;
                g_currentBOSCount = 0;
                g_currentATRCount = 0;
                g_lastStructureType = 1; // CHOCH
                g_lastStructureDirection = -1; // Bearish
                g_lastStructureCount = 0;
                isChoch = true;
                
                if(printLog)
                    Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] Trend Bias BEARISH confirmed by breaking OB at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
                
                if(g_pendingChochLineObj != "" && ObjectFind(0, g_pendingChochLineObj) >= 0)
                    ObjectSetInteger(0, g_pendingChochLineObj, OBJPROP_COLOR, C_RED);
                if(g_pendingChochTextObj != "" && ObjectFind(0, g_pendingChochTextObj) >= 0)
                    ObjectSetInteger(0, g_pendingChochTextObj, OBJPROP_COLOR, C_RED);
                g_pendingChochLineObj = "";
                g_pendingChochTextObj = "";
            }
        }
    }

    if(tfBosBull)
    {
        g_chochPending = false;
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
        g_chochPending = false;
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
        if(!g_chochPending)
        {
            g_currentATRCount++;
            isAtr = true;
            structStr = (g_lastStructureType == 1) ? "CHOCH Bullish" : ("BOS Bullish #" + IntegerToString(g_lastStructureCount));
            if(printLog)
                Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] ATR Bullish #", g_currentATRCount, " of ", structStr, " confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
        }
    }
    else if(g_tfTrendBias == BEARISH && g_atrSell)
    {
        if(!g_chochPending)
        {
            g_currentATRCount++;
            isAtr = true;
            structStr = (g_lastStructureType == 1) ? "CHOCH Bearish" : ("BOS Bearish #" + IntegerToString(g_lastStructureCount));
            if(printLog)
                Print("[XAUUSD ", Symbol(), " ", EnumToString((ENUM_TIMEFRAMES)Period()), "] ATR Bearish #", g_currentATRCount, " of ", structStr, " confirmed at ", TimeToString(t, TIME_DATE|TIME_MINUTES));
        }
    }

    g_tf_chochBull = isChoch && (g_lastStructureDirection == 1);
    g_tf_chochBear = isChoch && (g_lastStructureDirection == -1);
    g_tf_bosBull   = isBos && (g_lastStructureDirection == 1);
    g_tf_bosBear   = isBos && (g_lastStructureDirection == -1);

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
    SetIndexBuffer(0, g_atrStopBuf, INDICATOR_DATA);
    SetIndexBuffer(1, g_atrBuyBuf, INDICATOR_DATA);
    SetIndexBuffer(2, g_atrSellBuf, INDICATOR_DATA);
    SetIndexBuffer(3, g_chochBuf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(4, g_bosBuf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(5, g_atrSigBuf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(6, g_lastStructTypeBuf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, g_lastStructCountBuf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(8, g_atrCountBuf, INDICATOR_CALCULATIONS);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

    PlotIndexSetInteger(1, PLOT_ARROW, 233);
    PlotIndexSetInteger(2, PLOT_ARROW, 234);

    PlotIndexSetString(0, PLOT_LABEL, "ATR Stop");
    PlotIndexSetString(1, PLOT_LABEL, "ATR Buy");
    PlotIndexSetString(2, PLOT_LABEL, "ATR Sell");

    g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
    g_atr200Handle = iATR(_Symbol, PERIOD_CURRENT, 200);
    if(g_atrHandle == INVALID_HANDLE || g_atr200Handle == INVALID_HANDLE)
    {
        Print("ERROR: Cannot create ATR handles");
        return INIT_FAILED;
    }

    Print("XAUUSD PA Scalping Indicator M5 initialized.");
    return INIT_SUCCEEDED;
}

//=================================================================
// OnDeinit
//=================================================================
void OnDeinit(const int reason)
{
    DeleteAllObjects();
    Comment("");
    if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
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
    int minBars = MathMax(InpSwingLen, InpAtrPeriod) + 205;
    int i = 0, k = 0, s = 0, obK = 0;
    
    if(rates_total < minBars) return 0;

    int prevCalculated = prev_calculated;
    static int last_rates_total = 0;
    if(prevCalculated == 0 || last_rates_total == 0 || rates_total < last_rates_total || (rates_total - last_rates_total) > 2)
    {
        prevCalculated = 0;
    }
    last_rates_total = rates_total;

    // Copy full ATR buffers for MT5
    double atrBuf[], atr200Buf[];
    ArraySetAsSeries(atrBuf,    true);
    ArraySetAsSeries(atr200Buf, true);
    int nAtr    = CopyBuffer(g_atrHandle,    0, 0, rates_total, atrBuf);
    int nAtr200 = CopyBuffer(g_atr200Handle, 0, 0, rates_total, atr200Buf);

    ArrayResize(g_tfOBsHistory, rates_total);
    ArrayResize(g_currentBOSCountHistory, rates_total);
    ArrayResize(g_chochPendingHistory, rates_total);
    ArrayResize(g_chochPendingDirectionHistory, rates_total);
    ArrayResize(g_chochPendingOBLevelHistory, rates_total);
    ArrayResize(g_tfTrendBiasHistory, rates_total);
    ArrayResize(g_lastStructureTypeHistory, rates_total);
    ArrayResize(g_lastStructureDirectionHistory, rates_total);
    ArrayResize(g_lastStructureCountHistory, rates_total);
    ArrayResize(g_currentATRCountHistory, rates_total);
    ArrayResize(g_tfHighHistory, rates_total);
    ArrayResize(g_tfLowHistory, rates_total);
    ArrayResize(g_tfLegStateHistory, rates_total);
    ArrayResize(g_xATRStopHistory, rates_total);
    ArrayResize(g_srcPrice1History, rates_total);
    ArrayResize(g_haOpenHistory, rates_total);
    ArrayResize(g_haCloseHistory, rates_total);
    ArrayResize(g_stateHistory, rates_total);
    ArrayResize(g_biasHistory, rates_total);
    ArrayResize(g_bosSeenHistory, rates_total);
    ArrayResize(g_tfBosLimitHitHistory, rates_total);
    ArrayResize(g_chochAtrFiredHistory, rates_total);
    ArrayResize(g_tfSweepBullLevelHistory, rates_total);
    ArrayResize(g_tfSweepBearLevelHistory, rates_total);
    ArrayResize(g_cycleSLHistory, rates_total);
    ArrayResize(g_cycleSL_chochHistory, rates_total);
    ArrayResize(g_tfTrendBiasConfirmedHistory, rates_total);

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

    if(prevCalculated == 0)
    {
        DeleteAllObjects();

        g_state=0; g_bias=0;
        g_cycleSL=0; g_cycleSL_choch=0;
        g_bosSeen=false;
        g_tfBosCount=0; g_tfBosLimitHit=false; g_chochAtrFired=false;
        g_tfSweepBullLevel=0; g_tfSweepBearLevel=0;
        g_tfOBCount=0;
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
        
        g_chochPending = false;
        g_chochPendingDirection = 0;
        g_chochPendingOBLevel = 0.0;
        g_tfTrendBiasConfirmed = false;

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
        ArrayInitialize(g_obTimes,     0);
    }

    int start = (prevCalculated == 0) ? MathMax(InpAtrPeriod + 1, rates_total - 5000) : MathMax(0, prevCalculated - 1);
    int lookback = MathMax(InpSwingLen, InpAtrPeriod) + 5;

    ArrayResize(g_parsedHighs, rates_total);
    ArrayResize(g_parsedLows,  rates_total);
    ArrayResize(g_actualHighs, rates_total);
    ArrayResize(g_actualLows,  rates_total);
    ArrayResize(g_obTimes,     rates_total);

    for(i = start; i < rates_total - 1; i++)
    {
        if(i > 0)
        {
            g_currentBOSCount = g_currentBOSCountHistory[i-1];
            g_chochPending = g_chochPendingHistory[i-1];
            g_chochPendingDirection = g_chochPendingDirectionHistory[i-1];
            g_chochPendingOBLevel = g_chochPendingOBLevelHistory[i-1];
            g_tfTrendBias = g_tfTrendBiasHistory[i-1];
            g_tfTrendBiasConfirmed = g_tfTrendBiasConfirmedHistory[i-1];
            g_lastStructureType = g_lastStructureTypeHistory[i-1];
            g_lastStructureDirection = g_lastStructureDirectionHistory[i-1];
            g_lastStructureCount = g_lastStructureCountHistory[i-1];
            g_currentATRCount = g_currentATRCountHistory[i-1];
            g_tfHigh = g_tfHighHistory[i-1];
            g_tfLow = g_tfLowHistory[i-1];
            g_tfLegState = g_tfLegStateHistory[i-1];
            g_xATRStop = g_xATRStopHistory[i-1];
            g_srcPrice1 = g_srcPrice1History[i-1];
            g_haOpen = g_haOpenHistory[i-1];
            g_haClose = g_haCloseHistory[i-1];
            g_state = g_stateHistory[i-1];
            g_bias = g_biasHistory[i-1];
            g_bosSeen = g_bosSeenHistory[i-1];
            g_tfBosLimitHit = g_tfBosLimitHitHistory[i-1];
            g_chochAtrFired = g_chochAtrFiredHistory[i-1];
            g_tfSweepBullLevel = g_tfSweepBullLevelHistory[i-1];
            g_tfSweepBearLevel = g_tfSweepBearLevelHistory[i-1];
            g_cycleSL = g_cycleSLHistory[i-1];
            g_cycleSL_choch = g_cycleSL_chochHistory[i-1];
            g_tfOBCount = g_tfOBsHistory[i-1].count;
            for(obK = 0; obK < 100; obK++)
            {
                g_tfOBs[obK] = g_tfOBsHistory[i-1].ob[obK];
            }
        }
        else
        {
            g_currentBOSCount = 0;
            g_chochPending = false;
            g_chochPendingDirection = 0;
            g_chochPendingOBLevel = 0.0;
            g_tfTrendBiasConfirmed = false;
            g_tfTrendBias = 0;
            g_lastStructureType = 0;
            g_lastStructureDirection = 0;
            g_lastStructureCount = 0;
            g_currentATRCount = 0;
            g_tfHigh.currentLevel = 0; g_tfHigh.lastLevel = 0; g_tfHigh.crossed = false; g_tfHigh.barTime = 0; g_tfHigh.barIndex = 0;
            g_tfLow.currentLevel = 0;  g_tfLow.lastLevel = 0;  g_tfLow.crossed = false;  g_tfLow.barTime = 0;  g_tfLow.barIndex = 0;
            g_tfLegState = BEARISH_LEG;
            g_xATRStop = 0;
            g_srcPrice1 = 0;
            g_haOpen = 0;
            g_haClose = 0;
            g_state = 0;
            g_bias = 0;
            g_bosSeen = false;
            g_tfBosLimitHit = false;
            g_chochAtrFired = false;
            g_tfSweepBullLevel = 0.0;
            g_tfSweepBearLevel = 0.0;
            g_cycleSL = 0.0;
            g_cycleSL_choch = 0.0;
            g_tfOBCount = 0;
            for(obK = 0; obK < 100; obK++)
            {
                g_tfOBs[obK].barHigh = 0;
                g_tfOBs[obK].barLow = 0;
                g_tfOBs[obK].barTime = 0;
                g_tfOBs[obK].bias = 0;
                g_tfOBs[obK].active = false;
                g_tfOBs[obK].boxName = "";
            }
        }

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
        double atrVal    = (shift < nAtr    && nAtr    > 0) ? atrBuf[shift]    : 0.0;
        double atr200Val = (shift < nAtr200 && nAtr200 > 0) ? atr200Buf[shift] : 0.0;

        bool isChoch = false;
        bool isBos = false;
        bool isAtr = false;

        ProcessBar(rates, avail, atrVal, atr200Val, (i >= rates_total - 3), isChoch, isBos, isAtr, i);

        g_atrStopBuf[i]  = g_xATRStop;
        g_atrBuyBuf[i]   = (g_atrBuy  && InpShowATRSignal) ? low[i]  - atrVal * 0.5 : 0.0;
        g_atrSellBuf[i]  = (g_atrSell && InpShowATRSignal) ? high[i] + atrVal * 0.5 : 0.0;
        
        g_chochBuf[i]            = (isChoch) ? (double)g_lastStructureDirection : (g_chochPending ? (double)g_chochPendingDirection * 0.5 : 0.0);
        g_bosBuf[i]              = (isBos)   ? (double)(g_lastStructureDirection * g_currentBOSCount) : 0.0;
        g_atrSigBuf[i]           = (isAtr)   ? (double)(g_lastStructureDirection * g_currentATRCount) : 0.0;
        g_lastStructTypeBuf[i]   = (double)g_lastStructureType;
        g_lastStructCountBuf[i]  = !g_tfTrendBiasConfirmed ? 99.0 : (double)g_lastStructureCount;
        g_atrCountBuf[i]         = (double)g_currentATRCount;

        g_currentBOSCountHistory[i] = g_currentBOSCount;
        g_chochPendingHistory[i] = g_chochPending;
        g_chochPendingDirectionHistory[i] = g_chochPendingDirection;
        g_chochPendingOBLevelHistory[i] = g_chochPendingOBLevel;
        g_tfTrendBiasHistory[i] = g_tfTrendBias;
        g_tfTrendBiasConfirmedHistory[i] = g_tfTrendBiasConfirmed;
        g_lastStructureTypeHistory[i] = g_lastStructureType;
        g_lastStructureDirectionHistory[i] = g_lastStructureDirection;
        g_lastStructureCountHistory[i] = g_lastStructureCount;
        g_currentATRCountHistory[i] = g_currentATRCount;
        g_tfHighHistory[i] = g_tfHigh;
        g_tfLowHistory[i] = g_tfLow;
        g_tfLegStateHistory[i] = g_tfLegState;
        g_xATRStopHistory[i] = g_xATRStop;
        g_srcPrice1History[i] = g_srcPrice1;
        g_haOpenHistory[i] = g_haOpen;
        g_haCloseHistory[i] = g_haClose;
        g_stateHistory[i] = g_state;
        g_biasHistory[i] = g_bias;
        g_bosSeenHistory[i] = g_bosSeen;
        g_tfBosLimitHitHistory[i] = g_tfBosLimitHit;
        g_chochAtrFiredHistory[i] = g_chochAtrFired;
        g_tfSweepBullLevelHistory[i] = g_tfSweepBullLevel;
        g_tfSweepBearLevelHistory[i] = g_tfSweepBearLevel;
        g_cycleSLHistory[i] = g_cycleSL;
        g_cycleSL_chochHistory[i] = g_cycleSL_choch;
        g_tfOBsHistory[i].count = g_tfOBCount;
        for(obK = 0; obK < 100; obK++)
        {
            g_tfOBsHistory[i].ob[obK] = g_tfOBs[obK];
        }
    }

    UpdateInfoTable();
    ChartRedraw(0);

    return rates_total;
}
