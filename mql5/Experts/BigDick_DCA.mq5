//+------------------------------------------------------------------+
//| MT5 Migrated EA                                                  |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

CTrade trade;
CPositionInfo m_position;

#define OP_BUY 0
#define OP_SELL 1
#define ORDER_TYPE_BUY 0
#define ORDER_TYPE_SELL 1

// MQL4 compatibility functions
double iCloseMQL4(string symbol, ENUM_TIMEFRAMES tf, int index) {
   double Arr[1];
   if(CopyClose(symbol, tf, index, 1, Arr) > 0) return(Arr[0]);
   return(-1);
}
double iHighMQL4(string symbol, ENUM_TIMEFRAMES tf, int index) {
   double Arr[1];
   if(CopyHigh(symbol, tf, index, 1, Arr) > 0) return(Arr[0]);
   return(-1);
}
double iLowMQL4(string symbol, ENUM_TIMEFRAMES tf, int index) {
   double Arr[1];
   if(CopyLow(symbol, tf, index, 1, Arr) > 0) return(Arr[0]);
   return(-1);
}
double iOpenMQL4(string symbol, ENUM_TIMEFRAMES tf, int index) {
   double Arr[1];
   if(CopyOpen(symbol, tf, index, 1, Arr) > 0) return(Arr[0]);
   return(-1);
}
datetime iTimeMQL4(string symbol, ENUM_TIMEFRAMES tf, int index) {
   datetime Arr[1];
   if(CopyTime(symbol, tf, index, 1, Arr) > 0) return(Arr[0]);
   return(0);
}
int iBarShiftMQL4(string symbol, ENUM_TIMEFRAMES tf, datetime time, bool exact=false) {
   datetime bars[];
   if(CopyTime(symbol, tf, time, 1, bars) > 0) {
       if(exact && bars[0] != time) return -1;
       return Bars(symbol, tf, bars[0], TimeCurrent()) - 1;
   }
   return -1;
}

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

input int MagicNumber = 179092;                                     // Magic Number

input string ________GENERAL________ = "============== GENERAL ==============";  
input double lotsize = 0.1;                                         // Lot Size
input double pipsDiff = 250;                                        // Khoang Cach Vao Lenh (Pips)
input double multiple = 1.05;                                       // He So Nhan Lot
input double multipleDiff = 1.4;                                    // He So Khoang Cach
input double pipFirstTP = 230;                                      // TP Lenh Dau Tien (Pips)
input double pipTP = 230;                                           // TP Chuoi Tu Lenh 2 Tro Di (Pips)
input double pipSL = 0;                                             // SL Chuoi Tinh Tu Lenh Cuoi Cung (Pips)
input double inpBE_Extra = 0.5;                                     // BE Extra Profit (Pips)

input string ________LOTSIZE_SETTINGS________ = "============== AUTO LOTSIZE ==============";
input bool autoLotsize = false;                                     // Tu Dong Tinh LotSize Theo Balance
input int lotsizePercentBasedOnBalance = 9;                         // % Lotsize Theo Balance

input string ________GRID_SETTINGS________ = "============== SETTINGS DCA ==============";
input int maxOrderBUY = 4;                                          // So Lenh BUY Toi Da
input int maxOrderSELL = 4;                                         // So Lenh SELL Toi Da
input int delayTime = 3;                                            // Khoang gian dung giua 2 lenh (Tính theo giay)

input string ________BUTTONS________ = "===== SETTING BUTTONS =====";
input bool confirmClose = false;                 // Hoi Lai Khi Click Close Buttons
input bool showHedgeBtn = true;                 // Hien Thi Button Hedge
input bool showCloseBtn = true;                  // Hien Thi Button Close All

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
datetime lastOrderTime = 0;
int lastTotalOrdBuy = -1;
int lastTotalOrdSell = -1;

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
   ObjectsDeleteAll(0);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   GetHigh_LowPrice();
   doAction();
   showInfo();
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

void doAction ()
{
   doActionBuy();
   doActionSell();
   
}// End void doAction()

void doActionBuy()
{
   if (TimeCurrent() - lastOrderTime < delayTime) return;
   // Lenh L2-n
   if (totalOrdBuy != 0 && totalOrdBuy < maxOrderBUY)
   {
      // Check buy order
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double tp = price + (pipFirstTP * 10 * _Point);
      double sl = price - (pipSL * 10 * _Point);
      
      if (pipSL == 0) 
      {
         sl = 0;
      }
      string cm = cmt + "BUY-" + (totalOrdBuy + 1);
   
      double buyPipsDiff = GetPipsDiff(ORDER_TYPE_BUY, multipleDiff, pipsDiff);
      if (lowPriceBuy - price >= buyPipsDiff*10*_Point)
      {
         int tmp = openOrd (ORDER_TYPE_BUY, price, sl, tp, cm, multiple, baseLotsize);
         if (tmp > 0) {
            UpdateBasketTP(ORDER_TYPE_BUY);
         }
      }
   }
}

void doActionSell()
{
   if (TimeCurrent() - lastOrderTime < delayTime) return;
   // Lenh L2-n
   if (totalOrdSell != 0 && totalOrdSell < maxOrderSELL)
   {
      // Check Sell order
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double tp = price - (pipFirstTP * 10 * _Point);
      double sl = price + (pipSL * 10 * _Point);
      
      if (pipSL == 0) 
      {
         sl = 0;
      }
      string cm = cmt + "SELL-" + (totalOrdSell + 1);
      
      double sellPipsDiff = GetPipsDiff(ORDER_TYPE_SELL, multipleDiff, pipsDiff);
      if (price - higPriceSell > sellPipsDiff*10*_Point)
      {
         int tmp = openOrd (ORDER_TYPE_SELL, price, sl, tp, cm, multiple, baseLotsize);
         if (tmp > 0) {
            UpdateBasketTP(ORDER_TYPE_SELL);
         }
      }
   }
}

int openOrd ( int oP, double entry, double sL, double tP, string cm, double multi, double lot)
{
   GetValLot (oP, multi, lot);
   string col;
   if (oP == OP_BUY)  col = ColorToString(clrGreen);
   else if (oP == OP_SELL) col = ColorToString(clrRed);

   if (openOrder == true)
   {
      // Final Hedge Protection
      for (int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if (ticket > 0 && PositionSelectByTicket(ticket))
         {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
               long pType = PositionGetInteger(POSITION_TYPE);
               if (oP == OP_BUY && pType == POSITION_TYPE_SELL) {
                  Print("HEDGE PROTECTION: Refused to open BUY while SELL positions exist.");
                  return 0;
               }
               if (oP == OP_SELL && pType == POSITION_TYPE_BUY) {
                  Print("HEDGE PROTECTION: Refused to open SELL while BUY positions exist.");
                  return 0;
               }
            }
         }
      }

      trade.SetExpertMagicNumber(MagicNumber);
      trade.SetDeviationInPoints(30); // slippage 30 points

      // Refresh prices
      MqlTick tick;
      if(!SymbolInfoTick(_Symbol, tick)) return 0;
      
      double executionPrice = entry;
      if (oP == OP_BUY)  executionPrice = tick.ask;
      if (oP == OP_SELL) executionPrice = tick.bid;
      
      executionPrice = NormalizeDouble(executionPrice, _Digits);
      if (sL > 0) sL = NormalizeDouble(sL, _Digits);
      if (tP > 0) tP = NormalizeDouble(tP, _Digits);

      if (oP == OP_BUY) {
          if (!trade.Buy(currentLots, _Symbol, executionPrice, sL, tP, cm)) {
              Print("Error Open Order DCA BUY : ", GetLastError());
              return 0;
          }
      } else {
          if (!trade.Sell(currentLots, _Symbol, executionPrice, sL, tP, cm)) {
              Print("Error Open Order DCA SELL : ", GetLastError());
              return 0;
          }
      }
      lastOrderTime = TimeCurrent();
      return 1;
   }
   return 0;
}// End int openOrd()

void modifyTP(string symbol, int oP, double tp, double sl)
{
   long pt = oP == OP_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   for (int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0) continue;
      if (!PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      if (PositionGetInteger(POSITION_TYPE) == pt) { 
         trade.PositionModify(ticket, sl, tp);
      }
   }
}// End void modifyTP()

void UpdateBasketTP(int oP, int oldTotal = -1, int newTotal = -1)
{
   if (oP == ORDER_TYPE_BUY || oP == OP_BUY)
   {
      if (totalOrdBuy >= 2)
      {
         double BE_Buy = breakeven(_Symbol, ORDER_TYPE_BUY, MagicNumber, baseLotsize);
         double sl = (pipSL == 0) ? 0 : (lowPriceBuy - (pipSL * 10 * _Point));
         double buyAllTP = (BE_Buy + pipTP*10*_Point);
         modifyTP (_Symbol, ORDER_TYPE_BUY, buyAllTP, sl);
         if (oldTotal != -1 && newTotal != -1) {
            Print("[Self-Healing] Detected Buy Position Count Change: ", oldTotal, " -> ", newTotal, ". Re-modified TP to: ", buyAllTP);
         }
      }
   }
   else if (oP == ORDER_TYPE_SELL || oP == OP_SELL)
   {
      if (totalOrdSell >= 2)
      {
         double BE_Sell = breakeven(_Symbol, ORDER_TYPE_SELL, MagicNumber, baseLotsize);
         double sl = (pipSL == 0) ? 0 : (higPriceSell + (pipSL * 10 * _Point));
         double sellAllTP = (BE_Sell - pipTP*10*_Point);
         modifyTP (_Symbol, ORDER_TYPE_SELL, sellAllTP, sl);
         if (oldTotal != -1 && newTotal != -1) {
            Print("[Self-Healing] Detected Sell Position Count Change: ", oldTotal, " -> ", newTotal, ". Re-modified TP to: ", sellAllTP);
         }
      }
   }
}

double breakeven(string symBE, int bTyp, int mNumber, double addLot)
{
   double equity = 0, lots = 0;
   int cnt = PositionsTotal();
   for (int i=0; i<cnt; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0) continue;
      if (!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != mNumber) continue;
      long oType = PositionGetInteger(POSITION_TYPE);
      
      if(PositionGetString(POSITION_SYMBOL) == symBE) 
      {
         if (bTyp == OP_SELL && oType == POSITION_TYPE_SELL) 
         {  
            equity += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);  
            lots -= PositionGetDouble(POSITION_VOLUME);  
         }
         else if (bTyp == OP_BUY && oType == POSITION_TYPE_BUY) 
         {  
            equity += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);  
            lots += PositionGetDouble(POSITION_VOLUME);  
         }
      }
   }
   
   double entryBE = 0;
   double price = (bTyp == OP_BUY) ? SymbolInfoDouble(symBE, SYMBOL_BID) : SymbolInfoDouble(symBE, SYMBOL_ASK);
   double tickSize = SymbolInfoDouble(symBE, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symBE, SYMBOL_TRADE_TICK_VALUE);
   
   if (lots != 0 && tickValue > 0) 
   {
      entryBE = price - (equity / (lots * (tickValue / tickSize)));
   }
   
   return entryBE;
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
      orderLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }
   
   if (orderLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
      orderLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }
   
   if (orderLot > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)) {
      orderLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   }
   
   currentLots = NormalizeDouble(orderLot, normalLotUnit);
} // End void GetValLot()

void GetNormalLotUnit()
{
   if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)== 0.01)
   {
      normalLotUnit = 2;
   }
   if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)== 0.1)
   {
      normalLotUnit = 1;
   }
   if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)== 0.001)
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
   
   totalOrder = 0;
   totalOrdBuy = 0;
   totalOrdSell = 0;
   double profit = 0, swap = 0;
   
   totalLotsBuy = 0;
   totalLotsSell = 0;
   
   accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   accountEnquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   for (int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0) continue;
      if (!PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      totalOrder ++; 
      profit += PositionGetDouble(POSITION_PROFIT);
      swap += PositionGetDouble(POSITION_SWAP);
            
      long pType = PositionGetInteger(POSITION_TYPE);
      double pOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double pLots = PositionGetDouble(POSITION_VOLUME);
      
      if (pType == POSITION_TYPE_SELL)
      {
         totalOrdSell++;
         totalLotsSell += pLots;
         
         if (pOpen > higPriceSell || higPriceSell == 0) higPriceSell = pOpen;
         if (pOpen < lowPriceSell || lowPriceSell == 0)
         {
            lowPriceSell = pOpen;
            totalProfitSell += PositionGetDouble(POSITION_PROFIT);
         }
      } 
      if (pType == POSITION_TYPE_BUY)
      {
         totalOrdBuy++;
         totalLotsBuy += pLots;
         
         if (pOpen < lowPriceBuy || lowPriceBuy == 0) lowPriceBuy = pOpen;
         if (pOpen > higPriceBuy || higPriceBuy == 0)
         {
            higPriceBuy = pOpen;
            totalProfitBuy += PositionGetDouble(POSITION_PROFIT);
         }
      } 
   } 
   
   totalProfit = profit + swap;
   CalculateLotsizeBasedOnBalance();
   
   // Self-Healing Double-Insurance TP Modification
   if (lastTotalOrdBuy == -1)  lastTotalOrdBuy = totalOrdBuy;
   if (lastTotalOrdSell == -1) lastTotalOrdSell = totalOrdSell;
   
   if (totalOrdBuy != lastTotalOrdBuy)
    {
       UpdateBasketTP(ORDER_TYPE_BUY, lastTotalOrdBuy, totalOrdBuy);
       lastTotalOrdBuy = totalOrdBuy;
    }
   
   if (totalOrdSell != lastTotalOrdSell)
    {
       UpdateBasketTP(ORDER_TYPE_SELL, lastTotalOrdSell, totalOrdSell);
       lastTotalOrdSell = totalOrdSell;
    }
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
   if (id == CHARTEVENT_OBJECT_CLICK) {if (ObjectGetInteger(0, action, OBJPROP_TYPE) == OBJ_BUTTON) {ButtonPressed (0, action);}}
}
//+------------------------------------------------------------------+

void ButtonPressed (const long chartID, const string action)
{
   ObjectSetInteger (chartID, action, OBJPROP_BORDER_COLOR, clrBlack); // button pressed
   
   if (action == "MakeBuy") BuyPressed (chartID, action);
   if (action == "MakeSell") SellPressed (chartID, action);
   
   if (action == "closeAll") closeAllPressed (chartID, action);
   if (action == "closeBuy") closeBuyPressed (chartID, action);
   if (action == "closeSell") closeSellPressed (chartID, action);
   
   if (action == "hedge") hedgePressed (chartID, action);
   if (action == "clearSLTP") clearSLTPPressed (chartID, action);
   // BEButton removed
   
   //Sleep (1000);
   
   ObjectSetInteger (chartID, action, OBJPROP_BORDER_COLOR, clrYellow); // button unpressed
   ObjectSetInteger (chartID, action, OBJPROP_STATE, false); // button unpressed
   
   ChartRedraw();
}
//+------------------------------------------------------------------+

int BuyPressed (const long chartID, const string action)
{   
   // Check buy order
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tp = price + (pipFirstTP * 10 * _Point);
   double sl = price - (pipSL * 10 * _Point);
   
   if (pipSL == 0) 
   {
      sl = 0;
   }
   string cm = cmt + "BUY-" + (totalOrdBuy + 1);
   
   // Lenh L1
   if (totalOrdBuy == 0)
   {
      openOrd (ORDER_TYPE_BUY, price, sl, tp, cm, 1, baseLotsize);
   }
   
   return (0);
}

int SellPressed (const long chartID, const string action)
{   
   // Check Sell order
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = price - (pipFirstTP * 10 * _Point);
   double sl = price + (pipSL * 10 * _Point);
   
   if (pipSL == 0) 
   {
      sl = 0;
   }
   string cm = cmt + "SELL-" + (totalOrdSell + 1);
   
   // Lenh L1
   if (totalOrdSell == 0)
   {
      openOrd (ORDER_TYPE_SELL, price, sl, tp, cm, 1, baseLotsize);
   }
   
   return (0);
}

int BEPressed(const long chartID, const string action) { return 0; }

//+------------------------------------------------------------------+

int closeNegativePressed (const long chartID, const string action) { closeNegativeOrders_MT5(); return(0); }

int closeNegativeOrders() { closeNegativeOrders_MT5(); return(0); }
//+------------------------------------------------------------------+

int closePositivePressed (const long chartID, const string action) { closePositiveOrders_MT5(); return(0); }

int closePositiveOrders() { closePositiveOrders_MT5(); return(0); }
//+------------------------------------------------------------------+

int closeBuyPressed (const long chartID, const string action) { closeBuyOrders_MT5(); return(0); }

int closeBuyOrders() { closeBuyOrders_MT5(); return(0); }
//+------------------------------------------------------------------+

int closeSellPressed (const long chartID, const string action) { closeSellOrders_MT5(); return(0); }

int closeSellOrders() { closeSellOrders_MT5(); return(0); }
//+------------------------------------------------------------------+

int closeAllPressed (const long chartID, const string action) { closeAllOrders_MT5(); return(0); }

int closeAllOrders() { closeAllOrders_MT5(); return(0); }
//+------------------------------------------------------------------+

int hedgePressed(const long chartID, const string action)
{
   if (totalLotsBuy != totalLotsSell) {
      if (totalLotsBuy > totalLotsSell) {
         // Sell hedging
         double diffLots = totalLotsBuy - totalLotsSell;
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         string cm = cmt + "Hedge - SELL";
         
         openOrd (ORDER_TYPE_SELL, price, 0, 0, cm, 1, diffLots);
      } else {
         // Buy hedging
         
         double diffLots = totalLotsSell - totalLotsBuy;
         double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         string cm = cmt + "Hedge - BUY";
         
         openOrd (ORDER_TYPE_BUY, price, 0, 0, cm, 1, diffLots);
      }
   }
   
   return (0);
} //End int hedgePressed()
//+------------------------------------------------------------------+

int clearSLTPPressed(const long chartID, const string action)
{
   for (int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0) continue;
      if (!PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      trade.PositionModify(ticket, 0.0, 0.0);
   }
   return (0);
}
//+------------------------------------------------------------------+

void CreateButtons()
{
   int Button_Height = (int)(Font_Size * 3.5);
   if (!ButtonCreate (0, "MakeBuy", 0, 520, 60, 230, Button_Height * 2, 1, "Buy", Font_Type, 18, Font_Color, clrTeal, clrYellow)) return;
   if (!ButtonCreate (0, "MakeSell", 0, 260, 60, 230, Button_Height * 2, 1, "Sell", Font_Type, 18, Font_Color, clrRed, clrYellow)) return;
   
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
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, windows, 0, 0);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, label);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
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
//--- reset the error value
   ResetLastError();
//--- create a rectangle label if it doesn't exist
   if(ObjectFind(chart_ID, name) < 0)
   {
      if(!ObjectCreate(chart_ID,name,OBJ_RECTANGLE_LABEL,sub_window,0,0))
      {
         Print(__FUNCTION__,
               ": failed to create a rectangle label! Error code = ",GetLastError());
         return(false);
      }
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
   if(y!=0)forma=StringSubstr(nnumb,0,y) + delim;
   for(int i=0;i<x;i++)
      {
      if(i!=x-1)forma=forma + StringSubstr(nnumb,y+i*3,3) + delim;
      else forma=forma + StringSubstr(nnumb,y+i*3,3);
      }
   forma=forma + enumb; 
   return(forma);
}     


void closeAllOrders_MT5()
{
   int cnt = PositionsTotal();
   for(int i = cnt - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0 && PositionSelectByTicket(ticket)) {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            trade.PositionClose(ticket);
         }
      }
   }
}

void closeBuyOrders_MT5()
{
   int cnt = PositionsTotal();
   for(int i = cnt - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0 && PositionSelectByTicket(ticket)) {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               trade.PositionClose(ticket);
            }
         }
      }
   }
}

void closeSellOrders_MT5()
{
   int cnt = PositionsTotal();
   for(int i = cnt - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0 && PositionSelectByTicket(ticket)) {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               trade.PositionClose(ticket);
            }
         }
      }
   }
}

void closeNegativeOrders_MT5()
{
   int cnt = PositionsTotal();
   for(int i = cnt - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0 && PositionSelectByTicket(ticket)) {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            if (PositionGetDouble(POSITION_PROFIT) < 0) {
               trade.PositionClose(ticket);
            }
         }
      }
   }
}

void closePositiveOrders_MT5()
{
   int cnt = PositionsTotal();
   for(int i = cnt - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0 && PositionSelectByTicket(ticket)) {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            if (PositionGetDouble(POSITION_PROFIT) >= 0) {
               trade.PositionClose(ticket);
            }
         }
      }
   }
}
