

#include <Zmq/Zmq.mqh>

extern string PROJECT_NAME = "Mi_server";
extern string ZEROMQ_PROTOCOL = "tcp";
extern string HOSTNAME = "*";
extern int REP_PORT = 1111;
extern int PUSH_PORT = 1112;
extern int MILLISECOND_TIMER = 1;  // 1 millisecond

extern string t0 = "--- Trading Parameters ---";
extern int MagicNumber = 01;
extern int MaximumOrders = 1;
extern double MaximumLotSize = 0.01;
extern int Slippage = 3;
int Total, Ticket, Ticket2;
double StopLossLevel, TakeProfitLevel, StopLevel;

// CREATE ZeroMQ Context
Context context(PROJECT_NAME);

// CREATE ZMQ_REP SOCKET
Socket repSocket(context,ZMQ_REP);

// CREATE ZMQ_PUSH SOCKET
Socket pushSocket(context,ZMQ_PUSH);

// VARIABLES FOR LATER
uchar data[];
ZmqMsg request;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

   EventSetMillisecondTimer(MILLISECOND_TIMER);     // Set Millisecond Timer to get client socket input
   
   Print("[REP] Binding MT4 Server to Socket on Port " + REP_PORT + "..");   
   Print("[PUSH] Binding MT4 Server to Socket on Port " + PUSH_PORT + "..");
   
   repSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT));
   pushSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PUSH_PORT));
   
   /*
       Maximum amount of time in milliseconds that the thread will try to send messages 
       after its socket has been closed (the default value of -1 means to linger forever):
   */
   
   repSocket.setLinger(5000);  // 1000 milliseconds
   
   /* 
      If we initiate socket.send() without having a corresponding socket draining the queue, 
      we'll eat up memory as the socket just keeps enqueueing messages.
      
      So how many messages do we want ZeroMQ to buffer in RAM before blocking the socket?
   */
   
   repSocket.setSendHighWaterMark(20);     // 5 messages only.
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
   Print("[REP] Unbinding MT4 Server from Socket on Port " + REP_PORT + "..");
   repSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT));
   
   Print("[PUSH] Unbinding MT4 Server from Socket on Port " + PUSH_PORT + "..");
   pushSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PUSH_PORT));
   
}
//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
//---

   /*
      For this example, we need:
      1) socket.recv(request,true)
      2) MessageHandler() to process the request
      3) socket.send(reply)
   */
   
   // Get client's response, but don't wait.
   repSocket.recv(request,true);
   
   // MessageHandler() should go here.   
   ZmqMsg reply = MessageHandler(request);
   
   // socket.send(reply) should go here.
   repSocket.send(reply);
}
//+------------------------------------------------------------------+

ZmqMsg MessageHandler(ZmqMsg &request) {
   
   // Output object
   ZmqMsg reply;
   
   // Message components for later.
   string components[];
   
   if(request.size() > 0) {
   
      // Get data from request   
      ArrayResize(data, request.size());
      request.getData(data);
      string dataStr = CharArrayToString(data);
      
      // Process data
      ParseZmqMessage(dataStr, components);
      
      // Interpret data
      InterpretZmqMessage(pushSocket, components);
      
      // Construct response
      ZmqMsg ret(StringFormat("[SERVER] Processing: %s", dataStr));
      reply = ret;
      
   }
   else {
      // NO DATA RECEIVED
   }
   
   return(reply);
}

// Interpret Zmq Message and perform actions
void InterpretZmqMessage(Socket &pSocket, string& compArray[]) {

   Print("ZMQ: Interpreting Message..");
   
   // Message Structures:
   
   // 1) Trading
   // TRADE|ACTION|TYPE|SYMBOL|PRICE|SL|TP|COMMENT|TICKET
   // e.g. TRADE|OPEN|1|EURUSD|0|50|50|R-to-MetaTrader4|12345678
   
   // The 12345678 at the end is the ticket ID, for MODIFY and CLOSE.
   
   // 2) Data Requests
   
   // 2.1) RATES|SYMBOL   -> Returns Current Bid/Ask
   
   // 2.2) DATA|SYMBOL|TIMEFRAME|START_DATETIME|END_DATETIME
   
   // NOTE: datetime has format: D'2015.01.01 00:00'
   
   /*
      compArray[0] = TRADE or RATES
      If RATES -> compArray[1] = Symbol
      
      If TRADE ->
         compArray[0] = TRADE
         compArray[1] = ACTION (e.g. OPEN, MODIFY, CLOSE)
         compArray[2] = TYPE (e.g. OP_BUY, OP_SELL, etc - only used when ACTION=OPEN)
         
         // ORDER TYPES: 
         // https://docs.mql4.com/constants/tradingconstants/orderproperties
         
         // OP_BUY = 0
         // OP_SELL = 1
         // OP_BUYLIMIT = 2
         // OP_SELLLIMIT = 3
         // OP_BUYSTOP = 4
         // OP_SELLSTOP = 5
         
         compArray[3] = Symbol (e.g. EURUSD, etc.)
         compArray[4] = Open/Close Price (ignored if ACTION = MODIFY)
         compArray[5] = SL
         compArray[6] = TP
         compArray[7] = Trade Comment
   */
 
   int switch_action = 0;
   
   if(compArray[0] == "TRADE" && compArray[1] == "OPEN")
      switch_action = 1;
   if(compArray[0] == "RATES")
      switch_action = 2;
   if(compArray[0] == "TRADE" && compArray[1] == "CLOSE")
      switch_action = 3;
   if(compArray[0] == "DATA" )
      switch_action = 4;
   if(compArray[0] == "INFO"&& compArray[1] != "0")
      switch_action = 5;
   if(compArray[0] == "MODIFY"&& compArray[1] != "0")
      switch_action = 6;
   if(compArray[0] == "TIMING")
      switch_action = 7;
   string ret = "";
   string retopen = "";
   string rethigh = "";
   string retlow = "";
   string retclose = "";
   int ticket = -1;
   bool ans = FALSE;
   double price_open[];
   double price_high[];
   double price_low[];
   double price_close[];
   ArraySetAsSeries(price_open, true);
   ArraySetAsSeries(price_high, true);
   ArraySetAsSeries(price_low, true);
   ArraySetAsSeries(price_close, true);
   int price_count = 0;
   double timing_value;
   switch(switch_action) 
   {
      case 1: 
         //InformPullClient(pSocket, "OPEN TRADE Instruction Received");
         if (compArray[2] == "0") {
            StopLossLevel = Ask - StrToDouble(compArray[4]) * Point;
            TakeProfitLevel = Ask + StrToDouble(compArray[5]) * Point;
            //InformPullClient(pSocket, "Buy Order");
            Ticket= OrderSend(compArray[3], OP_BUY, MaximumLotSize, Ask, Slippage, StopLossLevel,TakeProfitLevel, "Buy(#" + MagicNumber + ")", MagicNumber, 0, DodgerBlue);
            if(Ticket > 0) {
               if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
      				Print("BUY order opened : ", OrderOpenPrice());
      				InformPullClient(pSocket, IntegerToString(Ticket));}
                  } 
               else {
                  InformPullClient(pSocket, "OrderSend failed");
                  Print("Error opening BUY order : ", GetLastError());
               
              }
   			}
   		if (compArray[2] == "1") {
            StopLossLevel = Bid + StrToDouble(compArray[4]) * Point;
            TakeProfitLevel = Bid - StrToDouble(compArray[5]) * Point;
            //InformPullClient(pSocket, "Buy Order");
            Ticket= OrderSend(compArray[3], OP_SELL, MaximumLotSize, Bid, Slippage, StopLossLevel,TakeProfitLevel, "Sell(#" + MagicNumber + ")", MagicNumber, 0, DodgerBlue);
            if(Ticket > 0) {
               if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
      				Print("SELL order opened : ", OrderOpenPrice());
      				InformPullClient(pSocket, IntegerToString(Ticket));}
                  } 
               else {
                  InformPullClient(pSocket, "OrderSend failed");
                  Print("Error opening SELL order : ", GetLastError());
               
              }
   			}
         break;
      case 2: 
         ret = "N/A"; 
         if(ArraySize(compArray) > 1) 
            ret = GetBidAsk(compArray[1]); 
         InformPullClient(pSocket, ret); 
         break;
      case 3:
         if (compArray[2] == "0") {
            OrderSelect(StrToInteger(compArray[3]), SELECT_BY_TICKET, MODE_TRADES);
            Ticket2=OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, MediumSeaGreen);
            
            ret = StringFormat("Trade Closed (Ticket: %d)", ticket);
            InformPullClient(pSocket, ret);
            }
         if (compArray[2] == "1") {
            OrderSelect(StrToInteger(compArray[3]), SELECT_BY_TICKET, MODE_TRADES);
            Ticket2 = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, DarkOrange);
            }
         break;
     
      case 4:
         //InformPullClient(pSocket, "HISTORICAL DATA Instruction Received");
         
         // Format: DATA|SYMBOL|TIMEFRAME|START_DATETIME|END_DATETIME
         CopyOpen(compArray[1], StrToInteger(compArray[2]), 
                        StrToInteger(compArray[3]), StrToInteger(compArray[4]), 
                        price_open);
          CopyHigh(compArray[1], StrToInteger(compArray[2]), 
                        StrToInteger(compArray[3]), StrToInteger(compArray[4]), 
                        price_high);
         CopyLow(compArray[1], StrToInteger(compArray[2]), 
                        StrToInteger(compArray[3]), StrToInteger(compArray[4]), 
                        price_low);
         price_count = CopyClose(compArray[1], StrToInteger(compArray[2]), 
                        StrToInteger(compArray[3]), StrToInteger(compArray[4]), 
                        price_close);               
         if (price_count > 0) {
            ret = "";
            retopen = "";
            rethigh = "";
            retlow = "";
            retclose = "";
            
            // Construct string of price|price|price|.. etc and send to PULL client.
            for(int i = 0; i < price_count; i++ ) {
               
               if(i == 0)
               {
                  retopen = compArray[1] + "|" + DoubleToStr(price_open[i], 5);
                  rethigh = compArray[1] + "|" + DoubleToStr(price_high[i], 5);
                  retlow = compArray[1] + "|" + DoubleToStr(price_low[i], 5);
                  retclose = compArray[1] + "|" + DoubleToStr(price_close[i], 5);
               }
               else if(i > 0) {
                  retopen = retopen + "|" + DoubleToStr(price_open[i], 5);
                  rethigh = rethigh + "|" + DoubleToStr(price_high[i], 5);
                  retlow = retlow + "|" + DoubleToStr(price_low[i], 5);
                  retclose = retclose + "|" + DoubleToStr(price_close[i], 5);
               }   
            }
            ret = retopen + "&" + rethigh + "&" + retlow +"&" +retclose ;
            Print("Sending: " + ret);
            
            // Send data to PULL client.
            InformPullClient(pSocket, StringFormat("%s", ret));
            // ret = "";
         }
            
         break;
      /// get_info
      case 5: 
         ret = "";              
         OrderSelect(StrToInteger(compArray[1]), SELECT_BY_TICKET, MODE_TRADES);
         ret = IntegerToString( int(OrderCloseTime()))+"|"+ DoubleToStr(OrderProfit())+ "|"+ DoubleToStr(OrderProfit()/ MaximumLotSize) 
         + "|"+DoubleToStr(OrderOpenPrice())+ "|"+ DoubleToStr(OrderStopLoss()) + "|"+ DoubleToStr(OrderTakeProfit());
         InformPullClient(pSocket, ret); 
         Comment(int(OrderCloseTime()));
         break;
         
      // modify
      case 6: 
         ret = "";
        
         OrderSelect(StrToInteger(compArray[1]), SELECT_BY_TICKET, MODE_TRADES);
         OrderModify(OrderTicket(),OrderOpenPrice(),StringToDouble(compArray[2]),OrderTakeProfit(),0,Blue);
         ret = StrToInteger(OrdersTotal())+"|"+ DoubleToStr(OrderProfit());
         InformPullClient(pSocket, ret); 
         break;
            
      default: 
         break;
   
     case 7:
         ret = ""; 
         timing_value = timing(compArray[1], StrToInteger(compArray[2]));
         
         ret = DoubleToStr(timing_value); 
         InformPullClient(pSocket, ret); 
        break;
   }  
}

// Parse Zmq Message
void ParseZmqMessage(string& message, string& retArray[]) {
   
   Print("Parsing: " + message);
   
   string sep = "|";
   ushort u_sep = StringGetCharacter(sep,0);
   
   int splits = StringSplit(message, u_sep, retArray);
   
   for(int i = 0; i < splits; i++) {
      Print(i + ") " + retArray[i]);
   }
}

//+------------------------------------------------------------------+
// Generate string for Bid/Ask by symbol
string GetBidAsk(string symbol) {
   
   double bid = MarketInfo(symbol, MODE_BID);
   double ask = MarketInfo(symbol, MODE_ASK);
   
   return(StringFormat("%f|%f", bid, ask));
}

// Inform Client
void InformPullClient(Socket& pushSocket, string message) {

   ZmqMsg pushReply(StringFormat("%s", message));
   // pushSocket.send(pushReply,true,false);
   
   pushSocket.send(pushReply,true); // NON-BLOCKING
   // pushSocket.send(pushReply,false); // BLOCKING
   
}


double timing(string symbol, int timeframe){
   int Len = 7;
   double ld_0;
   double ld_8;
   double ld_16;
   double ld_24;
   double ld_32;
   double ld_40;
   double ld_48;
   double ld_56;
   double ld_64;
   double ld_72;
   double ld_80;
   double ld_88;
   double ld_96;
   double ld_104;
   double ld_112;
   double ld_120;
   double ld_128;
   double ld_136;
   double ld_144;
   double ld_152;
   double ld_160;
   double ld_168;
   double ld_176;
   double ld_184;
   double ld_192;
   double ld_200;
   double ld_208;
   double ld_216 = 100 - Len - 1;
   for (int li_224 = ld_216; li_224 >= 0; li_224--) {
      if (ld_8 == 0.0) {
         ld_8 = 1.0;
         ld_16 = 0.0;
         if (Len - 1 >= 5) ld_0 = Len - 1.0;
         else ld_0 = 5.0;
         ld_80 = 100.0 * ((iHigh(symbol,timeframe,li_224) + iLow(symbol,timeframe,li_224) + iClose(symbol,timeframe,li_224)) / 3.0);
         ld_96 = 3.0 / (Len + 2.0);
         ld_104 = 1.0 - ld_96;
      } else {
         if (ld_0 <= ld_8) ld_8 = ld_0 + 1.0;
         else ld_8 += 1.0;
         ld_88 = ld_80;
         ld_80 = 100.0 * ((iHigh(symbol,timeframe,li_224) + iLow(symbol,timeframe,li_224) + iClose(symbol,timeframe,li_224)) / 3.0);
         ld_32 = ld_80 - ld_88;
         ld_112 = ld_104 * ld_112 + ld_96 * ld_32;
         ld_120 = ld_96 * ld_112 + ld_104 * ld_120;
         ld_40 = 1.5 * ld_112 - ld_120 / 2.0;
         ld_128 = ld_104 * ld_128 + ld_96 * ld_40;
         ld_208 = ld_96 * ld_128 + ld_104 * ld_208;
         ld_48 = 1.5 * ld_128 - ld_208 / 2.0;
         ld_136 = ld_104 * ld_136 + ld_96 * ld_48;
         ld_152 = ld_96 * ld_136 + ld_104 * ld_152;
         ld_56 = 1.5 * ld_136 - ld_152 / 2.0;
         ld_160 = ld_104 * ld_160 + ld_96 * MathAbs(ld_32);
         ld_168 = ld_96 * ld_160 + ld_104 * ld_168;
         ld_64 = 1.5 * ld_160 - ld_168 / 2.0;
         ld_176 = ld_104 * ld_176 + ld_96 * ld_64;
         ld_184 = ld_96 * ld_176 + ld_104 * ld_184;
         ld_144 = 1.5 * ld_176 - ld_184 / 2.0;
         ld_192 = ld_104 * ld_192 + ld_96 * ld_144;
         ld_200 = ld_96 * ld_192 + ld_104 * ld_200;
         ld_72 = 1.5 * ld_192 - ld_200 / 2.0;
         if (ld_0 >= ld_8 && ld_80 != ld_88) ld_16 = 1.0;
         if (ld_0 == ld_8 && ld_16 == 0.0) ld_8 = 0.0;
      }
      if (ld_0 < ld_8 && ld_72 > 0.0000000001) {
         ld_24 = 50.0 * (ld_56 / ld_72 + 1.0);
         if (ld_24 > 100.0) ld_24 = 100.0;
         if (ld_24 < 0.0) ld_24 = 0.0;
      } else ld_24 = 50.0;
      
      }
   //Comment(string(ld_0)+"_|_"+ string(ld_24));
   return (ld_24);
}