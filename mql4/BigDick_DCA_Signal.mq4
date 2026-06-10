//+------------------------------------------------------------------+
//|                                                       Farmer.mq4 |
//|                                                    Trung đẹp zai |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#define OP_BUYSELL 999

enum modetrade
  {
   ONLY_BUY = 1,  // BUY
   ONLY_SELL = 2, // SELL
   BUY_AND_SELL = 3,       // BUY & SELL
  };

enum tradingType
  {
   SECOND = 1,  // Vao Lenh Mac Dinh
   CANDLE = 2,  // Vao Lenh Theo Nen Xanh Do
  };  
  
enum boolType
  {
   TRUE_VAL = 1,  // true
   FALSE_VAL = 2, // false
  };  

extern int MagicNumber = 179092;                                     // Magic Number

extern string ________AUTO_ENTRY________ = "============== AUTO ENTRY ==============";
extern bool EnableAutoEntry = true;                                  // Tu Dong Vao Lenh L1
extern bool EnableChochEntry = true;                                 // Cho Phep Vao Lenh CHOCH Xac Nhan
extern string IndicatorM1Name = "Scapling_Indicator_M1";             // Indicator M1
extern string IndicatorM5Name = "Scapling_Indicator_M5";             // Indicator M5
extern int M5TrendMaxBars = 1000;                                    // So Nen Toi Da Quet Xu Huong M5
extern int M1TrendMaxBars = 500;                                    // So Nen Toi Da Quet Xu Huong M1

extern string ________INDICATOR_SETTINGS________ = "=========== INDICATOR SETTINGS ===========";
extern int             InpSwingLen    = 5;          // Swing Length (TF hien tai)
extern bool            InpOBMitigClose   = true;    // OB Mitigation = Close (false = High/Low)
extern int             InpObCount        = 5;       // So OB TF Hien Tai De Hien Thi
extern double          InpAtrKey    = 1.0;          // ATR Key Value
extern int             InpAtrPeriod = 10;           // ATR Period
extern bool            InpUseHA     = false;        // Dung Heikin Ashi
extern bool            InpEnableTimeFilter = true;  // Bat Loc Khung Gio
extern string          InpTZ  = "UTC+7";            // Timezone
extern bool            InpEnS1 = true;              // London
extern string          InpS1   = "1515-1815";       // London session
extern bool            InpEnS2 = true;              // New York
extern string          InpS2   = "2030-0045";       // New York session
extern bool            InpEnS3 = true;              // Phien A
extern string          InpS3   = "0730-0900";       // Phien A session
extern bool            InpEnS4 = true;              // Tuy Chinh
extern string          InpS4   = "1030-1315";       // Tuy Chinh session
extern bool            InpShowTFStruct   = true;    // Hien CHoCH/BOS TF Hien Tai
extern bool            InpShowTFOBs      = true;    // Hien OB TF Hien Tai
extern bool            InpShowATRSignal  = true;    // Hien ATR Confirm signals
extern bool            InpShowSessionBox = false;   // Ve box phien


datetime lastBuyTime = 0;
datetime lastSellTime = 0;


extern string ________GENERAL________ = "============== GENERAL ==============";  
extern double lotsize = 0.1;                                         // Lot Size
extern double pipsDiff = 250;                                        // Khoang Cach Vao Lenh (Pips)
extern double multiple = 1.05;                                       // He So Nhan Lot
extern double multipleDiff = 1.4;                                    // He So Khoang Cach
extern double pipFirstTP = 230;                                      // TP Lenh Dau Tien (Pips)
extern double pipTP = 230;                                           // TP Chuoi Tu Lenh 2 Tro Di (Pips)
extern double pipSL = 0;                                             // SL Chuoi Tinh Tu Lenh Cuoi Cung (Pips)
extern double inpBE_Extra = 0.5;                                     // BE Extra Profit (Pips)

extern string ________LOTSIZE_SETTINGS________ = "============== AUTO LOTSIZE ==============";
extern bool autoLotsize = true;                                     // Tu Dong Tinh LotSize Theo Balance
extern int lotsizePercentBasedOnBalance = 8;                         // % Lotsize Theo Balance

extern string ________GRID_SETTINGS________ = "============== SETTINGS DCA ==============";
extern int maxOrderBUY = 5;                                          // So Lenh BUY Toi Da
extern int maxOrderSELL = 5;                                         // So Lenh SELL Toi Da
extern int delayTime = 3;                                            // Khoang gian dung giua 2 lenh (Tính theo giay)

extern string ________BUTTONS________ = "===== SETTING BUTTONS =====";
extern bool confirmClose = false;                 // Hoi Lai Khi Click Close Buttons
extern bool showHedgeBtn = true;                 // Hien Thi Button Hedge
extern bool showCloseBtn = true;                  // Hien Thi Button Close All

// ---- Button
string Font_Type = "Arial Bold";
color Font_Color = clrWhite;
int Font_Size = 10;
// ---- Button

string cmt = "BigDick - DCA: ";

bool openOrder = true;
double p0w, currentLots;

// TotalOrder
int totalOrder, totalOrdBuy, totalOrdSell;
double totalProfit;
int countOrd;

// GetHigh_LowPrice()
double higPriceBuy, higPriceSell, lowPriceSell, lowPriceBuy;
double recentBuy, recentSell;
int tckLowSell, tckHigBuy;
double comSell, swapSell, lotsSell, profitSell, totalProfitSell;
double totalProfitBuy, profitBuy, comBuy, swapBuy, lotsBuy;

double totalLotsBuy, totalLotsSell;

double accountBalance, accountEnquity;

double baseLotsize = 0;

// Global variables
double pipSize;
int dig;

// GetNormalLotUnit()
int normalLotUnit = 2;

datetime trial_end_date = D'10.12.2024';

int OnInit()
  {
//---
   if (checkActivation() == 1) {
      CreateButtons();
   } else {
      Draw("notif", "EA da het han su dung. Vui long lien he: https://t.me/gnurt28 | +84782390668", 12, "Calibri Bold", clrYellow, 4, 20, 20);
   }
   
   dig = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if (dig == 3 || dig == 5) pipSize = 10 * _Point;
   else pipSize = _Point;
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   ObjectsDeleteAll();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   GetHigh_LowPrice();
   showInfo();
   
   doAction();
}
//+------------------------------------------------------------------+

int checkActivation()
{
   return (1);
   if(TimeCurrent() > trial_end_date)
   {
       Alert("EA Da Het Han! Vui Long Lien He Chu Nhan EA!");
       ExpertRemove();
       
       return (-1);
   }
   
   return (1);
} // End void checkActivation()

double GetM1IndicatorValue(int buffer, int shift)
{
   return iCustom(Symbol(), PERIOD_M1, IndicatorM1Name,
                  InpSwingLen, InpOBMitigClose, InpObCount,
                  InpAtrKey, InpAtrPeriod, InpUseHA,
                  InpEnableTimeFilter, InpTZ,
                  InpEnS1, InpS1, InpEnS2, InpS2, InpEnS3, InpS3, InpEnS4, InpS4,
                  InpShowTFStruct, InpShowTFOBs, InpShowATRSignal, InpShowSessionBox,
                  buffer, shift);
}

double GetM5IndicatorValue(int buffer, int shift)
{
   return iCustom(Symbol(), PERIOD_M5, IndicatorM5Name,
                  InpSwingLen, InpOBMitigClose, InpObCount,
                  InpAtrKey, InpAtrPeriod, InpUseHA,
                  InpEnableTimeFilter, InpTZ,
                  InpEnS1, InpS1, InpEnS2, InpS2, InpEnS3, InpS3, InpEnS4, InpS4,
                  InpShowTFStruct, InpShowTFOBs, InpShowATRSignal, InpShowSessionBox,
                  buffer, shift);
}

int GetM5TrendBias()
{
   for(int i = 1; i < M5TrendMaxBars; i++)
   {
      double choch = GetM5IndicatorValue(3, i);
      double bos   = GetM5IndicatorValue(4, i);
      if(choch != 0.0) return (choch > 0.0) ? 1 : -1;
      if(bos != 0.0)   return (bos > 0.0)   ? 1 : -1;
   }
   return 0;
}

int GetM1TrendDirection()
{
   for(int i = 1; i < M1TrendMaxBars; i++)
   {
      double choch = GetM1IndicatorValue(3, i);
      double bos   = GetM1IndicatorValue(4, i);
      if(choch != 0.0) return (choch > 0.0) ? 1 : -1;
      if(bos != 0.0)   return (bos > 0.0)   ? 1 : -1;
   }
   return 0;
}

datetime GetM5LastChochTime(int direction)
{
   for(int i = 1; i < M5TrendMaxBars; i++)
   {
      double m5_choch = GetM5IndicatorValue(3, i);
      if(m5_choch == (double)direction) 
      {
         return iTime(Symbol(), PERIOD_M5, i);
      }
   }
   return 0;
}

bool WasM1AlreadyInDirectionBefore(datetime t_m5, int direction)
{
   for(int j = 1; j < M1TrendMaxBars; j++)
   {
      datetime t_m1 = iTime(Symbol(), PERIOD_M1, j);
      if(t_m1 < t_m5)
      {
         double m1_choch = GetM1IndicatorValue(3, j);
         double m1_bos   = GetM1IndicatorValue(4, j);
         if(m1_choch == (double)direction || (direction == 1 && m1_bos > 0.0) || (direction == -1 && m1_bos < 0.0))
         {
            return true;
         }
         if(m1_choch == (double)(-direction) || (direction == 1 && m1_bos < 0.0) || (direction == -1 && m1_bos > 0.0))
         {
            return false;
         }
      }
   }
   return false;
}

bool HasM1FlippedAndReturned(datetime t_m5, int target_direction)
{
   int start_j = iBarShift(Symbol(), PERIOD_M1, t_m5, true);
   if(start_j < 0) return false;
   
   bool found_opposite = false;
   bool returned_to_target = false;
   
   for(int j = start_j; j >= 1; j--)
   {
      double m1_choch = GetM1IndicatorValue(3, j);
      if(target_direction == -1) // target Bearish, opposite is Bullish
      {
         if(m1_choch == 0.5 || m1_choch == 1.0)
            found_opposite = true;
         if(found_opposite && m1_choch == -1.0)
            returned_to_target = true;
      }
      else // target Bullish, opposite is Bearish
      {
         if(m1_choch == -0.5 || m1_choch == -1.0)
            found_opposite = true;
         if(found_opposite && m1_choch == 1.0)
            returned_to_target = true;
      }
   }
   return returned_to_target;
}

int GetTargetTZOffsetHours(string tz)
{
    int plusPos  = StringFind(tz, "+");
    int minusPos = StringFind(tz, "-", 3);
    string rest = "";
    int h = 0;
    
    if(plusPos >= 0)
    {
        rest = StringSubstr(tz, plusPos + 1);
        int colonPos = StringFind(rest, ":");
        if(colonPos >= 0)
            h = (int)StringToInteger(StringSubstr(rest, 0, colonPos));
        else
            h = (int)StringToInteger(rest);
        return h;
    }
    else if(minusPos >= 0)
    {
        rest = StringSubstr(tz, minusPos + 1);
        int colonPos = StringFind(rest, ":");
        if(colonPos >= 0)
            h = (int)StringToInteger(StringSubstr(rest, 0, colonPos));
        else
            h = (int)StringToInteger(rest);
        return -h;
    }
    return 7; // Default to GMT+7 if parsing fails
}

datetime ConvertServerToTargetTZ(datetime serverTime)
{
   datetime gmt = TimeGMT();
   int serverOffset = (int)TimeCurrent() - (int)gmt;
   int serverOffsetHours = (int)MathRound((double)serverOffset / 3600.0);
   int targetTZHours = GetTargetTZOffsetHours(InpTZ);
   int diffHours = targetTZHours - serverOffsetHours;
   return serverTime + diffHours * 3600;
}

bool InSessionAt(datetime targetTZTime, bool en, string sess)
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

    MqlDateTime dt;
    TimeToStruct(targetTZTime, dt);
    int nowMin   = dt.hour * 60 + dt.min;
    int startMin = startH * 60 + startM;
    int endMin   = endH   * 60 + endM;

    if(startMin <= endMin)
        return (nowMin >= startMin && nowMin < endMin);
    else
        return (nowMin >= startMin || nowMin < endMin);
}

bool SessionOKAt(datetime serverTime)
{
    if(!InpEnableTimeFilter) return true;
    datetime targetTime = ConvertServerToTargetTZ(serverTime);
    return InSessionAt(targetTime, InpEnS1, InpS1) ||
           InSessionAt(targetTime, InpEnS2, InpS2) ||
           InSessionAt(targetTime, InpEnS3, InpS3) ||
           InSessionAt(targetTime, InpEnS4, InpS4);
}

void checkAutoEntry()
{
   if (totalOrdSell == 0 && totalOrdBuy == 0)
   {
      // Check Sell L1 Trigger
      int m5_bias = GetM5TrendBias();
      double m5_last_count = GetM5IndicatorValue(7, 1);
      
      if (m5_bias == -1 && m5_last_count <= 2.0)
      {
         bool m1_flip_ok = true;
         datetime t_m5 = GetM5LastChochTime(-1);
         if(t_m5 > 0)
         {
            if(WasM1AlreadyInDirectionBefore(t_m5, -1))
            {
               m1_flip_ok = HasM1FlippedAndReturned(t_m5, -1);
            }
         }

         if(m1_flip_ok)
         {
            double m1_choch = GetM1IndicatorValue(3, 1);
            double m1_atr   = GetM1IndicatorValue(5, 1);
            double m1_last_count = GetM1IndicatorValue(7, 1);
            double m1_atr_count = GetM1IndicatorValue(8, 1);
            
            bool sell_signal = false;
            
            // Trigger 1: CHOCH Bearish on M1
            if (EnableChochEntry && m1_choch == -1.0)
            {
               sell_signal = true;
            }
            // Trigger 2 & 3: ATR Bearish #1 after CHOCH or BOS 1 on M1
            else if (GetM1TrendDirection() == -1 && m1_last_count <= 1.0 && m1_atr == -1.0 && m1_atr_count == 1.0)
            {
               sell_signal = true;
            }
            
            if (sell_signal)
            {
               datetime m1_bar_time = iTime(Symbol(), PERIOD_M1, 1);
               if (lastSellTime != m1_bar_time)
               {
                  if (!SessionOKAt(TimeCurrent()))
                  {
                     datetime targetTime = ConvertServerToTargetTZ(TimeCurrent());
                     Print("[AutoEntry] SELL L1 signal detected at server time ", TimeToString(TimeCurrent()), " (", InpTZ, ": ", TimeToString(targetTime), ") but BLOCKED by Time Filter.");
                     lastSellTime = m1_bar_time; // Avoid spamming
                  }
                  else
                  {
                     double price = MarketInfo(Symbol(), MODE_BID);
                     double tp = price - (pipFirstTP * 10 * MarketInfo(Symbol(), MODE_POINT));
                     double sl = (pipSL == 0) ? 0 : (price + (pipSL * 10 * MarketInfo(Symbol(), MODE_POINT)));
                     string cm = cmt + "SELL-1";
                     
                     int ticket = openOrd(ORDER_TYPE_SELL, price, sl, tp, cm, 1, baseLotsize);
                     if (ticket > 0)
                     {
                        lastSellTime = m1_bar_time;
                        Print("[AutoEntry] SELL L1 entered at price: ", price, " M5 Trend: Bear, M1 Signal Bar Time: ", TimeToString(m1_bar_time));
                     }
                  }
               }
            }
         }
      }

      // Check Buy L1 Trigger
      int m5_bias_buy = GetM5TrendBias();
      double m5_last_count_buy = GetM5IndicatorValue(7, 1);
      
      if (m5_bias_buy == 1 && m5_last_count_buy <= 2.0)
      {
         bool m1_flip_ok = true;
         datetime t_m5 = GetM5LastChochTime(1);
         if(t_m5 > 0)
         {
            if(WasM1AlreadyInDirectionBefore(t_m5, 1))
            {
               m1_flip_ok = HasM1FlippedAndReturned(t_m5, 1);
            }
         }

         if(m1_flip_ok)
         {
            double m1_choch = GetM1IndicatorValue(3, 1);
            double m1_atr   = GetM1IndicatorValue(5, 1);
            double m1_last_count = GetM1IndicatorValue(7, 1);
            double m1_atr_count = GetM1IndicatorValue(8, 1);
            
            bool buy_signal = false;
            
            // Trigger 1: CHOCH Bullish on M1
            if (EnableChochEntry && m1_choch == 1.0)
            {
               buy_signal = true;
            }
            // Trigger 2 & 3: ATR Bullish #1 after CHOCH or BOS 1 on M1
            else if (GetM1TrendDirection() == 1 && m1_last_count <= 1.0 && m1_atr == 1.0 && m1_atr_count == 1.0)
            {
               buy_signal = true;
            }
            
            if (buy_signal)
            {
               datetime m1_bar_time = iTime(Symbol(), PERIOD_M1, 1);
               if (lastBuyTime != m1_bar_time)
               {
                  if (!SessionOKAt(TimeCurrent()))
                  {
                     datetime targetTime = ConvertServerToTargetTZ(TimeCurrent());
                     Print("[AutoEntry] BUY L1 signal detected at server time ", TimeToString(TimeCurrent()), " (", InpTZ, ": ", TimeToString(targetTime), ") but BLOCKED by Time Filter.");
                     lastBuyTime = m1_bar_time; // Avoid spamming
                  }
                  else
                  {
                     double price = MarketInfo(Symbol(), MODE_ASK);
                     double tp = price + (pipFirstTP * 10 * MarketInfo(Symbol(), MODE_POINT));
                     double sl = (pipSL == 0) ? 0 : (price - (pipSL * 10 * MarketInfo(Symbol(), MODE_POINT)));
                     string cm = cmt + "BUY-1";
                     
                     int ticket = openOrd(ORDER_TYPE_BUY, price, sl, tp, cm, 1, baseLotsize);
                     if (ticket > 0)
                     {
                        lastBuyTime = m1_bar_time;
                        Print("[AutoEntry] BUY L1 entered at price: ", price, " M5 Trend: Bull, M1 Signal Bar Time: ", TimeToString(m1_bar_time));
                     }
                  }
               }
            }
         }
      }
   }
}

void doAction ()
{
   if (EnableAutoEntry)
   {
      checkAutoEntry();
   }
   doActionBuy();
   doActionSell();
   
}// End void doAction()

void doActionBuy()
{
   // Lenh L2-n
   if (totalOrdBuy != 0 && totalOrdBuy < maxOrderBUY)
   {
      // Check buy order
      double price = MarketInfo(Symbol(), MODE_ASK);
      double tp = price + (pipFirstTP * 10 * MarketInfo(Symbol(), MODE_POINT));
      double sl = price - (pipSL * 10 * MarketInfo(Symbol(), MODE_POINT));
      
      if (pipSL == 0) 
      {
         sl = 0;
      }
      string cm = cmt + "BUY-" + (totalOrdBuy + 1);
   
      double buyPipsDiff = GetPipsDiff(ORDER_TYPE_BUY, multipleDiff, pipsDiff);
      if (lowPriceBuy - price >= buyPipsDiff*10*MarketInfo(Symbol(), MODE_POINT))
      {
         int tmp = openOrd (ORDER_TYPE_BUY, price, sl, tp, cm, multiple, baseLotsize);
         if (tmp > 0) {
            // Modify SL - TP
            double BE_Buy = breakeven(Symbol(), ORDER_TYPE_BUY, MagicNumber, baseLotsize);
            double buyAllTP = (BE_Buy + pipTP*10*MarketInfo(Symbol(), MODE_POINT));
            modifyTP (Symbol(), ORDER_TYPE_BUY, buyAllTP, sl);
         }
         
         Sleep(delayTime*1000);
      }
   }
}

void doActionSell()
{
   // Lenh L2-n
   if (totalOrdSell != 0 && totalOrdSell < maxOrderSELL)
   {
      // Check Sell order
      double price = MarketInfo(Symbol(), MODE_BID);
      double tp = price - (pipFirstTP * 10 * MarketInfo(Symbol(), MODE_POINT));
      double sl = price + (pipSL * 10 * MarketInfo(Symbol(), MODE_POINT));
      
      if (pipSL == 0) 
      {
         sl = 0;
      }
      string cm = cmt + "SELL-" + (totalOrdSell + 1);
      
      double sellPipsDiff = GetPipsDiff(ORDER_TYPE_SELL, multipleDiff, pipsDiff);
      if (price - higPriceSell > sellPipsDiff*10*MarketInfo(Symbol(), MODE_POINT))
      {
         int tmp = openOrd (ORDER_TYPE_SELL, price, sl, tp, cm, multiple, baseLotsize);
         if (tmp > 0) {
            // Modify SL - TP
            double BE_Sell = breakeven(Symbol(), ORDER_TYPE_SELL, MagicNumber, baseLotsize);
            double sellAllTP = (BE_Sell - pipTP*10*MarketInfo(Symbol(), MODE_POINT));
            modifyTP (Symbol(), ORDER_TYPE_SELL, sellAllTP, sl);
         }
         
         Sleep(delayTime*1000);
      }
   }
}

int openOrd ( int oP, double entry, double sL, double tP, string cm, double multi, double lot)
{
   GetValLot (oP, multi, lot);
   string col;
   if (oP == OP_BUY)
   {
      col = DoubleToStr(clrGreen, 0);
   }
   else if (oP == OP_SELL)
   {
      col = DoubleToStr(clrRed, 0);
   }
   if ( openOrder == true)
   {
      int tk = OrderSend(Symbol(), oP, currentLots, entry, 5, sL, tP, cm, MagicNumber, 0, StringToColor(col));
      if (tk <= 0) { 
         Print("Error Open Order DCA " + DoubleToStr(oP,0) + " : ",GetLastError());
         
         return (0);
      }
   }
   
   return (1);
}// End int openOrd()

void modifyTP(string symbol, int oP, double tp, double sl)
{
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (!OrderSelect(i,SELECT_BY_POS, MODE_TRADES)) { continue;}
      if (OrderSymbol() != symbol) { continue;}
      if (OrderMagicNumber() != MagicNumber) { continue;}
      
      if (OrderType() == oP) { 
         // Modify TP nhung lenh truoc do
         int tk = OrderModify(OrderTicket(), OrderOpenPrice(), sl, tp, 0, clrAliceBlue);
         if (tk <= 0) { Print("Error Modify Order DCA " + DoubleToStr(oP,0) + " : ",GetLastError());}
      }
   }
}// End void modifyTP()

double breakeven(string symBE, int bTyp, int mNumber, double addLot)
{
   double equity = 0, lots = 0;
   int cnt = OrdersTotal(),   size = 0, ind = 0;
   for (int i=0; i<cnt; i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if ( OrderMagicNumber() != MagicNumber)   {  continue;   }
      int oType = OrderType();
      if (oType != OP_BUY && oType != OP_SELL) continue;
      if(OrderSymbol() == symBE) 
      {
         if (bTyp == OP_SELL) 
         {  if (oType == OP_SELL) 
            {  equity += OrderProfit() + OrderCommission() + OrderSwap();  lots -= OrderLots();  } }
         else if (bTyp == OP_BUY) 
         {  if (oType == OP_BUY) 
            {  equity += OrderProfit() + OrderCommission() + OrderSwap();  lots += OrderLots(); }  }
         else if(bTyp == OP_BUYSELL) 
         {  equity += OrderProfit() + OrderCommission() + OrderSwap();  if (oType == OP_BUY) lots += OrderLots(); if (oType == OP_SELL) lots -= OrderLots();   }
      }
   }
   double curPrice = bTyp == OP_SELL  ? MarketInfo(symBE, MODE_ASK) : MarketInfo(symBE, MODE_BID);
   double bre = 0;
   if (lots == 0) {  bre = 0; }
   else 
   {  double COP = lots*MarketInfo(symBE, MODE_TICKVALUE);  double val = curPrice - MarketInfo(Symbol(),MODE_POINT)*equity/COP;  bre = NormalizeDouble(val, _Digits);   }
   return bre;
} //End double breakeven()

void CalculateLotsizeBasedOnBalance()
{
   if (autoLotsize) 
   {
      // Chi tinh lai base lot khi khong co order nao
      if (baseLotsize == 0 || totalOrder == 0) 
      {
         GetNormalLotUnit();
         double tmpLotsize = (accountBalance / 100000) * lotsizePercentBasedOnBalance;
         
         baseLotsize = NormalizeDouble(tmpLotsize, normalLotUnit);
      }
   } 
   else {
      baseLotsize = lotsize;
   }
}

double GetPipsDiff(int oP, double Multi, double diff)
{
   if (oP == OP_BUY)
   {
      p0w = totalOrdBuy;
   }
   else if ( oP == OP_SELL)
   {
      p0w = totalOrdSell;
   }
   
   GetNormalLotUnit();
   
   // Neu la lenh thu 2 thi khong x khoang cach
   if (p0w < 2) 
   {
      return diff;
   }
   
   int tmpp0w = p0w - 1;
   double pDiff = diff * MathPow(Multi, tmpp0w);
   
   return NormalizeDouble(pDiff, normalLotUnit);
}

void GetValLot(int oP, double Multi, double fixLots)
{
   if (oP == OP_BUY)
   {
      p0w = totalOrdBuy;
   }
   else if ( oP == OP_SELL)
   {
      p0w = totalOrdSell;
   }
   
   GetNormalLotUnit();
   
   double orderLot = fixLots * MathPow(Multi, p0w);
   
   if (orderLot <= 0) {
      orderLot = MarketInfo(Symbol(), MODE_MINLOT);
   }
   
   if (orderLot < MarketInfo(Symbol(), MODE_MINLOT)) {
      orderLot = MarketInfo(Symbol(), MODE_MINLOT);
   }
   
   if (orderLot > MarketInfo(Symbol(), MODE_MAXLOT)) {
      orderLot = MarketInfo(Symbol(), MODE_MAXLOT);
   }
   
   currentLots = NormalizeDouble(orderLot, normalLotUnit);
} // End void GetValLot()

void GetNormalLotUnit()
{
   if(MarketInfo(Symbol(), MODE_MINLOT)== 0.01)
   {
      normalLotUnit = 2;
   }
   if(MarketInfo(Symbol(), MODE_MINLOT)== 0.1)
   {
      normalLotUnit = 1;
   }
   if(MarketInfo(Symbol(), MODE_MINLOT)== 0.001)
   {
      normalLotUnit = 3;
   }
}// End void GetNormalLotUnit()

void GetHigh_LowPrice()
{  
   higPriceBuy = 0;
   higPriceSell = 0;
   lowPriceBuy = 0;
   lowPriceSell = 0;
   recentBuy = 0;
   recentSell = 0;
   totalProfitSell = 0;
   totalProfitBuy = 0;
   double tckSell = 0, tckBuy = 0;
   
   totalOrder = 0;
   totalOrdBuy = 0;
   totalOrdSell = 0;
   double profit = 0, swap = 0;
   
   totalLotsBuy = 0;
   totalLotsSell = 0;
   
   accountBalance = AccountBalance();
   accountEnquity = AccountEquity();
   
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) { continue;}
      if (OrderSymbol() != Symbol()) { continue;}
      if (OrderMagicNumber() != MagicNumber) { continue;}
      
      // Total order
      totalOrder ++; 
      profit += OrderProfit();
      swap += OrderSwap();
            
      if (OrderType() == OP_SELL)
      {
         // Total order SELL
         totalOrdSell++;
         totalLotsSell += OrderLots();
         
         if (OrderOpenPrice() > higPriceSell || higPriceSell == 0)
         {
            higPriceSell = OrderOpenPrice();
         }
         if ( OrderOpenPrice() < lowPriceSell || lowPriceSell == 0)
         {
            lowPriceSell = OrderOpenPrice();
            tckLowSell = OrderTicket();
            profitSell = OrderProfit();
            comSell = OrderCommission();
            swapSell = OrderSwap();
            lotsSell = OrderLots();
            
            totalProfitSell += profitSell;
         }
         if ( OrderTicket() > tckSell)
         {
            tckSell = OrderTicket();
            recentSell = OrderOpenPrice();
         }
        
      } // End if (OrderType() == OP_BUY)
      if ( OrderType() == OP_BUY )
      {
         // Total order BUY
         totalOrdBuy++;
         totalLotsBuy += OrderLots();
         
         if (OrderOpenPrice() < lowPriceBuy || lowPriceBuy == 0)
         {
            lowPriceBuy = OrderOpenPrice();
         }
         if ( OrderOpenPrice() > higPriceBuy || higPriceBuy == 0)
         {
            higPriceBuy = OrderOpenPrice();
            tckHigBuy = OrderTicket();
            profitBuy = OrderProfit();
            comBuy = OrderCommission();
            swapBuy = OrderSwap();
            lotsBuy = OrderLots();
            
            totalProfitBuy += profitBuy;
         }
         if ( OrderTicket() > tckBuy)
         {
            tckBuy = OrderTicket();
            recentBuy = OrderOpenPrice();
         }
      }  // End if ( OrderType() == OP_BUY )
      
   } // End for (int i = 0; i < OrdersTotal(); i++)
   
   totalProfit = profit + swap;
   
   // Tinh lotsize theo balance
   CalculateLotsizeBasedOnBalance();
   
} // End void GetHigh_LowPrice()
//+------------------------------------------------------------------+

void showInfo()
{
   bool oneclick = ChartGetInteger(0,CHART_SHOW_ONE_CLICK);
   int x = 20;
   if (oneclick) {
      x = 220;
   }
   
   RectLabelCreate(0,"BG", 0, x - 10, 20, 300, 250, clrMidnightBlue, BORDER_RAISED, CORNER_LEFT_UPPER, clrMidnightBlue, STYLE_SOLID, 2, false, false, true, 0);
   Draw("Bot_Name", "============ Farmer EA ============", 12, "Calibri Bold", clrYellow, 4, x, 20);
      
   Draw("Balance", "Balance: " + FormatNumber(NormalizeDouble(accountBalance, 2), " "), 12, "Calibri Bold", clrYellow, 4, x, 160);
   Draw("Enquity", "Enquity: " + FormatNumber(NormalizeDouble(accountEnquity, 2), " "), 12, "Calibri Bold", clrYellow, 4, x, 180);
   
   if (totalProfit > 0) {
      Draw("Profit", "===== Total Profit: " + NormalizeDouble(totalProfit, 2), 12, "Calibri Bold", clrLime, 4, x, 120);
   } else {
      Draw("Profit", "===== Total Profit: " + NormalizeDouble(totalProfit, 2), 12, "Calibri Bold", clrTomato, 4, x, 120);
   }
   
   Draw("Total_Buy", "Buy: " + totalOrdBuy + " orders" + " / " + NormalizeDouble(totalLotsBuy, 2) + " lots", 12, "Calibri Bold", clrLime, 4, x, 100);
   Draw("Profit_Buy", "Profit Buy: " + NormalizeDouble(totalProfitBuy, 2), 12, "Calibri Bold", clrLime, 4, x, 80);
   Draw("Total_Sell", "Sell: " + totalOrdSell + " orders" + " / " + NormalizeDouble(totalLotsSell, 2) + " lots", 12, "Calibri Bold", clrRed, 4, x, 60);
   Draw("Profit_Sell", "Profit Sell: " + NormalizeDouble(totalProfitSell, 2), 12, "Calibri Bold", clrRed, 4, x, 40);
   
   Draw("BaseLotsize", "Lotsize: " + baseLotsize, 12, "Calibri Bold", clrYellow, 4, x, 210);
   
   datetime server_time = TimeCurrent();
   datetime gmt_time = TimeGMT();
     
   int offset_seconds=((int)server_time)-((int)gmt_time);
   int serverOffset = offset_seconds / 3600;
   
   int diffServerGMT7Offset = 7 - serverOffset;
   Draw("ServerTime", "TZ Diff From GMT7: -" + diffServerGMT7Offset, 12, "Calibri Bold", clrYellow, 4, x, 240);
   //Draw("Expired", "Expire date: " + trial_end_date, 12, "Calibri Bold", clrYellow, 4, x, 230);
   
}

void OnChartEvent (const int id, const long &lparam, const double &dparam, const string &action)
{
   ResetLastError();
   if (id == CHARTEVENT_OBJECT_CLICK) {if (ObjectType (action) == OBJ_BUTTON) {ButtonPressed (0, action);}}
}
//+------------------------------------------------------------------+

void ButtonPressed (const long chartID, const string action)
{
   ObjectSetInteger (chartID, action, OBJPROP_BORDER_COLOR, clrBlack); // button pressed
   
   if (action == "closeAll") closeAllPressed (chartID, action);
   if (action == "closeBuy") closeBuyPressed (chartID, action);
   if (action == "closeSell") closeSellPressed (chartID, action);
   
   if (action == "hedge") hedgePressed (chartID, action);
   if (action == "clearSLTP") clearSLTPPressed (chartID, action);
   if (action == "BEButton") BEPressed (chartID, action);
   
   //Sleep (1000);
   
   ObjectSetInteger (chartID, action, OBJPROP_BORDER_COLOR, clrYellow); // button unpressed
   ObjectSetInteger (chartID, action, OBJPROP_STATE, false); // button unpressed
   
   ChartRedraw();
}
//+------------------------------------------------------------------+

int BuyPressed (const long chartID, const string action)
{   
   // Check buy order
   double price = MarketInfo(Symbol(), MODE_ASK);
   double tp = price + (pipFirstTP * 10 * MarketInfo(Symbol(), MODE_POINT));
   double sl = price - (pipSL * 10 * MarketInfo(Symbol(), MODE_POINT));
   
   if (pipSL == 0) 
   {
      sl = 0;
   }
   string cm = cmt + "BUY-" + (totalOrdBuy + 1);
   
   // Lenh L1
   if (totalOrdBuy == 0)
   {
      openOrd (ORDER_TYPE_BUY, price, sl, tp, cm, 1, baseLotsize);
      
      Sleep(delayTime*1000);
      
   }
   
   return (0);
}

int SellPressed (const long chartID, const string action)
{   
   // Check Sell order
   double price = MarketInfo(Symbol(), MODE_BID);
   double tp = price - (pipFirstTP * 10 * MarketInfo(Symbol(), MODE_POINT));
   double sl = price + (pipSL * 10 * MarketInfo(Symbol(), MODE_POINT));
   
   if (pipSL == 0) 
   {
      sl = 0;
   }
   string cm = cmt + "SELL-" + (totalOrdSell + 1);
   
   // Lenh L1
   if (totalOrdSell == 0)
   {
      openOrd (ORDER_TYPE_SELL, price, sl, tp, cm, 1, baseLotsize);
      
      Sleep(delayTime*1000);
      
   }
   
   return (0);
}

int BEPressed(const long chartID, const string action) 
{
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == _Symbol && OrderMagicNumber() == MagicNumber) {
         double openPrice = OrderOpenPrice();
         double currentSl = OrderStopLoss();
         double tp = OrderTakeProfit();
         int type = OrderType();
         double lots = OrderLots();
         
         // 1. Calculate costs in money
         double commission = OrderCommission();
         double swap = OrderSwap();
         double totalCostsMoney = commission + swap;
         
         // 2. Convert costs to price offset
         double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
         double tickSize = MarketInfo(_Symbol, MODE_TICKSIZE);
         
         double priceOffset = 0;
         if(lots > 0 && tickValue > 0) {
            // Formula: Money = (Pips * TickValue / TickSize) * Lots
            // => Pips = -Money / (Lots * TickValue / TickSize)
            priceOffset = -totalCostsMoney / (lots * (tickValue / tickSize));
         }
         
         // 3. Add user extra buffer
         priceOffset += inpBE_Extra * pipSize;
         
         double bePrice = openPrice;
         if(type == OP_BUY) bePrice += priceOffset;
         else if(type == OP_SELL) bePrice -= priceOffset;
         
         // 4. Check if we should modify
         bool shouldModify = false;
         double currentPrice = (type == OP_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         // Check if current price is far enough to allow SL modification (StopLevel check)
         double stopLevel = MarketInfo(_Symbol, MODE_STOPLEVEL) * _Point;
         
         if(type == OP_BUY) {
            if(currentPrice > bePrice + stopLevel + 2*_Point && (currentSl < bePrice - _Point || currentSl == 0)) shouldModify = true;
         } else if(type == OP_SELL) {
            if(currentPrice < bePrice - stopLevel - 2*_Point && (currentSl > bePrice + _Point || currentSl == 0)) shouldModify = true;
         }
         
         if(shouldModify) {
            if(!OrderModify(OrderTicket(), openPrice, NormalizeDouble(bePrice, dig), NormalizeDouble(tp, dig), 0)) {
               Print("Error moving to BE (Auto): ", GetLastError(), " Costs:", totalCostsMoney, " Offset:", priceOffset);
            }
         }
      }
   }
   
   return (0);
}

//+------------------------------------------------------------------+

int closeNegativePressed (const long chartID, const string action)
{   
   if (confirmClose) {
      int CloseNegative = MessageBox("Close All (-)", "Close Order", IDOK);
   
      if (CloseNegative == IDOK) {
         closeNegativeOrders();
         
         return (0);
      }
   } else {
      closeNegativeOrders();
      
      return (0);
   }
   
   return (0);
}

int closeNegativeOrders ()
{   
   if (OrdersTotal() == 0) return(0);

   // --- Bước 1: Gom toàn bộ ticket cần đóng ---
   int    tickets[];
   double lots[];
   int    types[];
   double profits[];
   int    count = 0;

   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol()      != Symbol())              continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderType()        >= 2)                     continue; // bỏ pending

      ArrayResize(tickets, count + 1);
      ArrayResize(lots,    count + 1);
      ArrayResize(types,   count + 1);
      tickets[count] = OrderTicket();
      lots[count]    = OrderLots();
      types[count]   = OrderType();
      profits[count] = OrderProfit();
      count++;
   }

   if (count == 0) return(0);

   // --- Bước 2: Đóng Sell trước, Buy sau (giảm exposure hedge nhanh hơn) ---
   // Đổi thứ tự thành Buy trước nếu bạn không dùng hedge

   int    SLIPPAGE   = 3000;  // pip * 10, rộng để tránh reject
   int    MAX_RETRY  = 5;
   int    RETRY_WAIT = 200;   // ms

   for (int j = 0; j < count; j++)
   {
      if (profits[j] > 0) continue;

      bool closed = false;
      for (int attempt = 0; attempt < MAX_RETRY; attempt++)
      {
         RefreshRates(); // <-- lấy giá mới nhất trước mỗi lần gửi lệnh

         double closePrice = (types[j] == OP_BUY) ? Bid : Ask;

         bool result = OrderClose(tickets[j], lots[j], closePrice, SLIPPAGE);

         if (result)
         {
            Print("[CloseAll] Closed ticket #", tickets[j]);
            closed = true;
            break;
         }

         int err = GetLastError();
         Print("[CloseAll] Attempt ", attempt + 1, " failed ticket #", tickets[j],
               " Error: ", err);

         // Chỉ retry với lỗi tạm thời
         if (err == ERR_TRADE_CONTEXT_BUSY  ||
             err == ERR_REQUOTE             ||
             err == ERR_PRICE_CHANGED       ||
             err == ERR_OFF_QUOTES          ||
             err == ERR_SERVER_BUSY         ||
             err == ERR_NO_CONNECTION)
         {
            Sleep(RETRY_WAIT);
            continue;
         }

         // Lỗi nghiêm trọng → không retry
         break;
      }

      if (!closed)
         Print("[CloseAll] FAILED to close ticket #", tickets[j], " after ", MAX_RETRY, " attempts");
   }

   return(0);
}
//+------------------------------------------------------------------+

int closePositivePressed (const long chartID, const string action)
{   
   if (confirmClose) {
      int ClosePositive = MessageBox("Close All (+)", "Close Order", IDOK);
   
      if (ClosePositive == IDOK) {
         closePositiveOrders();
         
         return (0);
      }
   } else {
      closePositiveOrders();
      
      return (0);
   }
   
   
   return (0);
}

int closePositiveOrders ()
{   
   if (OrdersTotal() == 0) return(0);

   // --- Bước 1: Gom toàn bộ ticket cần đóng ---
   int    tickets[];
   double lots[];
   int    types[];
   double profits[];
   int    count = 0;

   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol()      != Symbol())              continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderType()        >= 2)                     continue; // bỏ pending

      ArrayResize(tickets, count + 1);
      ArrayResize(lots,    count + 1);
      ArrayResize(types,   count + 1);
      tickets[count] = OrderTicket();
      lots[count]    = OrderLots();
      types[count]   = OrderType();
      profits[count] = OrderProfit();
      count++;
   }

   if (count == 0) return(0);

   // --- Bước 2: Đóng Sell trước, Buy sau (giảm exposure hedge nhanh hơn) ---
   // Đổi thứ tự thành Buy trước nếu bạn không dùng hedge

   int    SLIPPAGE   = 3000;  // pip * 10, rộng để tránh reject
   int    MAX_RETRY  = 5;
   int    RETRY_WAIT = 200;   // ms

   for (int j = 0; j < count; j++)
   {
      if (profits[j] <= 0) continue;

      bool closed = false;
      for (int attempt = 0; attempt < MAX_RETRY; attempt++)
      {
         RefreshRates(); // <-- lấy giá mới nhất trước mỗi lần gửi lệnh

         double closePrice = (types[j] == OP_BUY) ? Bid : Ask;

         bool result = OrderClose(tickets[j], lots[j], closePrice, SLIPPAGE);

         if (result)
         {
            Print("[CloseAll] Closed ticket #", tickets[j]);
            closed = true;
            break;
         }

         int err = GetLastError();
         Print("[CloseAll] Attempt ", attempt + 1, " failed ticket #", tickets[j],
               " Error: ", err);

         // Chỉ retry với lỗi tạm thời
         if (err == ERR_TRADE_CONTEXT_BUSY  ||
             err == ERR_REQUOTE             ||
             err == ERR_PRICE_CHANGED       ||
             err == ERR_OFF_QUOTES          ||
             err == ERR_SERVER_BUSY         ||
             err == ERR_NO_CONNECTION)
         {
            Sleep(RETRY_WAIT);
            continue;
         }

         // Lỗi nghiêm trọng → không retry
         break;
      }

      if (!closed)
         Print("[CloseAll] FAILED to close ticket #", tickets[j], " after ", MAX_RETRY, " attempts");
   }

   return(0);
}
//+------------------------------------------------------------------+

int closeBuyPressed (const long chartID, const string action)
{   
   if (confirmClose) {
      int CloseBuy = MessageBox("Close All BUY?", "Close Order", IDOK);
      
      if (CloseBuy == IDOK) {
         closeBuyOrders();
         
         return (0);
      }
   }else{
      closeBuyOrders();
      
      return (0);
   }
   
   
   return (0);
}

int closeBuyOrders ()
{   
   if (OrdersTotal() == 0) return(0);

   // --- Bước 1: Gom toàn bộ ticket cần đóng ---
   int    tickets[];
   double lots[];
   int    types[];
   int    count = 0;

   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol()      != Symbol())              continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderType()        >= 2)                     continue; // bỏ pending

      ArrayResize(tickets, count + 1);
      ArrayResize(lots,    count + 1);
      ArrayResize(types,   count + 1);
      tickets[count] = OrderTicket();
      lots[count]    = OrderLots();
      types[count]   = OrderType();
      count++;
   }

   if (count == 0) return(0);

   // --- Bước 2: Đóng Sell trước, Buy sau (giảm exposure hedge nhanh hơn) ---
   // Đổi thứ tự thành Buy trước nếu bạn không dùng hedge

   int    SLIPPAGE   = 3000;  // pip * 10, rộng để tránh reject
   int    MAX_RETRY  = 5;
   int    RETRY_WAIT = 200;   // ms

   for (int j = 0; j < count; j++)
   {
      if (types[j] != OP_BUY) continue;

      bool closed = false;
      for (int attempt = 0; attempt < MAX_RETRY; attempt++)
      {
         RefreshRates(); // <-- lấy giá mới nhất trước mỗi lần gửi lệnh

         double closePrice = (types[j] == OP_BUY) ? Bid : Ask;

         bool result = OrderClose(tickets[j], lots[j], closePrice, SLIPPAGE);

         if (result)
         {
            Print("[CloseAll] Closed ticket #", tickets[j]);
            closed = true;
            break;
         }

         int err = GetLastError();
         Print("[CloseAll] Attempt ", attempt + 1, " failed ticket #", tickets[j],
               " Error: ", err);

         // Chỉ retry với lỗi tạm thời
         if (err == ERR_TRADE_CONTEXT_BUSY  ||
             err == ERR_REQUOTE             ||
             err == ERR_PRICE_CHANGED       ||
             err == ERR_OFF_QUOTES          ||
             err == ERR_SERVER_BUSY         ||
             err == ERR_NO_CONNECTION)
         {
            Sleep(RETRY_WAIT);
            continue;
         }

         // Lỗi nghiêm trọng → không retry
         break;
      }

      if (!closed)
         Print("[CloseAll] FAILED to close ticket #", tickets[j], " after ", MAX_RETRY, " attempts");
   }

   return(0);
}
//+------------------------------------------------------------------+

int closeSellPressed (const long chartID, const string action)
{   
   if (confirmClose) {
      int CloseSell = MessageBox("Close All SELL?", "Close Order", IDOK);
   
      if (CloseSell == IDOK) {
         closeSellOrders();
         
         return (0);
      }
   } else {
      closeSellOrders();
      
      return (0);
   }
   
   
   return (0);
}

int closeSellOrders ()
{   
   if (OrdersTotal() == 0) return(0);

   // --- Bước 1: Gom toàn bộ ticket cần đóng ---
   int    tickets[];
   double lots[];
   int    types[];
   int    count = 0;

   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol()      != Symbol())              continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderType()        >= 2)                     continue; // bỏ pending

      ArrayResize(tickets, count + 1);
      ArrayResize(lots,    count + 1);
      ArrayResize(types,   count + 1);
      tickets[count] = OrderTicket();
      lots[count]    = OrderLots();
      types[count]   = OrderType();
      count++;
   }

   if (count == 0) return(0);

   // --- Bước 2: Đóng Sell trước, Buy sau (giảm exposure hedge nhanh hơn) ---
   // Đổi thứ tự thành Buy trước nếu bạn không dùng hedge

   int    SLIPPAGE   = 3000;  // pip * 10, rộng để tránh reject
   int    MAX_RETRY  = 5;
   int    RETRY_WAIT = 200;   // ms

   for (int j = 0; j < count; j++)
   {
      if (types[j] != OP_SELL) continue;

      bool closed = false;
      for (int attempt = 0; attempt < MAX_RETRY; attempt++)
      {
         RefreshRates(); // <-- lấy giá mới nhất trước mỗi lần gửi lệnh

         double closePrice = (types[j] == OP_BUY) ? Bid : Ask;

         bool result = OrderClose(tickets[j], lots[j], closePrice, SLIPPAGE);

         if (result)
         {
            Print("[CloseAll] Closed ticket #", tickets[j]);
            closed = true;
            break;
         }

         int err = GetLastError();
         Print("[CloseAll] Attempt ", attempt + 1, " failed ticket #", tickets[j],
               " Error: ", err);

         // Chỉ retry với lỗi tạm thời
         if (err == ERR_TRADE_CONTEXT_BUSY  ||
             err == ERR_REQUOTE             ||
             err == ERR_PRICE_CHANGED       ||
             err == ERR_OFF_QUOTES          ||
             err == ERR_SERVER_BUSY         ||
             err == ERR_NO_CONNECTION)
         {
            Sleep(RETRY_WAIT);
            continue;
         }

         // Lỗi nghiêm trọng → không retry
         break;
      }

      if (!closed)
         Print("[CloseAll] FAILED to close ticket #", tickets[j], " after ", MAX_RETRY, " attempts");
   }

   return(0);
}
//+------------------------------------------------------------------+

int closeAllPressed (const long chartID, const string action)
{   
   if (confirmClose) {
      int CloseAll = MessageBox("Close All?", "Close Order", IDOK);
      
      if (CloseAll == IDOK) {
         closeAllOrders();
         
         return (0);
      }
   } else {
      closeAllOrders();
      
      return (0);
   }
   
   
   return (0);
}

int closeAllOrders()
{
   if (OrdersTotal() == 0) return(0);

   // --- Bước 1: Gom toàn bộ ticket cần đóng ---
   int    tickets[];
   double lots[];
   int    types[];
   int    count = 0;

   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol()      != Symbol())              continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderType()        >= 2)                     continue; // bỏ pending

      ArrayResize(tickets, count + 1);
      ArrayResize(lots,    count + 1);
      ArrayResize(types,   count + 1);
      tickets[count] = OrderTicket();
      lots[count]    = OrderLots();
      types[count]   = OrderType();
      count++;
   }

   if (count == 0) return(0);

   // --- Bước 2: Đóng Sell trước, Buy sau (giảm exposure hedge nhanh hơn) ---
   // Đổi thứ tự thành Buy trước nếu bạn không dùng hedge
   int order[2];
   order[0] = OP_SELL;
   order[1] = OP_BUY;

   int    SLIPPAGE   = 3000;  // pip * 10, rộng để tránh reject
   int    MAX_RETRY  = 5;
   int    RETRY_WAIT = 50;   // ms

   for (int pass = 0; pass < 2; pass++)
   {
      for (int j = 0; j < count; j++)
      {
         if (types[j] != order[pass]) continue;

         bool closed = false;
         for (int attempt = 0; attempt < MAX_RETRY; attempt++)
         {
            RefreshRates(); // <-- lấy giá mới nhất trước mỗi lần gửi lệnh

            double closePrice = (types[j] == OP_BUY) ? Bid : Ask;

            bool result = OrderClose(tickets[j], lots[j], closePrice, SLIPPAGE);

            if (result)
            {
               Print("[CloseAll] Closed ticket #", tickets[j]);
               closed = true;
               break;
            }

            int err = GetLastError();
            Print("[CloseAll] Attempt ", attempt + 1, " failed ticket #", tickets[j],
                  " Error: ", err);

            // Chỉ retry với lỗi tạm thời
            if (err == ERR_TRADE_CONTEXT_BUSY  ||
                err == ERR_REQUOTE             ||
                err == ERR_PRICE_CHANGED       ||
                err == ERR_OFF_QUOTES          ||
                err == ERR_SERVER_BUSY         ||
                err == ERR_NO_CONNECTION)
            {
               Sleep(RETRY_WAIT);
               continue;
            }

            // Lỗi nghiêm trọng → không retry
            break;
         }

         if (!closed)
            Print("[CloseAll] FAILED to close ticket #", tickets[j], " after ", MAX_RETRY, " attempts");
      }
   }

   return(0);
}
//+------------------------------------------------------------------+

int hedgePressed(const long chartID, const string action)
{
   if (totalLotsBuy != totalLotsSell) {
      if (totalLotsBuy > totalLotsSell) {
         // Sell hedging
         double diffLots = totalLotsBuy - totalLotsSell;
         double price = MarketInfo(Symbol(), MODE_BID);
         string cm = cmt + "Hedge - SELL";
         
         openOrd (ORDER_TYPE_SELL, price, 0, 0, cm, 1, diffLots);
      } else {
         // Buy hedging
         
         double diffLots = totalLotsSell - totalLotsBuy;
         double price = MarketInfo(Symbol(), MODE_ASK);
         string cm = cmt + "Hedge - BUY";
         
         openOrd (ORDER_TYPE_BUY, price, 0, 0, cm, 1, diffLots);
      }
   }
   
   return (0);
} //End int hedgePressed()
//+------------------------------------------------------------------+

int clearSLTPPressed(const long chartID, const string action)
{
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (!OrderSelect(i,SELECT_BY_POS, MODE_TRADES)) { continue;}
      if (OrderSymbol() != Symbol()) { continue;}
      if (OrderMagicNumber() != MagicNumber) { continue;}
      
      if (OrderType() < 2) { 
         // Modify SL TP về 0
         int tk = OrderModify(OrderTicket(), OrderOpenPrice(), 0, 0, 0, clrAliceBlue);
         if (tk <= 0) { Print("Error Modify Order " + DoubleToStr(OrderTicket(),0) + " : ",GetLastError());}
      }
   }
   
   return (0);
}
//+------------------------------------------------------------------+

void CreateButtons()
{
   int Button_Height = (int)(Font_Size * 3.5);
   
   if (showCloseBtn) {
      if (!ButtonCreate (0, "closeAll", 0, 280, 80, 250, Button_Height, 3, "Close All", Font_Type, Font_Size, Font_Color, clrDarkGreen, clrYellow)) return;
      if (!ButtonCreate (0, "closeBuy", 0, 280, 40, 120, Button_Height, 3, "Close Buy", Font_Type, Font_Size, Font_Color, clrDarkGreen, clrYellow)) return;
      if (!ButtonCreate (0, "closeSell", 0, 150, 40, 120, Button_Height, 3, "Close Sell", Font_Type, Font_Size, Font_Color, clrDarkGreen, clrYellow)) return;
      //if (!ButtonCreate (0, "closePositive", 0, 280, 40, 120, Button_Height, 3, "Close (+)", Font_Type, Font_Size, Font_Color, clrDarkGreen, clrYellow)) return;
      //if (!ButtonCreate (0, "closeNegative", 0, 150, 40, 120, Button_Height, 3, "Close (-)", Font_Type, Font_Size, Font_Color, clrDarkGreen, clrYellow)) return;
   }
   
   if (showHedgeBtn) {
      if (!ButtonCreate (0, "hedge", 0, 420, 40, 120, Button_Height, 3, "Hedge", Font_Type, Font_Size, clrWhite, clrDarkCyan, clrYellow)) return;
      if (!ButtonCreate (0, "clearSLTP", 0, 560, 40, 120, Button_Height, 3, "Clear SL TP", Font_Type, Font_Size, clrWhite, clrDarkBlue, clrYellow)) return;
      if (!ButtonCreate (0, "BEButton", 0, 700, 40, 120, Button_Height, 3, "BE", Font_Type, Font_Size, clrWhite, clrDarkOrange, clrYellow)) return;
   }
   
   ChartRedraw();
}
//+------------------------------------------------------------------+

bool ButtonCreate (const long chart_ID = 0, const string name = "Button", const int sub_window = 0, const int x = 0, const int y = 0, const int width = 500,
                   const int height = 18, int corner = 0, const string text = "button", const string font = "Arial Bold",
                   const int font_size = 10, const color clr = clrBlack, const color back_clr = C'170,170,170', const color border_clr = clrNONE,
                   const bool state = false, const bool back = false, const bool selection = false, const bool hidden = true, const long z_order = 0)
{
   ResetLastError();
   if (!ObjectCreate (chart_ID,name, OBJ_BUTTON, sub_window, 0, 0))
     {
      Print (__FUNCTION__, " : failed to create the button! Error code : ", GetLastError());
      return(false);
     }
   ObjectSetInteger (chart_ID, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger (chart_ID, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger (chart_ID, name, OBJPROP_XSIZE, width);
   ObjectSetInteger (chart_ID, name, OBJPROP_YSIZE, height);
   ObjectSetInteger (chart_ID, name, OBJPROP_CORNER, corner);
   ObjectSetInteger (chart_ID, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger (chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger (chart_ID, name, OBJPROP_BGCOLOR, back_clr);
   ObjectSetInteger (chart_ID, name, OBJPROP_BORDER_COLOR, border_clr);
   ObjectSetInteger (chart_ID, name, OBJPROP_BACK, back);
   ObjectSetInteger (chart_ID, name, OBJPROP_STATE, state);
   ObjectSetInteger (chart_ID, name, OBJPROP_SELECTABLE, selection);
   ObjectSetInteger (chart_ID, name, OBJPROP_SELECTED, selection);
   ObjectSetInteger (chart_ID, name, OBJPROP_HIDDEN, hidden);
   ObjectSetInteger (chart_ID, name, OBJPROP_ZORDER,z_order);
   ObjectSetString  (chart_ID, name, OBJPROP_TEXT, text);
   ObjectSetString  (chart_ID, name, OBJPROP_FONT, font);
   return(true);
}

void Draw(string name,string label,int size,string font,color clr,int corner,int x,int y)
{
   int windows=0;
   
   ObjectDelete(name);
   ObjectCreate(name,OBJ_LABEL,windows,0,0);
   ObjectSetText(name,label,size,font,clr);
   ObjectSet(name,OBJPROP_CORNER,corner);
   ObjectSet(name,OBJPROP_XDISTANCE,x);
   ObjectSet(name,OBJPROP_YDISTANCE,y);
}//End void Draw()

//+------------------------------------------------------------------+
//| Create rectangle label                                           |
//+------------------------------------------------------------------+
bool RectLabelCreate(const long             chart_ID=0,               // chart's ID
                     const string           name="RectLabel",         // label name
                     const int              sub_window=0,             // subwindow index
                     const int              x=0,                      // X coordinate
                     const int              y=0,                      // Y coordinate
                     const int              width=50,                 // width
                     const int              height=18,                // height
                     const color            back_clr=C'236,233,216',  // background color
                     const ENUM_BORDER_TYPE border=BORDER_SUNKEN,     // border type
                     const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                     const color            clr=clrRed,               // flat border color (Flat)
                     const ENUM_LINE_STYLE  style=STYLE_SOLID,        // flat border style
                     const int              line_width=1,             // flat border width
                     const bool             back=false,               // in the background
                     const bool             selection=false,          // highlight to move
                     const bool             hidden=true,              // hidden in the object list
                     const long             z_order=0)                // priority for mouse click
  {
  ObjectDelete(name);
//--- reset the error value
   ResetLastError();
//--- create a rectangle label
   if(!ObjectCreate(chart_ID,name,OBJ_RECTANGLE_LABEL,sub_window,0,0))
     {
      Print(__FUNCTION__,
            ": failed to create a rectangle label! Error code = ",GetLastError());
      return(false);
     }
//--- set label coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set label size
   ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);
//--- set background color
   ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);
//--- set border type
   ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_TYPE,border);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set flat border color (in Flat mode)
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set flat border line style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set flat border width
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,line_width);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the label by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
  
  
//+------------------------------------------------------------------+  
template<typename T>
string NumberToString(T number,int digits = 0,string sep=",")
{
   CString num_str;
   string prepend = number<0?"-":"";
   number=number<0?-number:number;
   int decimal_index = -1;
   if(typename(number)=="double" || typename(number)=="float")
   {
      num_str.Assign(DoubleToString((double)number,digits));
      decimal_index = num_str.Find(0,".");
   }
   else
      num_str.Assign(string(number));
   int len = (int)num_str.Len();
   decimal_index = decimal_index > 0 ? decimal_index : len; 
   int res = len - (len - decimal_index);
   for(int i = res-3;i>0;i-=3)
      num_str.Insert(i,sep);
   return prepend+num_str.Str();
}  

string FormatNumber(string numb, string delim=",",string dec=".")
{
   int pos=StringFind(numb,dec);
   string nnumb=numb;
   string enumb="";
   if(pos!=-1)
      {
      nnumb=StringSubstr(numb,0,pos);
      enumb=StringSubstr(numb,pos);
      }
   int cnt=StringLen(nnumb);
   if (cnt<4)return(numb);
   int x=MathFloor(cnt/3);
   int y=cnt-x*3;
   string forma="";
   if(y!=0)forma=StringConcatenate(StringSubstr(nnumb,0,y),delim);
   for(int i=0;i<x;i++)
      {
      if(i!=x-1)forma=StringConcatenate(forma,StringSubstr(nnumb,y+i*3,3),delim);
      else forma=StringConcatenate(forma,StringSubstr(nnumb,y+i*3,3));
      }
   forma=StringConcatenate(forma,enumb); 
   return(forma);
}     