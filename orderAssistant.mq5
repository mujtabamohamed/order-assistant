//+------------------------------------------------------------------+
//|                                     OrderAssistant.mq5           |
//+------------------------------------------------------------------+
#property copyright "Expert MQL5 Developer"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input parameters
input string   InpSymbol = "EURUSD";        // Trading Symbol
input bool     InpDryRun = false;           // Dry Run Mode (Simulation)

//--- Global variables
CTrade         trade;
CPositionInfo  posInfo;
COrderInfo     ordInfo;

int            g_MagicNumber;                // Random magic number for this session
datetime       g_SessionStartTime;           // Session start timestamp
string         g_CurrentSymbol;              // Active trading symbol

//--- GUI Input values
double         g_LotSize = 0.01;
double         g_TakeProfit = 0;             // TP in USD
double         g_StopLoss = 0;               // SL in USD
int            g_NumberOfOrders = 1;
double         g_SpaceBetweenOrders = 10;    // Space in USD
int            g_Direction = 0;              // 0=BUY, 1=SELL, 2=BUY STOP, 3=SELL STOP
double         g_LimitPrice = 0;             // If 0, auto-calculate

//--- GUI Object names
#define GUI_BASE_NAME "OrderManager_"
#define GUI_PANEL     GUI_BASE_NAME + "Panel"
#define GUI_BG        GUI_BASE_NAME + "Background"

//--- GUI Layout constants
#define PANEL_X       20
#define PANEL_Y       50
#define PANEL_WIDTH   400
#define PANEL_HEIGHT  650
#define ROW_HEIGHT    35
#define LABEL_WIDTH   150
#define INPUT_WIDTH   200
#define BUTTON_HEIGHT 30
#define MARGIN        10

//--- GUI Button names
#define BTN_PLACE_ORDER        GUI_BASE_NAME + "BtnPlaceOrder"
#define BTN_CLOSE_ALL_PENDING  GUI_BASE_NAME + "BtnCloseAllPending"
#define BTN_CLOSE_RT_PENDING   GUI_BASE_NAME + "BtnCloseRTPending"
#define BTN_CLOSE_PROFITABLE   GUI_BASE_NAME + "BtnCloseProfitable"
#define BTN_CLOSE_LOSS         GUI_BASE_NAME + "BtnCloseLoss"
#define BTN_DIR_BUY            GUI_BASE_NAME + "BtnDirBuy"
#define BTN_DIR_SELL           GUI_BASE_NAME + "BtnDirSell"
#define BTN_DIR_BUYSTOP        GUI_BASE_NAME + "BtnDirBuyStop"
#define BTN_DIR_SELLSTOP       GUI_BASE_NAME + "BtnDirSellStop"

//--- GUI Input field names
#define INPUT_LOT_SIZE         GUI_BASE_NAME + "InputLotSize"
#define INPUT_TP               GUI_BASE_NAME + "InputTP"
#define INPUT_SL               GUI_BASE_NAME + "InputSL"
#define INPUT_NUM_ORDERS       GUI_BASE_NAME + "InputNumOrders"
#define INPUT_SPACE            GUI_BASE_NAME + "InputSpace"
#define INPUT_LIMIT            GUI_BASE_NAME + "InputLimit"

//--- Display labels
#define LABEL_BUY_LOTS         GUI_BASE_NAME + "LabelBuyLots"
#define LABEL_SELL_LOTS        GUI_BASE_NAME + "LabelSellLots"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Generate random magic number for this session
   MathSrand((int)TimeLocal());
   g_MagicNumber = MathRand() * 10000 + MathRand();
   g_SessionStartTime = TimeCurrent();
   g_CurrentSymbol = InpSymbol;
   
   //--- Setup trade object
   trade.SetExpertMagicNumber(g_MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.LogLevel(LOG_LEVEL_ERRORS);
   
   //--- Log session start
   LogInfo("=== EA SESSION STARTED ===");
   LogInfo(StringFormat("Magic Number: %d", g_MagicNumber));
   LogInfo(StringFormat("Symbol: %s", g_CurrentSymbol));
   LogInfo(StringFormat("Dry Run Mode: %s", InpDryRun ? "ENABLED" : "DISABLED"));
   LogInfo(StringFormat("Session Time: %s", TimeToString(g_SessionStartTime, TIME_DATE|TIME_SECONDS)));
   
   //--- Create GUI
   if(!CreateGUI())
   {
      LogError("Failed to create GUI");
      return(INIT_FAILED);
   }
   
   //--- Enable chart events
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
   
   //--- Update display
   UpdateDisplay();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Remove all GUI objects
   DeleteGUI();
   
   //--- Log session end
   LogInfo(StringFormat("=== EA SESSION ENDED (Reason: %d) ===", reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Update display values on each tick
   UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      //--- Handle button clicks
      if(sparam == BTN_PLACE_ORDER)
      {
         ReadGUIInputs();
         HandlePlaceOrder();
         ObjectSetInteger(0, BTN_PLACE_ORDER, OBJPROP_STATE, false);
      }
      else if(sparam == BTN_CLOSE_ALL_PENDING)
      {
         HandleCloseAllPending();
         ObjectSetInteger(0, BTN_CLOSE_ALL_PENDING, OBJPROP_STATE, false);
      }
      else if(sparam == BTN_CLOSE_RT_PENDING)
      {
         HandleCloseRuntimePending();
         ObjectSetInteger(0, BTN_CLOSE_RT_PENDING, OBJPROP_STATE, false);
      }
      else if(sparam == BTN_CLOSE_PROFITABLE)
      {
         HandleCloseProfitable();
         ObjectSetInteger(0, BTN_CLOSE_PROFITABLE, OBJPROP_STATE, false);
      }
      else if(sparam == BTN_CLOSE_LOSS)
      {
         HandleCloseLoss();
         ObjectSetInteger(0, BTN_CLOSE_LOSS, OBJPROP_STATE, false);
      }
      else if(sparam == BTN_DIR_BUY)
      {
         g_Direction = 0;
         UpdateDirectionButtons();
         ObjectSetInteger(0, BTN_DIR_BUY, OBJPROP_STATE, false);
      }
      else if(sparam == BTN_DIR_SELL)
      {
         g_Direction = 1;
         UpdateDirectionButtons();
         ObjectSetInteger(0, BTN_DIR_SELL, OBJPROP_STATE, false);
      }
      else if(sparam == BTN_DIR_BUYSTOP)
      {
         g_Direction = 2;
         UpdateDirectionButtons();
         ObjectSetInteger(0, BTN_DIR_BUYSTOP, OBJPROP_STATE, false);
      }
      else if(sparam == BTN_DIR_SELLSTOP)
      {
         g_Direction = 3;
         UpdateDirectionButtons();
         ObjectSetInteger(0, BTN_DIR_SELLSTOP, OBJPROP_STATE, false);
      }
      
      ChartRedraw();
   }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      //--- Read inputs when user finishes editing
      ReadGUIInputs();
   }
}

//+------------------------------------------------------------------+
//| Create GUI Panel                                                 |
//+------------------------------------------------------------------+
bool CreateGUI()
{
   int yPos = PANEL_Y + MARGIN;
   
   //--- Create background rectangle
   if(!CreateRectangle(GUI_BG, PANEL_X, PANEL_Y, PANEL_WIDTH, PANEL_HEIGHT, clrBlack, clrWhite, 2))
      return false;
   
   //--- Title
   if(!CreateLabel(GUI_BASE_NAME + "Title", PANEL_X + PANEL_WIDTH/2, yPos, "ADVANCED ORDER MANAGER", clrWhite, 12, ANCHOR_CENTER))
      return false;
   yPos += ROW_HEIGHT;
   
   //--- Symbol display
   if(!CreateLabel(GUI_BASE_NAME + "SymbolLabel", PANEL_X + MARGIN, yPos, "Symbol: " + g_CurrentSymbol, clrYellow, 10))
      return false;
   yPos += ROW_HEIGHT;
   
   //--- Magic number display
   if(!CreateLabel(GUI_BASE_NAME + "MagicLabel", PANEL_X + MARGIN, yPos, "Magic: " + IntegerToString(g_MagicNumber), clrYellow, 10))
      return false;
   yPos += ROW_HEIGHT;
   
   //--- Lot Size
   if(!CreateLabel(GUI_BASE_NAME + "LblLot", PANEL_X + MARGIN, yPos, "Lot Size:", clrWhite, 10))
      return false;
   if(!CreateEdit(INPUT_LOT_SIZE, PANEL_X + LABEL_WIDTH, yPos - 5, INPUT_WIDTH, 25, "0.01"))
      return false;
   yPos += ROW_HEIGHT;
   
   //--- Take Profit
   if(!CreateLabel(GUI_BASE_NAME + "LblTP", PANEL_X + MARGIN, yPos, "Take Profit (USD):", clrWhite, 10))
      return false;
   if(!CreateEdit(INPUT_TP, PANEL_X + LABEL_WIDTH, yPos - 5, INPUT_WIDTH, 25, "0"))
      return false;
   yPos += ROW_HEIGHT;
   
   //--- Stop Loss
   if(!CreateLabel(GUI_BASE_NAME + "LblSL", PANEL_X + MARGIN, yPos, "Stop Loss (USD):", clrWhite, 10))
      return false;
   if(!CreateEdit(INPUT_SL, PANEL_X + LABEL_WIDTH, yPos - 5, INPUT_WIDTH, 25, "0"))
      return false;
   yPos += ROW_HEIGHT;
   
   //--- Number of Orders
   if(!CreateLabel(GUI_BASE_NAME + "LblNum", PANEL_X + MARGIN, yPos, "Number of Orders:", clrWhite, 10))
      return false;
   if(!CreateEdit(INPUT_NUM_ORDERS, PANEL_X + LABEL_WIDTH, yPos - 5, INPUT_WIDTH, 25, "1"))
      return false;
   yPos += ROW_HEIGHT;
   
   //--- Space Between Orders
   if(!CreateLabel(GUI_BASE_NAME + "LblSpace", PANEL_X + MARGIN, yPos, "Space (USD):", clrWhite, 10))
      return false;
   if(!CreateEdit(INPUT_SPACE, PANEL_X + LABEL_WIDTH, yPos - 5, INPUT_WIDTH, 25, "10"))
      return false;
   yPos += ROW_HEIGHT;
   
   //--- Limit Price
   if(!CreateLabel(GUI_BASE_NAME + "LblLimit", PANEL_X + MARGIN, yPos, "Limit Price:", clrWhite, 10))
      return false;
   if(!CreateEdit(INPUT_LIMIT, PANEL_X + LABEL_WIDTH, yPos - 5, INPUT_WIDTH, 25, "0"))
      return false;
   yPos += ROW_HEIGHT;
   
   //--- Direction buttons
   if(!CreateLabel(GUI_BASE_NAME + "LblDir", PANEL_X + MARGIN, yPos, "Direction:", clrWhite, 10))
      return false;
   yPos += 25;
   
   int btnWidth = (PANEL_WIDTH - 3*MARGIN) / 4;
   if(!CreateButton(BTN_DIR_BUY, PANEL_X + MARGIN, yPos, btnWidth, BUTTON_HEIGHT, "BUY", clrGreen))
      return false;
   if(!CreateButton(BTN_DIR_SELL, PANEL_X + MARGIN + btnWidth + 5, yPos, btnWidth, BUTTON_HEIGHT, "SELL", clrRed))
      return false;
   if(!CreateButton(BTN_DIR_BUYSTOP, PANEL_X + MARGIN + 2*(btnWidth + 5), yPos, btnWidth, BUTTON_HEIGHT, "BUY STOP", clrLimeGreen))
      return false;
   if(!CreateButton(BTN_DIR_SELLSTOP, PANEL_X + MARGIN + 3*(btnWidth + 5), yPos, btnWidth, BUTTON_HEIGHT, "SELL STOP", clrOrangeRed))
      return false;
   yPos += BUTTON_HEIGHT + MARGIN;
   UpdateDirectionButtons();
   
   //--- Place Order button
   if(!CreateButton(BTN_PLACE_ORDER, PANEL_X + MARGIN, yPos, PANEL_WIDTH - 2*MARGIN, BUTTON_HEIGHT, "PLACE ORDER", clrDodgerBlue))
      return false;
   yPos += BUTTON_HEIGHT + MARGIN;
   
   //--- Separator
   yPos += 10;
   
   //--- Close buttons
   if(!CreateButton(BTN_CLOSE_ALL_PENDING, PANEL_X + MARGIN, yPos, PANEL_WIDTH - 2*MARGIN, BUTTON_HEIGHT, "CL ALL Pending (0)", clrOrange))
      return false;
   yPos += BUTTON_HEIGHT + 5;
   
   if(!CreateButton(BTN_CLOSE_RT_PENDING, PANEL_X + MARGIN, yPos, PANEL_WIDTH - 2*MARGIN, BUTTON_HEIGHT, "CL Pending (0)", clrOrangeRed))
      return false;
   yPos += BUTTON_HEIGHT + 5;
   
   if(!CreateButton(BTN_CLOSE_PROFITABLE, PANEL_X + MARGIN, yPos, PANEL_WIDTH - 2*MARGIN, BUTTON_HEIGHT, "CL Profitable (0)", clrGreen))
      return false;
   yPos += BUTTON_HEIGHT + 5;
   
   if(!CreateButton(BTN_CLOSE_LOSS, PANEL_X + MARGIN, yPos, PANEL_WIDTH - 2*MARGIN, BUTTON_HEIGHT, "CL Loss (0)", clrRed))
      return false;
   yPos += BUTTON_HEIGHT + MARGIN;
   
   //--- Display values
   yPos += 10;
   if(!CreateLabel(LABEL_BUY_LOTS, PANEL_X + MARGIN, yPos, "Total BUY Lots: 0.00", clrLimeGreen, 11))
      return false;
   yPos += 25;
   if(!CreateLabel(LABEL_SELL_LOTS, PANEL_X + MARGIN, yPos, "Total SELL Lots: 0.00", clrOrangeRed, 11))
      return false;
   
   ChartRedraw();
   return true;
}

//+------------------------------------------------------------------+
//| Delete all GUI objects                                           |
//+------------------------------------------------------------------+
void DeleteGUI()
{
   ObjectsDeleteAll(0, GUI_BASE_NAME);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create rectangle object                                          |
//+------------------------------------------------------------------+
bool CreateRectangle(string name, int x, int y, int width, int height, color bgColor, color borderColor, int borderWidth)
{
   if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      return false;
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, borderWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   
   return true;
}

//+------------------------------------------------------------------+
//| Create label object                                              |
//+------------------------------------------------------------------+
bool CreateLabel(string name, int x, int y, string text, color clr, int fontSize, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
{
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      return false;
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   
   return true;
}

//+------------------------------------------------------------------+
//| Create edit box object                                           |
//+------------------------------------------------------------------+
bool CreateEdit(string name, int x, int y, int width, int height, string text)
{
   if(!ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0))
      return false;
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   
   return true;
}

//+------------------------------------------------------------------+
//| Create button object                                             |
//+------------------------------------------------------------------+
bool CreateButton(string name, int x, int y, int width, int height, string text, color clr)
{
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
      return false;
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   
   return true;
}

//+------------------------------------------------------------------+
//| Read values from GUI input fields                                |
//+------------------------------------------------------------------+
void ReadGUIInputs()
{
   g_LotSize = StringToDouble(ObjectGetString(0, INPUT_LOT_SIZE, OBJPROP_TEXT));
   g_TakeProfit = StringToDouble(ObjectGetString(0, INPUT_TP, OBJPROP_TEXT));
   g_StopLoss = StringToDouble(ObjectGetString(0, INPUT_SL, OBJPROP_TEXT));
   g_NumberOfOrders = (int)StringToInteger(ObjectGetString(0, INPUT_NUM_ORDERS, OBJPROP_TEXT));
   g_SpaceBetweenOrders = StringToDouble(ObjectGetString(0, INPUT_SPACE, OBJPROP_TEXT));
   g_LimitPrice = StringToDouble(ObjectGetString(0, INPUT_LIMIT, OBJPROP_TEXT));
   
   //--- Validate inputs
   if(g_LotSize <= 0) g_LotSize = 0.01;
   if(g_NumberOfOrders < 1) g_NumberOfOrders = 1;
   if(g_SpaceBetweenOrders < 0) g_SpaceBetweenOrders = 0;
}

//+------------------------------------------------------------------+
//| Update direction button states                                   |
//+------------------------------------------------------------------+
void UpdateDirectionButtons()
{
   ObjectSetInteger(0, BTN_DIR_BUY, OBJPROP_BGCOLOR, g_Direction == 0 ? clrDarkGreen : clrGreen);
   ObjectSetInteger(0, BTN_DIR_SELL, OBJPROP_BGCOLOR, g_Direction == 1 ? clrDarkRed : clrRed);
   ObjectSetInteger(0, BTN_DIR_BUYSTOP, OBJPROP_BGCOLOR, g_Direction == 2 ? clrDarkGreen : clrLimeGreen);
   ObjectSetInteger(0, BTN_DIR_SELLSTOP, OBJPROP_BGCOLOR, g_Direction == 3 ? clrDarkRed : clrOrangeRed);
}

//+------------------------------------------------------------------+
//| Update display values                                            |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   //--- Count lots by direction
   double buyLots = 0, sellLots = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == g_CurrentSymbol)
         {
            if(posInfo.PositionType() == POSITION_TYPE_BUY)
               buyLots += posInfo.Volume();
            else if(posInfo.PositionType() == POSITION_TYPE_SELL)
               sellLots += posInfo.Volume();
         }
      }
   }
   
   //--- Count orders
   int allPending = 0, rtPending = 0, profitable = 0, loss = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(ordInfo.SelectByIndex(i))
      {
         if(ordInfo.Symbol() == g_CurrentSymbol)
         {
            allPending++;
            if(ordInfo.Magic() == g_MagicNumber && ordInfo.TimeSetup() >= g_SessionStartTime)
               rtPending++;
         }
      }
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == g_CurrentSymbol && posInfo.Magic() == g_MagicNumber && 
            posInfo.Time() >= g_SessionStartTime)
         {
            if(posInfo.Profit() > 0) profitable++;
            else if(posInfo.Profit() < 0) loss++;
         }
      }
   }
   
   //--- Update labels
   ObjectSetString(0, LABEL_BUY_LOTS, OBJPROP_TEXT, StringFormat("Total BUY Lots: %.2f", buyLots));
   ObjectSetString(0, LABEL_SELL_LOTS, OBJPROP_TEXT, StringFormat("Total SELL Lots: %.2f", sellLots));
   
   //--- Update button labels
   ObjectSetString(0, BTN_CLOSE_ALL_PENDING, OBJPROP_TEXT, StringFormat("CL ALL Pending (%d)", allPending));
   ObjectSetString(0, BTN_CLOSE_RT_PENDING, OBJPROP_TEXT, StringFormat("CL Pending (%d)", rtPending));
   ObjectSetString(0, BTN_CLOSE_PROFITABLE, OBJPROP_TEXT, StringFormat("CL Profitable (%d)", profitable));
   ObjectSetString(0, BTN_CLOSE_LOSS, OBJPROP_TEXT, StringFormat("CL Loss (%d)", loss));
}

//+------------------------------------------------------------------+
//| Handle Place Order button                                        |
//+------------------------------------------------------------------+
void HandlePlaceOrder()
{
   LogInfo("=== PLACE ORDER REQUEST ===");
   LogInfo(StringFormat("Direction: %s, Lots: %.2f, Orders: %d", GetDirectionString(), g_LotSize, g_NumberOfOrders));
   
   //--- Get current market price
   double currentPrice = (g_Direction == 0 || g_Direction == 2) ? 
                         SymbolInfoDouble(g_CurrentSymbol, SYMBOL_ASK) : 
                         SymbolInfoDouble(g_CurrentSymbol, SYMBOL_BID);
   
   //--- Calculate space in price
   double spaceInPrice = USDToPriceDistance(g_SpaceBetweenOrders);
   
   //--- Determine first order price
   double firstPrice;
   if(g_LimitPrice > 0)
   {
      firstPrice = g_LimitPrice;
   }
   else
   {
      //--- Auto-calculate based on direction
      if(g_Direction == 0) // BUY
         firstPrice = currentPrice - spaceInPrice;
      else if(g_Direction == 1) // SELL
         firstPrice = currentPrice + spaceInPrice;
      else if(g_Direction == 2) // BUY STOP
         firstPrice = currentPrice + spaceInPrice;
      else // SELL STOP
         firstPrice = currentPrice - spaceInPrice;
   }
   
   //--- Calculate TP/SL in price
   double tpPrice = 0, slPrice = 0;
   if(g_TakeProfit > 0)
   {
      double tpDistance = USDToPriceDistance(g_TakeProfit);
      if(g_Direction == 0 || g_Direction == 2) // BUY types
         tpPrice = firstPrice + tpDistance;
      else // SELL types
         tpPrice = firstPrice - tpDistance;
   }
   
   if(g_StopLoss > 0)
   {
      double slDistance = USDToPriceDistance(g_StopLoss);
      if(g_Direction == 0 || g_Direction == 2) // BUY types
         slPrice = firstPrice - slDistance;
      else // SELL types
         slPrice = firstPrice + slDistance;
   }
   
   //--- Place orders
   for(int i = 0; i < g_NumberOfOrders; i++)
   {
      double orderPrice = firstPrice + (spaceInPrice * i * ((g_Direction == 0 || g_Direction == 3) ? -1 : 1));
      double orderTP = (tpPrice > 0) ? (tpPrice + (spaceInPrice * i * ((g_Direction == 0 || g_Direction == 3) ? -1 : 1))) : 0;
      double orderSL = (slPrice > 0) ? (slPrice + (spaceInPrice * i * ((g_Direction == 0 || g_Direction == 3) ? -1 : 1))) : 0;
      
      PlaceOrder(orderPrice, orderTP, orderSL, i + 1);
   }
   
   UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Place single order                                               |
//+------------------------------------------------------------------+
void PlaceOrder(double price, double tp, double sl, int orderNum)
{
   if(InpDryRun)
   {
      LogInfo(StringFormat("[DRY RUN] Order #%d: %s at %.5f, TP=%.5f, SL=%.5f, Lot=%.2f", 
              orderNum, GetDirectionString(), price, tp, sl, g_LotSize));
      return;
   }
   
   bool result = false;
   
   if(g_Direction == 0) // BUY
   {
      result = trade.Buy(g_LotSize, g_CurrentSymbol, price, sl, tp, "OrderManager");
   }
   else if(g_Direction == 1) // SELL
   {
      result = trade.Sell(g_LotSize, g_CurrentSymbol, price, sl, tp, "OrderManager");
   }
   else if(g_Direction == 2) // BUY STOP
   {
      result = trade.BuyStop(g_LotSize, price, g_CurrentSymbol, sl, tp, ORDER_TIME_GTC, 0, "OrderManager");
   }
   else if(g_Direction == 3) // SELL STOP
   {
      result = trade.SellStop(g_LotSize, price, g_CurrentSymbol, sl, tp, ORDER_TIME_GTC, 0, "OrderManager");
   }
   
   if(result)
   {
      LogInfo(StringFormat("Order #%d placed successfully: %s at %.5f", orderNum, GetDirectionString(), price));
   }
   else
   {
      LogError(StringFormat("Failed to place order #%d: %s (Error: %d)", orderNum, GetDirectionString(), GetLastError()));
   }
}

//+------------------------------------------------------------------+
//| Handle Close All Pending button                                  |
//+------------------------------------------------------------------+
void HandleCloseAllPending()
{
   //--- Count pending orders
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(ordInfo.SelectByIndex(i))
      {
         if(ordInfo.Symbol() == g_CurrentSymbol)
            count++;
      }
   }
   
   if(count == 0)
   {
      MessageBox("No pending orders to close.", "Information", MB_OK | MB_ICONINFORMATION);
      return;
   }
   
   //--- Confirm action
   int response = MessageBox(StringFormat("Close ALL %d pending orders for %s?", count, g_CurrentSymbol),
                             "Confirm Action", MB_YESNO | MB_ICONQUESTION);
   
   if(response != IDYES)
      return;
   
   LogInfo(StringFormat("=== CLOSING ALL PENDING ORDERS (%d) ===", count));
   
   //--- Close orders
   int closed = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(ordInfo.SelectByIndex(i))
      {
         if(ordInfo.Symbol() == g_CurrentSymbol)
         {
            if(InpDryRun)
            {
               LogInfo(StringFormat("[DRY RUN] Close pending order #%lld", ordInfo.Ticket()));
               closed++;
            }
            else
            {
               if(trade.OrderDelete(ordInfo.Ticket()))
               {
                  LogInfo(StringFormat("Closed pending order #%lld", ordInfo.Ticket()));
                  closed++;
               }
               else
               {
                  LogError(StringFormat("Failed to close order #%lld (Error: %d)", ordInfo.Ticket(), GetLastError()));
               }
            }
         }
      }
   }
   
   LogInfo(StringFormat("Closed %d of %d pending orders", closed, count));
   UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Handle Close Runtime Pending button                              |
//+------------------------------------------------------------------+
void HandleCloseRuntimePending()
{
   //--- Count runtime pending orders
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(ordInfo.SelectByIndex(i))
      {
         if(ordInfo.Symbol() == g_CurrentSymbol && ordInfo.Magic() == g_MagicNumber && 
            ordInfo.TimeSetup() >= g_SessionStartTime)
            count++;
      }
   }
   
   if(count == 0)
   {
      MessageBox("No runtime pending orders to close.", "Information", MB_OK | MB_ICONINFORMATION);
      return;
   }
   
   //--- Confirm action
   int response = MessageBox(StringFormat("Close %d runtime pending orders?", count),
                             "Confirm Action", MB_YESNO | MB_ICONQUESTION);
   
   if(response != IDYES)
      return;
   
   LogInfo(StringFormat("=== CLOSING RUNTIME PENDING ORDERS (%d) ===", count));
   
   //--- Close orders
   int closed = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(ordInfo.SelectByIndex(i))
      {
         if(ordInfo.Symbol() == g_CurrentSymbol && ordInfo.Magic() == g_MagicNumber && 
            ordInfo.TimeSetup() >= g_SessionStartTime)
         {
            if(InpDryRun)
            {
               LogInfo(StringFormat("[DRY RUN] Close runtime pending order #%lld", ordInfo.Ticket()));
               closed++;
            }
            else
            {
               if(trade.OrderDelete(ordInfo.Ticket()))
               {
                  LogInfo(StringFormat("Closed runtime pending order #%lld", ordInfo.Ticket()));
                  closed++;
               }
               else
               {
                  LogError(StringFormat("Failed to close order #%lld (Error: %d)", ordInfo.Ticket(), GetLastError()));
               }
            }
         }
      }
   }
   
   LogInfo(StringFormat("Closed %d of %d runtime pending orders", closed, count));
   UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Handle Close Profitable button                                   |
//+------------------------------------------------------------------+
void HandleCloseProfitable()
{
   //--- Count profitable runtime positions
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == g_CurrentSymbol && posInfo.Magic() == g_MagicNumber && 
            posInfo.Time() >= g_SessionStartTime && posInfo.Profit() > 0)
            count++;
      }
   }
   
   if(count == 0)
   {
      MessageBox("No profitable runtime positions to close.", "Information", MB_OK | MB_ICONINFORMATION);
      return;
   }
   
   //--- Confirm action
   int response = MessageBox(StringFormat("Close %d profitable runtime positions?", count),
                             "Confirm Action", MB_YESNO | MB_ICONQUESTION);
   
   if(response != IDYES)
      return;
   
   LogInfo(StringFormat("=== CLOSING PROFITABLE POSITIONS (%d) ===", count));
   
   //--- Close positions
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == g_CurrentSymbol && posInfo.Magic() == g_MagicNumber && 
            posInfo.Time() >= g_SessionStartTime && posInfo.Profit() > 0)
         {
            if(InpDryRun)
            {
               LogInfo(StringFormat("[DRY RUN] Close profitable position #%lld (Profit: %.2f)", 
                       posInfo.Ticket(), posInfo.Profit()));
               closed++;
            }
            else
            {
               if(trade.PositionClose(posInfo.Ticket()))
               {
                  LogInfo(StringFormat("Closed profitable position #%lld (Profit: %.2f)", 
                          posInfo.Ticket(), posInfo.Profit()));
                  closed++;
               }
               else
               {
                  LogError(StringFormat("Failed to close position #%lld (Error: %d)", 
                           posInfo.Ticket(), GetLastError()));
               }
            }
         }
      }
   }
   
   LogInfo(StringFormat("Closed %d of %d profitable positions", closed, count));
   UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Handle Close Loss button                                         |
//+------------------------------------------------------------------+
void HandleCloseLoss()
{
   //--- Count loss-making runtime positions
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == g_CurrentSymbol && posInfo.Magic() == g_MagicNumber && 
            posInfo.Time() >= g_SessionStartTime && posInfo.Profit() < 0)
            count++;
      }
   }
   
   if(count == 0)
   {
      MessageBox("No loss-making runtime positions to close.", "Information", MB_OK | MB_ICONINFORMATION);
      return;
   }
   
   //--- Confirm action
   int response = MessageBox(StringFormat("Close %d loss-making runtime positions?", count),
                             "Confirm Action", MB_YESNO | MB_ICONQUESTION);
   
   if(response != IDYES)
      return;
   
   LogInfo(StringFormat("=== CLOSING LOSS-MAKING POSITIONS (%d) ===", count));
   
   //--- Close positions
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == g_CurrentSymbol && posInfo.Magic() == g_MagicNumber && 
            posInfo.Time() >= g_SessionStartTime && posInfo.Profit() < 0)
         {
            if(InpDryRun)
            {
               LogInfo(StringFormat("[DRY RUN] Close loss position #%lld (Loss: %.2f)", 
                       posInfo.Ticket(), posInfo.Profit()));
               closed++;
            }
            else
            {
               if(trade.PositionClose(posInfo.Ticket()))
               {
                  LogInfo(StringFormat("Closed loss position #%lld (Loss: %.2f)", 
                          posInfo.Ticket(), posInfo.Profit()));
                  closed++;
               }
               else
               {
                  LogError(StringFormat("Failed to close position #%lld (Error: %d)", 
                           posInfo.Ticket(), GetLastError()));
               }
            }
         }
      }
   }
   
   LogInfo(StringFormat("Closed %d of %d loss-making positions", closed, count));
   UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Convert USD to price distance                                    |
//+------------------------------------------------------------------+
double USDToPriceDistance(double usd)
{
   if(usd == 0)
      return 0;
   
   //--- Get symbol properties
   double tickValue = SymbolInfoDouble(g_CurrentSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(g_CurrentSymbol, SYMBOL_TRADE_TICK_SIZE);
   double lotSize = g_LotSize;
   
   if(tickValue == 0 || tickSize == 0)
   {
      LogError("Invalid symbol tick value or tick size");
      return 0;
   }
   
   //--- Calculate price distance
   // USD = (PriceDistance / TickSize) * TickValue * LotSize
   // PriceDistance = (USD * TickSize) / (TickValue * LotSize)
   double priceDistance = (usd * tickSize) / (tickValue * lotSize);
   
   return priceDistance;
}

//+------------------------------------------------------------------+
//| Get direction as string                                          |
//+------------------------------------------------------------------+
string GetDirectionString()
{
   switch(g_Direction)
   {
      case 0: return "BUY";
      case 1: return "SELL";
      case 2: return "BUY STOP";
      case 3: return "SELL STOP";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Log information message                                          |
//+------------------------------------------------------------------+
void LogInfo(string message)
{
   Print("[INFO] ", message);
}

//+------------------------------------------------------------------+
//| Log error message                                                |
//+------------------------------------------------------------------+
void LogError(string message)
{
   Print("[ERROR] ", message);
}

//+------------------------------------------------------------------+