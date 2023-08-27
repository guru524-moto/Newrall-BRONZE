//+------------------------------------------------------------------+
//|                                               Newrall BRONZE.mq5 |
//|                                  Copyright 2023, Neurals Project |
//|                                   https://www.neuralsproject.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Neurals Project"
#property link      "https://www.neuralsproject.com"
#property version   "1.1"

//TODO ADD RSI FUNCTIONALITY
//TODO ADD MONEY MANAGEMENT
//TODO CHECK AND TEST THE CODE
#include <Trade/Trade.mqh>

CTrade *Trade;

sinput string General = ""; // GENERAL PARAMETERS
input string EAName = "Newrall BRONZE";
input int MagicNumber = 2004;

sinput string RiskSettings = ""; // RISK PARAMETERS
input double FirstLot = 0.01;
input double FirstLotMultiplier = 3;
input double MoreLotMultiplier = 2;

sinput string ExitSettings = ""; // EXIT PARAMETERS
input int StopLoss = 40;
input int TakeProfit = 60;
input int HedgingDistance = 20;

double ASK, BID, STP, TKP, HedgeDistance, FirstPendingLot = 0, PendingPrice = 0, NextLot = 0;
int OldNumOfBuy = 0, OldNumOfSell = 0, OldNumOfBars = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //---
   Trade = new CTrade;
   Trade.SetExpertMagicNumber(MagicNumber);

   STP = StopLoss * 10 * _Point;
   TKP = TakeProfit * 10 * _Point;
   HedgeDistance = HedgingDistance * 10 * _Point;
   FirstPendingLot = NormalizeDouble(FirstLot * FirstLotMultiplier, 2);

   //---
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //---
   delete Trade;
   DeletePending();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (NewBarPresent())
   {
      ASK = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      BID = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if (PositionsTotal() == 0)
      {
         DeletePending();
         if (CheckVolumeLimit() && CheckMoneyForTrade(_Symbol, FirstLot * FirstLotMultiplier, ORDER_TYPE_BUY))
         {
            FirstBuy();
         }
         else
         {
            DeletePending();
         }
      }
      else
      {
         PendingBuy();
         MorePendingSell();
      }
   }
}
//+------------------------------------------------------------------+

void FirstBuy()
{
   if(PositionsTotal() == 0)
   {
      double lotSize = FirstLot * FirstLotMultiplier;
      if(!Trade.Buy(lotSize, _Symbol, ASK, ASK - STP, ASK + TKP, "First Buy"))
         return;
      else
      {
         PendingPrice = ASK - HedgeDistance;
         NextLot = FirstPendingLot;
         PendingSell();
      }
   }
}

void PendingSell()
{
   double lotSize = NextLot;
   double price = PendingPrice;
   
   Trade.SellStop(lotSize, price, _Symbol, price + STP, price - TKP, ORDER_TIME_GTC, 0, "FirstPendingSell");
   PendingPrice = price + HedgeDistance;
   NextLot *= MoreLotMultiplier;
}

void PendingBuy()
{
   if(NewSellPresent() && NumOfBuy() != 0 && NumOfSell() != 0)
   {
      double lotSize = NextLot;
      double price = PendingPrice;
      
      Trade.BuyStop(lotSize, price, _Symbol, price - STP, price + TKP, ORDER_TIME_GTC, 0, "MorePendingBuy");
      PendingPrice = price - HedgeDistance;
      NextLot *= MoreLotMultiplier;
   }
}

void MorePendingSell()
{
   if(NewBuyPresent() && NumOfBuy() != 0 && NumOfSell() != 0)
   {
      double lotSize = NextLot;
      double price = PendingPrice;
      
      Trade.SellStop(lotSize, price, _Symbol, price + STP, price - TKP, ORDER_TIME_GTC, 0, "MorePendingSell");
      PendingPrice = price + HedgeDistance;
      NextLot *= MoreLotMultiplier;
   }
}

void DeletePending(){
for(int i=0;i<OrdersTotal();i++)
   {
   ulong OrderTicket = OrderGetTicket(i);
   if(OrderTicket!=0)
   {
   Trade.OrderDelete(OrderTicket);
   Print("P/O Deleted successfuly");
      }
   }
}

int NumOfBuy(){

int NumOfBuy = 0;
for(int i=0;i<PositionsTotal();i++){
if(!PositionSelectByTicket(PositionGetTicket(i)))
   continue;
   if(PositionGetInteger(POSITION_MAGIC)!= MagicNumber)
   continue;
   if(PositionGetString(POSITION_SYMBOL)!=Symbol())
   continue;
   if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
   continue;
   NumOfBuy++;
}
 return NumOfBuy;
}

int NumOfSell(){

int NumOfSell = 0;
for(int i=0;i<PositionsTotal();i++){
if(!PositionSelectByTicket(PositionGetTicket(i)))
   continue;
   if(PositionGetInteger(POSITION_MAGIC)!= MagicNumber)
   continue;
   if(PositionGetString(POSITION_SYMBOL)!=Symbol())
   continue;
   if(PositionGetInteger(POSITION_TYPE)!= POSITION_TYPE_SELL)
   continue;
   NumOfSell++;
}
 return NumOfSell;
}

bool NewBuyPresent(){

if(OldNumOfBuy!=NumOfBuy())
{
OldNumOfBuy = NumOfBuy();
return true;
}
return false;

}

bool NewSellPresent(){

if(OldNumOfSell!=NumOfSell())
{
OldNumOfSell = NumOfSell();
return true;
}
return false;

}

bool NewBarPresent(){
int bars = Bars(_Symbol,PERIOD_CURRENT);
if(OldNumOfBars!=bars)
{
OldNumOfBars = bars;
return true;
}
return false;

}
bool CheckVolumeLimit()
{
   double minLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotSize = FirstLot * FirstLotMultiplier;

   if (lotSize < minLotSize || lotSize > maxLotSize)
   {
      Print("Lot size is not within the allowed range.");
      return false;
   }
   return true;
}
bool CheckMoneyForTrade(string symb, double lots, ENUM_ORDER_TYPE type)
{
   // Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symb, mqltick);
   double price = (type == ORDER_TYPE_SELL) ? mqltick.bid : mqltick.ask;

   // Values of the required and free margin
   double margin, free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   // Call the checking function
   if (!OrderCalcMargin(type, symb, lots, price, margin))
   {
      // Something went wrong, report and return false
      Print("Error in ", __FUNCTION__, " code=", GetLastError());
      return false;
   }

   // If there are insufficient funds to perform the operation
   if (margin > free_margin)
   {
      // Report the error and return false
      Print("Not enough money for ", EnumToString(type), " ", lots, " ", symb, " Error code=", GetLastError());
      return false;
   }

   // Checking successful
   return true;
}


//SECOND WORKING APPROVED CODE BUT NOT PROFITABLE
//CAUSE:ONLY OPENS ONE BUY POSITION AND ONE SELL POSITION.
