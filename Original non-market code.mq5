//+------------------------------------------------------------------+
//|                                               Newrall BRONZE.mq5 |
//|                                  Copyright 2023, Neurals Project |
//|                                   https://www.neuralsproject.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Neurals Project"
#property link      "https://www.neuralsproject.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

CTrade *Trade;

sinput string General = ""; //GENERAL PARAMETERS
input string EAName = "Newrall BRONZE";
input int MagicNumber = 2004;

sinput string RiskSettings = ""; //RISK PARAMETERS
input double FirstLot = 0.1;
input double FirstLotMultiplier = 3;
input double MoreLotMultiplier = 2;

sinput string ExitSettings = ""; //EXIT PARAMETERS
input int StopLoss = 60;
input int TakeProfit = 30;
input int HedgingDistance = 30;

double ASK,BID,STP,TKP,HedgeDistance,FirstPendingLot = 0,PendingPrice = 0,NextLot = 0;
int OldNumOfBuy = 0,OldNumOfSell = 0, OldNumOfBars = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Trade = new CTrade;
   Trade.SetExpertMagicNumber(MagicNumber);
   
   STP =StopLoss*10*_Point;
   TKP = TakeProfit*10*_Point;
   HedgeDistance = HedgingDistance*10*_Point;
   FirstPendingLot = NormalizeDouble(FirstLot*FirstLotMultiplier,2);
   
//---
   return(INIT_SUCCEEDED);
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
//---
if(NewBarPresent())
{
   ASK = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   BID = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
   if(PositionsTotal()==0){
   DeletePending();
   }
   
   FirstBuy();
   PendingBuy();
   MorePendingSell();
  }
 }
//+------------------------------------------------------------------+

void FirstBuy()
{
if(PositionsTotal()==0){
   if(!Trade.Buy(FirstLot,_Symbol,ASK,ASK-STP,ASK+TKP,"First Buy"))
   return;
   else {
   PendingPrice = ASK-HedgeDistance;
   NextLot = FirstPendingLot;
   PendingSell();
   
       }
    }
   }

void PendingSell()
{
   Trade.SellStop(NextLot,PendingPrice,_Symbol,PendingPrice+STP,PendingPrice-TKP,ORDER_TIME_GTC,0,"FirstPendingSell");
   PendingPrice = PendingPrice+HedgeDistance;
   NextLot = NextLot*MoreLotMultiplier;
}

void PendingBuy()
{
if(NewSellPresent() && NumOfBuy()!=0&&NumOfSell()!=0){


   Trade.BuyStop(NextLot,PendingPrice,_Symbol,PendingPrice-STP,PendingPrice+TKP,ORDER_TIME_GTC,0,"MorePendingBuy");
   PendingPrice = PendingPrice-HedgeDistance;
   NextLot = NextLot*MoreLotMultiplier;
   }
}

void MorePendingSell()
{
if(NewBuyPresent() && NumOfBuy()!=0&&NumOfSell()!=0){


   Trade.SellStop(NextLot,PendingPrice,_Symbol,PendingPrice+STP,PendingPrice-TKP,ORDER_TIME_GTC,0,"MorePendingSell");
   PendingPrice = PendingPrice+HedgeDistance;
   NextLot = NextLot*MoreLotMultiplier;
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

//ORIGINAL CODE
