//+------------------------------------------------------------------+
//|                                                      FlexEA.mq4  |
//|                        Custom Expert Advisor                    |
//+------------------------------------------------------------------+
#include <stdlib.mqh>

#define DEFAULT_STOP_LOSS_PERCENTAGE 0.05  // Example: 5% of available equity
#define INVALID_STRATEGY -1  // Constant for invalid strategy
#define MAX_TP 500           // Maximum Take Profit value (adjust as per your requirement)
#define MAX_LOG_MESSAGE_LENGTH 1024  // Define in a configuration section
#define DEFAULT_TRADE_PERFORMANCE_SIZE 6
#define LOG_LEVEL_ERROR 1
#define MAX_RISK_LEVEL 0.5
#define MAX_SL 500.0
#define DEFAULT_RISK_LEVEL 0.03
#define FALLBACK_ATR 1.0
#define FALLBACK_RSI 50.0
#define FALLBACK_MA 100.0
#define FALLBACK_TREND 0.0
#define TrendThreshold 25  // Example threshold for trend strength
#define NO_FALLBACK_OPTIMIZATION 0
#define ERROR_ADX_INVALID -1  // Error code for invalid ADX value
#define MAX_ARRAY_SIZE 1000  // Define a constant for the maximum array size
#define LEVEL_ERROR LOG_ERROR
#define LEVEL_WARNING LOG_WARNING
#define ERR_VALIDATION_FAILED 1004
#define MAX_STRATEGIES 10
#define INVALID_MARGIN_LEVEL -1
#define EPSILON 0.0001  // Tolerance for indicator values
#define LOG_LEVEL 2
#define MAX_RISK               3.0    // Maximum risk when there is no drawdown
#define MIN_RISK               1.0    // Minimum risk when drawdown reaches or exceeds the threshold
#define FALLBACK_ADX       20.0      // Example fallback value for ADX
#define FALLBACK_UPPERBAND 0.0       // Adjust as appropriate
#define FALLBACK_LOWERBAND 0.0       // Adjust as appropriate
#define INDICATOR_MACD_SIGNAL 1  // MACD Signal Line index
#define MAX_ERROR_COUNT 3

enum TradingStrategy {TrendFollowing, Scalping, RangeBound, Hybrid, CounterTrend, Grid, MeanReversion, Breakout, Momentum, OtherStrategy, SafeMode};
enum RiskLevelType {RiskLow = 1, RiskMedium = 2, RiskHigh = 3};
enum ResetMarketInfoStatus {SUCCESS = 0, SYMBOL_EMPTY = 1, SYMBOL_UNAVAILABLE = 2, LOGGING_ERROR = 3};
enum LogLevel {LOG_NONE = 0, LOG_ERROR = 1, LOG_WARNING = 2, LOG_SUCCESS = 3, LOG_INFO = 4, LOG_DEBUG = 5};
enum OptimizationError {NO_ERROR = 0, PARAMETER_ERROR = 1, PERFORMANCE_ERROR = 2, UNKNOWN_ERROR = 3,SYSTEM_ERROR, NETWORK_ERROR, DEFAULT_ERROR_MESSAGE};
enum OrderStatus {STATUS_OK, STATUS_CLOSED_ALL, STATUS_PYRAMID_SKIPPED, STATUS_SCALE_OUT_SKIPPED, STATUS_CRITICAL_ERROR, STATUS_INVALID_PARAMETER};
enum ParameterType {Param_RiskLevel, Param_SL, Param_TP, Param_ATR};
enum IndicatorType {INDICATOR_RSI, INDICATOR_MACD_MAIN};
enum MarketCondition {VOLATILE, NEUTRAL, REVERSING, TRENDING, RANGE_BOUND, SHORT_TRADE, UNKNOWN};
enum VolatilityCheckError {VOLATILITY_SUCCESS = 0, MISSING_SYMBOL, OUT_OF_RANGE, INSUFFICIENT_DATA, INVALID_ATR, VOLATILITY_TOO_HIGH};
enum IndicatorValidationResult {VALID, INVALID_NAN, INVALID_INFINITY, INVALID_EMPTY_VALUE, INVALID_ZERO, INVALID_RANGE};
enum SimulationErrorCodes {SIMULATION_OK = 0, TIMEOUT = -1, UNEXPECTED_ERROR = -2, INVALID_INPUT = -3, RESOURCE_FAILURE = -4};
enum OptimizationStatus {OPTIMIZATION_SUCCESS = 1, OPTIMIZATION_FAILED = -1, OPTIMIZATION_UNKNOWN = 0};
enum GridDistanceError {GRID_SUCCESS = 0, NEGATIVE_DISTANCE = 1, SMALL_DISTANCE = 2, LARGE_DISTANCE = 3};
enum RiskPercentageError {RISK_SUCCESS = 0, RISK_TOO_LOW = 1, RISK_TOO_HIGH = 2, RISK_NEGATIVE = 3};
enum TransactionCostError {COST_SUCCESS = 0, COST_TOO_LOW = 1, COST_TOO_HIGH = 2, COST_INVALID = 3};
enum OptimizationResult {OPT_SUCCESS, OPT_TIMEOUT, OPT_FAILURE};

input int    MagicNumber = 123456;             // Magic Number to identify orders
input bool   EnablePyramiding = true;         // Enable scaling into winning trades
input bool   EnableScalingOut = true;        // Enable scaling out of losing trades
input double MaxDrawdown = 50;
input double MaxAllowedLotSize = 0.5;  // Max allowed total lot size for pyramiding
input double BaseThreshold = 100.0;  // User-defined base threshold
input double MinPyramidProfitThreshold = 500;  // Minimum profit for pyramiding
input double BaseSL = 50;  // Minimum SL value
input double BaseTP = 100;  // Minimum TP value
input int    MaxOpenOrders = 5; // Adjust the limit as needed
input int    RSIPeriod = 14;                  // RSI period
input int    Slippage = 3;                    // Maximum slippage allowed
input int FastMAPeriod = 50;
input int SlowMAPeriod = 200;
input int Timeframe = PERIOD_H1;
input int MaxPyramidLevels = 3;  // Max pyramid levels (configurable)
input int ADXPeriod = 14;
input int BollingerPeriod = 20;

bool recoveryMode = false;         // Flag for recovery mode
bool debugMode = true; // Set to `false` in production
bool isVerboseLoggingEnabled = true; // or false, depending on your needs
bool DebugMode = true; // Add DebugMode as an extern variable
const bool DEBUG_MODE = true; // Set to false for production
const datetime INVALID_TIME = -1;  // Invalid time marker
const double NaN = -999999.0;  // Choose a value that makes sense in your context
const double INVALID_PRICE = -999999;  // Invalid price constant
const double ATRMultiplier = 1.5;
const int INVALID_ORDER_TYPE = -1;
const int ALERT_INTERVAL = 60, ALL_CLEAR_INTERVAL = 300, ESCALATION_THRESHOLD = 5;
datetime lastLogTime = 0;  // Variable to store the last log time
datetime lastIndicatorUpdateTime = 0;
double cachedATR;  
double cachedFastMA;
double cachedSlowMA;
double cachedRSI;
double MarginThreshold = AccountEquity() * 0.50;   // Define margin threshold as 10% of account equity
double peakEquity = 0;             // Highest equity recorded
double trendStrength;
double SL = 50;         // Stop loss in points, now modifiable
double TP = 100;        // Take profit in points, now modifiable
double TradeRisk = 0.02; // Risk level per trade, now modifiable
double strategyWinRate[6] = {0.5, 0.5, 0.5, 0.5, 0.5, 0.5};  // Array for win rates of each strategy
double tradePerformanceBuffer[];  // Define as a dynamic array
double drawdownThreshold = 0.50;   // Trigger recovery mode if drawdown exceeds 50% (0.50)
double MinMarginLevel = 150;
double cachedADX;
double cachedBollingerWidth;
double volatilityThreshold = 0.1;  // Adjustable threshold for volatility score
double cachedTrendStrength;
double cachedDrawdownPercentage = 0;
double cachedMarketSentiment = 0;
double cachedUpperBand;
double cachedLowerBand;
double cachedIndicators[10];  // Array for multiple indicators
extern int ATRPeriod = 14;  // ATR period (can be adjusted as input)
extern double exitRecoveryThreshold = 0.5;      // Example threshold; set appropriately
int TF = PERIOD_H1;
int strategyConsecutiveLosses[6] = {0, 0, 0, 0, 0, 0};  // Array for consecutive losses for each strategy
int performanceCheckInterval = 60;  // Time interval in seconds for checking performance
int logFileHandle = -1;
int tradeCooldown = 300;    // Minimum time in seconds between trades (e.g., 5 minutes)
int currentLogLevel = LOG_LEVEL_ERROR; // Set log level to error by default
static datetime lastUpdateTime = 0;
static datetime lastCheckedTime = 0;
static int alertCount = 0;
static int tradesSinceLastOptimization = 0;
string LogFileName = "log.txt";

struct TradePerformance {double profit; double duration; int strategy; double entryPrice; double exitPrice; double SL; double TP; double RiskLevel; double winRate; double grossProfit; double grossLoss; int tradeCount; double sharpeRatio; double maxDrawdown;};
struct MarketState {bool isVolatile; bool isBullish; bool isBearish; bool isNeutral; bool isNonVolatile; bool isTrending; double volatilityScore; datetime lastUpdate; double fastMASlope; double slowMASlope; double atr; double bollingerWidth; double prevFastMA; double prevSlowMA;};
struct TradeData {double profit; double duration; int strategy; double entryPrice; double exitPrice; double maxDrawdown; double sharpeRatio;};
struct RingBuffer {TradeData data[]; int capacity; int head; int count;    
    // Initialize the buffer
    void Init(int size) {capacity = size; ArrayResize(data, capacity); head = 0; count = 0;}    
    // Add a trade to the buffer (circular behavior)
    void Add(const TradeData &value) {data[head] = value; head = (head + 1) % capacity;  // Circular increment
        if (count < capacity) {
            count++;
        } else {
            // Buffer is full, no need to increment `count` as it remains at capacity
        }
    }
    // Retrieve an element at a specific index (from 0 to count-1)
    bool Get(int index, TradeData &result) {
        if (index < 0 || index >= count) return false;
        int pos = (head - count + index + capacity) % capacity;
        result = data[pos];
        return true;
    }
    // Get the current size of the buffer
    int Size() {
        return count;
    }
    // Remove the oldest trade (the one that was inserted first)
    void RemoveOldest() {
        if (count > 0) {
            // Adjust head and count to remove the oldest item
            head = (head - 1 + capacity) % capacity; // Move head backwards
            count--; // Decrease count as we've removed one element
        }
    }
};
struct Parameter {int value; int minValue; int maxValue; string name;};
struct MarketInfoData {string symbol; double minLotSize; double maxLotSize; double marginRequired; double lotStep;};
struct Threshold {double value; double min; double max; string name;};
struct LoggingConfig {bool verboseLoggingEnabled; int errorLogIntervalSeconds; int debugLogIntervalSeconds;};
struct ValidationResult {bool isValid; string message;};
struct IndicatorLogTimes {datetime ATR; datetime RSI; datetime MA; datetime TrendStrength;};
struct StrategyState {datetime lastLogTime; TradingStrategy lastStrategy;};
struct VolatilityState {double cachedVolatility; datetime lastUpdate; double lastPrintedVolatility;};
struct TrendInfo {double adxValue; string trendDescription; string trendStrength; string errorMessage;};
struct TrendInfoConfig {bool isVerboseLoggingEnabled; double adxThreshold;};
struct StrategyThreshold {TradingStrategy strategy; double threshold;};
struct StrategyTP {string strategy; double multiplier;};
struct StrategyPerformanceResult {double performance; bool error;};
struct IndicatorCache {double atr; double rsi; double fastMA; double slowMA; double adx; double upperBand; double lowerBand; double bollingerWidth; double trendStrength; double macdMain; double macdSignal; datetime lastUpdate;};
struct ErrorRecord {string symbol; int errorCount; datetime lastErrorTime;};

double errorStack[];
double requestedPrices[];  // Array to store requested prices for multiple trades
double indicators[];
double fallbackValues[];
double sentimentArray[];
static MarketState previousState;
double strategyPerformances[11] = {0.15, 0.10, 0.12, 0.09, 0.11, 0.08, 0.14, 0.13, 0.16, 0.07, 0.05};
static TradingStrategy fallbackStrategies[] = {TrendFollowing, MeanReversion, CounterTrend, Momentum};
string invalidIndicators[4]; // This could be dynamically sized in more complex versions
string indicatorNames[] = {"ATR", "RSI", "Fast MA", "Slow MA", "Trend Strength"};
StrategyTP Strategies[] = {{"Scalping", 1.0}, {"TrendFollowing", 2.0}, {"RangeBound", 1.5}};

TradePerformance tradePerformance[];  // Dynamic array (no fixed size)
TradePerformance tradeHistory[];      // Dynamic array (no fixed size)
TradingStrategy currentStrategy = TrendFollowing;
TradingStrategy fallbackStrategy = TrendFollowing;  // Default safer strategy
StrategyState g_strategyState; // Global state
IndicatorLogTimes logTimes = {};
IndicatorCache g_IndicatorCache;
VolatilityState volatilityState = { -1, 0, -1 }; // Initialize with default values
ErrorRecord Blacklist[];

//+------------------------------------------------------------------+
//| Expert Advisor Initialization                                    |
//+------------------------------------------------------------------+
int OnInit(){
   MathSrand((int)TimeLocal());
   
   // Use MT4 timer function for periodic tasks
   EventSetTimer(60);
   
   if(!InitializeLogging("", false, true))
      AddError("Logging setup failed.");
      
   MarketInfoData marketInfo;
   if(!InitializeMarketInfo(marketInfo))
      AddError("Market info initialization failed.");
      
   if(!ResizeArrays(100))
      AddError("Array resizing failed.");
      
   InitializeTradePerformanceArray();
   UpdateCachedIndicators();
   
   // Select strategy using enhanced filtering that considers multiple indicators
   TradingStrategy selectedStrategy = EnhancedStrategySelection();
   if(selectedStrategy == INVALID_STRATEGY)   {
      AddError("Invalid strategy selected. Defaulting to TrendFollowing.");
      selectedStrategy = TrendFollowing;
   }
   else   {
      Log("Initial strategy selected: " + StrategyToString(selectedStrategy), LOG_INFO);
   }
   currentStrategy = selectedStrategy; // Update global strategy variable
   
   int optimizationResult = OptimizeStrategyParameters();
   // Only log an error if optimization returns a nonzero code (assuming 0 means success)
   if(optimizationResult != NO_ERROR)
      AddError("Strategy optimization failed. Using default settings. (Error Code: " + IntegerToString(optimizationResult) + ")");
   else
      Log("Strategy parameters optimized.", LOG_INFO);
   
   Log("EA Initialized successfully.", LOG_INFO);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Initialize logging system                                        |
//+------------------------------------------------------------------+
bool InitializeLogging(string customLogFileName = "", bool append = false, bool addTimestamp = true){
   string baseFileName = (customLogFileName != "") ? customLogFileName : "Flex_EA_log";
   string timestamp = "";
   if(addTimestamp)
      timestamp = StringFormat("-%04d%02d%02d_%02d%02d", TimeYear(TimeLocal()), TimeMonth(TimeLocal()),
                               TimeDay(TimeLocal()), TimeHour(TimeLocal()), TimeMinute(TimeLocal()));
   string fullLogFileName = baseFileName + timestamp + ".txt";
   
   int fileHandle = FileOpen(fullLogFileName, FILE_WRITE | FILE_TXT | (append ? FILE_READ : 0));
   if(fileHandle < 0)   {
      Print("Failed to open log file: " + fullLogFileName + ". Error: " + IntegerToString(GetLastError()));
      return false;
   }
   if(append)
      FileSeek(fileHandle, 0, SEEK_END);
   else
      FileWrite(fileHandle, StringFormat("=== Logging Initialized ===\nTimestamp: %s\n", TimeToStr(TimeLocal(), TIME_DATE|TIME_MINUTES)));
   
   FileClose(fileHandle);
   Print("Log file created successfully at: " + fullLogFileName);
   return true;
}

//+------------------------------------------------------------------+
//| Initializes and validates market information                     |
//+------------------------------------------------------------------+
bool InitializeMarketInfo(MarketInfoData &marketInfo, string inputSymbol = "", int maxRetries = 3, int retryDelay = 500, int maxDelay = 5000, int timeoutSeconds = 10){
   // Validate input parameters for market info retrieval
   if(maxRetries <= 0 || retryDelay <= 0 || maxDelay <= 0 || retryDelay > maxDelay)   {
      Log("Invalid market info parameters.", LOG_ERROR);
      return false;
   }
   
   string symbolToUse = (StringLen(inputSymbol) == 0) ? Symbol() : inputSymbol;
   if(!SymbolSelect(symbolToUse, true))   {
      Log("Invalid symbol: " + symbolToUse, LOG_ERROR);
      return false;
   }
   
   ResetMarketInfo(marketInfo);
   marketInfo.symbol = symbolToUse;
   
   ulong timeoutEnd = GetTickCount() + (ulong)timeoutSeconds * 1000;
   int currentDelay = retryDelay;
   bool success = false;
   for(int attempt = 0; attempt < maxRetries && GetTickCount() <= timeoutEnd; attempt++)   {
      if(RetrieveMarketInfo(symbolToUse, marketInfo))      {
         success = true;
         break;
      }
      Log("Retrying market info retrieval. Attempts left: " + IntegerToString(maxRetries - attempt - 1), LOG_WARNING);
      Sleep(currentDelay);
      currentDelay = MathMin(currentDelay * 2, maxDelay);
   }
   
   if(!success || marketInfo.minLotSize <= 0 || marketInfo.maxLotSize <= 0 || marketInfo.marginRequired <= 0 ||
      marketInfo.lotStep <= 0 || marketInfo.maxLotSize < marketInfo.minLotSize)   {
      Log("Failed to initialize MarketInfo for " + symbolToUse, LOG_ERROR);
      return false;
   }
   
   Log(StringFormat("Market Info for %s: MinLot=%.2f, MaxLot=%.2f, Margin=%.2f, LotStep=%.5f",
                    marketInfo.symbol, marketInfo.minLotSize, marketInfo.maxLotSize,
                    marketInfo.marginRequired, marketInfo.lotStep), LOG_INFO);
   return true;
}

//+------------------------------------------------------------------+
//| OnTick Event - Updated with enhanced risk controls and logging   |
//+------------------------------------------------------------------+
void OnTick(){
   // Update indicators and market state from the modular indicator manager
   UpdateIndicatorCache(Symbol(), Timeframe);
   
   // Use weighted signal fusion to select strategy
   TradingStrategy strategy = SelectCombinedStrategy();
   if(strategy == INVALID_STRATEGY)   {
      Log("No valid combined strategy selected. Aborting tick execution.", LOG_ERROR);
      return;
   }
   
   // Calculate dynamic lot size for new orders
   double lotSize = CalculateDynamicLotSize();
   double equity = AccountEquity();
   double drawdown = CalculateDrawdownPercentage();
   double sentiment = CalculateMarketSentiment();
   // Proceed to execute strategy (your ExecuteStrategy() function may need to accept lotSize)
   if(!ExecuteStrategy(strategy, equity, drawdown, sentiment))   {
      int error = GetLastError();
      EnhancedLogError("Execution error for strategy " + StrategyToString(strategy), error, Symbol());
      return;
   }
   
   // Manage existing orders with risk hedging (partial exits)
   PartialExitCheck();
   
   // Update order management functions
   UpdateStopLossTakeProfit();
   UpdateTrailingStop();
   MoveStopToBreakEven();
}

//+------------------------------------------------------------------+
//| OnTimer Event - Updated with adaptive scheduling and strategy    |
//+------------------------------------------------------------------+
void OnTimer(){
   static datetime lastCheck = 0, lastOptionalTaskRun = 0, lastOptimizationTime = 0;
   datetime currentTime = TimeCurrent();
   
   // Execute timer tasks only if the performance interval has elapsed
   if(currentTime - lastCheck < performanceCheckInterval)
      return;
   lastCheck = currentTime;
   
   // Exit if risk limits or recovery mode conditions are met
   if(CheckRecoveryMode() || CalculateConsolidatedRisk(AccountEquity(), 2.0, RiskMedium, CalculateDrawdownPercentage()))   {
      Log("Risk limits exceeded or recovery mode active. Trading disabled.", LOG_WARNING);
      return;
   }
   
   // Process open orders and update market data with modularized functions
   if(HandleExistingOrders(MarginThreshold, EnablePyramiding, EnableScalingOut, 0.1) != STATUS_OK)   {
      Log("Error handling open orders.", LOG_ERROR);
      return;
   }
   UpdateCachedIndicators();
   cachedDrawdownPercentage = CalculateDrawdownPercentage();
   cachedMarketSentiment = CalculateMarketSentiment();
   AdjustSLTP();
   EvaluateStrategyPerformance();
   ExecuteAllStrategies();
   
   // Optimize strategy parameters every 15 minutes
   const int optimizationCooldown = 900;
   if(currentTime - lastOptimizationTime >= optimizationCooldown)   {
      Log("Starting strategy optimization process.", LOG_INFO);
      ResetAndOptimizeStrategy();
      lastOptimizationTime = currentTime;
   }
   
   // Log performance metrics and execute optional tasks on a longer interval
   if(ShouldLogPerformanceMetrics(LOG_INFO))
      LogPerformanceMetrics();
   if(currentTime - lastOptionalTaskRun >= 3600)   {
      RunOptionalTasks();
      lastOptionalTaskRun = currentTime;
   }
   Log("OnTimer tasks executed successfully.", LOG_INFO);
}

//+------------------------------------------------------------------+
//| SelectCombinedStrategy - fuse signals from multiple strategies     |
//+------------------------------------------------------------------+
TradingStrategy SelectCombinedStrategy(){
   // Example weights for each strategy signal (these might be configurable)
   double weightTrend = 0.4;
   double weightReversion = 0.3;
   double weightMomentum = 0.3;
   
   // Get individual strategy signals (these functions return a value between -1 and +1)
   double signalTrend = GetTrendFollowingSignal();      // e.g., +1 for bullish, -1 for bearish
   double signalReversion = GetMeanReversionSignal();
   double signalMomentum = GetMomentumSignal();
   
   // Weighted sum of signals
   double combinedSignal = (signalTrend * weightTrend) +
                           (signalReversion * weightReversion) +
                           (signalMomentum * weightMomentum);
   
   // Determine strategy based on combined signal
   if(combinedSignal > 0.3)
      return TrendFollowing;
   else if(combinedSignal < -0.3)
      return CounterTrend;
   else
      return RangeBound;
}

// Returns a trend following signal (-1 to +1) based on dual EMAs.
// A positive value indicates bullish conditions; a negative value indicates bearish.
double GetTrendFollowingSignal(){
   // Fast and slow EMA periods (configurable as needed)
   int fastPeriod = 20;
   int slowPeriod = 50;
   
   // Retrieve the fast and slow EMAs
   double fastEMA = iMA(Symbol(), Timeframe, fastPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double slowEMA = iMA(Symbol(), Timeframe, slowPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   // Calculate the difference and normalize by current price
   double diff = fastEMA - slowEMA;
   double normDiff = diff / Bid;
   
   // Define a threshold (e.g., 0.1% of current price) to filter noise
   double threshold = 0.001;
   if(normDiff > threshold)
      return 1.0;
   else if(normDiff < -threshold)
      return -1.0;
   return 0.0;
}

// Returns a mean reversion signal (-1 to +1).
// Uses RSI and Bollinger Bands: if RSI is overbought and price is near the upper band, expect a reversal (-1).
// If RSI is oversold and price is near the lower band, expect a reversal upward (+1).
double GetMeanReversionSignal(){
   // Retrieve the RSI value
   int rsiPeriod = 14;
   double rsi = iRSI(Symbol(), Timeframe, rsiPeriod, PRICE_CLOSE, 0);
   
   // Bollinger Bands parameters
   int bbPeriod = 20;
   double bbStdDev = 2.0;
   double bbMiddle = iMA(Symbol(), Timeframe, bbPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double bbUpper = iBands(Symbol(), Timeframe, bbPeriod, bbStdDev, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double bbLower = iBands(Symbol(), Timeframe, bbPeriod, bbStdDev, 0, PRICE_CLOSE, MODE_LOWER, 0);
   
   // Normalize the price's deviation from the middle of the bands
   double deviation = (Bid - bbMiddle) / (bbUpper - bbLower);
   
   // Define thresholds for RSI and deviation
   if(rsi > 70 && deviation > 0.3)
      return -1.0;
   else if(rsi < 30 && deviation < -0.3)
      return 1.0;
   return 0.0;
}

// Returns a momentum signal (-1 to +1) based on the change in momentum.
// A positive value indicates increasing upward momentum; a negative value indicates increasing downward momentum.
double GetMomentumSignal(){
   int period = 14;
   // Retrieve momentum values for the current and previous bars.
   double momentumNow = iMomentum(Symbol(), Timeframe, period, PRICE_CLOSE, 0);
   double momentumPrev = iMomentum(Symbol(), Timeframe, period, PRICE_CLOSE, 1);
   
   // Calculate the difference in momentum
   double momentumDelta = momentumNow - momentumPrev;
   
   // Define a dynamic threshold as a fraction of the current momentum magnitude to filter out noise.
   double threshold = 0.05 * MathAbs(momentumNow);
   if(momentumDelta > threshold)
      return 1.0;
   else if(momentumDelta < -threshold)
      return -1.0;
   return 0.0;
}

// Returns a measure of market volatility using an average of ATR and standard deviation.
// If the calculated volatility is invalid or zero, a fallback value is returned.
double GetMarketVolatility(){
   int atrPeriod = 14;
   int stdDevPeriod = 14;
   
   // Calculate ATR as a measure of volatility
   double atr = iATR(Symbol(), Timeframe, atrPeriod, 0);
   
   // Calculate standard deviation (using EMA smoothing)
   double stdDev = iStdDev(Symbol(), Timeframe, stdDevPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   // Combine both measures (simple average)
   double volatility = (atr + stdDev) / 2.0;
   
   // Use a fallback if volatility is not valid
   if(volatility <= 0)
      return FALLBACK_ATR;
   return volatility;
}

//+------------------------------------------------------------------+
//| CalculateDynamicLotSize - compute lot size based on ATR, volatility|
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(){
   // Retrieve the current ATR value (make sure GetCachedATR() is updated regularly)
   double currentATR = GetCachedATR();
   // Retrieve a measure of market volatility (this could be based on standard deviation or other indicator)
   double volatility = GetMarketVolatility();
   
   // Base risk percentage per trade (can be an input variable)
   double riskPercentage = TradeRisk;  // e.g., 0.02 for 2% risk
   
   // Determine risk per pip; this calculation might be more advanced in your context.
   double riskPerPip = currentATR * volatility;
   if(riskPerPip <= 0)
      riskPerPip = 1;  // fallback
   
   // Calculate maximum risk in currency for this trade
   double equity = AccountEquity();
   double riskAmount = equity * riskPercentage;
   
   // Calculate lot size. For simplicity, assume 1 pip = 10 currency units risk per lot.
   double lotSize = riskAmount / (riskPerPip * 10);
   
   // Ensure lot size meets broker’s minimum and maximum requirements.
   MarketInfoData marketInfo;
   if(!InitializeMarketInfo(marketInfo))
      return 0;
   
   lotSize = MathMax(marketInfo.minLotSize, lotSize);
   lotSize = MathMin(marketInfo.maxLotSize, lotSize);
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| PartialExitCheck - exit part of a position if profit exceeds      |
//+------------------------------------------------------------------+
void PartialExitCheck(){
   string symbol = Symbol();
   int totalOrders = OrdersTotal();
   double tickSize = MarketInfo(symbol, MODE_TICKSIZE);
   // Profit threshold in pips to consider a partial exit
   double profitThresholdPips = 50; // example value
   
   for (int i = 0; i < totalOrders; i++)   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))      {
         if(OrderSymbol() != symbol)
            continue;
         
         int orderType = OrderType();
         double openPrice = OrderOpenPrice();
         double currentPrice = (orderType == OP_BUY) ? Bid : Ask;
         double profitPips = (orderType == OP_BUY) ? (currentPrice - openPrice) / tickSize :
                                                     (openPrice - currentPrice) / tickSize;
         // Check if the profit threshold is reached and partial exit is allowed
         if(profitPips >= profitThresholdPips)         {
            double lotToClose = OrderLots() * 0.5; // exit 50% of the position
            if(lotToClose < MarketInfo(symbol, MODE_MINLOT))
               lotToClose = OrderLots(); // if too small, close full
            
            // Place a partial exit order (this is a simplified example)
            int ticket = OrderClose(OrderTicket(), lotToClose, currentPrice, Slippage, clrBlue);
            if(ticket > 0)
               Log("Partial exit executed for order #" + IntegerToString(OrderTicket()), LOG_INFO);
            else
               Log("Failed partial exit for order #" + IntegerToString(OrderTicket()), LOG_WARNING);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| EnhancedLogError - log error and add symbol to blacklist if needed |
//+------------------------------------------------------------------+
void EnhancedLogError(string message, int errorCode, string symbol){
   Log(message + " Error code: " + IntegerToString(errorCode), LOG_ERROR);
   
   // Search for existing record for symbol in the blacklist
   int recordIndex = -1;
   for(int i = 0; i < ArraySize(Blacklist); i++)   {
      if(Blacklist[i].symbol == symbol)      {
         recordIndex = i;
         break;
      }
   }
   
   if(recordIndex == -1)   {
      // Create a new record if not found
      ErrorRecord rec;
      rec.symbol = symbol;
      rec.errorCount = 1;
      rec.lastErrorTime = TimeCurrent();
      ArrayResize(Blacklist, ArraySize(Blacklist)+1);
      Blacklist[ArraySize(Blacklist)-1] = rec;
   }
   else   {
      Blacklist[recordIndex].errorCount++;
      Blacklist[recordIndex].lastErrorTime = TimeCurrent();
      if(Blacklist[recordIndex].errorCount >= MAX_ERROR_COUNT)
         Log("Symbol " + symbol + " has been blacklisted due to repeated errors.", LOG_WARNING);
   }
}

//+------------------------------------------------------------------+
//| Update Stop Loss and Take Profit for all open orders             |
//+------------------------------------------------------------------+
void UpdateStopLossTakeProfit(){
   // Use an explicit enum value (e.g., RiskMedium)
   double sl = CalculateStopLoss(RiskMedium);
   double tp = CalculateTakeProfit(RiskMedium);
   
   if(sl < 0 || tp < 0)   {
      Log("Invalid SL/TP values calculated.", LOG_ERROR);
      return;
   }
   
   if(SetStopLossTakeProfit(sl, tp))
      Log("SL/TP updated: SL=" + DoubleToString(sl,2) + ", TP=" + DoubleToString(tp,2), LOG_INFO);
   else
      Log("Failed to update SL/TP.", LOG_WARNING);
}

//+------------------------------------------------------------------+
//| Update trailing stops with dynamic calculation based on ATR      |
//+------------------------------------------------------------------+
void UpdateTrailingStop(){
   string symbol = Symbol();
   int totalOrders = OrdersTotal();
   double tickSize = MarketInfo(symbol, MODE_TICKSIZE);
   double currentATR = GetCachedATR(); // Use ATR for dynamic trailing steps
   double trailingStart = MathMax(20 * tickSize, currentATR * 1.2);
   double trailingStep = MathMax(5 * tickSize, currentATR * 0.3);
   
   for(int i = 0; i < totalOrders; i++)   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))      {
         if(OrderSymbol() != symbol)
            continue;
         int orderType = OrderType();
         double currentPrice = (orderType == OP_BUY) ? Bid : Ask;
         double openPrice = OrderOpenPrice();
         double profitPips = (orderType == OP_BUY) ? (currentPrice - openPrice) / tickSize : (openPrice - currentPrice) / tickSize;
         
         // Only adjust trailing stop if profit exceeds the dynamic threshold
         if(profitPips >= (trailingStart / tickSize))         {
            double newSL = (orderType == OP_BUY) ? currentPrice - trailingStep : currentPrice + trailingStep;
            if((orderType == OP_BUY && newSL > OrderStopLoss()) ||
               (orderType == OP_SELL && newSL < OrderStopLoss()))            {
               if(OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrYellow))
                  Log("Trailing stop updated for order #" + IntegerToString(OrderTicket()), LOG_INFO);
               else
                  Log("Failed to update trailing stop for order #" + IntegerToString(OrderTicket()), LOG_WARNING);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Move stop loss to break-even if profit threshold is reached       |
//+------------------------------------------------------------------+
void MoveStopToBreakEven(){
   string sym = Symbol();
   int totalOrders = OrdersTotal();
   double tickSize = MarketInfo(sym, MODE_TICKSIZE);
   double breakEvenThreshold = 30 * tickSize;
   
   for(int i = 0; i < totalOrders; i++)   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))      {
         if(OrderSymbol() != sym)
            continue;
         int orderType = OrderType();
         double currentPrice = (orderType == OP_BUY) ? Bid : Ask;
         double openPrice = OrderOpenPrice();
         double profitPips = (orderType == OP_BUY) ? (currentPrice - openPrice) / tickSize : (openPrice - currentPrice) / tickSize;
         if(profitPips >= (breakEvenThreshold / tickSize))         {
            // Use order open price as break-even stop loss
            if(OrderModify(OrderTicket(), OrderOpenPrice(), openPrice, OrderTakeProfit(), 0, clrGreen))
               Log("Stop loss moved to break-even for order #" + IntegerToString(OrderTicket()), LOG_INFO);
            else
               Log("Failed to move stop loss to break-even for order #" + IntegerToString(OrderTicket()), LOG_WARNING);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if an error code is considered retryable                   |
//+------------------------------------------------------------------+
bool IsRetryableError(int errorCode){
    // Consider non-negative and specific trade context errors as retryable
    if (errorCode < 0)    {
        Print("Invalid error code: " + IntegerToString(errorCode) + " for symbol " + Symbol() + " at " + TimeToString(TimeCurrent()));
        return false;
    }
    return (errorCode == ERR_NOT_ENOUGH_MONEY || errorCode == ERR_TRADE_CONTEXT_BUSY);
}

//+------------------------------------------------------------------+
//| Determine if sentiment update is required                        |
//+------------------------------------------------------------------+
bool ShouldUpdateSentiment(double marketSentiment, datetime currentTime, double sentimentChangeThreshold = 0.1, int sentimentUpdateInterval = 60){
    static double lastMarketSentiment = 0.0;
    static datetime lastSentimentUpdateTime = 0;
    
    if (currentTime <= 0 || currentTime > (TimeCurrent() + 10))
        return false;
    
    if (MathAbs(marketSentiment - lastMarketSentiment) > sentimentChangeThreshold ||
        (currentTime - lastSentimentUpdateTime) > sentimentUpdateInterval)    {
        lastMarketSentiment = marketSentiment;
        lastSentimentUpdateTime = currentTime;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get dynamic execution interval based on market volatility        |
//+------------------------------------------------------------------+
int GetDynamicExecutionInterval(double threshold = 0.5, int highInterval = 120, int lowInterval = 60){
    double vol = MarketVolatility();
    if (vol <= 0)    {
        Print("ERROR: Invalid volatility value. Using default interval: " + IntegerToString(lowInterval));
        return lowInterval;
    }
    return (vol > threshold) ? highInterval : lowInterval;
}

//+------------------------------------------------------------------+
//| Adjust risk parameters for retry based on drawdown and win rate    |
//+------------------------------------------------------------------+
void AdjustRiskParametersForRetry(int maxDrawdown = 10){
   if(maxDrawdown < 0)   {
      Log("maxDrawdown cannot be negative.", LOG_ERROR);
      return;
   }
   
   static double lastBalance = AccountBalance();
   double currentBalance = AccountBalance();
   
   // Update peak equity if balance has increased significantly
   if(MathAbs(currentBalance - lastBalance) > 100)
      peakEquity = currentBalance;
   lastBalance = currentBalance;
   
   double currentDrawdown = peakEquity - currentBalance;
   double recentWinRate = tradePerformance[(int)currentStrategy].winRate; // ensure valid index
   
   RiskLevelType newRisk;
   if(currentDrawdown >= maxDrawdown || recentWinRate < 0.4)
      newRisk = RiskLow;
   else if(currentDrawdown >= maxDrawdown * 0.5 || recentWinRate < 0.6)
      newRisk = RiskMedium;
   else
      newRisk = RiskHigh;
      
   SetRiskLevel(newRisk);
   Log("Adjusted Risk Parameters: New risk level: " + RiskLevelToString(newRisk) +
       ", Drawdown: " + DoubleToString(currentDrawdown,2) +
       ", Recent Win Rate: " + DoubleToString(recentWinRate*100,2) +
       ", Equity: " + DoubleToString(currentBalance,2) +
       ", Peak Equity: " + DoubleToString(peakEquity,2), LOG_INFO);
}

//------------------------------------------------------------------
// Set the risk level and adjust position size, stop loss, and take profit
//------------------------------------------------------------------
void SetRiskLevel(RiskLevelType riskLevel){
   if(riskLevel < RiskLow || riskLevel > RiskHigh) {
      Log("SetRiskLevel: Invalid risk level.", LOG_ERROR);
      return;
   }
   
   const double riskPercentage = 0.02; // Risk percentage per trade; can be made adaptive
   double calculatedSL = CalculateStopLoss(riskLevel);
   if(calculatedSL < 0) {
      Log("SetRiskLevel: Calculated stop loss is invalid.", LOG_ERROR);
      return;
   }
   
   // Calculate position size using the risk level and calculated stop loss (stop loss in points)
   double positionSize = CalculatePositionSize(riskLevel, calculatedSL);
   if(positionSize <= 0) {
      Log("SetRiskLevel: Invalid position size.", LOG_ERROR);
      return;
   }
   
   SetPositionSize(positionSize);
   
   const double MinStopLossDistance = 50;
   const double MinTakeProfitDistance = 100;
   double calculatedTP = CalculateTakeProfit(riskLevel);
   
   double finalSL = (calculatedSL < MinStopLossDistance) ? MinStopLossDistance : calculatedSL;
   double finalTP = (calculatedTP < MinTakeProfitDistance) ? MinTakeProfitDistance : calculatedTP;
   
   Log("SetRiskLevel: Risk level set to " + RiskLevelToString(riskLevel) + 
       ", Position size: " + DoubleToString(positionSize,2), LOG_INFO);
   
   if(calculatedSL < MinStopLossDistance || calculatedTP < MinTakeProfitDistance)
      Log("SetRiskLevel: Stop loss/take profit adjusted to minimum thresholds.", LOG_WARNING);
   
   SetStopLossTakeProfit(finalSL, finalTP);
}

//------------------------------------------------------------------
// Convert RiskLevelType enum to a human-readable string
//------------------------------------------------------------------
string RiskLevelToString(RiskLevelType level){
   switch(level)   {
      case RiskLow:    return "RiskLow";
      case RiskMedium: return "RiskMedium";
      case RiskHigh:   return "RiskHigh";
      default:         return "Unknown (" + IntegerToString(level) + ")";
   }
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss based on ATR and risk level                  |
//+------------------------------------------------------------------+
double CalculateStopLoss(RiskLevelType risk) {
   // Base stop-loss values (in points) by risk level
   double baseSL = 50; // default for medium risk
   if(risk == RiskLow)
      baseSL = 30;
   else if(risk == RiskHigh)
      baseSL = 70;
   
   // Widen stop-loss proportionally to volatility
   double volFactor = (cachedATR > 0 ? cachedATR / FALLBACK_ATR : 1.0);
   double adjustedSL = baseSL * volFactor;
   return NormalizeDouble(adjustedSL, 2);
}

//+------------------------------------------------------------------+
//| Calculate Take Profit based on ATR, with dynamic adjustments     |
//+------------------------------------------------------------------+
double CalculateTakeProfit(RiskLevelType risk) {
   // Base take-profit values (in points) by risk level
   double baseTP = 100; // default for medium risk
   if(risk == RiskLow)
      baseTP = 60;
   else if(risk == RiskHigh)
      baseTP = 140;
   
   // Widen take-profit based on volatility
   double volFactor = (cachedATR > 0 ? cachedATR / FALLBACK_ATR : 1.0);
   double adjustedTP = baseTP * volFactor;
   return NormalizeDouble(adjustedTP, 2);
}

//+------------------------------------------------------------------+
//| Set Stop Loss and Take Profit for all open orders                |
//+------------------------------------------------------------------+
bool SetStopLossTakeProfit(double stopLoss, double takeProfit) {
   int totalOrders = OrdersTotal();
   bool allModified = true;
   string sym = Symbol();
   
   double point = MarketInfo(sym, MODE_POINT);
   double spread = MarketInfo(sym, MODE_SPREAD) * point;
   double stopLevel = MarketInfo(sym, MODE_STOPLEVEL) * point;
   double customBuffer = 2 * spread;
   
   for (int i = totalOrders - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         Log("Error selecting order #" + IntegerToString(i), LOG_WARNING);
         continue;
      }
      if (OrderSymbol() != sym) {
         Log("Skipping order #" + IntegerToString(OrderTicket()) + " for symbol: " + OrderSymbol(), LOG_INFO);
         continue;
      }
      
      double openPrice = OrderOpenPrice();
      bool isBuy = (OrderType() == OP_BUY);
      double bidPrice = Bid, askPrice = Ask;
      double newSL, newTP;
      
      if (isBuy) {
         newSL = bidPrice - stopLoss * point - customBuffer;
         newTP = askPrice + takeProfit * point + customBuffer;
         if ((bidPrice - newSL) < stopLevel || (newTP - askPrice) < (stopLevel + customBuffer)) {
            Log("Order #" + IntegerToString(OrderTicket()) + ": SL/TP too close to price.", LOG_WARNING);
            allModified = false;
            continue;
         }
      }
      else {
         newSL = askPrice + stopLoss * point + customBuffer;
         newTP = bidPrice - takeProfit * point - customBuffer;
         if ((newSL - askPrice) < stopLevel || (bidPrice - newTP) < (stopLevel + customBuffer)) {
            Log("Order #" + IntegerToString(OrderTicket()) + ": SL/TP too close to price.", LOG_WARNING);
            allModified = false;
            continue;
         }
      }
      
      if (OrderStopLoss() == newSL && OrderTakeProfit() == newTP) {
         Log("Order #" + IntegerToString(OrderTicket()) + " already has correct SL/TP.", LOG_INFO);
         continue;
      }
      
      if (!OrderModify(OrderTicket(), openPrice, newSL, newTP, 0, clrNONE)) {
         int errorCode = GetLastError();
         Log("Error modifying order #" + IntegerToString(OrderTicket()) + ". Error code: " + IntegerToString(errorCode), LOG_ERROR);
         ResetLastError();
         allModified = false;
      }
      else {
         Log("Order #" + IntegerToString(OrderTicket()) + " modified: SL=" + DoubleToString(newSL, 5) + ", TP=" + DoubleToString(newTP, 5), LOG_INFO);
      }
   }
   return allModified;
}

//+------------------------------------------------------------------+
//| Calculate position size using risk percentage, dynamic volatility adjustment, and margin requirements        |
//+------------------------------------------------------------------+
double CalculatePositionSize(RiskLevelType risk, double stopLossInPoints) {
   // Base risk percentages by risk level (can be optimized via backtesting)
   double baseRiskPercentage = 0.02; // default for medium risk
   if(risk == RiskLow)
      baseRiskPercentage = 0.01;
   else if(risk == RiskHigh)
      baseRiskPercentage = 0.03;
   
   // Adjust risk percentage if drawdown is high (reduce risk further)
   double drawdown = CalculateDrawdownPercentage(); // assumes this function exists
   if(drawdown > 0.10)  // e.g., more than 10% drawdown
      baseRiskPercentage *= 0.8; // reduce risk by 20%
   
   // Incorporate market volatility: if current ATR is higher than a baseline, reduce risk
   double volFactor = (cachedATR > 0 ? cachedATR / FALLBACK_ATR : 1.0);
   if(volFactor > 1.0)
      baseRiskPercentage *= 0.9;  // reduce risk by 10% when volatility is high

   // Calculate the monetary risk (riskAmount) per trade
   double riskAmount = AccountEquity() * baseRiskPercentage;
   
   // Calculate lot size: riskAmount divided by (stop loss in points * tick value)
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(tickValue <= 0)
      tickValue = 1.0;
   double lotSize = riskAmount / (stopLossInPoints * tickValue);
   
   // Normalize lot size (2 decimal places) and check against maximum allowed
   lotSize = NormalizeDouble(lotSize, 2);
   double maxAllowedLot = MaxAllowedLotSize; // defined as an input
   if(lotSize > maxAllowedLot)
      lotSize = maxAllowedLot;
   return lotSize;
}

//+------------------------------------------------------------------+
//| Set position size by sending an order with risk parameters       |
//+------------------------------------------------------------------+
void SetPositionSize(double lotSize, int orderType = OP_BUY, double stopLoss = 0, double takeProfit = 0, int slippage = 3) {
   string sym = Symbol();
   double minLot = MarketInfo(sym, MODE_MINLOT);
   double maxLot = MarketInfo(sym, MODE_MAXLOT);
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   
   if (lotSize <= 0 || stopLoss <= 0 || takeProfit <= 0 ||
       (orderType != OP_BUY && orderType != OP_SELL) ||
       lotSize < minLot || lotSize > maxLot) {
      Print("Error: Invalid parameters for order placement.");
      return;
   }
   
   lotSize = NormalizeDouble(lotSize, digits);
   double price = (orderType == OP_BUY) ? Ask : Bid;
   
   if (AccountFreeMarginCheck(sym, orderType, lotSize) > AccountFreeMargin() ||
       (orderType == OP_BUY && (stopLoss >= price || takeProfit <= price)) ||
       (orderType == OP_SELL && (stopLoss <= price || takeProfit >= price))) {
      Print("Error: Invalid margin or price conditions.");
      return;
   }
   
   int ticket = OrderSend(sym, orderType, lotSize, price, slippage, stopLoss, takeProfit, "OrderComment", 0, 0, Blue);
   if (ticket < 0)
      Print("Error: Order failed. Code: " + IntegerToString(GetLastError()));
   else
      Print("Order placed successfully. Ticket: " + IntegerToString(ticket));
}

//------------------------------------------------------------------
// Calculate Market Volatility using ATR
//------------------------------------------------------------------
double MarketVolatility(int timeFrame = PERIOD_H1) {
   const int atrPeriod = 50;
   string sym = Symbol();
   if (Bars(sym, timeFrame) <= atrPeriod) {
      Print("Error: Insufficient data for ATR calculation on " + sym);
      return -1.0;
   }
   RefreshRates();
   double atr = cachedATR;
   if (atr <= 0) {
      Print("Error: ATR calculation failed for " + sym);
      return -1.0;
   }
   return atr;
}

//+------------------------------------------------------------------+
//| Run a set of optional tasks                                      |
//+------------------------------------------------------------------+
void RunOptionalTasks() {
   Print("Running optional tasks...");
   datetime startTime = TimeCurrent();
   string tasks[] = {"updatedashboard", "monitorandalert", "exportmetricstofile", "replaceunderperformingstrategy"};
   
   for (int i = 0; i < ArraySize(tasks); i++) {
      string taskName = tasks[i];
      if (!ExecuteTask(taskName))
         Print("Task '" + taskName + "' failed.");
      else
         Print(taskName + " completed successfully.");
   }
   Print("Total execution time: " + DoubleToString(TimeCurrent() - startTime, 2) + " seconds");
}

//+------------------------------------------------------------------+
//| Check if a function exists (case-insensitive)                    |
//+------------------------------------------------------------------+
bool FunctionExists(string functionName) {
   static const string validFunctions[] = {"updatedashboard", "monitorandalert", "exportmetricstofile", "replaceunderperformingstrategy"};
   functionName = StringToLower(functionName);
   for (int i = 0; i < ArraySize(validFunctions); i++) {
      if (functionName == validFunctions[i])
         return true;
   }
   if (IsDebugMode())
      Print("Function '" + functionName + "' does not exist.");
   return false;
}

//+------------------------------------------------------------------+
//| Check if debug mode is enabled (caches result after first call)  |
//+------------------------------------------------------------------+
bool IsDebugMode(string filePath = "debug_mode.txt") {
   static bool debugInitialized = false;
   static bool debugModeValue = false;
   if (!debugInitialized) {
      debugInitialized = true;
      debugModeValue = false;
      if (FileIsExist(filePath)) {
         int fileHandle = FileOpen(filePath, FILE_READ | FILE_TXT);
         if (fileHandle >= 0) {
            string mode = FileReadString(fileHandle);
            FileClose(fileHandle);
            while (StringFind(mode, " ") >= 0)
               mode = StringReplace(mode, " ", "");
            mode = StringToLower(mode);
            debugModeValue = (mode == "true");
         }
         else {
            Print("Failed to open file '" + filePath + "'. Defaulting to false.");
         }
      }
   }
   return debugModeValue;
}

//+------------------------------------------------------------------+
//| Execute a specific task                                          |
//+------------------------------------------------------------------+
bool ExecuteTask(string taskName) {
   string normalizedTask = StringTrim(StringToLower(taskName));
   if (!FunctionExists(normalizedTask)) {
      LogError(1003, "Invalid or empty task name: " + normalizedTask);
      return false;
   }
   
   if (normalizedTask == "updatedashboard")
      UpdateDashboard();
   else if (normalizedTask == "monitorandalert")
      MonitorAndAlert();
   else if (normalizedTask == "exportmetricstofile") {
      if (!ExportMetricsToFile()) {
         LogError(1002, "ExportMetricsToFile failed.");
         return false;
      }
   }
   else if (normalizedTask == "replaceunderperformingstrategy")
      ReplaceUnderperformingStrategy();
      
   Print("Task executed successfully: " + normalizedTask);
   return true;
}

//+------------------------------------------------------------------+
//| Sets periodic timers                                             |
//+------------------------------------------------------------------+
void SetTimers(int timerIntervalSeconds = 60) {
   if (timerIntervalSeconds <= 0) {
      Log("Invalid timer interval. Timer not set.", LOG_WARNING);
      return;
   }
   if (EventSetTimer(timerIntervalSeconds) > 0)
      Log(StringFormat("Timer set to %d seconds interval.", timerIntervalSeconds), LOG_INFO);
   else
      Log("Failed to set timer.", LOG_ERROR);
}

//+------------------------------------------------------------------+
//| Resizes arrays                                                   |
//+------------------------------------------------------------------+
bool ResizeArrays(int maxTradeHistory, int tradePerformanceSize = DEFAULT_TRADE_PERFORMANCE_SIZE, bool verbose = false) {
   const int MAX_TRADE_HISTORY = 10000;
   if (maxTradeHistory <= 0 || maxTradeHistory > MAX_TRADE_HISTORY) {
      LogError(1001, StringFormat("Invalid maxTradeHistory: %d. Range: 1 to %d.", maxTradeHistory, MAX_TRADE_HISTORY));
      return false;
   }
   if (!ResizeArrayIfNeeded(tradePerformance, tradePerformanceSize, verbose) ||
       !ResizeArrayIfNeeded(tradeHistory, maxTradeHistory, verbose)) {
      LogError(1002, "Failed to resize arrays.");
      return false;
   }
   if (verbose)
      Print("Arrays resized: tradePerformance=" + IntegerToString(ArraySize(tradePerformance)) +
            ", tradeHistory=" + IntegerToString(ArraySize(tradeHistory)));
   return true;
}

//+------------------------------------------------------------------+
//| Helper function to resize an array of TradePerformance type      |
//+------------------------------------------------------------------+
bool ResizeArrayIfNeeded(TradePerformance &array[], int newSize, bool verbose = false) {
   if (newSize < 0) {
      if (verbose)
         Print("Invalid newSize: " + IntegerToString(newSize));
      return false;
   }
   int currentSize = ArraySize(array);
   if (currentSize == newSize) {
      if (verbose)
         Print("Array already at desired size: " + IntegerToString(newSize));
      return true;
   }
   if (ArrayResize(array, newSize) == -1) {
      if (verbose)
         Print("Failed to resize array to " + IntegerToString(newSize));
      return false;
   }
   if (verbose)
      Print("Array resized to " + IntegerToString(newSize));
   for (int i = currentSize; i < newSize; i++) {
      InitializeTradePerformance(array[i]);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Initialize trade performance with optional logging               |
//+------------------------------------------------------------------+
bool InitializeTradePerformance(TradePerformance &trade, LogLevel logLevel = LOG_INFO) {
   const double UNCALCULATED_WIN_RATE = -1.0;
   const int INVALID_RISK_LEVEL = -1;
   
   trade.profit = 0.0;
   trade.duration = 0.0;
   trade.grossProfit = 0.0;
   trade.grossLoss = 0.0;
   trade.sharpeRatio = 0.0;
   trade.entryPrice = EMPTY_VALUE;
   trade.exitPrice = EMPTY_VALUE;
   trade.SL = EMPTY_VALUE;
   trade.TP = EMPTY_VALUE;
   trade.strategy = INVALID_STRATEGY;
   trade.RiskLevel = INVALID_STRATEGY;
   trade.winRate = UNCALCULATED_WIN_RATE;
   trade.maxDrawdown = UNCALCULATED_WIN_RATE;
   trade.tradeCount = 0;
   
   if (logLevel == LOG_DEBUG)
      PrintFormat("Trade initialized: strategy=%d, RiskLevel=%d, profit=%.2f, duration=%d",
                  trade.strategy, trade.RiskLevel, trade.profit, (int)trade.duration);
   else if (logLevel == LOG_WARNING && (trade.strategy == INVALID_STRATEGY || trade.RiskLevel == INVALID_RISK_LEVEL))
      Print("Warning: Invalid strategy or risk level.");
   return true;
}

//------------------------------------------------------------------
// Checks if the orderType is valid.
//------------------------------------------------------------------
bool IsValidOrderType(int orderType, LoggingConfig &logConfig, datetime currentTime, string symbol, ValidationResult &result) {
   static int validOrderTypes[] = { OP_BUY, OP_SELL, OP_BUYLIMIT, OP_SELLLIMIT, OP_BUYSTOP, OP_SELLSTOP };
   static datetime lastErrorLogTime = 0, lastDebugLogTime = 0;
   
   if ((result.isValid = (ArrayFind(validOrderTypes, orderType) >= 0))) {
      result.message = "Valid order type.";
      return true;
   }
   result.message = StringFormat("Invalid order type: %d for symbol %s.", orderType, symbol);
   if (currentTime - lastErrorLogTime > logConfig.errorLogIntervalSeconds) {
      Log(StringFormat("Error: %s at %s.", result.message, TimeToString(currentTime, TIME_DATE | TIME_MINUTES)), LOG_ERROR);
      lastErrorLogTime = currentTime;
   }
   if (logConfig.verboseLoggingEnabled && (currentTime - lastDebugLogTime > logConfig.debugLogIntervalSeconds)) {
      Log(StringFormat("Debug: %s at %s.", result.message, TimeToString(currentTime, TIME_DATE | TIME_MINUTES)), LOG_DEBUG);
      lastDebugLogTime = currentTime;
   }
   return false;
}

bool RetrieveMarketInfo(const string &inputSymbol, MarketInfoData &marketInfo, double threshold = 0.00001) {
   if (inputSymbol == "" || !SymbolSelect(inputSymbol, true)) {
      Log("Invalid or unavailable symbol: " + inputSymbol, LOG_ERROR);
      return false;
   }
   marketInfo.minLotSize = MarketInfo(inputSymbol, MODE_MINLOT);
   marketInfo.maxLotSize = MarketInfo(inputSymbol, MODE_MAXLOT);
   marketInfo.marginRequired = MarketInfo(inputSymbol, MODE_MARGINREQUIRED);
   marketInfo.lotStep = MarketInfo(inputSymbol, MODE_LOTSTEP);
   
   if (marketInfo.minLotSize <= threshold || marketInfo.maxLotSize <= threshold ||
       marketInfo.marginRequired <= threshold || marketInfo.lotStep <= threshold) {
      Log("Invalid market info for symbol " + inputSymbol, LOG_ERROR);
      return false;
   }
   marketInfo.symbol = inputSymbol;
   return true;
}

//+------------------------------------------------------------------+
//| Resets the MarketInfo structure                                  |
//+------------------------------------------------------------------+
ResetMarketInfoStatus ResetMarketInfo(MarketInfoData &info, bool logDetails = true) {
   if (StringLen(info.symbol) == 0) {
      Log("Symbol is empty.", LOG_WARNING);
      return SYMBOL_EMPTY;
   }
   if (!SymbolSelect(info.symbol, true)) {
      Log("Symbol " + info.symbol + " is unavailable.", LOG_WARNING);
      return SYMBOL_UNAVAILABLE;
   }
   if (logDetails)
      Log(StringFormat("Resetting market info for %s: minLotSize=%.5f, maxLotSize=%.5f, marginRequired=%.5f, lotStep=%.5f",
            info.symbol, info.minLotSize, info.maxLotSize, info.marginRequired, info.lotStep), LOG_INFO);
   info.minLotSize = info.maxLotSize = info.marginRequired = info.lotStep = MathSqrt(-1);
   Log("Market info reset for " + info.symbol, LOG_INFO);
   return SUCCESS;
}

//+------------------------------------------------------------------+
//| Trim leading and trailing whitespace                           |
//+------------------------------------------------------------------+
string StringTrim(string str) {
   int len = StringLen(str);
   if (len == 0)
      return "";
   int start = 0, end = len - 1;
   while (start <= end && StringFind(" \t\n\r", StringGetCharacter(str, start)) >= 0)
      start++;
   while (end >= start && StringFind(" \t\n\r", StringGetCharacter(str, end)) >= 0)
      end--;
   return (start > end) ? "" : StringSubstr(str, start, end - start + 1);
}

//------------------------------------------------------------------
// Determines whether performance metrics should be logged
//------------------------------------------------------------------
bool ShouldLogPerformanceMetrics(int logLevelThreshold = LOG_INFO, double balanceThreshold = 1000, double marginLevelThreshold = 100, int startHour = 9, int endHour = 17) {
   static datetime lastLogTimeLocal = 0;
   datetime now = TimeCurrent();
   int currentHour = TimeHour(now);
   bool isMarketHours = (startHour == endHour) ? (currentHour == startHour) : (currentHour >= startHour && currentHour <= endHour);
   if (!isMarketHours) {
      LogPerformanceMetric("Outside market hours", LOG_WARNING);
      return false;
   }
   double balance = AccountBalance();
   double marginLevel = AccountMarginLevel();
   if (balance <= 0 || marginLevel <= 0 || balance < balanceThreshold || marginLevel < marginLevelThreshold || GetLastError() != 0) {
      LogPerformanceMetric(StringFormat("Invalid data. Balance: %.2f, Margin: %.2f, Error: %d", balance, marginLevel, GetLastError()), LOG_WARNING);
      return false;
   }
   if (now - lastLogTimeLocal < 60)
      return false;
   lastLogTimeLocal = now;
   if (logLevelThreshold <= LOG_INFO)
      Log("Performance metrics logging enabled.", LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Function to log performance metrics
//------------------------------------------------------------------
bool LogPerformanceMetric(string message, int logLevel, string logFile = "", string customPrefix = "") {
   message = StringTrim(message);
   if (StringLen(message) == 0 || logLevel < LOG_INFO || logLevel > LOG_ERROR)
      return false;
   string prefix = (customPrefix != "") ? customPrefix : (logLevel == LOG_ERROR ? "ERROR" : (logLevel == LOG_WARNING ? "WARNING" : "INFO"));
   datetime now = TimeCurrent();
   string logMessage = StringFormat("[%s] %s: %s", TimeToString(now, TIME_DATE | TIME_SECONDS), prefix, message);
   Print(logMessage);
   if (StringLen(logFile) > 0) {
      int fileHandle = FileOpen(logFile, FILE_READ | FILE_WRITE | FILE_COMMON);
      if (fileHandle < 0)
         return false;
      FileSeek(fileHandle, 0, SEEK_END);
      FileWrite(fileHandle, logMessage);
      FileClose(fileHandle);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Structured logging function                                      |
//+------------------------------------------------------------------+
void Log(string message, int logLevel = LOG_INFO) {
   if (logLevel < LOG_ERROR || logLevel > LOG_DEBUG || logLevel > currentLogLevel)
      return;
   datetime now = TimeCurrent();
   string timeStamp = TimeToString(now, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   string levelName = LogLevelToString(logLevel, currentLogLevel);
   string formattedLog = StringFormat("[%s] [%s] %s", timeStamp, levelName, message);
   Print(formattedLog);
   if (logFileHandle >= 0) {
      int bytesWritten = FileWrite(logFileHandle, formattedLog);
      if (bytesWritten == -1) {
         Print("Error writing to log file. Error code: " + IntegerToString(GetLastError()));
         FileClose(logFileHandle);
         logFileHandle = -1;
      }
   }
}

//+------------------------------------------------------------------+
//| Converts log level to string                                     |
//+------------------------------------------------------------------+
string LogLevelToString(int logLevel, int localLogLevel) {
   if (logLevel != LOG_ERROR && logLevel != LOG_WARNING && logLevel != LOG_INFO && logLevel != LOG_DEBUG) {
      if (localLogLevel >= LOG_DEBUG)
         Print("Invalid log level: " + IntegerToString(logLevel));
      return StringFormat("UNKNOWN (%d)", logLevel);
   }
   static const string levelNames[] = {"ERROR", "WARNING", "INFO", "DEBUG"};
   return levelNames[logLevel - LOG_ERROR];
}

//+------------------------------------------------------------------+
//| Log an error message (includes error code if nonzero)            |
//+------------------------------------------------------------------+
void AddError(string message, int errorCode=-1){
   string fullMessage = message;
   if(errorCode > 0)
      fullMessage = "Error " + IntegerToString(errorCode) + ": " + message;
      
   Log(fullMessage, LOG_ERROR);
}

// Log the error with the error code and message
bool LogError(int errorCode, string message, int logLevel = LOG_ERROR, int strategyIndex = -1, ParameterType parameter = -1, double value = 0.0, int maxLength = MAX_LOG_MESSAGE_LENGTH) {
   if (logLevel < LOG_ERROR || logLevel > LOG_DEBUG || errorCode < 0) {
      Print("Invalid log level or error code. LogError aborted.");
      return false;
   }
   string context = "";
   if (strategyIndex >= 0) context += " | StrategyIndex: " + IntegerToString(strategyIndex);
   if (parameter >= 0) context += " | Parameter: " + IntegerToString(parameter);
   if (value != 0.0) context += " | Value: " + DoubleToString(value, 2);
   message = (StringLen(message) > 0) ? StringTrim(message) : "Missing error message in log call.";
   string fullMessage = StringFormat("[%s] Error: %d - %s%s", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), errorCode, message, (context != "") ? " Context: " + context : "");
   Log(StringSubstr(fullMessage, 0, maxLength), logLevel);
   static int fileHandle = INVALID_HANDLE;
   if (fileHandle == INVALID_HANDLE) fileHandle = FileOpen("error_log.txt", FILE_WRITE | FILE_TXT);
   if (fileHandle != INVALID_HANDLE) FileWrite(fileHandle, StringSubstr(fullMessage, 0, maxLength));
   return true;
}

//------------------------------------------------------------------
// Check if indicators should update (based on price or time)
//------------------------------------------------------------------
bool ShouldUpdateIndicators(double threshold = 0.0010, int timeInterval = 0, bool useBidPrice = false) {
   static double lastPrice = -1;
   double currentPrice = useBidPrice ? Bid : Ask;
   if(threshold <= 0) return false;
   if(lastPrice < 0) lastPrice = currentPrice;

   if(timeInterval > 0 && (TimeCurrent() - lastUpdateTime) >= timeInterval * 60) {
      lastUpdateTime = TimeCurrent();
      return true;
   }
   if(MathAbs(currentPrice - lastPrice) > threshold) {
      lastPrice = currentPrice;
      return true;
   }
   return false;
}

//------------------------------------------------------------------
// Optimizes strategy parameters
//------------------------------------------------------------------
OptimizationError OptimizeStrategyParameters() {
   if (currentStrategy < 0) {
      Log("Invalid strategy index.", LOG_ERROR);
      return PARAMETER_ERROR;
   }
   if (!AreStrategyParametersValid(currentStrategy)) {
      Log("Invalid strategy parameters, reverting to defaults.", LOG_ERROR);
      ResetStrategyParametersToDefault(currentStrategy);
      return PARAMETER_ERROR;
   }
   if (!IsPerformanceAcceptable()) {
      Log("Performance error: " + GetPerformanceDetails(), LOG_WARNING);
      return PERFORMANCE_ERROR;
   }
   if (!IsOptimizationSuccessful()) {
      Log("Optimization error.", LOG_WARNING);
      return UNKNOWN_ERROR;
   }
   Log("Optimization successful.", LOG_SUCCESS);
   return NO_ERROR;
}

//------------------------------------------------------------------
// Retrieves performance details from closed orders for logging
//------------------------------------------------------------------
string GetPerformanceDetails() {
   double totalExecutionTime = 0;
   double totalSlippage = 0;
   int tradeCount = 0;
   int digits = MarketInfo(Symbol(), MODE_DIGITS);
   
   for (int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && (OrderType() == OP_BUY || OrderType() == OP_SELL)) {
         if (i < ArraySize(requestedPrices)) {
            totalExecutionTime += OrderCloseTime() - OrderOpenTime();
            totalSlippage += MathAbs(OrderOpenPrice() - requestedPrices[i]);
            tradeCount++;
         }
      }
   }
   if (tradeCount == 0)
      return "No trades executed.";
   return StringFormat("Avg Execution Time: %.2f sec\nAvg Slippage: %.2f pips", totalExecutionTime / tradeCount, totalSlippage / tradeCount / MathPow(10, digits));
}

//+------------------------------------------------------------------+
//| Initializes trade performance array                              |
//+------------------------------------------------------------------+
void InitializeTradePerformanceArray() {
   const int desiredSize = 100;
   if (desiredSize <= 0) {
      Print("Error: Invalid desired size.");
      return;
   }
   if (ArrayResize(tradePerformance, desiredSize) != desiredSize) {
      Print("Error: Failed to resize tradePerformance array.");
      return;
   }
   for (int i = 0; i < desiredSize; i++) {
      tradePerformance[i].RiskLevel = TradeRisk;
      tradePerformance[i].SL = SL;
      tradePerformance[i].TP = TP;
   }
   Print("TradePerformance array initialized, size: " + IntegerToString(desiredSize));
}

//------------------------------------------------------------------
// Resets strategy parameters to default values if they are invalid
//------------------------------------------------------------------
void ResetStrategyParametersToDefault(int strategyIndex) {
   int size = ArraySize(tradePerformance);
   if (strategyIndex < 0 || strategyIndex >= size) {
      Log("Invalid strategy index: " + IntegerToString(strategyIndex), LOG_ERROR);
      return;
   }
   bool resetOccurred = false;
   const double DEFAULT_SL = 100.0;
   const double DEFAULT_TP = 200.0;
   if (tradePerformance[strategyIndex].RiskLevel <= 0 || tradePerformance[strategyIndex].RiskLevel > MAX_RISK_LEVEL) {
      ResetParameter(strategyIndex, Param_RiskLevel, DEFAULT_RISK_LEVEL);
      resetOccurred = true;
   }
   if (tradePerformance[strategyIndex].SL <= 0 || tradePerformance[strategyIndex].SL > MAX_SL ||
       tradePerformance[strategyIndex].SL >= tradePerformance[strategyIndex].TP) {
      ResetParameter(strategyIndex, Param_SL, DEFAULT_SL);
      resetOccurred = true;
   }
   if (tradePerformance[strategyIndex].TP <= 0 || tradePerformance[strategyIndex].TP <= tradePerformance[strategyIndex].SL ||
       tradePerformance[strategyIndex].TP > MAX_TP) {
      ResetParameter(strategyIndex, Param_TP, DEFAULT_TP);
      resetOccurred = true;
   }
   if (resetOccurred)
      Log("Strategy " + IntegerToString(strategyIndex) + " parameters reset.", LOG_INFO);
}

//------------------------------------------------------------------
// Improved ResetParameter function
//------------------------------------------------------------------
bool ResetParameter(int strategyIndex, ParameterType parameter, double defaultValue) {
   int size = ArraySize(tradePerformance);
   if (strategyIndex < 0 || strategyIndex >= size ||
       !ValidateDefaultValue(parameter, defaultValue) || !IsParameterValid(parameter)) {
      LogError(1001, "Invalid input", LOG_ERROR, strategyIndex, parameter, defaultValue);
      return false;
   }
   switch (parameter) {
      case Param_RiskLevel:
         tradePerformance[strategyIndex].RiskLevel = defaultValue;
         break;
      case Param_SL:
         tradePerformance[strategyIndex].SL = defaultValue;
         break;
      case Param_TP:
         tradePerformance[strategyIndex].TP = defaultValue;
         break;
      default:
         LogError(1002, "Unknown parameter type", LOG_ERROR, strategyIndex, parameter);
         return false;
   }
   LogSuccess(1005, StringFormat("Parameter %d reset to %.2f", parameter, defaultValue), LOG_INFO, strategyIndex);
   return true;
}

bool ValidateDefaultValue(ParameterType parameter, double value) {
   if (value != value || value > 1e308 || value < -1e308) {
      Print("Invalid value: " + DoubleToString(value, 2) + " for parameter: " + IntegerToString(parameter));
      return false;
   }
   switch (parameter) {
      case Param_RiskLevel: return value > 0 && value <= 1;
      case Param_SL: return value > 0 && value <= MAX_SL;
      case Param_TP: return value > 0 && value <= MAX_TP;
      default: return false;
   }
}

bool IsParameterValid(ParameterType parameter) {
   bool isDebugMode = true;
   if (parameter >= Param_RiskLevel && parameter <= Param_TP)
      return true;
   else {
      if (isDebugMode)
         Print("Invalid parameter: " + IntegerToString(parameter));
      return false;
   }
}

//------------------------------------------------------------------
// Checks if the performance metric is acceptable based on thresholds
//------------------------------------------------------------------
bool IsPerformanceAcceptable() {
   static double lastPerformanceMetric = -1;
   datetime now = TimeCurrent();
   if (now - lastCheckedTime > 60) {
      lastPerformanceMetric = GetPerformanceMetric();
      lastCheckedTime = now;
   }
   Log("Performance Metric: " + DoubleToString(lastPerformanceMetric, 2), LOG_INFO);
   if (!isFinite(lastPerformanceMetric) || lastPerformanceMetric < 0) {
      Log("Error: Invalid performance metric: " + DoubleToString(lastPerformanceMetric, 2), LOG_ERROR);
      return false;
   }
   const double MIN_ACCEPTABLE_PERFORMANCE = 0.8;
   double threshold = MIN_ACCEPTABLE_PERFORMANCE * (IsMarketVolatile() ? 1.5 : 1) - 0.01;
   Log("Checking performance metric: " + DoubleToString(lastPerformanceMetric, 2) + " against threshold: " + DoubleToString(threshold, 2), LOG_INFO);
   return lastPerformanceMetric >= threshold;
}

// Function to check if a value is finite (not NaN, not Infinity, and not -Infinity)
bool isFinite(double value) {
   #define INFINITY 1e308
   #define NEG_INFINITY -1e308
   return (value == value) && (value != INFINITY) && (value != NEG_INFINITY);
}

//------------------------------------------------------------------
// Determines whether optimization has been successful based on metrics
//------------------------------------------------------------------
bool IsOptimizationSuccessful(int optimizationTimeThreshold = 86400, bool reset = false) {
   static bool optimizationSuccess = false;
   static datetime lastOptimizationTime = 0;
   const double maxDrawdown = 20.0;
   const double currentDrawdown = 15.0;
   const double profitFactor = 1.5;
   const double minProfitFactor = 1.2;
   if (reset) {
      optimizationSuccess = false;
      lastOptimizationTime = 0;
      return false;
   }
   datetime now = TimeCurrent();
   if (now - lastOptimizationTime < optimizationTimeThreshold)
      return optimizationSuccess;
   string result = SomeOptimizationCheckFailed(maxDrawdown, currentDrawdown, profitFactor, minProfitFactor);
   optimizationSuccess = (StringLen(result) == 0);
   Log(StringFormat("Optimization Check - Drawdown: %.2f (Max: %.2f), ProfitFactor: %.2f (Min: %.2f), Success: %s", currentDrawdown, maxDrawdown, profitFactor, minProfitFactor, optimizationSuccess ? "YES" : "NO"), LOG_INFO);
   if (!optimizationSuccess)
      Log("Optimization failed: " + result, LOG_WARNING);
   lastOptimizationTime = now;
   return optimizationSuccess;
}

//------------------------------------------------------------------
// Placeholder function to simulate performance metric calculation
//------------------------------------------------------------------
double GetPerformanceMetric(double riskFreeRate = 0.01, datetime startTime = 0, datetime endTime = 0) {
   int totalTrades = OrdersHistoryTotal();
   if (totalTrades == 0) return 0.0;
   if (startTime > endTime && endTime != 0) {
      datetime temp = startTime;
      startTime = endTime;
      endTime = temp;
   }
   double sumReturns = 0, sumSquared = 0;
   int count = 0;
   for (int i = 0; i < totalTrades; i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
         datetime closeTime = OrderCloseTime();
         if ((startTime == 0 || closeTime >= startTime) && (endTime == 0 || closeTime <= endTime)) {
            double tradeReturn = (OrderProfit() + OrderSwap() + OrderCommission()) / (AccountBalance() - OrderProfit());
            if (tradeReturn != 0) {
               sumReturns += tradeReturn;
               sumSquared += tradeReturn * tradeReturn;
               count++;
            }
         }
      }
   }
   if (count == 0) return 0.0;
   double avgReturn = sumReturns / count;
   double variance = (sumSquared / count) - MathPow(avgReturn, 2);
   return (variance <= 0) ? 0.0 : (avgReturn - riskFreeRate) / MathSqrt(variance);
}

//------------------------------------------------------------------
// Checks optimization metrics and returns an error message if a check fails.
// Returns an empty string if all checks pass.
//------------------------------------------------------------------
string SomeOptimizationCheckFailed(double maxDrawdown, double currentDrawdown, double profitFactor, double minProfitFactor, bool logMessages = true, int logLevel = 1) {
   if (maxDrawdown <= 0 || currentDrawdown < 0 || profitFactor <= 0 || minProfitFactor <= 0) {
      if (logMessages && logLevel >= 2)
         Print("Error: Invalid input values.");
      return "Invalid input values";
   }
   if (currentDrawdown > maxDrawdown) {
      if (logMessages && logLevel >= 1)
         Print("Optimization failed: Max drawdown exceeded.");
      return "Max drawdown exceeded";
   }
   if (profitFactor < minProfitFactor) {
      if (logMessages && logLevel >= 1)
         Print("Optimization failed: Insufficient profit factor.");
      return "Insufficient profit factor";
   }
   return "";
}

// Function to update the indicator cache only when a new candle is detected
void UpdateIndicatorCache(string symbol = NULL, int timeframe = PERIOD_H1) {
   if (symbol == NULL || StringLen(symbol) == 0)
      symbol = Symbol();
   
   datetime currentCandleTime = iTime(symbol, timeframe, 0);
   if (g_IndicatorCache.lastUpdate == currentCandleTime)
      return;

   // Compute indicators
   double atrValue = iATR(symbol, timeframe, ATRPeriod, 0);
   double rsiValue = iRSI(symbol, timeframe, RSIPeriod, PRICE_CLOSE, 0);
   double fastMAValue = iMA(symbol, timeframe, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double slowMAValue = iMA(symbol, timeframe, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double adxValue = iADX(symbol, timeframe, 14, PRICE_CLOSE, MODE_MAIN, 0);
   double upperBand = iBands(symbol, timeframe, BollingerPeriod, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double lowerBand = iBands(symbol, timeframe, BollingerPeriod, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double localTrendStrength = CalculateMultiTimeframeTrendStrength();
   double macdMain = iMACD(symbol, timeframe, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
   double macdSignal = iMACD(symbol, timeframe, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
   double bollingerWidth = upperBand - lowerBand;

   // Apply fallbacks if necessary (specifying min and max values)
   atrValue = (IsValidIndicatorValue(atrValue, 0.0001, 100000) == VALID ? atrValue : FALLBACK_ATR);
   rsiValue = (IsValidIndicatorValue(rsiValue, 0.0001, 100000) == VALID ? rsiValue : FALLBACK_RSI);
   fastMAValue = (IsValidIndicatorValue(fastMAValue, 0.0001, 100000) == VALID ? fastMAValue : FALLBACK_MA);
   slowMAValue = (IsValidIndicatorValue(slowMAValue, 0.0001, 100000) == VALID ? slowMAValue : FALLBACK_MA);
   localTrendStrength = (IsValidIndicatorValue(localTrendStrength, 0.0001, 100000) == VALID ? localTrendStrength : FALLBACK_TREND);
   adxValue = (IsValidIndicatorValue(adxValue, 0.0001, 100000) == VALID ? adxValue : FALLBACK_ADX);
   macdMain = (IsValidIndicatorValue(macdMain, 0.0001, 100000) == VALID ? macdMain : 0);
   macdSignal = (IsValidIndicatorValue(macdSignal, 0.0001, 100000) == VALID ? macdSignal : 0);

   // Update cache
   g_IndicatorCache.atr = atrValue;
   g_IndicatorCache.rsi = rsiValue;
   g_IndicatorCache.fastMA = fastMAValue;
   g_IndicatorCache.slowMA = slowMAValue;
   g_IndicatorCache.adx = adxValue;
   g_IndicatorCache.upperBand = upperBand;
   g_IndicatorCache.lowerBand = lowerBand;
   g_IndicatorCache.bollingerWidth = bollingerWidth;
   g_IndicatorCache.trendStrength = localTrendStrength;
   g_IndicatorCache.macdMain = macdMain;
   g_IndicatorCache.macdSignal = macdSignal;
   g_IndicatorCache.lastUpdate = currentCandleTime;

   // Log update
   if (debugMode) {
      LogMessage(LOG_INFO, "Indicators updated: ATR=" + DoubleToString(atrValue,6) +
                           " RSI=" + DoubleToString(rsiValue,2) +
                           " FastMA=" + DoubleToString(fastMAValue,2) +
                           " SlowMA=" + DoubleToString(slowMAValue,2) +
                           " ADX=" + DoubleToString(adxValue,2) +
                           " Trend=" + DoubleToString(localTrendStrength,2) +
                           " MACD_MAIN=" + DoubleToString(macdMain,2) +
                           " MACD_SIGNAL=" + DoubleToString(macdSignal,2));
   }
}

// Utility functions to access the cached indicator values
double GetCachedATR()   { return g_IndicatorCache.atr; }
double GetCachedRSI()   { return g_IndicatorCache.rsi; }
double GetCachedFastMA(){ return g_IndicatorCache.fastMA; }
double GetCachedSlowMA(){ return g_IndicatorCache.slowMA; }

//------------------------------------------------------------------
// SmoothValue: Applies a simple moving average smoothing filter
//------------------------------------------------------------------
double SmoothValue(double currentValue, double previousSmoothed, double smoothingFactor = 0.2) {
   return (smoothingFactor * currentValue) + ((1 - smoothingFactor) * previousSmoothed);
}

//------------------------------------------------------------------
// SmoothEMA: Applies an exponential moving average filter.
// alpha: smoothing factor (0 < alpha < 1); lower = smoother
//------------------------------------------------------------------
double SmoothEMA(double currentValue, double previousEMA, double alpha = 0.2) {
   return (alpha * currentValue) + ((1.0 - alpha) * previousEMA);
}

//------------------------------------------------------------------
// Updates cached indicators with adaptive periods, including EMA smoothing
//------------------------------------------------------------------
void UpdateCachedIndicators(){
   datetime currentBarTime = Time[0];
   if(currentBarTime == lastIndicatorUpdateTime)
      return;
   
   lastIndicatorUpdateTime = currentBarTime;
   string sym = Symbol();
   int tf = TF;
   
   // Retrieve raw indicator values
   double rawATR = iATR(sym, tf, ATRPeriod, 0);
   double rawRSI = iRSI(sym, tf, RSIPeriod, PRICE_CLOSE, 0);
   double rawFastMA = iMA(sym, tf, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double rawSlowMA = iMA(sym, tf, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double rawADX = iADX(sym, tf, 14, PRICE_CLOSE, MODE_MAIN, 0);
   double upperBand = iBands(sym, tf, BollingerPeriod, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double lowerBand = iBands(sym, tf, BollingerPeriod, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double bollingerWidth = upperBand - lowerBand;
   double macdMain = iMACD(sym, tf, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
   double macdSignal = iMACD(sym, tf, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
   
   // Validate and apply fallbacks
   cachedATR = (IsValidIndicatorValue(rawATR) == VALID ? rawATR : FALLBACK_ATR);
   // Apply EMA smoothing to RSI. Use a static variable to hold the previous EMA.
   static double smoothedRSI = (IsValidIndicatorValue(rawRSI)==VALID ? rawRSI : FALLBACK_RSI);
   smoothedRSI = SmoothEMA(rawRSI, smoothedRSI, 0.2);
   cachedRSI = smoothedRSI;
   
   cachedFastMA = (IsValidIndicatorValue(rawFastMA) == VALID ? rawFastMA : FALLBACK_MA);
   cachedSlowMA = (IsValidIndicatorValue(rawSlowMA) == VALID ? rawSlowMA : FALLBACK_MA);
   
   // Calculate multi-timeframe trend strength and apply EMA smoothing
   double rawTrendStrength = CalculateMultiTimeframeTrendStrength(sym, FastMAPeriod, SlowMAPeriod);
   static double smoothedTrend = rawTrendStrength;
   smoothedTrend = SmoothEMA(rawTrendStrength, smoothedTrend, 0.2);
   cachedTrendStrength = smoothedTrend;
   
   cachedADX = (IsValidIndicatorValue(rawADX) == VALID ? rawADX : FALLBACK_ADX);
   cachedBollingerWidth = bollingerWidth;
   cachedUpperBand = upperBand;
   cachedLowerBand = lowerBand;
   cachedIndicators[INDICATOR_MACD_MAIN] = (IsValidIndicatorValue(macdMain)==VALID ? macdMain : 0);
   cachedIndicators[INDICATOR_MACD_SIGNAL] = (IsValidIndicatorValue(macdSignal)==VALID ? macdSignal : 0);

   // MarketState mismatch check (as before; using our adjusted version)
   MarketState currentState;
   currentState.isVolatile    = (MarketVolatility(tf) > volatilityThreshold);
   currentState.atr           = cachedATR;
   currentState.fastMASlope   = CalculateFastMASlope();
   currentState.slowMASlope   = CalculateSlowMASlope();
   currentState.volatilityScore = CalculateVolatilityScore();
   currentState.lastUpdate    = TimeCurrent();
   static MarketState cachedMarketState = currentState;
   double atrTolerance = cachedMarketState.atr * 0.05;
   double volTolerance = cachedMarketState.volatilityScore * 0.10;
   bool mismatchDetected = (MathAbs(cachedMarketState.atr - currentState.atr) > atrTolerance) ||
                           (MathAbs(cachedMarketState.volatilityScore - currentState.volatilityScore) > volTolerance) ||
                           (cachedMarketState.isVolatile != currentState.isVolatile);
   if(mismatchDetected) {
      Log("MarketState mismatch detected.", LOG_WARNING);
   }
   cachedMarketState = currentState;
   
   // Debug logging
   if(debugMode) {
      Log("UpdateCachedIndicators: ATR=" + DoubleToString(cachedATR,6) +
          " RSI=" + DoubleToString(cachedRSI,2) +
          " FastMA=" + DoubleToString(cachedFastMA,2) +
          " SlowMA=" + DoubleToString(cachedSlowMA,2) +
          " Trend=" + DoubleToString(cachedTrendStrength,2) +
          " ADX=" + DoubleToString(cachedADX,2) +
          " MACD_MAIN=" + DoubleToString(cachedIndicators[INDICATOR_MACD_MAIN],2) +
          " MACD_SIGNAL=" + DoubleToString(cachedIndicators[INDICATOR_MACD_SIGNAL],2), LOG_INFO);
   }
}

//------------------------------------------------------------------
// Helper: Retrieves an indicator value and applies fallback if invalid.
//------------------------------------------------------------------
double GetValidatedIndicator(double value, double fallback, const double minVal = 0.0001, const double maxVal = 100000) {
   if(IsValidIndicatorValue(value) != VALID)
      return fallback;
   return value;
}

//------------------------------------------------------------------
// Calculate the slope of the fast moving average using EMA smoothing
//------------------------------------------------------------------
double CalculateFastMASlope() {
   string sym = Symbol();
   int tf = TF;
   
   // Get the EMA instead of SMA for smoother trend detection
   double currentFastMA = iMA(sym, tf, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double previousFastMA = iMA(sym, tf, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double olderFastMA = iMA(sym, tf, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 2);
   
   // Use a more refined slope calculation
   double slope = ((currentFastMA - previousFastMA) + (previousFastMA - olderFastMA)) / 2;
   
   return NormalizeDouble(slope, 5);
}

//------------------------------------------------------------------
// Calculate the slope of the slow moving average using EMA smoothing
//------------------------------------------------------------------
double CalculateSlowMASlope() {
   string sym = Symbol();
   int tf = TF;
   
   // Get the EMA instead of SMA for smoother trend detection
   double currentSlowMA = iMA(sym, tf, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double previousSlowMA = iMA(sym, tf, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double olderSlowMA = iMA(sym, tf, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 2);
   
   // Use a more refined slope calculation
   double slope = ((currentSlowMA - previousSlowMA) + (previousSlowMA - olderSlowMA)) / 2;
   
   return NormalizeDouble(slope, 5);
}

//------------------------------------------------------------------
// Calculate volatility score using ATR and Bollinger Band width
//------------------------------------------------------------------
double CalculateVolatilityScore() {
   string sym = Symbol();
   int tf = TF;
   
   // Bollinger Band width (existing approach)
   double upperBand = iBands(sym, tf, BollingerPeriod, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double lowerBand = iBands(sym, tf, BollingerPeriod, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double bollingerWidth = upperBand - lowerBand;

   // ATR (more reliable volatility indicator)
   double atrValue = iATR(sym, tf, ATRPeriod, 0);
   
   // Weighted combination of ATR and Bollinger width for a more refined score
   double volatilityScore = (0.6 * atrValue) + (0.4 * bollingerWidth);
   
   return NormalizeDouble(volatilityScore, 5);
}

double ValidateAndFallbackBands(double bandValue, string indicatorName) {
    if(IsValidIndicatorValue(bandValue) == VALID)
        return bandValue;
    
    // Calculate a dynamic fallback using current price and ATR
    double fallback;
    if(indicatorName == "Upper Band")
        fallback = Bid + (2 * FALLBACK_ATR); // Adjust multiplier as needed
    else if(indicatorName == "Lower Band")
        fallback = Bid - (2 * FALLBACK_ATR);
    else
        fallback = bandValue; // default

    Log(StringFormat("Using fallback for %s: %.5f", indicatorName, fallback), LOG_WARNING);
    return fallback;
}

//------------------------------------------------------------------
// Checks the validity of all cached indicators and resets those that are invalid
//------------------------------------------------------------------
bool IsValidIndicators() {
    // Validate each indicator using the helper function
    bool valid = true;
    valid &= CheckAndLogIndicator(cachedATR, "ATR");
    valid &= CheckAndLogIndicator(cachedRSI, "RSI");
    valid &= CheckAndLogIndicator(cachedFastMA, "Fast MA");
    valid &= CheckAndLogIndicator(cachedSlowMA, "Slow MA");
    valid &= CheckAndLogIndicator(trendStrength, "Trend Strength");

    // If any indicator is invalid, reset only the invalid ones
    if (!valid)
        ResetInvalidIndicators();

    return valid;
}

// Helper: Checks an indicator value and logs if invalid.
bool CheckAndLogIndicator(double indicatorValue, string indicatorName) {
    if (IsValidIndicatorValue(indicatorValue) != VALID) {
        LogInvalidIndicator(indicatorName, indicatorValue);
        return false;
    }
    return true;
}

//------------------------------------------------------------------
// Logs invalid indicators with rate limiting
//------------------------------------------------------------------
void LogInvalidIndicator(string indicatorName, double invalidValue = 0.0) {
    static int invalidCount = 0;
    datetime now = TimeCurrent();
    datetime localLastLogTime = GetLastLogTime(indicatorName);

    // If not set, initialize to current time
    if (localLastLogTime == 0)
        localLastLogTime = now;

    // Log if either every 5 invalid checks or more than 10 seconds have passed,
    // and if the invalid value is outside the expected range.
    if (((invalidCount % 5) == 0 || (now - localLastLogTime > 10)) &&
        (invalidValue < 0.0 || invalidValue > 1000.0))
    {
        Log("Invalid " + indicatorName + " value: " + DoubleToString(invalidValue, 2) +
            ", Time: " + TimeToString(now), LOG_WARNING);
        UpdateLastLogTime(indicatorName);
    }
    
    const int MAX_INVALID_COUNT = 100;
    invalidCount = (invalidCount + 1) % (MAX_INVALID_COUNT + 1);
}

//------------------------------------------------------------------
// Returns the last log time for a given indicator
//------------------------------------------------------------------
datetime GetLastLogTime(string indicatorName) {
    datetime now = TimeCurrent();

    // Return known log times from the global logTimes struct
    if (indicatorName == "ATR")           return logTimes.ATR;
    else if (indicatorName == "RSI")      return logTimes.RSI;
    else if (indicatorName == "Fast MA")  return logTimes.MA;
    else if (indicatorName == "Trend Strength") return logTimes.TrendStrength;

    // For unknown indicator names, check if it has already been flagged
    for (int i = 0; i < ArraySize(invalidIndicators); i++) {
        if (invalidIndicators[i] == indicatorName)
            return INVALID_TIME;
    }

    // Log error for unknown indicators only if 10 seconds have passed since last global error
    if (now - lastLogTime > 10) {
        Print("Error: Unknown indicator name passed to GetLastLogTime: ", indicatorName);
        lastLogTime = now;
        
        // Ensure the invalidIndicators array does not exceed MAX_INVALID_INDICATORS
        const int MAX_INVALID_INDICATORS = 100;
        int size = ArraySize(invalidIndicators);
        if (size >= MAX_INVALID_INDICATORS) {
            // Shift array left to remove the oldest element
            for (int j = 1; j < size; j++) {
                invalidIndicators[j - 1] = invalidIndicators[j];
            }
            ArrayResize(invalidIndicators, size - 1);
        }
        // Add this unknown indicator to the array
        ArrayResize(invalidIndicators, ArraySize(invalidIndicators) + 1);
        invalidIndicators[ArraySize(invalidIndicators) - 1] = indicatorName;
    }

    return INVALID_TIME;
}

//------------------------------------------------------------------
// Updates the last log time for each known indicator
//------------------------------------------------------------------
void UpdateLastLogTime(string indicatorName) {
    datetime now = TimeCurrent();
    if (indicatorName == "ATR")
        logTimes.ATR = now;
    else if (indicatorName == "RSI")
        logTimes.RSI = now;
    else if (indicatorName == "Fast MA")
        logTimes.MA = now;
    else if (indicatorName == "Trend Strength")
        logTimes.TrendStrength = now;
}

//------------------------------------------------------------------
// Resets any invalid indicators to their fallback values
//------------------------------------------------------------------
void ResetInvalidIndicators() {
    // Ensure indicator arrays are initialized.
    InitIndicatorArrays();
    int count = ArraySize(indicators);
    
    for (int i = 0; i < count; i++) {
        // If the indicator is invalid, log (if in debug) and reset it.
        if (IsValidIndicatorValue(indicators[i]) != VALID) {
            if (DEBUG_MODE) {
                Print(indicatorNames[i], " is invalid. Resetting to fallback: ", fallbackValues[i]);
            }
            indicators[i] = fallbackValues[i];
            if (DEBUG_MODE) {
                Print(indicatorNames[i], " reset complete.");
            }
        }
    }

    // Reassign the array values back to the global variables.
    cachedATR     = indicators[0];
    cachedRSI     = indicators[1];
    cachedFastMA  = indicators[2];
    cachedSlowMA  = indicators[3];
    trendStrength = indicators[4];
}

//------------------------------------------------------------------
// Initializes the indicator and fallback arrays (runs only once)
//------------------------------------------------------------------
void InitIndicatorArrays() {
    static bool initialized = false;
    if (initialized)
        return;

    const int count = 5;
    ArrayResize(indicators, count);
    ArrayResize(fallbackValues, count);

    // Set initial indicator values from globals.
    indicators[0] = cachedATR;
    indicators[1] = cachedRSI;
    indicators[2] = cachedFastMA;
    indicators[3] = cachedSlowMA;
    indicators[4] = trendStrength;

    // Set fallback values.
    fallbackValues[0] = FALLBACK_ATR;
    fallbackValues[1] = FALLBACK_RSI;
    fallbackValues[2] = FALLBACK_MA;
    fallbackValues[3] = FALLBACK_MA;
    fallbackValues[4] = FALLBACK_TREND;

    initialized = true;
}

//------------------------------------------------------------------
// Validates an indicator value and applies a fallback if invalid
//------------------------------------------------------------------
double ValidateAndFallback(double indicatorValue, double fallbackValue, string indicatorName, int logFrequency = 60, bool enableLogging = true) {
    // Return immediately if the indicator value is valid
    if (IsValidIndicatorValue(indicatorValue) == VALID)
        return indicatorValue;
    
    static datetime lastLogTimeLocal = 0;
    datetime currentTime = TimeCurrent();

    // Log message if enabled and enough time has passed
    if (enableLogging && (currentTime - lastLogTimeLocal >= logFrequency)) {
        Log(StringFormat("Invalid %s value (%.4f). Falling back to default: %.4f", indicatorName, indicatorValue, fallbackValue), LOG_WARNING);
        lastLogTimeLocal = currentTime;
    }
    
    // If the fallback value is also invalid, use a secondary fallback
    const double SECONDARY_FALLBACK_VALUE = 0.0;
    if (IsValidIndicatorValue(fallbackValue) != VALID) {
        Log(StringFormat("Invalid fallback value for %s (%.4f). Using secondary fallback.", indicatorName, fallbackValue), LOG_WARNING);
        return SECONDARY_FALLBACK_VALUE;
    }
    
    return fallbackValue;
}

//------------------------------------------------------------------
// Determines if there has been a significant market change based on a threshold
//------------------------------------------------------------------
bool HasSignificantMarketChange(double currentValue, double previousValue, double thresholdPercentage) {
    // Ensure threshold is within a valid range.
    if (thresholdPercentage <= 0 || thresholdPercentage > 1)
        return false;

    // Check for NaN values.
    if (currentValue != currentValue || previousValue != previousValue)
        return false;

    // Prevent division by zero (or nearly zero).
    const double epsilon = 1e-10;
    if (MathAbs(previousValue) < epsilon)
        return false;

    double changePercentage = MathAbs(currentValue - previousValue) / MathAbs(previousValue);
    double atrValue = cachedATR;
    double atrRatio = atrValue / previousValue;

    return (changePercentage > thresholdPercentage && changePercentage <= MathMin(0.5, atrRatio));
}

//------------------------------------------------------------------
// Logs multi-timeframe indicators in debug mode
//------------------------------------------------------------------
void LogDebugIndicators(const int &timeframes[]){
   if (!ShouldLog(LOG_DEBUG))
      return;

   int count = ArraySize(timeframes);
   if(count == 0)   {
      Print("Error: timeframes array is empty. Expected at least 1 timeframe.");
      return;
   }

   if(!AreTimeframesValid(timeframes))   {
      Print("Invalid timeframes array: Contains invalid timeframes.");
      return;
   }

   LogMultiTimeframeIndicators(timeframes);
}

//------------------------------------------------------------------
// Validates timeframes array
//------------------------------------------------------------------
bool AreTimeframesValid(const int &timeframes[], bool allowEmpty = false){
   int size = ArraySize(timeframes);
   if(size == 0)
      return allowEmpty;

   // Known valid timeframes (already sorted)
   int validTimeframes[] = {1, 5, 15, 30, 60, 240, 1440, 10080, 43200};

   for(int i = 0; i < size; i++)   {
      int tf = timeframes[i];
      // Check range and membership in validTimeframes via binary search
      if(tf < validTimeframes[0] || tf > validTimeframes[ArraySize(validTimeframes)-1] ||
         ArrayBsearch(validTimeframes, tf) < 0)      {
         PrintFormat("Error: Invalid timeframe: %d", tf);
         return false;
      }
      // Check for duplicates using a simple inner loop
      for(int j = i + 1; j < size; j++)      {
         if(tf == timeframes[j])         {
            PrintFormat("Error: Duplicate timeframe: %d", tf);
            return false;
         }
      }
   }
   return true;
}

//------------------------------------------------------------------
// Calculates and logs multi-timeframe indicators
//------------------------------------------------------------------
void LogMultiTimeframeIndicators(const int &inputTimeframes[], bool logDebug = true){
   int minBarsRequired = MathMax(MathMax(RSIPeriod, ATRPeriod), MathMax(FastMAPeriod, SlowMAPeriod));
   string symbol = Symbol();
   string logMessage = "";
   int tfCount = ArraySize(inputTimeframes);

   for(int i = 0; i < tfCount; i++)   {
      int tf = inputTimeframes[i];
      if(tf <= 0 || Bars(symbol, tf) < minBarsRequired)
         continue;

      double rsi     = cachedRSI;
      double atr     = cachedATR;
      double fastMA  = cachedFastMA;
      double slowMA  = cachedSlowMA;

      if(rsi != EMPTY_VALUE && atr != EMPTY_VALUE &&
         fastMA != EMPTY_VALUE && slowMA != EMPTY_VALUE)      {
         logMessage += StringFormat("Timeframe %d: RSI = %.2f, ATR = %.2f, Fast MA = %.2f, Slow MA = %.2f\n",
                                    tf, rsi, atr, fastMA, slowMA);
      }
   }

   if(logDebug)   {
      if(logMessage != "")
         Print("Indicators for ", symbol, ":\n", logMessage);
      else
         Print("No valid timeframes.");
   }
}

//------------------------------------------------------------------
// Calculates a moving average for a given symbol and timeframe, with basic error handling
//------------------------------------------------------------------
double GetMovingAverage(string maSymbol, int maTimeframe, int maPeriod, int shift){
   // Validate parameters and symbol availability
   if(maSymbol == "" || maTimeframe <= 0 || maPeriod <= 0 || shift < 0 || MarketInfo(maSymbol, MODE_BID) <= 0)
      return 0.0;

   // Ensure sufficient bars are available
   int availableBars = iBars(maSymbol, maTimeframe);
   if(availableBars <= maPeriod || shift >= availableBars - maPeriod)
      return 0.0;

   double maValue = iMA(maSymbol, maTimeframe, maPeriod, 0, MODE_SMA, PRICE_CLOSE, shift);
   return (maValue != EMPTY_VALUE ? maValue : 0.0);
}

//------------------------------------------------------------------
// Calculates trend strength from multiple timeframes using moving averages
//------------------------------------------------------------------
double CalculateMultiTimeframeTrendStrength(string symbol = "", int fastMAPeriod = 50, int slowMAPeriod = 200) {
   if(StringLen(symbol) == 0)
      symbol = Symbol();

   // Define timeframes and base weights
   const int timeframes[] = { PERIOD_M15, PERIOD_H1, PERIOD_H4 };
   double weights[] = { 0.3, 0.4, 0.3 };

   // Optionally adjust weights based on market volatility (using PERIOD_H1 as reference)
   double overallVol = MarketVolatility(PERIOD_H1);
   if(overallVol > 2.0) {
      weights[0] += 0.1;  // Increase weight for M15 timeframe
      weights[2] -= 0.1;  // Decrease weight for H4 timeframe
   }

   // Normalize weights using unique loop variable names in their own blocks
   double weightSum = 0.0;
   int weightCount = ArraySize(weights);   {
      for(int w_loop = 0; w_loop < weightCount; w_loop++) {
         weightSum += weights[w_loop];
      }
   }   {
      for(int w_loop2 = 0; w_loop2 < weightCount; w_loop2++) {
         weights[w_loop2] /= weightSum;
      }
   }

   double totalTrendStrength = 0.0;
   int tfCount = ArraySize(timeframes);
   for(int tf_index = 0; tf_index < tfCount; tf_index++) {
      double fastMA = GetMovingAverage(symbol, timeframes[tf_index], fastMAPeriod, 0);
      double slowMA = GetMovingAverage(symbol, timeframes[tf_index], slowMAPeriod, 0);
      if(fastMA > 0 && slowMA > 0) {
         totalTrendStrength += ((fastMA - slowMA) / slowMA) * weights[tf_index];
      }
   }

   totalTrendStrength = NormalizeDouble(totalTrendStrength, 5);
   if(DebugMode)
      Print(StringFormat("Trend Strength: %.5f", totalTrendStrength));
   return totalTrendStrength;
}

//------------------------------------------------------------------
// Update Trend Strength and Recalibrate Strategy if Needed
//------------------------------------------------------------------
void UpdateTrendStrength() {
    static datetime lastRecalibrationTime = 0;
    static double previousTrendStrength = 0;

    // Update only on a new bar
    if (Time[0] == lastUpdateTime)
        return;
    lastUpdateTime = Time[0];

    const string sym = Symbol();
    double fastMA = cachedFastMA;
    double slowMA = cachedSlowMA;
    double adx    = iADX(sym, TF, 14, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Abort if any indicator is invalid
    if (fastMA == 0 || slowMA == 0 || adx == EMPTY_VALUE)
        return;
    
    const double adxThreshold      = 25.0;
    const double gradientThreshold = 0.005;
    double maGradient = (fastMA - slowMA) / slowMA;
    bool isTrending = (adx > adxThreshold && MathAbs(maGradient) > gradientThreshold);
    double localTrendStrength = isTrending ? adx + maGradient * 100 : 0.0;
    
    if (DebugMode)
        Log(StringFormat("Fast MA=%.5f, Slow MA=%.5f, ADX=%.2f, Trend Strength=%.2f", fastMA, slowMA, adx, localTrendStrength), LOG_DEBUG);
    
    const double recalibrationCooldown = 60.0;
    datetime now = TimeCurrent();
    double diffThreshold = (previousTrendStrength > 50.0) ? 5.0 : 2.0;
    
    if (now - lastRecalibrationTime > recalibrationCooldown &&
        MathAbs(localTrendStrength - previousTrendStrength) > diffThreshold) {
        TradingStrategy recalibratedStrategy = EnhancedStrategySelection();
        if (currentStrategy != recalibratedStrategy) {
            currentStrategy = recalibratedStrategy;
            strategyConsecutiveLosses[(int)currentStrategy] = 0;
            if (DebugMode)
                Log(StringFormat("Switched to recalibrated strategy: %s", StrategyToString(currentStrategy)), LOG_INFO);
        }
        lastRecalibrationTime = now;
    }
    previousTrendStrength = localTrendStrength;
}

//------------------------------------------------------------------
// Check if the market is volatile by updating and comparing indicators.
//------------------------------------------------------------------
bool IsMarketVolatile(){
   datetime now = TimeCurrent();
   MarketState state = { false, false, false, false, false, false, 0.0, 0, 0.0, 0.0, 0.0 };
   state.lastUpdate = now;
   
   const int RETRIES = 3;
   bool valid = false;
   for (int r = 0; r < RETRIES; r++)   {
      if (UpdateIndicatorsAndValidate(state))      {
         valid = true;
         break;
      }
      Log("Indicator validation failed. Retrying...", LOG_WARNING);
   }
   if (!valid)   {
      Log("Validation failed after retries. Defaulting to neutral.", LOG_ERROR);
      return false;
   }
   
   // If this is the first update, store state and return volatility flag.
   if (previousState.lastUpdate == 0)   {
      previousState = state;
      return state.isVolatile;
   }
   
   // If market state has changed, update sentiment and log if necessary.
   if (!CompareMarketStates(state, previousState))   {
      double sentiment = CalculateMarketSentiment();
      if (sentiment == 0.0)
         sentiment = 0.5;  // Neutral default
      
      const string sym = Symbol();
      int index = GetSymbolIndex(sym);
      int newSize = MathMax(ArraySize(sentimentArray), index + 1);
      if (ArrayResize(sentimentArray, newSize) > 0 && sentimentArray[index] != sentiment)      {
         sentimentArray[index] = sentiment;
         LogMarketState(state, sentiment);
      }
   }
   
   // Handle any extreme volatility conditions.
   HandleExtremeVolatility(state);
   if (state.volatilityScore < volatilityThreshold)
      state.isVolatile = state.isTrending;
   
   previousState = state;
   return state.isVolatile;
}

//------------------------------------------------------------------
// Helper function to find the index of a given symbol (using predefined symbols)
//------------------------------------------------------------------
int GetSymbolIndex(string symbol) {
    if (StringLen(symbol) == 0) {
        Log("Empty symbol input.", LOG_ERROR);
        return -1;
    }
    static string symbols[] = {"EURUSD", "GBPUSD", "USDJPY", "AUDUSD"};
    for (int i = 0; i < ArraySize(symbols); i++) {
        if (symbols[i] == symbol)
            return i;
    }
    static bool symbolNotFoundLogged = false;
    if (!symbolNotFoundLogged) {
        Log("Symbol not found: " + symbol, LOG_WARNING);
        symbolNotFoundLogged = true;
    }
    return -1;
}

//------------------------------------------------------------------
// Simplified helper function to compare market states
//------------------------------------------------------------------
bool CompareMarketStates(const MarketState &current, const MarketState &previous, double epsilon = 1e-6, int datetimeThreshold = 10){
   bool equal =
      (current.isNeutral     == previous.isNeutral) &&
      (current.isVolatile    == previous.isVolatile) &&
      (current.isBullish     == previous.isBullish) &&
      (current.isBearish     == previous.isBearish) &&
      (current.isNonVolatile == previous.isNonVolatile) &&
      (current.isTrending    == previous.isTrending) &&
      CompareValues(current.volatilityScore, previous.volatilityScore, epsilon) &&
      CompareValues(current.fastMASlope,    previous.fastMASlope,    epsilon) &&
      CompareValues(current.slowMASlope,    previous.slowMASlope,    epsilon) &&
      CompareValues(current.atr,            previous.atr,            epsilon) &&
      CompareValues(current.bollingerWidth, previous.bollingerWidth, epsilon) &&
      CompareValues(current.lastUpdate,     previous.lastUpdate,     datetimeThreshold);
   
   if (!equal)
      Print("MarketState mismatch detected.");
   
   return equal;
}

//------------------------------------------------------------------
// General comparison function for double values
//------------------------------------------------------------------
bool CompareValues(double a, double b, double epsilon = 1e-6){
   return MathAbs(a - b) < epsilon;
}

//------------------------------------------------------------------
// Compares two datetime values to see if their difference is within a specified threshold
//------------------------------------------------------------------
bool CompareValues(datetime a, datetime b, int timeDifferenceThreshold = 10){
   return MathAbs(a - b) <= timeDifferenceThreshold;
}

//------------------------------------------------------------------
// Compares two boolean values and optionally logs the result
//------------------------------------------------------------------
bool CompareValues(bool a, bool b, LogLevel logLevel = LOG_NONE){
   bool result = (a == b);
   if (!result && logLevel >= LOG_WARNING)
      Print("Mismatch: a = ", a, ", b = ", b);
   return result;
}

//------------------------------------------------------------------
// Main function to update win rates, cache, and validate indicators
//------------------------------------------------------------------
bool UpdateIndicatorsAndValidate(MarketState &state){
   if (!RetryCalculateWinRates())   {
      Log("Error: Failed to update win rates after multiple attempts.", LOG_ERROR);
      return false;
   }

   if (!RetryIndicatorCachingAndValidation(state))   {
      Log("Error: Indicator caching or validation failed after multiple attempts.", LOG_ERROR);
      return false;
   }

   Log("Successfully updated win rates and validated indicators.", LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Retry function for win rate calculation
//------------------------------------------------------------------
bool RetryCalculateWinRates(int maxRetries = 3, int delayMs = 1000){
   // If tradeHistory is already populated, no need to retry.
   if (ArraySize(tradeHistory) > 0)
      return true;

   for (int attempt = 0; attempt < maxRetries; attempt++)   {
      CalculateWinRates(false);
      if (ArraySize(tradeHistory) > 0)      {
         Log(StringFormat("Win rate calculation successful after %d attempt(s).", attempt + 1), LOG_INFO);
         return true;
      }

      Log(StringFormat("Retrying win rate calculation... Attempt %d/%d", attempt + 1, maxRetries), LOG_INFO);
      Sleep(delayMs);
   }

   Log("Error: Failed to calculate win rates after multiple attempts.", LOG_ERROR);
   return false;
}

//------------------------------------------------------------------
// Retry function for indicator caching and validation with exponential backoff
//------------------------------------------------------------------
bool RetryIndicatorCachingAndValidation(MarketState &state, int maxRetries = 3, int baseDelayMs = 1000, int maxBackoffMs = 5000){
   // Use constant parameters to avoid reinitialization on each attempt.
   const int customTimeframe = 15;  // Example: 15 minutes timeframe
   const int customATRPeriod = 14;  // Example ATR period

   for (int attempt = 0; attempt < maxRetries; attempt++)   {
      if (CacheAndValidateIndicators(state, customTimeframe, customATRPeriod))
         return true;

      // Exponential backoff delay (capped at maxBackoffMs)
      int backoffTime = baseDelayMs * (int)MathPow(2, attempt);
      backoffTime = MathMin(backoffTime, maxBackoffMs);

      Log(StringFormat("Retrying indicator caching and validation... Attempt %d/%d, Sleeping for %d ms", attempt + 1, maxRetries, backoffTime), LOG_WARNING);
      Sleep(backoffTime);
   }

   Log("Error: Failed to cache and validate indicators after multiple attempts.", LOG_ERROR);
   return false;
}

//------------------------------------------------------------------
// Helper: Cache and validate indicators
//------------------------------------------------------------------
bool CacheAndValidateIndicators(MarketState &state, int customTimeframe, int customATRPeriod){
   // Cache the symbol to avoid repeated calls.
   string sym = Symbol();
   
   double upperBand, lowerBand, fastMA, slowMA;
   // Retrieve Bollinger Bands and Moving Averages.
   if (!RetrieveBollingerBands(upperBand, lowerBand, sym, customTimeframe) ||
       !RetrieveMovingAverages(fastMA, slowMA, customTimeframe))   {
      Log("Error: Invalid indicator values for " + sym, LOG_ERROR);
      return false;
   }
   
   // Cache Bollinger Width and ATR.
   state.bollingerWidth = upperBand - lowerBand;
   state.atr = cachedATR;
   if (state.atr == EMPTY_VALUE || state.atr < 0)   {
      Log("Error: Invalid ATR value for " + sym, LOG_ERROR);
      return false;
   }
   
   // Calculate slopes if previous values exist.
   if (state.prevFastMA != EMPTY_VALUE && state.prevSlowMA != EMPTY_VALUE)   {
      state.fastMASlope = fastMA - state.prevFastMA;
      state.slowMASlope = slowMA - state.prevSlowMA;
   }
   
   // Update previous MA values.
   state.prevFastMA = fastMA;
   state.prevSlowMA = slowMA;
   
   return true;
}

//------------------------------------------------------------------
// Helper: Retrieve Bollinger Bands and validate
//------------------------------------------------------------------
bool RetrieveBollingerBands(double &upperBand, double &lowerBand, string symbol = NULL, int customTimeframe = 0, int bollingerPeriod = 20, int bollingerDeviation = 2){
   if (symbol == NULL)
      symbol = Symbol();
   if (customTimeframe == 0)
      customTimeframe = Period();
   if (customTimeframe <= 0)   {
      Print("Invalid custom timeframe: ", customTimeframe);
      return false;
   }
   
   upperBand = iBands(symbol, customTimeframe, bollingerPeriod, bollingerDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
   lowerBand = iBands(symbol, customTimeframe, bollingerPeriod, bollingerDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
   if (upperBand == EMPTY_VALUE || lowerBand == EMPTY_VALUE ||
       IsNaN(upperBand) || IsNaN(lowerBand))   {
      Print("Error: Invalid Bollinger Bands data retrieved.");
      return false;
   }
   
   return true;
}

//------------------------------------------------------------------
// Helper: Retrieve Moving Averages and validate
//------------------------------------------------------------------
bool RetrieveMovingAverages(double &fastMA, double &slowMA, int customTimeframe, int fastMAPeriod = 50, int slowMAPeriod = 200, int maType = MODE_SMA){
   // Cache the symbol to avoid redundant calls.
   string sym = Symbol();
   
   if (customTimeframe <= 0 || customTimeframe > 1440)   {
      Print("Invalid custom timeframe: ", customTimeframe);
      return false;
   }
   
   int bars = iBars(sym, customTimeframe);
   if (bars <= MathMax(fastMAPeriod, slowMAPeriod) || bars < 50)   {
      Print("Not enough bars for moving averages calculation for ", sym, " on timeframe ", customTimeframe);
      return false;
   }
   
   fastMA = cachedFastMA;
   slowMA = cachedSlowMA;
   if (fastMA == EMPTY_VALUE || slowMA == EMPTY_VALUE)   {
      Print("Error: Invalid Moving Averages data retrieved for ", sym, " on timeframe ", customTimeframe);
      return false;
   }
   
   return true;
}

//------------------------------------------------------------------
// Handle extreme volatility conditions
//------------------------------------------------------------------
void HandleExtremeVolatility(const MarketState &state){
   // Cache symbol and timeframe.
   string sym = Symbol();
   int tf = Period();

   // Exit early if market is not volatile or ATR is invalid.
   if (!state.isVolatile || state.atr <= 0)   {
      Log(StringFormat("[%s %d] %s", sym, tf,
            !state.isVolatile ? "Market not volatile." : StringFormat("Invalid ATR: %.5f", state.atr)),
            !state.isVolatile ? LOG_DEBUG : LOG_ERROR);
      return;
   }
   
   string context = StringFormat("VolatilityLastUpdate_%s_%d", sym, tf);
   datetime now = TimeCurrent();
   if (now - GetLastUpdate(context) < GetCooldownDuration(state))   {
      Log(StringFormat("[%s %d] Skipped due to cooldown.", sym, tf), LOG_DEBUG);
      return;
   }
   
   SetLastUpdate(context, now);
   Log(StringFormat("[%s %d] High volatility detected. ATR: %.5f, optimizing.", sym, tf, state.atr), LOG_INFO);
   
   if (!RetryOptimizeStrategyParameters() || !ReassessParameters())   {
      Log(StringFormat("[%s %d] Optimization/Reassessment failed.", sym, tf), LOG_ERROR);
      return;
   }
   
   TradingStrategy newStrategy = EnhancedStrategySelection();
   if (!IsValidStrategy(newStrategy))   {
      Log(StringFormat("[%s %d] Invalid strategy. Aborting.", sym, tf), LOG_ERROR);
      return;
   }
   
   Log(StringFormat("[%s %d] New strategy: %s. ATR: %.5f", sym, tf, StrategyToString(newStrategy), state.atr), LOG_INFO);
}

//------------------------------------------------------------------
// Retry mechanism for optimizing strategy parameters with exponential backoff
//------------------------------------------------------------------
bool RetryOptimizeStrategyParameters(int maxRetries = 3){
   if (maxRetries <= 0)
      return false;

   string sym = Symbol();
   int tf = Period();
   for (int attempt = 0; attempt < maxRetries; attempt++)   {
      if (OptimizeStrategyParameters())      {
         Log(StringFormat("[%s %d] Optimization succeeded after %d attempt(s).", sym, tf, attempt + 1), LOG_INFO);
         return true;
      }

      if (attempt % 3 == 0)
         Log(StringFormat("[%s %d] Retrying... Attempt: %d", sym, tf, attempt + 1), LOG_DEBUG);

      int delay = MathMin(1000 * (int)MathPow(2, attempt), 30000);
      Sleep(delay);
   }

   int errorCode = GetLastError();
   Log(StringFormat("[%s %d] Optimization failed after %d attempts. Error: %d - %s", sym, tf, maxRetries, errorCode, GetErrorMessage(errorCode)), LOG_ERROR);
   return false;
}

//------------------------------------------------------------------
// Simplified GetErrorMessage function
//------------------------------------------------------------------
string GetErrorMessage(int errorCode){
   static string localErrorMessages[] = {
      "No error", "No error returned, but the result is unknown", "Common error", "Invalid arguments",
      "Request is rejected", "Trade server is busy", "Old version of the client terminal",
      "No connection with the trade server", "Not enough rights", "Too frequent requests",
      "Account is disabled", "Account is locked", "Trade timeout", "Invalid price", "Invalid stops",
      "Invalid trade volume"
   };

   if (errorCode >= 0 && errorCode < ArraySize(localErrorMessages))
      return localErrorMessages[errorCode];

   string category = (errorCode >= 100 && errorCode < 200) ? "Trade-related" :
                     (errorCode >= 200 && errorCode < 300) ? "Server" : "Unknown";
   Log(StringFormat("Unrecognized error code: %d [%s].", errorCode, category), category == "Unknown" ? LOG_WARNING : LOG_ERROR);
   return StringFormat("Unknown error (%s)", category);
}

//------------------------------------------------------------------
// Determine cooldown duration based on market conditions
//------------------------------------------------------------------
int GetCooldownDuration(const MarketState &state, double atrThreshold = 0.005, double localVolatilityThreshold = 0.5, int baseCooldown = 300){
   int cooldown = baseCooldown;
   if (state.atr > atrThreshold)   {
      cooldown = state.isTrending ? baseCooldown * (1 + (state.atr * 10)) :
                 (state.isVolatile ? baseCooldown * 1.5 : baseCooldown);
      if (currentLogLevel >= LOG_DEBUG)
         Print("Cooldown set to: ", cooldown);
      return cooldown;
   }
   
   if (state.volatilityScore > localVolatilityThreshold)   {
      cooldown = baseCooldown * 1.75;
      if (currentLogLevel >= LOG_DEBUG)
         Print("Cooldown set to: ", cooldown);
      return cooldown;
   }
   
   return cooldown;
}

//------------------------------------------------------------------
// Validates that the provided strategy is acceptable
//------------------------------------------------------------------
bool IsValidStrategy(TradingStrategy strategy) {
    if (!IsStrategyValid(strategy)) {
        LogInvalidStrategy(strategy);
        return false;
    }
    return true;
}

//------------------------------------------------------------------
// Check if the strategy is valid using a switch-case for performance
//------------------------------------------------------------------
bool IsStrategyValid(TradingStrategy strategy) {
   switch(strategy) {
      case TrendFollowing:
      case Scalping:
      case RangeBound:
      case Hybrid:
      case CounterTrend:
      case Grid:
         return true;
      default:
         return false;
   }
}

//------------------------------------------------------------------
// Log invalid strategy attempts with timestamp
//------------------------------------------------------------------
void LogInvalidStrategy(TradingStrategy strategy, int logLevel = LOG_WARNING) {
   string strategyName = StrategyToString(strategy);
   if (StringLen(strategyName) == 0 || strategyName == "Unknown")
      strategyName = "Invalid Strategy (Unknown Enum)";
   if (logLevel >= LOG_WARNING) {
      string logMessage = StringFormat("Invalid strategy passed: %s at time: %s",
                                         strategyName,
                                         TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
      Print(logMessage);
   }
}

//------------------------------------------------------------------
// Get the last update timestamp from a global variable
//------------------------------------------------------------------
datetime GetLastUpdate(const string &context, LogLevel logLevel = LOG_NONE){
   if (!GlobalVariableCheck(context))   {
      if (logLevel >= LOG_ERROR)
         PrintFormat("Error: Global variable %s does not exist", context);
      return 0;
   }
   
   datetime lastUpdate = GlobalVariableGet(context);
   if (lastUpdate == 0)   {
      if (logLevel >= LOG_WARNING)
         PrintFormat("Warning: Failed to retrieve %s", context);
      return 0;
   }
   
   int age = TimeCurrent() - lastUpdate;
   if (age > 86400 && logLevel >= LOG_WARNING)
      PrintFormat("Warning: %s timestamp is %d seconds old", context, age);
   if (logLevel >= LOG_DEBUG)
      PrintFormat("Debug: %s timestamp is %ld", context, lastUpdate);
      
   return lastUpdate;
}

//------------------------------------------------------------------
// Set the last update timestamp via a global variable
//------------------------------------------------------------------
void SetLastUpdate(const string &context, datetime time, LogLevel logLevel = LOG_INFO, bool overwrite = true){
   if (GlobalVariableCheck(context))   {
      if (!overwrite)      {
         Log("Error: Global variable " + context + " exists and will not be overwritten.", LOG_ERROR);
         return;
      }
      GlobalVariableDel(context);
   }
   
   bool success = GlobalVariableSet(context, time);
   if (success && GlobalVariableGet(context) == time)
      Log("Success: Global variable " + context + " set to " + IntegerToString(time), LOG_SUCCESS);
   else
      Log("Error: Failed to set global variable " + context, logLevel);
}

//------------------------------------------------------------------
// Returns the default trading strategy based on market conditions
//------------------------------------------------------------------
TradingStrategy DefaultStrategy() {
   datetime now = TimeCurrent();
   bool trending = MarketIsTrending();
   bool volatile = MarketIsVolatile();
   TradingStrategy defaultStrategy = trending ? TrendFollowing : (volatile ? Breakout : MeanReversion);

   int currentHour = TimeHour(now);
   int logInterval = (currentHour >= 9 && currentHour <= 16) ? (volatile ? 900 : 1800) : (volatile ? 1800 : 3600);
   
   if (defaultStrategy != g_strategyState.lastStrategy ||
       now - g_strategyState.lastLogTime > logInterval) {
      Print("Using default strategy: ", StrategyToString(defaultStrategy));
      g_strategyState.lastLogTime = now;
      g_strategyState.lastStrategy = defaultStrategy;
   }
   
   return defaultStrategy;
}

//------------------------------------------------------------------
// Checks if the market is volatile based on ATR with periodic updates
//------------------------------------------------------------------
bool MarketIsVolatile() {
   static double lastATR = 0;
   static datetime lastUpdate = 0;
   datetime currentTime = TimeCurrent();
   string sym = Symbol();  // Cache symbol to avoid redundant calls
   ENUM_TIMEFRAMES atrTimeframe = PERIOD_H1;  // ATR timeframe

   // Update ATR every 5 minutes if valid, otherwise every 10 minutes
   int updateInterval = (lastATR > 0.001) ? 300 : 600;
   if (currentTime - lastUpdate > updateInterval) {
      lastATR = cachedATR;
      if (lastATR <= 0) {
         Print("Error: Invalid ATR value.");
         return false;
      }
      lastUpdate = currentTime;
   }

   // Compute dynamic threshold based on symbol properties
   double pointSize = SymbolInfoDouble(sym, SYMBOL_POINT);
   double dynamicThreshold = pointSize * (SymbolIsExotic(sym) ? 15.0 : 10.0);
   bool isVolatile = (lastATR > dynamicThreshold);

   // Log volatility changes every 600 seconds
   if (currentTime - g_strategyState.lastLogTime >= 600) {
      Print("Market volatility changed. ATR: ", lastATR, ", Threshold: ", dynamicThreshold);
      g_strategyState.lastLogTime = currentTime;
   }
   
   return isVolatile;
}

//------------------------------------------------------------------
// Determines if a symbol is exotic with enhanced checks
//------------------------------------------------------------------
bool SymbolIsExotic(string symbol) {
   // Convert symbol to uppercase for case-insensitive matching
   symbol = StringToUpper(symbol);

   // Validate symbol format: must be at least 6 characters with no slashes, hyphens, or dots
   if (StringLen(symbol) < 6 || StringFind(symbol, "/") != -1 ||
       StringFind(symbol, "-") != -1 || StringFind(symbol, ".") != -1)
         return false;

   // List of common exotic currency codes (declared static to avoid reallocation)
   static const string exoticPairs[] = {"TRY", "ZAR", "INR", "BRL", "MXN", "SGD", "HKD", "IDR", "PHP"};

   // Split symbol into base and quote parts (e.g., "EURUSD" => "EUR" and "USD")
   string baseCurrency = StringSubstr(symbol, 0, 3);
   string quoteCurrency = StringSubstr(symbol, 3, 3);

   // Check if either currency is in the exotic pairs list
   for (int i = 0; i < ArraySize(exoticPairs); i++) {
      if (baseCurrency == exoticPairs[i] || quoteCurrency == exoticPairs[i])
         return true;
   }

   return false;
}

//------------------------------------------------------------------
// Determines if the market is trending using moving averages and ATR
//------------------------------------------------------------------
bool MarketIsTrending() {
   string sym = Symbol();
   int tf = Timeframe;  // Assumes Timeframe is defined globally

   // Retrieve moving averages
   double ma50 = cachedFastMA;
   double ma200 = cachedSlowMA;
   if(ma50 <= 0 || ma200 <= 0)
      return false;

   double atr = cachedATR;
   double diff = MathAbs(ma50 - ma200);

   // Use the globally declared ATRMultiplier
   if(diff > atr * ATRMultiplier)
      return (ma50 > ma200);  // true for upward trend, false for downward

   // Use Bollinger Bands to further assess market behavior
   double upper = iBands(sym, tf, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double lower = iBands(sym, tf, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double bollingerWidth = upper - lower;
   return (bollingerWidth >= atr);
}

//------------------------------------------------------------------
// Helper function to calculate sentiment based on RSI and MACD values
//------------------------------------------------------------------
double CalculateSentiment(double RSI, double MACDMain, double MACDSignal, double RSI_Overbought, double RSI_Oversold) {
   // Validate inputs and log error (once every 10 minutes) if invalid
   if (RSI < 0 || RSI > 100 || MACDMain == EMPTY_VALUE || MACDSignal == EMPTY_VALUE ||
       RSI_Overbought < 0 || RSI_Overbought > 100 || RSI_Oversold < 0 || RSI_Oversold > 100) {
      static datetime lastLogTimeInternal = 0;
      datetime currentTime = TimeCurrent();
      if (currentTime - lastLogTimeInternal >= 600) {
         Log("Error: Invalid input values for sentiment calculation. Returning neutral sentiment.", LOG_ERROR);
         lastLogTimeInternal = currentTime;
      }
      return 0.5; // Neutral sentiment
   }

   // Determine sentiment based on RSI and MACD conditions
   if (RSI >= RSI_Overbought && MACDMain < MACDSignal)
      return 0.2; // Strong Bearish sentiment
   if (RSI <= RSI_Oversold && MACDMain > MACDSignal)
      return 0.8; // Strong Bullish sentiment
   return (MACDMain > MACDSignal) ? 0.6 : 0.4; // Neutral sentiment based on MACD comparison
}

//------------------------------------------------------------------
// Calculates market sentiment using multi-timeframe indicators.
//------------------------------------------------------------------
double CalculateMarketSentiment(){
   static datetime lastBar = 0;
   static double sentimentCache = 0.5; // Neutral default
   
   if (Time[0] == lastBar)
      return sentimentCache;
   lastBar = Time[0];
   
   const string sym = Symbol();
   // H4 calculations
   double rsiH4    = GetIndicatorValue(sym, PERIOD_H4, INDICATOR_RSI, 0);
   double macdH4_0 = GetIndicatorValue(sym, PERIOD_H4, INDICATOR_MACD_MAIN, 0);
   double macdH4_1 = GetIndicatorValue(sym, PERIOD_H4, INDICATOR_MACD_MAIN, 1);
   double h4Sentiment = CalculateSentiment(rsiH4, macdH4_0, macdH4_1, 70, 30);
   
   // M15 calculations
   double rsiM15    = GetIndicatorValue(sym, PERIOD_M15, INDICATOR_RSI, 0);
   double macdM15_0 = GetIndicatorValue(sym, PERIOD_M15, INDICATOR_MACD_MAIN, 0);
   double macdM15_1 = GetIndicatorValue(sym, PERIOD_M15, INDICATOR_MACD_MAIN, 1);
   double m15Sentiment = CalculateSentiment(rsiM15, macdM15_0, macdM15_1, 70, 30);
   
   const double weightH4 = 0.7, weightM15 = 0.3;
   double combined = MathMax(0.0, MathMin(h4Sentiment * weightH4 + m15Sentiment * weightM15, 1.0));
   
   if (MathAbs(combined - sentimentCache) > 0.2)   {
      Log(StringFormat("Sentiment change: %.2f -> %.2f", sentimentCache, combined), LOG_WARNING);
      sentimentCache = combined;
   }
   return sentimentCache;
}

//------------------------------------------------------------------
// Main function to fetch indicator values with caching
//------------------------------------------------------------------
double GetIndicatorValue(string symbol, int period, IndicatorType indicatorType, int shift, int cachePeriod = 1) {
   // Cache for RSI and MACD main values (index 0 for RSI, 1 for MACD)
   static double cachedValues[2] = {0.5, 0.5};
   static datetime lastUpdateTimes[2] = {0, 0};

   int index = (indicatorType == INDICATOR_RSI) ? 0 : 1;
   datetime currentTime = Time[0];

   // Return cached value if within the caching period
   if (currentTime - lastUpdateTimes[index] <= cachePeriod)
      return cachedValues[index];

   // Fetch new value based on indicator type
   double value = (indicatorType == INDICATOR_RSI) ?
      iRSI(symbol, period, RSIPeriod, PRICE_CLOSE, shift) :
      iMACD(symbol, period, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, shift);

   // Update cache with fetched value or default to neutral if failed
   cachedValues[index] = (value != EMPTY_VALUE) ? value : 0.5;
   lastUpdateTimes[index] = currentTime;
   return cachedValues[index];
}

//------------------------------------------------------------------
// Enhanced Strategy Selection & Optimization based on Market Conditions
//------------------------------------------------------------------
TradingStrategy EnhancedStrategySelection(){
   UpdateCachedIndicators();
   
   if(!CheckStrategyValidity()){
      Log("EnhancedStrategySelection: Conditions not met. Defaulting to TrendFollowing.", LOG_WARNING);
      return TrendFollowing;
   }
   
   double localTrendStrength = cachedTrendStrength;
   double localRSI = cachedRSI;
   double localADX = cachedADX;
   double macdHistogram = cachedIndicators[INDICATOR_MACD_MAIN] - cachedIndicators[INDICATOR_MACD_SIGNAL];
   double spread = MarketInfo(Symbol(), MODE_SPREAD);
   double volume = MarketVolume(); // now defined
   double overallVol = MarketVolatility(PERIOD_H1);
   
   Log("EnhancedStrategySelection: Trend=" + DoubleToString(localTrendStrength,2) +
       " RSI=" + DoubleToString(localRSI,2) +
       " ADX=" + DoubleToString(localADX,2) +
       " MACDHist=" + DoubleToString(macdHistogram,2) +
       " Spread=" + DoubleToString(spread,2) +
       " Volume=" + DoubleToString(volume,2) +
       " Vol=" + DoubleToString(overallVol,2), LOG_INFO);
   
   // (Your strategy selection logic continues...)
   if(localADX >= 25 && localTrendStrength > 0.05 && macdHistogram > 0.0 && spread < 10) {
      return TrendFollowing;
   }
   else if(localRSI < 30 || localRSI > 70) {
      return MeanReversion;
   }
   else if(localTrendStrength < 0.02 && MathAbs(macdHistogram) > 0.05) {
      return CounterTrend;
   }
   else if(overallVol > 2.0 && localRSI > 40 && localRSI < 60) {
      return Scalping;
   }
   else {
      return TrendFollowing;
   }
}

//------------------------------------------------------------------
// MarketVolume: Returns the average tick volume over a specified
// number of recent bars for the current symbol and timeframe.
//------------------------------------------------------------------
double MarketVolume() {
   string sym = Symbol();
   int tf = PERIOD_H1;  // You can change this to a different timeframe if desired.
   int barsToAverage = 10;  // Number of bars to average volume over.
   double volSum = 0.0;
   
   int totalBars = Bars(sym, tf);
   if(totalBars < barsToAverage)
      barsToAverage = totalBars;  // Use available bars if fewer than desired.
   
   for(int i = 0; i < barsToAverage; i++) {
      volSum += iVolume(sym, tf, i);
   }
   
   double avgVolume = (barsToAverage > 0) ? volSum / barsToAverage : 0;
   return avgVolume;
}

bool CheckStrategyValidity(){
   // Define minimum acceptable thresholds
   double minATRThreshold = 0.0005;   // Adjust this threshold based on your instrument
   int minTimeframeMinutes = 15;      // Minimum timeframe in minutes

   // Calculate current ATR value (14-period ATR on current symbol and timeframe)
   double currentATR = iATR(Symbol(), 0, 14, 0);
   if(currentATR <= 0)   {
      Log("CheckStrategyValidity: ATR calculation error.", LOG_ERROR);
      return LogAndReturnFalseWithContext("Invalid strategy: ATR calculation error.");
   }
   if(currentATR < minATRThreshold)   {
      return LogAndReturnFalseWithContext("Invalid strategy: Insufficient volatility. ATR (" + 
                                             DoubleToString(currentATR,6) + 
                                             ") is below threshold (" + DoubleToString(minATRThreshold,6) + ").");
   }
   
   // Convert current timeframe (Period()) to minutes
   int currentTimeframe = Period();
   int currentTimeframeMinutes = 0;
   switch(currentTimeframe)   {
      case PERIOD_M1:   currentTimeframeMinutes = 1; break;
      case PERIOD_M5:   currentTimeframeMinutes = 5; break;
      case PERIOD_M15:  currentTimeframeMinutes = 15; break;
      case PERIOD_M30:  currentTimeframeMinutes = 30; break;
      case PERIOD_H1:   currentTimeframeMinutes = 60; break;
      case PERIOD_H4:   currentTimeframeMinutes = 240; break;
      case PERIOD_D1:   currentTimeframeMinutes = 1440; break;
      default:          currentTimeframeMinutes = 1; break;
   }
   if(currentTimeframeMinutes < minTimeframeMinutes)   {
      return LogAndReturnFalseWithContext("Invalid strategy: Timeframe too low (" + IntegerToString(currentTimeframeMinutes) +
                                             " minutes). Minimum required is " + IntegerToString(minTimeframeMinutes) + " minutes.");
   }
   
   // All checks passed
   return true;
}

//------------------------------------------------------------------
// Determine if optimization is needed for the selected strategy
//------------------------------------------------------------------
bool ShouldOptimize(TradingStrategy strategy) {
    // Check specific conditions for optimization
    if ((strategy == TrendFollowing && IsMarketVolatile()) ||
        (strategy == MeanReversion && IsMarketNeutral()) ||
        (strategy == CounterTrend && IsMarketReversing()) ||
        (strategy == Momentum && IsMarketTrending())) {
        LogOptimizationTrigger(strategy, determineMarketConditionForStrategy(strategy));
        return true;
    }
    
    if (ShouldLog(LOG_DEBUG))
        Log("No specific optimization conditions met for strategy: " + IntegerToString(strategy), LOG_DEBUG);
    
    // Check fallback optimization conditions
    if (ShouldFallbackOptimization(strategy)) {
        Log("Performing basic fallback optimization for strategy: " + IntegerToString(strategy), LOG_DEBUG);
        return true;
    }
    
    return false;
}

//------------------------------------------------------------------
// Maps strategy to its corresponding market condition description
//------------------------------------------------------------------
MarketCondition determineMarketConditionForStrategy(TradingStrategy strategy) {
    MarketCondition marketCondition = UNKNOWN;
    if (strategy == TrendFollowing)
        marketCondition = VOLATILE;
    else if (strategy == MeanReversion)
        marketCondition = NEUTRAL;
    else if (strategy == CounterTrend)
        marketCondition = REVERSING;
    else if (strategy == Momentum)
        marketCondition = TRENDING;
    
    if (marketCondition == UNKNOWN)
        Log("Invalid or undefined strategy: " + IntegerToString(strategy), LOG_ERROR);
    
    return marketCondition;
}

//------------------------------------------------------------------
// Logs optimization triggers with market condition validation
//------------------------------------------------------------------
void LogOptimizationTrigger(TradingStrategy strategy, string marketCondition, LogLevel logLevel = LOG_DEBUG) {
    if (strategy == INVALID_STRATEGY) {
        Log("Invalid strategy provided for optimization trigger.", LOG_ERROR);
        return;
    }
    
    // Use a static array of valid conditions for fast lookup
    static const string validConditions[] = {"volatile", "neutral", "reversing", "trending"};
    bool isValid = false;
    for (int i = 0; i < ArraySize(validConditions); i++) {
        if (marketCondition == validConditions[i]) {
            isValid = true;
            break;
        }
    }
    
    if (!isValid) {
        marketCondition = "neutral"; // Fallback to default
        Log("Unrecognized market condition. Defaulting to neutral.", LOG_WARNING);
    }
    
    Log("Optimization triggered: " + StrategyToString(strategy) + " in " + marketCondition + " market.", logLevel);
}

//------------------------------------------------------------------
// Determines if fallback optimization is needed for a given strategy
//------------------------------------------------------------------
int ShouldFallbackOptimization(TradingStrategy strategy) {
    // Validate strategy first
    if (!IsValidStrategy(strategy)) {
        Print("Error: Invalid strategy provided.");
        const int ERROR_INVALID_STRATEGY = -1;
        return ERROR_INVALID_STRATEGY;  // Defined globally, e.g., const int ERROR_INVALID_STRATEGY = -1;
    }
    
    // Ensure fallback strategies are defined
    if (ArraySize(fallbackStrategies) == 0) {
        Print("Error: No fallback strategies defined.");
        return NO_FALLBACK_OPTIMIZATION;  // Defined globally
    }
    
    // Check if the provided strategy is among the fallback strategies
    const int FALLBACK_OPTIMIZATION_NEEDED = 1;
    for (int i = 0; i < ArraySize(fallbackStrategies); i++) {
        if (strategy == fallbackStrategies[i])
            return FALLBACK_OPTIMIZATION_NEEDED;  // Defined globally, e.g., const int FALLBACK_OPTIMIZATION_NEEDED = 1;
    }
    
    return NO_FALLBACK_OPTIMIZATION;
}

//------------------------------------------------------------------
// Checks if the market is trending
//------------------------------------------------------------------
double IsMarketTrending() {
    static double lastTrendStrength = -1, lastVolatilityFactor = -1;
    const int updateInterval = 5; // seconds
    double currentTime = TimeCurrent();
    
    // Update trend info if the update interval has passed
    if (currentTime - lastUpdateTime > updateInterval) {
        TrendInfo trendResult = GetTrendStrength();
        lastTrendStrength = trendResult.adxValue;
        lastVolatilityFactor = GetMarketVolatilityFactor();
        lastUpdateTime = currentTime;
    }
    
    // Use local constants for error codes
    const int ERROR_INVALID_TREND_STRENGTH = -1;
    const int ERROR_NO_TREND_DETECTED = -888;
    
    // Return error if ADX value is out of bounds
    if (lastTrendStrength < 0 || lastTrendStrength > 100)
        return ERROR_INVALID_TREND_STRENGTH;
    
    // Bound the volatility factor and compute a dynamic threshold
    double minFactor = 0.5, maxFactor = 2.0;
    double volatilityFactor = MathMax(minFactor, MathMin(lastVolatilityFactor, maxFactor));
    double dynamicThreshold = TrendThreshold * (1 + volatilityFactor);
    
    // Return trend strength if above the threshold; otherwise, return an error code
    return (lastTrendStrength > dynamicThreshold) ? lastTrendStrength : ERROR_NO_TREND_DETECTED;
}

//------------------------------------------------------------------
// Get the market volatility factor based on ATR
//------------------------------------------------------------------
double GetMarketVolatilityFactor(int period = 14, double normalizationFactor = 100, bool dynamicScaling = false, LogLevel logLevel = LOG_ERROR) {
    currentLogLevel = logLevel;
    
    string sym = Symbol();
    int bars = iBars(sym, 0);
    int periodToUse = (bars < period) ? 7 : period;
    double atr = cachedATR;
    
    const double INVALID_VOLATILITY = -1.0;
    if (atr <= 0 || atr > MaxAllowedATR(sym)) {
        LogMessage(LOG_ERROR, "Invalid ATR value.");
        return INVALID_VOLATILITY;
    }
    
    // Adjust normalization factor if dynamic scaling is enabled
    if (dynamicScaling)
        normalizationFactor = atr * ScalingFactor(sym);
    
    // Bound the result between (atr*0.001) and (atr*10)
    return MathMax(atr * 0.001, MathMin(atr / normalizationFactor, atr * 10));
}

//------------------------------------------------------------------
// Updated MaxAllowedATR function with improvements
//------------------------------------------------------------------
double MaxAllowedATR(string symbol, int customTimeframe = 0, LogLevel logLevel = LOG_ERROR) {
    // Define default ATR limits based on symbol and timeframe
    double atrLimit;
    if (symbol == "EURUSD")
        atrLimit = (customTimeframe == PERIOD_H1) ? 30.0 : 40.0;
    else if (symbol == "XAUUSD")
        atrLimit = (customTimeframe == PERIOD_H1) ? 100.0 : 150.0;
    else if (symbol == "GBPUSD")
        atrLimit = (customTimeframe == PERIOD_H1) ? 35.0 : 45.0;
    else
        atrLimit = 50.0;
    
    double avgATR = cachedATR;
    if (avgATR <= 0)
        avgATR = atrLimit;  // Fallback if calculation fails

    if (logLevel >= LOG_INFO)
        LogMessage(LOG_INFO, "ATR for " + symbol + ": " + DoubleToString(avgATR));
    
    // Apply a scaling multiplier based on ATR size and return a value not below the limit
    double multiplier = (avgATR > 100) ? 1.2 : 1.5;
    return MathMax(avgATR * multiplier, atrLimit);
}

//------------------------------------------------------------------
// Calculate the scaling factor based on ATR for dynamic adjustment
//------------------------------------------------------------------
double ScalingFactor(string symbol, int customTimeframe = 0, int logInterval = 10, LogLevel logLevel = LOG_ERROR){
   // Validate symbol and ensure sufficient bars are available
   if (!SymbolInfoInteger(symbol, SYMBOL_SELECT))   {
      if (logLevel >= LOG_ERROR)
         LogMessage(LOG_ERROR, "Symbol " + symbol + " is not available.");
      return 0.1;
   }
   
   int bars = iBars(symbol, customTimeframe);
   if (bars < ATRPeriod)   {
      if (logLevel >= LOG_ERROR)
         LogMessage(LOG_ERROR, "Symbol " + symbol + " has insufficient data (" + IntegerToString(bars) + " bars).");
      return 0.1;
   }
   
   // Retrieve ATR value; use fallback if invalid
   double atr = cachedATR;
   if (atr <= 0)   {
      if (logLevel >= LOG_WARNING)
         LogMessage(LOG_WARNING, "ATR for " + symbol + " is zero or invalid.");
      atr = DefaultATR(symbol);
   }
   
   // Determine scaling factor based on ATR thresholds
   double scalingFactor = (atr > 100) ? 0.05 : (atr > 50) ? 0.075 : 0.1;
   
   // Periodic logging of the scaling factor
   static int callCount = 0;
   if (++callCount >= logInterval)   {
      if (logLevel >= LOG_INFO)
         LogMessage(LOG_INFO, "Scaling factor for " + symbol + " is: " + DoubleToString(scalingFactor));
      callCount = 0;
   }
   
   return scalingFactor;
}

//------------------------------------------------------------------
// Return a default ATR value based on symbol availability and market conditions
//------------------------------------------------------------------
double DefaultATR(string symbol, double defaultAtr = 10.0){
   // Check symbol validity, tradability, and data sufficiency
   if (!SymbolInfoInteger(symbol, SYMBOL_SELECT) ||
       MarketInfo(symbol, MODE_MARGINREQUIRED) == 0 ||
       iBars(symbol, 0) < ATRPeriod)   {
      LogMessage(LOG_WARNING, "Symbol " + symbol + " is not available, tradable, or lacks sufficient data.");
      return defaultAtr;
   }
   
   double atr = cachedATR;
   // Check for invalid or NaN ATR (atr != atr tests for NaN)
   if (atr <= 0 || atr != atr)   {
      LogMessage(LOG_WARNING, "Failed to calculate ATR for " + symbol + ". Using default value.");
      return defaultAtr;
   }
   
   return atr;
}

//------------------------------------------------------------------
// Log a message to file or console based on settings
//------------------------------------------------------------------
void LogMessage(LogLevel level, string message, bool toFile = false){
   if (!IsValidLogLevel(level) || level == LOG_NONE || !ShouldLog(level))
      return;

   string logMessage = FormatLogMessage(level, message);
   if(logMessage=="") return; // In case filtering in FormatLogMessage is used

   if (toFile)   {
      EnsureLogFileIsInitialized();
      RotateLogFile();
      if (logFileHandle != INVALID_HANDLE)      {
         if (!FileWrite(logFileHandle, logMessage))
            Print(GetFileErrorMessage("write to"));
      }
      else
         Print("ERROR: Log file is not initialized.");
   }
   else
      Print(logMessage);
}

//------------------------------------------------------------------
// Validate if the log level is one of the allowed values
//------------------------------------------------------------------
bool IsValidLogLevel(int level){
   int validLevels[] = {LOG_NONE, LOG_ERROR, LOG_WARNING, LOG_SUCCESS, LOG_INFO, LOG_DEBUG};
   return (ArrayBsearch(validLevels, level) >= 0);
}

//------------------------------------------------------------------
// Ensure the log file is open and ready for writing
//------------------------------------------------------------------
void EnsureLogFileIsInitialized(){
   // Use the global logFileHandle as our flag for initialization
   if (logFileHandle != INVALID_HANDLE)
      return;

   string logDir   = TerminalInfoString(TERMINAL_DATA_PATH) + "\\Logs\\";
   string fullPath = logDir + LogFileName;

   if (!DirectoryExists(logDir))   {
      Print("ERROR: Log directory does not exist. Please create the directory manually.");
      return;
   }

   logFileHandle = FileOpen(fullPath, FILE_WRITE | FILE_TXT);
   if (logFileHandle == INVALID_HANDLE)
      Print(StringFormat("ERROR: Unable to open log file '%s'. Error code: %d", fullPath, GetLastError()));
}

//------------------------------------------------------------------
// Check if a directory exists by attempting to create and delete a test file
//------------------------------------------------------------------
bool DirectoryExists(string path){
   string testFile = path + "\\test.txt";
   int handle = FileOpen(testFile, FILE_READ | FILE_WRITE | FILE_TXT);
   if (handle == INVALID_HANDLE)
      return false;
   
   FileClose(handle);
   FileDelete(testFile);
   return true;
}

//------------------------------------------------------------------
// Rotate the log file if it exceeds the maximum allowed size
//------------------------------------------------------------------
void RotateLogFile(){
   // Check if the current log file exists and exceeds 10 MB
   int size = FileSize(LogFileName);
   if (size == -1 || size <= 10 * 1024 * 1024 || !FileIsExist(LogFileName))
      return;

   // Close current log file so it can be rotated
   FileClose(logFileHandle);
   logFileHandle = INVALID_HANDLE;

   // Build the rotated file name using current time (to the minute)
   string oldLogFileName = StringFormat("log_%s.txt", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
   int srcHandle = FileOpen(LogFileName, FILE_READ | FILE_TXT);
   int dstHandle = FileOpen(oldLogFileName, FILE_WRITE | FILE_TXT);

   if (srcHandle == INVALID_HANDLE || dstHandle == INVALID_HANDLE)   {
      Print("ERROR: Failed to open log files for rotation.");
      if(srcHandle != INVALID_HANDLE) FileClose(srcHandle);
      if(dstHandle != INVALID_HANDLE) FileClose(dstHandle);
      return;
   }

   // Copy file contents from current log to rotated file and verify integrity
   if (RotateFileContents(srcHandle, dstHandle, oldLogFileName) && FileDelete(LogFileName))   {
      EnsureLogFileIsInitialized();
      if (logFileHandle != INVALID_HANDLE)
         ManageLogFileRetention();
      else
         Print("ERROR: Failed to reinitialize log file after rotation.");
   }
   else   {
      Print("ERROR: Log rotation or deletion failed.");
   }

   FileClose(srcHandle);
   FileClose(dstHandle);
}

//------------------------------------------------------------------
// Copy the entire contents from srcHandle to dstHandle and verify size
//------------------------------------------------------------------
bool RotateFileContents(int srcHandle, int dstHandle, string dstFileName){
   if (srcHandle == INVALID_HANDLE || dstHandle == INVALID_HANDLE)   {
      Print("ERROR: Invalid file handles provided for rotation.");
      return false;
   }

   int totalBytesWritten = 0;
   // Copy each line from the source file to the destination file
   while (!FileIsEnding(srcHandle))   {
      string line = FileReadString(srcHandle);
      if (!FileWrite(dstHandle, line))      {
         Print("ERROR: Failed to write to destination file during rotation.");
         return false;
      }
      // Assume each line ends with a newline (2 bytes)
      totalBytesWritten += StringLen(line) + 2;
   }

   // Verify the destination file size meets our expectations
   int dstSize = FileSize(dstFileName);
   if (dstSize == -1 || dstSize < totalBytesWritten)   {
      Print(StringFormat("ERROR: Destination file size mismatch (%d < %d).", dstSize, totalBytesWritten));
      return false;
   }

   return true;
}

//------------------------------------------------------------------
// Manage retention: delete oldest rotated log files if more than the limit
//------------------------------------------------------------------
void ManageLogFileRetention(){
   const string LOG_FILE_PATTERN      = "log_*.txt";
   const int    LOG_FILE_RETENTION_LIMIT = 5;

   string fileName;
   int handle = FileFindFirst(LOG_FILE_PATTERN, fileName);
   if (handle == INVALID_HANDLE)
      return;

   string fileArray[];
   // Collect all matching file names
   while (FileFindNext(handle, fileName))   {
      ArrayResize(fileArray, ArraySize(fileArray) + 1);
      fileArray[ArraySize(fileArray) - 1] = fileName;
   }
   FileFindClose(handle);

   if (ArraySize(fileArray) <= LOG_FILE_RETENTION_LIMIT)
      return;

   // Sort the array of files (alphabetical order works if filenames contain dates)
   ArraySort(fileArray);
   int filesToDelete = ArraySize(fileArray) - LOG_FILE_RETENTION_LIMIT;
   for (int i = 0; i < filesToDelete; i++)
      FileDelete(fileArray[i]);
}

//------------------------------------------------------------------
// Retrieve and format an error message for file operations
//------------------------------------------------------------------
string GetFileErrorMessage(string operation){
   int errorCode = GetLastError();
   if (errorCode == 0)
      return "";
      
   string errorMessage = StringFormat("ERROR: Failed to %s log file. Error: %d", operation, errorCode);
   switch (errorCode)   {
      case 5001: errorMessage += " (End of file reached)."; break;
      case 5004: errorMessage += " (File could not be deleted)."; break;
      case 5011: errorMessage += " (File not found)."; break;
      case 5021: errorMessage += " (Permission denied)."; break;
      case 5012: errorMessage += " (Write failed)."; break;
      case 5005: errorMessage += " (Invalid file handle)."; break;
      default:   errorMessage += StringFormat(" (Unknown error code: %d)", errorCode); break;
   }

   // Use a runtime check instead of preprocessor directives
   const bool LOG_FILE_ERRORS = true;
   if (LOG_FILE_ERRORS)
      Print(errorMessage);

   return errorMessage;
}

//------------------------------------------------------------------
// Format the log message with a timestamp and prefix
//------------------------------------------------------------------
string FormatLogMessage(LogLevel level, string message){
   // Get and validate the prefix; fall back to a default if invalid
   string prefix = GetLogPrefix(level);
   if(StringLen(prefix) == 0 || !IsValidPrefix(prefix))   {
      prefix = "[INVALID_PREFIX]";
      Print("Error: Invalid log prefix for level ", level);
   }

   int now = TimeCurrent();
   string timeStamp = TimeToString(now, TIME_DATE | TIME_SECONDS);
   int millisec = now % 1000;

   // Inline the milliseconds into the timestamp and format the final message
   return StringFormat("[%s.%03d] %s%s", timeStamp, millisec, prefix, message);
}

//------------------------------------------------------------------
// Validate the log prefix
//------------------------------------------------------------------
bool IsValidPrefix(string prefix){
   string trimmed = StringTrim(prefix);
   if(trimmed == "")   {
      if(currentLogLevel >= LOG_DEBUG)
         Print("Invalid prefix: Empty string detected");
      return false;
   }

   if(StringLen(trimmed) > 20)   {
      if(currentLogLevel >= LOG_DEBUG)
         Print("Invalid prefix: Too long: ", trimmed);
      return false;
   }

   // Valid prefixes (must match exactly)
   static string validPrefixes[] = {"[INFO]", "[ERROR]", "[DEBUG]", "[WARNING]"};
   for(int i = 0; i < ArraySize(validPrefixes); i++)   {
      if(trimmed == validPrefixes[i])
         return true;
   }

   if(currentLogLevel >= LOG_DEBUG)
      Print("Invalid prefix: Unrecognized prefix: ", trimmed);
   return false;
}

//------------------------------------------------------------------
// Retrieve the log prefix based on log level
//------------------------------------------------------------------
string GetLogPrefix(LogLevel level){
   // Mapping from log levels (assumed contiguous from LOG_ERROR to LOG_DEBUG) to prefixes
   static string logPrefixes[] = {"ERROR: ", "WARNING: ", "SUCCESS: ", "INFO: ", "DEBUG: "};

   if(level >= LOG_ERROR && level <= LOG_DEBUG)
      return logPrefixes[level];

   int GlobalLogLevel = LOG_WARNING; // Default to LOG_WARNING (you can set it to any log level)
   if(GlobalLogLevel >= LOG_DEBUG)
      Print(StringFormat("WARNING: Unknown log level encountered: %d", level));

   return StringFormat("UNKNOWN LEVEL (%d): ", level);
}

//------------------------------------------------------------------
// Checks if the market is potentially reversing
//------------------------------------------------------------------
bool IsMarketReversing(){
   TrendInfo trend = GetTrendStrength();
   double adx = trend.adxValue;
   if (adx <= 0 || adx > 100)
      return false;

   // For weak trends, further validate using RSI and MACD conditions
   if (adx < CalculateDynamicThreshold())   {
      double rsi = cachedRSI;
      if ((rsi > 80 || rsi < 20) && IsMACDCrossing())
         return true;
   }
   return false;
}

//------------------------------------------------------------------
// Calculate dynamic threshold based on volatility
//------------------------------------------------------------------
double CalculateDynamicThreshold() {
    const int logLevel = LOG_DEBUG;
    datetime now = TimeCurrent();
    static datetime lastUpdate = 0;
    static double cachedVol = -1;
    
    // Update volatility every 60 seconds, or every 30 seconds if high
    int updateInterval = (cachedVol > 5) ? 30 : 60;
    if(now - lastUpdate > updateInterval) {
        cachedVol = MarketVolatility();
        lastUpdate = now;
    }
    
    if(cachedVol <= 0) {
        Print("Error: Invalid volatility data");
        return TrendThreshold;  // Fallback to default threshold
    }
    
    double scaling = IsForexAsset() ? (cachedVol > 5 ? 100 : 75) : 50;
    const double lowerClamp = 0.1;
    const double upperClamp = 10;
    double clampedVol = GetClampedVolatility(cachedVol, logLevel, lowerClamp, upperClamp);
    
    return TrendThreshold * (1 + clampedVol / scaling);
}

//------------------------------------------------------------------
// Calculate and return the clamped volatility value
//------------------------------------------------------------------
double GetClampedVolatility(double volatility, int logLevelValue, double lowerClamp, double upperClamp){
   // Validate volatility (including NaN check)
   if(volatility <= 0 || volatility != volatility)   {
      if(logLevelValue == LOG_DEBUG)
         Print("Invalid volatility: ", volatility, ", using default value: ", lowerClamp);
      return lowerClamp;
   }
   
   bool highVol = AssetIsHighVolatility();
   double lowerAdjusted = highVol ? 2 : lowerClamp;
   double upperAdjusted = highVol ? 25 : upperClamp;
   
   // Apply a 1% buffer on the range to avoid hitting exact boundaries
   double range = upperAdjusted - lowerAdjusted;
   double buffer = range * 0.01;
   double clamped = MathMin(MathMax(volatility, lowerAdjusted + buffer), upperAdjusted - buffer);
   
   if(clamped != volatility && logLevelValue == LOG_DEBUG)
      Print("Volatility clamped: ", volatility, " -> ", clamped);
   
   return clamped;
}

//------------------------------------------------------------------
// Determine if the asset has high volatility
//------------------------------------------------------------------
bool AssetIsHighVolatility(){
   // Update volatility if needed
   if (IsVolatilityUpdated())
      UpdateVolatility();

   double vol = volatilityState.cachedVolatility;
   if (!IsValidVolatility(vol))   {
      Print("Invalid volatility value: ", vol);
      return false;
   }
   
   const bool ENABLE_LOGGING = true;
   const double VOL_CHANGE_THRESHOLD = 1.0;  // Adjust threshold as needed
   if (ENABLE_LOGGING && MathAbs(vol - volatilityState.lastPrintedVolatility) > VOL_CHANGE_THRESHOLD)   {
      Print("Volatility: ", vol);
      volatilityState.lastPrintedVolatility = vol;
   }
   
   const double HIGH_VOL_THRESHOLD = 5.0;
   return (vol > HIGH_VOL_THRESHOLD);
}

//------------------------------------------------------------------
// Check if the volatility value should be updated
//------------------------------------------------------------------
bool IsVolatilityUpdated(){
   // Local configuration for update intervals (in seconds)
   const double DEFAULT_UPDATE_INTERVAL = 60.0;
   const int MIN_UPDATE_INTERVAL = 1;
   const int TIME_TOLERANCE = 10;
   
   double updateInterval = DEFAULT_UPDATE_INTERVAL;
   if (updateInterval <= 0)   {
      Print("Invalid VolatilityUpdateInterval: must be greater than 0.");
      return false;
   }
   if (updateInterval < MIN_UPDATE_INTERVAL)   {
      updateInterval = MIN_UPDATE_INTERVAL;
      Print("Warning: VolatilityUpdateInterval adjusted to minimum value.");
   }
   
   datetime currentTime = TimeCurrent();
   if (volatilityState.lastUpdate == 0 || volatilityState.lastUpdate > currentTime + TIME_TOLERANCE)   {
      Print("volatilityState.lastUpdate is uninitialized or in the future.");
      return false;
   }
   
   return (currentTime - volatilityState.lastUpdate > updateInterval);
}

//------------------------------------------------------------------
// Update the cached volatility value
//------------------------------------------------------------------
void UpdateVolatility() {
    datetime currentTime = TimeCurrent();
    const int MAX_TIME_GAP         = 3600;  // Maximum gap (seconds)
    const int UPDATE_INTERVAL      = 60;    // Update interval (seconds)
    const int TICKS_BETWEEN_CHECKS = 10;    // Minimum seconds between tick-based updates

    // Retrieve current market volatility
    double volatility = MarketVolatility();
    if(volatility < 0 || volatility != volatility)  // Check for negative or NaN
        return;
    
    // Determine if a forced update is needed:
    // - Never updated before, or
    // - A long gap has passed since the last update, or
    // - (Depending on your logic) if last update was very recent.
    bool forceUpdate = (volatilityState.lastUpdate == 0) ||
                       ((currentTime - volatilityState.lastUpdate) > MAX_TIME_GAP) ||
                       ((currentTime - lastUpdateTime) < UPDATE_INTERVAL);
    if(forceUpdate) {
        volatilityState.cachedVolatility = volatility;
        volatilityState.lastUpdate       = currentTime;
        lastUpdateTime                   = currentTime;
        return;
    }
    
    // Rate-limit tick-based updates
    static datetime lastTickTime = 0;
    if((currentTime - lastTickTime) < TICKS_BETWEEN_CHECKS)
        return;
    
    lastTickTime = currentTime;
}

//------------------------------------------------------------------
// Validate a given volatility value, with limited logging
//------------------------------------------------------------------
bool IsValidVolatility(double volatility){
   static datetime lastLogTimeLocal = 0;
   static int logCount = 0;
   datetime now = TimeCurrent();
   
   if (volatility <= 0 || volatility == EMPTY_VALUE || IsNaN(volatility) || volatility < 1e-6)   {
      // Log at most 5 times per 5-minute window (reset count after 5 minutes)
      if (now - lastLogTimeLocal > 60 && logCount < 5)      {
         Log(LOG_ERROR, StringFormat("Invalid volatility value: %.4f", volatility));
         lastLogTimeLocal = now;
         logCount++;
      }
      return false;
   }
   
   if (now - lastLogTimeLocal > 300)
      logCount = 0;
   
   return true;
}

//------------------------------------------------------------------
// Determine if the asset is a Forex asset
//------------------------------------------------------------------
bool IsForexAsset() {
   string sym = Symbol();
   int dotPos = StringFind(sym, ".");
   if(dotPos >= 0) {
      string suffix = StringSubstr(sym, dotPos + 1);
      // Check if suffix starts with any known forex designator
      static string forexSuffixes[] = {"m", "micro", "cent", "pro", "mini"};
      for(int i = 0; i < ArraySize(forexSuffixes); i++) {
         if(StringFind(suffix, forexSuffixes[i]) == 0) {
            sym = StringSubstr(sym, 0, dotPos);
            break;
         }
      }
   }
   sym = StringToUpper(sym);
   int len = StringLen(sym);
   bool standardPair = (len >= 6 && len <= 7 &&
                        isValidCurrencyCode(StringSubstr(sym, 0, 3)) &&
                        isValidCurrencyCode(StringSubstr(sym, 3, 3)));
   return (standardPair || isExoticPair(sym));
}

//------------------------------------------------------------------
// Helper function to check if a symbol is an exotic pair
//------------------------------------------------------------------
bool isExoticPair(string symbol) {
   int symLen = StringLen(symbol);
   if(symLen < 6)
      return false;

   static string suffixes[] = {".a", ".b", ".c", "_ecn", "_stp", "m", "pro"};
   for(int i = 0; i < ArraySize(suffixes); i++) {
      int sufLen = StringLen(suffixes[i]);
      // Ensure we have enough characters and check the suffix
      if(symLen >= sufLen && StringSubstr(symbol, symLen - sufLen, sufLen) == suffixes[i]) {
         symbol = StringSubstr(symbol, 0, symLen - sufLen);
         symLen = StringLen(symbol);
         break;
      }
   }

   if(symLen < 6)
      return false;
   string quoteCurrency = StringSubstr(symbol, symLen - 3, 3);
   static string exoticPairs[] = {"TRY", "MXN", "ZAR", "INR", "BRL", "RUB"};
   // Use a different loop variable name for the second loop
   for(int j = 0; j < ArraySize(exoticPairs); j++) {
      if(quoteCurrency == exoticPairs[j])
         return true;
   }
   return false;
}

//------------------------------------------------------------------
// Helper function to check if the substring is a valid 3-letter currency code
//------------------------------------------------------------------
bool isValidCurrencyCode(string code) {
   if(StringLen(code) != 3)
      return false;
   code = StringToUpper(code);
   // Check each character is an uppercase letter (A-Z)
   for(int i = 0; i < 3; i++) {
      if(code[i] < 'A' || code[i] > 'Z')
         return false;
   }
   static string validCodes[] = {"USD", "EUR", "GBP", "JPY", "AUD", "CHF", "CAD", "NZD"};
   // Use a different loop variable name for the second loop
   for(int j = 0; j < ArraySize(validCodes); j++) {
      if(code == validCodes[j])
         return true;
   }
   return false;
}

// Function to check for MACD crossover
bool IsMACDCrossing() {
    // Prevent multiple checks on the same bar
    if(Time[1] == lastCheckedTime)
        return false;
    lastCheckedTime = Time[1];

    // Retrieve MACD and Signal values for current and previous bars
    double macdCurrent   = GetMACDValue(0, MODE_MAIN);
    double signalCurrent = GetMACDValue(0, MODE_SIGNAL);
    double macdPrevious  = GetMACDValue(1, MODE_MAIN);
    double signalPrevious= GetMACDValue(1, MODE_SIGNAL);

    // Validate MACD data
    if(macdCurrent == EMPTY_VALUE || signalCurrent == EMPTY_VALUE ||
       macdPrevious == EMPTY_VALUE || signalPrevious == EMPTY_VALUE)    {
        Print("Error: Invalid MACD data.");
        return false;
    }

    // Calculate dynamic tolerance based on ATR
    string sym = Symbol();
    double dynamicTolerance = cachedATR * ATRMultiplier;

    // Check for bullish crossover with sufficient gap
    return (macdPrevious < signalPrevious &&
            macdCurrent  > signalCurrent &&
            MathAbs(macdCurrent - signalCurrent) > dynamicTolerance);
}

// Function to fetch MACD values for a given shift and mode
double GetMACDValue(int shift, int mode) {
    // Validate shift and mode parameters
    if(shift < 0 || (mode != MODE_MAIN && mode != MODE_SIGNAL)) {
        LogError(100, "Invalid shift or mode value. Symbol: " + Symbol() +
                       ", Shift: " + IntegerToString(shift) +
                       ", Mode: " + IntegerToString(mode));
        return EMPTY_VALUE;
    }

    // MACD parameters as constants
    const int fastEMA       = 12;
    const int slowEMA       = 26;
    const int signalSmoothing = 9;
    
    // Validate MACD parameters
    if(fastEMA <= 1 || slowEMA <= 1 || signalSmoothing <= 1 || fastEMA >= slowEMA) {
        LogError(102, "Invalid MACD parameters. fastEMA: " + IntegerToString(fastEMA) +
                       ", slowEMA: " + IntegerToString(slowEMA) +
                       ", signalSmoothing: " + IntegerToString(signalSmoothing));
        return EMPTY_VALUE;
    }

    // Fetch MACD value using iMACD
    double macdValue = iMACD(Symbol(), 0, fastEMA, slowEMA, signalSmoothing, PRICE_CLOSE, mode, shift);

    if(macdValue == EMPTY_VALUE) {
        LogError(101, "Invalid MACD value fetched for Shift: " + IntegerToString(shift) +
                       ", Mode: " + IntegerToString(mode));
        return EMPTY_VALUE;
    }

    return macdValue;
}

//------------------------------------------------------------------
// Checks if the market is neutral
//------------------------------------------------------------------
bool IsMarketNeutral() {
    TrendInfo trend = GetTrendStrength();
    double adx = trend.adxValue;
    
    // Validate ADX value
    if (IsNaN(adx) || adx >= DBL_MAX || adx <= -DBL_MAX)
        return false;
    
    // If market is trending, it's not neutral
    if (adx >= CalculateDynamicThreshold())
        return false;
    
    return IsVolatilityLow() && IsPriceRangeBound();
}

//------------------------------------------------------------------
// Helper function to check if volatility is low
//------------------------------------------------------------------
bool IsVolatilityLow() {
    static double lastATR = 0;
    static datetime lastCalcTime = 0;
    
    if(Time[0] != lastCalcTime) {
        lastATR = cachedATR;
        lastCalcTime = Time[0];
    }
    
    if(IsNaN(lastATR) || lastATR <= 0) {
        int errorCode = 1001;
        string message = "ATR calculation failed for " + Symbol() +
                         " at " + TimeToString(Time[0]) +
                         ". ATR value: " + DoubleToString(lastATR, 6);
        LogError(errorCode, message, LOG_ERROR, -1, Param_ATR, lastATR);
        return false;
    }
    
    return lastATR < volatilityThreshold;
}

//------------------------------------------------------------------
// Helper function to check if price action is range-bound
//------------------------------------------------------------------
bool IsPriceRangeBound(string symbol = NULL, ENUM_TIMEFRAMES tf = 0, double multiplier = 0.1) {
    // Use current symbol and timeframe if not passed
    if(symbol == NULL)
        symbol = Symbol();
    if(tf == 0)
        tf = (ENUM_TIMEFRAMES)Period();
    
    double atr = cachedATR;
    if(atr < 0.0001)
        return false;
    
    double rangeThreshold = atr * multiplier;
    double high = iHigh(symbol, tf, 0);
    double low  = iLow(symbol, tf, 0);
    
    return (high - low) < rangeThreshold;
}

//------------------------------------------------------------------
// Get trend strength using the ADX indicator
//------------------------------------------------------------------
TrendInfo GetTrendStrength(string symbol = "", bool isDebugMode = false) {
    TrendInfo result;
    if(symbol == "")
        symbol = Symbol();
    
    // Validate ADX period (assumed defined globally)
    if (ADXPeriod < 1 || ADXPeriod > 100) {
        Print("Error: Invalid ADX period.");
        result.adxValue = ERROR_ADX_INVALID;
        result.trendDescription = "Invalid period";
        return result;
    }
    
    double adx = iADX(symbol, 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 0);
    if(adx == EMPTY_VALUE || adx == 0 || adx > 100) {
        if(isDebugMode)
            Print("Error: Invalid ADX value. ADX: ", adx);
        result.adxValue = ERROR_ADX_INVALID;
        result.trendDescription = "Invalid ADX value";
        return result;
    }
    
    if(adx < 20)
        result.trendDescription = "Weak or non-existent";
    else if(adx < 25)
        result.trendDescription = "Moderate";
    else
        result.trendDescription = "Strong";
    
    if(isDebugMode)
        Print("Trend strength: ", result.trendDescription, ", ADX: ", adx);
    
    result.adxValue = adx;
    return result;
}

//------------------------------------------------------------------
// Validate the selected trading strategy
//------------------------------------------------------------------
bool ValidateStrategy(TradingStrategy strategy) {
   const int riskLevel    = 3;
   const double stratParam = 100.0;
   const double stopLoss   = 50;
   const double takeProfit = 100;
   
   // Immediately reject Hybrid strategy
   if(strategy == Hybrid)
      return LogStrategyError(100, "Invalid strategy: Hybrid strategy is not valid here.");
   
   // Determine trade direction (cached symbol inside function)
   bool isLongTrade = DetectTradeDirection();  

   switch(strategy) {
      case TrendFollowing:
         if(!ValidateTrendFollowing(isLongTrade))
            return false;
         break;
         
      case Scalping:
         if(!IsLiquiditySufficient() || !ValidateRiskManagement(stopLoss, takeProfit, "Scalping"))
            return LogStrategyError(101, "Scalping conditions not met.");
         break;
         
      case RangeBound: {
         double atr14 = cachedATR;
         if(!IsMarketRangeStable())
            return LogStrategyError(102, StringConcatenate("Market range unstable. ATR(14): ", DoubleToString(atr14, 2)));
         break;
      }
      
      case CounterTrend: {
         ValidationResult validation = ValidateCounterTrend();
         if(!validation.isValid) {
            Print(validation.message);
            return false;
         }
         break;
      }
      
      case Grid:
         if(!ValidateGrid(riskLevel))
            return false;
         break;
         
      case MeanReversion:
         if(IsVolatilityTooHigh() != VolatilityCheckError::VOLATILITY_SUCCESS)
            return LogStrategyError(103, "Volatility too high for MeanReversion.");
         break;
         
      case Breakout:
         if(!IsPriceAboveKeyLevel())
            return LogStrategyError(104, "Price not above key level for Breakout.");
         break;
         
      case Momentum:
         if(!IsMomentumSufficient())
            return LogStrategyError(105, "Insufficient momentum for Momentum strategy.");
         break;
         
      case OtherStrategy:
         if(!ValidateOtherStrategy(stratParam, riskLevel))
            return false;
         break;
         
      default:
         return LogStrategyError(106, StringConcatenate("Unknown strategy type - ", IntegerToString(strategy)));
   }
   
   Log(StringConcatenate("Strategy validated successfully: ", IntegerToString(strategy)), LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Main function to detect trade direction
//------------------------------------------------------------------
MarketCondition DetectTradeDirection() {
   string sym = Symbol();
   
   // Retrieve indicator values once
   double fastMA       = cachedFastMA;
   double slowMA       = cachedSlowMA;
   double adx          = cachedADX;
   double diPlus       = iADX(sym, 0, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
   double diMinus      = iADX(sym, 0, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
   double currentPrice = iClose(sym, 0, 0);
   double atr          = cachedATR;
   double spread       = MarketInfo(sym, MODE_SPREAD);
   
   // Validate essential indicator data
   if(MathAbs(adx) < 1e-4 || MathAbs(diPlus) < 1e-4 || MathAbs(diMinus) < 1e-4 ||
      adx < 20 || atr < 0.005)
      return RANGE_BOUND;
   
   double adxThreshold = (((spread + atr) / 2) > 0.01) ? 30 : 20;
   bool isUpTrend   = (fastMA > slowMA && diPlus > diMinus && adx > adxThreshold && currentPrice > slowMA);
   bool isDownTrend = (fastMA < slowMA && diMinus > diPlus && adx > adxThreshold && currentPrice < slowMA);
   
   // Retrieve previous ADX values for trend strength comparison
   double adxPrev  = iADX(sym, 0, 14, PRICE_CLOSE, MODE_MAIN, 1);
   double adxPrev2 = iADX(sym, 0, 14, PRICE_CLOSE, MODE_MAIN, 2);
   
   // If breakout conditions and a strong trend are detected, return the market condition accordingly
   if(IsBreakout(currentPrice, 5) && IsStrongTrend(adx, adxPrev, adxPrev2, diPlus, diMinus)) {
      if(isUpTrend)
         return TRENDING;
      if(isDownTrend)
         return SHORT_TRADE;
   }
   
   return NEUTRAL;
}

//------------------------------------------------------------------
// Simplified Moving Average Calculation
//------------------------------------------------------------------
double CalculateMA(string symbol, int tf, int period, int shift = 1) {
   // Validate inputs and data availability
   if(period <= 0 || shift < 1)
      return 0.0;
   if(MarketInfo(symbol, MODE_BID) == 0.0 || !IsValidTimeframe(tf))
      return 0.0;
   if(SeriesInfoInteger(symbol, tf, SERIES_SYNCHRONIZED) == 0 || Bars(symbol, tf) <= period)
      return 0.0;
   
   static datetime lastBarTime = 0;
   static double lastMAValue = 0.0;
   
   datetime currentBarTime = iTime(symbol, tf, shift);
   if(currentBarTime == lastBarTime)
      return lastMAValue;
   
   lastBarTime = currentBarTime;
   lastMAValue = iMA(symbol, tf, period, 0, MODE_SMA, PRICE_CLOSE, shift);
   return lastMAValue;
}

//------------------------------------------------------------------
// Check if the timeframe is valid for the current symbol
//------------------------------------------------------------------
bool IsValidTimeframe(int tf) {
   return ((tf > 0) || (tf == PERIOD_CURRENT)) && (iTime(Symbol(), tf, 0) > 0);
}

//------------------------------------------------------------------
// Helper function to detect trend strength
//------------------------------------------------------------------
bool IsStrongTrend(double adx, double adxPrev, double adxPrev2, double diPlus, double diMinus, bool checkDirection = false, double adxMin = 25, double adxMax = 60, double adxGrowthFactor = 1.02) {
   // Validate ADX readings and ensure a proper increasing trend
   if(adx <= 0 || adxPrev <= 0 || adxPrev2 <= 0 || adx < adxMin || adx > adxMax || adx < adxPrev || adxPrev < adxPrev2) {
      if(isVerboseLoggingEnabled)
         Print("Invalid ADX trend: ", adx, ", ", adxPrev, ", ", adxPrev2);
      return false;
   }
   
   // Cache ATR value (assumed to be calculated on the same timeframe)
   double atrValue = cachedATR;
   if(atrValue <= 0 || atrValue > 100) {
      if(isVerboseLoggingEnabled)
         Print("Invalid ATR value: ", atrValue);
      return false;
   }
   
   // Optionally, check if the difference between DI values is sufficient
   if(checkDirection && (diPlus - diMinus < 5)) {
      if(isVerboseLoggingEnabled)
         Print("Weak trend direction: diPlus = ", diPlus, ", diMinus = ", diMinus);
      return false;
   }
   
   // Return true if the trend is strengthening appropriately
   return (adx > adxPrev * adxGrowthFactor && adxPrev > adxPrev2);
}

//------------------------------------------------------------------
// Helper function to detect breakout condition
//------------------------------------------------------------------
bool IsBreakout(double currentPrice, int lookBackPeriod) {
   string sym = Symbol();
   int barsAvail = iBars(sym, 0);
   
   // Validate available data and look-back period
   if(barsAvail < 2 || lookBackPeriod < 2)
      return false;
   lookBackPeriod = MathMin(lookBackPeriod, barsAvail - 1);
   
   int highestIndex = iHighest(sym, 0, MODE_HIGH, lookBackPeriod, 0);
   int lowestIndex  = iLowest(sym, 0, MODE_LOW, lookBackPeriod, 0);
   double recentHigh = iHigh(sym, 0, highestIndex);
   double recentLow  = iLow(sym, 0, lowestIndex);
   
   int digits = MarketInfo(sym, MODE_DIGITS);
   double buffer = 2 * Point;
   
   return (currentPrice > NormalizeDouble(recentHigh + buffer, digits) || currentPrice < NormalizeDouble(recentLow - buffer, digits));
}

//------------------------------------------------------------------
// Log error and return false
//------------------------------------------------------------------
bool LogStrategyError(int errorCode, string message, int logLevel = LOG_ERROR) {
   if(StringLen(message) > MAX_LOG_MESSAGE_LENGTH)
      message = StringSubstr(message, 0, MAX_LOG_MESSAGE_LENGTH) + "...";
   
   if(!LogError(errorCode, message, logLevel)) {
      static int fileHandle = INVALID_HANDLE;
      if(fileHandle == INVALID_HANDLE)
         fileHandle = FileOpen("error_log.txt", FILE_WRITE | FILE_TXT);
      
      FileWrite(fileHandle, StringFormat("LogError failed: %s", message));
   }
   return false;
}

//------------------------------------------------------------------
// Check if volatility is too high for MeanReversion strategy
//------------------------------------------------------------------
VolatilityCheckError IsVolatilityTooHigh(string symbol = "", double localVolatilityThreshold = 0.05, int atrPeriodLocal = 14, int timeframeLocal = PERIOD_H1) {
   if(symbol == "")
      symbol = Symbol();
   if(symbol == "")
      return MISSING_SYMBOL;
   if(atrPeriodLocal < 5 || atrPeriodLocal > 100)
      return OUT_OF_RANGE;
   if(iBars(symbol, timeframeLocal) < atrPeriodLocal)
      return INSUFFICIENT_DATA;
   
   double atr = cachedATR;
   if(atr <= 0)
      return INVALID_ATR;
   
   // Return appropriate error if ATR exceeds threshold
   return (atr > localVolatilityThreshold) ? VOLATILITY_TOO_HIGH : VOLATILITY_SUCCESS;
}

//------------------------------------------------------------------
// Check if the price is above a key level for Breakout strategy
//------------------------------------------------------------------
bool IsPriceAboveKeyLevel(string symbol = "", int barsBack = 20, int inputTimeframe = 0) {
   if(symbol == "")
      symbol = Symbol();
   if(inputTimeframe == 0)
      inputTimeframe = Period();
   
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT) || iBars(symbol, inputTimeframe) < barsBack)
      return false;
   
   double keyLevel    = iHigh(symbol, inputTimeframe, barsBack);
   double currentPrice= iClose(symbol, inputTimeframe, 0);
   
   return (keyLevel > 0 && currentPrice > 0 && currentPrice > keyLevel);
}

//------------------------------------------------------------------
// Check if momentum is sufficient for Momentum strategy
//------------------------------------------------------------------
bool IsMomentumSufficient(int rsiPeriod = 14, double threshold = 50) {
   double rsi = cachedRSI;
   return (!IsNaN(rsi) && rsi > threshold);
}

//------------------------------------------------------------------
// Validate CounterTrend strategy
//------------------------------------------------------------------
ValidationResult ValidateCounterTrend() {
   ValidationResult result;
   string failureMessage = "";
   
   // Accumulate error messages (empty string means no error)
   failureMessage += CheckIfVolatile(currentLogLevel);
   failureMessage += CheckIfRSIIndicatesOverboughtOversold();
   
   ValidationResult riskValidation = CheckIfRiskAcceptable();
   if(!riskValidation.isValid)
      failureMessage += riskValidation.message;
   
   // If any error messages exist, the strategy is invalid
   if(failureMessage != "") {
      result.isValid = false;
      result.message = "CounterTrend strategy validation failed: " + failureMessage;
      Log(result.message, LOG_ERROR);
   }
   else {
      result.isValid = true;
      result.message = "CounterTrend strategy is valid.";
      Log(result.message, LOG_INFO);
   }
   return result;
}

//------------------------------------------------------------------
// Check if market volatility is high
//------------------------------------------------------------------
string CheckIfVolatile(int logLevel) {
    static bool cachedIsVolatile;
    static datetime lastCheck = 0;
    datetime now = TimeCurrent();
    
    // Update cache if more than 10 seconds have passed
    if(now - lastCheck > 10) {
        cachedIsVolatile = IsHighVolatilityMarket();
        lastCheck = now;
    }
    
    // Compose the volatility message
    string message = cachedIsVolatile ? "Market volatility is too high." : "Market volatility is normal.";
    
    // Log the message based on the log level
    if(logLevel >= LOG_INFO)
        Print(message);
    if(logLevel >= LOG_DEBUG)
        Print("Detailed log: Volatility status is ", (cachedIsVolatile ? "high" : "normal"), ".");
    
    // Only return a message if volatility is too high (an error condition)
    return cachedIsVolatile ? message : "";
}

//------------------------------------------------------------------
// Check if RSI indicates overbought or oversold conditions
//------------------------------------------------------------------
string CheckIfRSIIndicatesOverboughtOversold(int rsiPeriod = 14, int overboughtLevel = 70, int oversoldLevel = 30, int cacheInterval = 10) {
    static datetime lastRSICheck = 0;
    datetime now = TimeCurrent();
    
    // Update the cached RSI if the cache interval has expired
    if(now - lastRSICheck > cacheInterval) {
        double rsi = cachedRSI;
        lastRSICheck = now;
    }
    
    // If RSI calculation failed, log and return an error message.
    if(rsi == EMPTY_VALUE) {
        string errorMsg = "Error: RSI calculation failed for symbol: " + Symbol() + " at time: " + TimeToString(now) + ". ";
        Print(errorMsg);
        return errorMsg;
    }
    
    // Return an error message if RSI indicates overbought or oversold conditions; otherwise, return empty.
    if(rsi > overboughtLevel)
        return "Market is overbought (RSI > " + IntegerToString(overboughtLevel) + ", RSI: " + DoubleToString(rsi, 2) + "). ";
    else if(rsi < oversoldLevel)
        return "Market is oversold (RSI < " + IntegerToString(oversoldLevel) + ", RSI: " + DoubleToString(rsi, 2) + "). ";
    
    return "";
}

//------------------------------------------------------------------
// Check if risk level is acceptable
//------------------------------------------------------------------
ValidationResult CheckIfRiskAcceptable() {
    ValidationResult result;
    double riskLevel = GetRiskLevel();
    
    // Check for an invalid risk level (negative or NaN)
    if(riskLevel < 0 || riskLevel != riskLevel) {
        result.isValid = false;
        result.message = "Error: Invalid risk level. ";
        return result;
    }
    
    // Evaluate individual risk conditions
    bool fundamentalRiskOk = IsRiskAcceptable();      // equity, drawdown, and account status
    bool marketStable     = !IsMarketVolatile();        // volatility check
    bool marketTrending   = IsMarketTrending();           // trending condition
    
    // Overall market risk is acceptable only if all individual conditions pass
    if(fundamentalRiskOk && marketStable && marketTrending) {
        result.isValid = true;
        result.message = "";
    }
    else {
        result.isValid = false;
        // If the fundamental risk is fine, the issue is market volatility/trend.
        // Otherwise, the risk is inherently too high.
        if(fundamentalRiskOk)
            result.message = StringFormat("Market volatility detected. Risk level: %.2f. ", riskLevel);
        else
            result.message = StringFormat("Risk level too high: %.2f. Exposure exceeds the allowed threshold. ", riskLevel);
    }
    
    return result;
}

//------------------------------------------------------------------
// Calculate the current risk level based on account parameters
//------------------------------------------------------------------
double GetRiskLevel() {
    double accountBalance = AccountBalance();
    double accountEquity  = AccountEquity();
    
    if(accountBalance <= 0)
        return 0;
    
    // If equity is critically low (≤1% of account balance), risk is maximal
    if(accountEquity <= 0.01 * accountBalance)
        return 1;
    
    double marginUsed = AccountMargin();
    double riskLevel  = marginUsed / accountEquity;
    
    // Clamp risk level if margin usage is excessively high
    if(marginUsed > accountEquity * 10)
        riskLevel = 1;
    // Adjust for extreme leverage
    else if(AccountLeverage() > 100)
        riskLevel = MathMin(riskLevel * 1.5, 1);
    
    return MathMin(riskLevel, 1);
}

//------------------------------------------------------------------
// Check if market volatility is high using ATR
//------------------------------------------------------------------
bool IsHighVolatilityMarket(int atrPeriodLocal = 14, int atrTimeframeLocal = PERIOD_H1, double volatilityThresholdLocal = 0.02, int logLevel = LOG_DEBUG){
   double atr = cachedATR;
   if(atr <= 0)   {
      Print("Error: Invalid ATR value.");
      return false;
   }
   
   if(logLevel >= LOG_DEBUG)
      Print("ATR: ", atr, " (Period: ", atrPeriodLocal, ", Timeframe: ", atrTimeframeLocal, ")");
      
   return atr > volatilityThresholdLocal;
}

//------------------------------------------------------------------
// Validate Grid strategy parameters
//------------------------------------------------------------------
bool ValidateGrid(int riskLevel) {
   const double gridSize = 10.0;
   const int maxGridSteps = 10;
   
   if(!ValidateParameterInRange(gridSize, 0.1, 1000.0, "Grid size"))
      return false;
   
   if(!ValidateParameterInRange(riskLevel, 1, 5, "Risk level"))
      return false;
   
   if(!ValidateParameterInRange(maxGridSteps, 1, 50, "Maximum grid steps"))
      return false;
   
   if(DEBUG_MODE)
      Log("Grid strategy validation passed.", LOG_DEBUG);
   
   return true;
}

//------------------------------------------------------------------
// General utility function for parameter validation
// with configurable epsilon tolerance and NaN/Infinity checks
//------------------------------------------------------------------
bool ValidateParameterInRange(double param, double min, double max, string paramName, double epsilon = 1e-7, int logLevel = LOG_ERROR) {
    // Check for NaN or Infinity
    if(IsNaN(param) || IsInfinityOrNaN(param)) {
        Log(StringFormat("%s is not a valid number (NaN or Infinity).", paramName), logLevel);
        return false;
    }

    // Check if parameter is within the specified range (with epsilon tolerance)
    if(param < min - epsilon || param > max + epsilon) {
        Log(StringFormat("%s is out of range: %f. Valid range is %f to %f", paramName, param, min, max), logLevel);
        return false;
    }
    return true;
}

// Custom function to check if a value is either infinite or NaN
bool IsInfinityOrNaN(double value) {
    return value == INFINITY || value == -INFINITY || IsNaN(value);
}

//------------------------------------------------------------------
// Validate OtherStrategy parameters
//------------------------------------------------------------------
bool ValidateOtherStrategy(double someParameter, int someRiskLevel, int logLevel = LOG_INFO) {
   if(someParameter <= 0 || someParameter > 1000) {
      Log("Invalid parameter value for OtherStrategy: " + DoubleToString(someParameter), LOG_ERROR);
      return false;
   }
   
   if(someRiskLevel < 1 || someRiskLevel > 5) {
      Log("Invalid risk level for OtherStrategy: " + IntegerToString(someRiskLevel), LOG_ERROR);
      return false;
   }
   
   if(logLevel >= LOG_INFO)
      Log("OtherStrategy validation passed.", logLevel);
   
   return true;
}

//------------------------------------------------------------------
// Validate Trend Following strategy conditions
//------------------------------------------------------------------
bool ValidateTrendFollowing(bool isLongTrade) {
   // Check basic conditions: sufficient volatility data and proper timeframe
   if (!IsVolatilityDataSufficient() || Period() < PERIOD_H1)
      return LogAndReturnFalseWithContext("Invalid strategy: Insufficient volatility or timeframe too low.");

   // Configure and retrieve trend information
   #define ADX_THRESHOLD 25
   TrendInfoConfig config;
   config.isVerboseLoggingEnabled = true;
   config.adxThreshold = ADX_THRESHOLD;
   TrendInfo trend = GetTrendInfo(config);

   // If ADX is too low or the market is ranging, the strategy is invalid
   if (trend.adxValue < ADX_THRESHOLD || IsMarketRanging(trend.adxValue) == RANGE_BOUND)
      return LogAndReturnFalseWithContext(StringFormat("Invalid strategy: Weak or ranging market (ADX=%.2f).", trend.adxValue));

   // Calculate moving average slopes
   const int FAST_MA_PERIOD = 10, FAST_MA_SLOPE_LOOKBACK = 5;
   const int SLOW_MA_PERIOD = 50, SLOW_MA_SLOPE_LOOKBACK = 10;
   double fastMASlope = GetMASlope(FAST_MA_PERIOD, FAST_MA_SLOPE_LOOKBACK);
   double slowMASlope = GetMASlope(SLOW_MA_PERIOD, SLOW_MA_SLOPE_LOOKBACK);

   // Validate trend direction relative to the trade type
   if ((isLongTrade && (fastMASlope < 0 || slowMASlope < 0)) ||
       (!isLongTrade && (fastMASlope > 0 || slowMASlope > 0)))   {
      string trendType = isLongTrade ? "Downtrend" : "Uptrend";
      return LogAndReturnFalseWithContext(StringFormat("Invalid strategy: %s detected (Fast MA=%.5f, Slow MA=%.5f).", trendType, fastMASlope, slowMASlope));
   }

   LogMessage(LOG_INFO, StringFormat("TrendFollowing validated (ADX=%.2f, Fast MA=%.5f, Slow MA=%.5f).", trend.adxValue, fastMASlope, slowMASlope));
   return true;
}

//------------------------------------------------------------------
// Calculate the slope of a moving average over a given lookback period
//------------------------------------------------------------------
double GetMASlope(int maPeriod, int barsBack) {
   if (barsBack <= 0 || barsBack >= Bars - 1) {
      Print("GetMASlope Error: Invalid barsBack value.");
      return 0;
   }

   double currentMA = iMA(NULL, 0, maPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double pastMA = iMA(NULL, 0, maPeriod, 0, MODE_SMA, PRICE_CLOSE, barsBack);

   if (currentMA == EMPTY_VALUE || pastMA == EMPTY_VALUE) {
      Print("GetMASlope Warning: iMA returned EMPTY_VALUE.");
      return EMPTY_VALUE;
   }

   return (currentMA - pastMA) / barsBack;
}

//------------------------------------------------------------------
// Determine if market is ranging based on ADX and Bollinger Bands
//------------------------------------------------------------------
MarketCondition IsMarketRanging(double adxValue, double bollingerWidthThreshold = 0.0010, double adxThreshold = 20, int period = 20, int deviation = 2) {
   double upperBand = iBands(NULL, 0, period, deviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double lowerBand = iBands(NULL, 0, period, deviation, 0, PRICE_CLOSE, MODE_LOWER, 0);

   if (upperBand == EMPTY_VALUE || lowerBand == EMPTY_VALUE)
      return UNKNOWN;

   double bollingerWidth = upperBand - lowerBand;
   if (adxValue < adxThreshold && bollingerWidth < bollingerWidthThreshold)
      return RANGE_BOUND;
   if (adxValue >= adxThreshold)
      return TRENDING;

   return UNKNOWN;
}

//------------------------------------------------------------------
// Retrieve trend information based on ADX and log if changed
//------------------------------------------------------------------
TrendInfo GetTrendInfo(TrendInfoConfig &config) {
   TrendInfo trend;
   trend.adxValue = cachedADX;

   if (trend.adxValue == EMPTY_VALUE) {
      trend.adxValue = 0;
      trend.trendDescription = "Invalid ADX Value";
   }
   else {
      trend.trendDescription = (trend.adxValue < config.adxThreshold) ? "Weak Trend" :
                                (trend.adxValue < 50) ? "Trending" : "Strong Trend";
   }

   // Log only if verbose logging is enabled and the trend has changed
   static string lastTrendDescription = "";
   if (config.isVerboseLoggingEnabled && trend.trendDescription != lastTrendDescription) {
      Print(StringFormat("Symbol: %s, ADX: %.2f, Trend: %s", Symbol(), trend.adxValue, trend.trendDescription));
      lastTrendDescription = trend.trendDescription;
   }

   return trend;
}

//------------------------------------------------------------------
// Check if liquidity is sufficient for Scalping strategy
//------------------------------------------------------------------
bool IsLiquiditySufficient() {
   const int numBars         = 5;
   const double spreadThresh = 10;
   const int volumeThresh    = 1000;
   double totalSpread = 0, totalVolume = 0;
   int validBars = 0;
   string sym = Symbol();
   
   for(int i = 0; i < numBars; i++) {
      double spread = MarketInfo(sym, MODE_SPREAD);
      int volume = iVolume(sym, 0, i);
      
      if(spread < spreadThresh && volume > volumeThresh) {
         totalSpread += spread;
         totalVolume += volume;
         validBars++;
      }
   }
   return (validBars == numBars && (totalSpread / numBars) < spreadThresh &&
           (totalVolume / numBars) > volumeThresh);
}

//------------------------------------------------------------------
// Log error with context and return false
//------------------------------------------------------------------
bool LogAndReturnFalseWithContext(string errorMessage){
   string context = "Symbol: " + Symbol() + ", Timeframe: " + IntegerToString(Period()) +
                    ", ATR: " + DoubleToString(iATR(Symbol(), 0, 14, 0), 6);
   Log("Strategy validation failed - " + errorMessage + " | Context: " + context, LOG_ERROR);
   return false;
}

//------------------------------------------------------------------
// Check if volatility data is sufficient for trend-following strategy
//------------------------------------------------------------------
bool IsVolatilityDataSufficient(double localVolatilityThreshold = 0.02) {
   double atrValue = cachedATR;  // ATR from the previous bar
   if (atrValue <= 0) {
      Print("Error: ATR value is invalid.");
      return false;
   }
   return atrValue > localVolatilityThreshold;
}

//------------------------------------------------------------------
// Check if the market is in a stable range for range trading strategy
//------------------------------------------------------------------
bool IsMarketRangeStable() {
   const int period   = 14;
   const int lookback = 10;
   double priceRange = 0, atrSum = 0;
   
   for(int i = 0; i < lookback; i++) {
      priceRange += iHigh(NULL, 0, i) - iLow(NULL, 0, i);
      atrSum     += cachedATR;
   }
   return ((priceRange / lookback) < ((atrSum / lookback) * 0.2));
}

//------------------------------------------------------------------
// Validate risk management settings with dynamic configuration
//------------------------------------------------------------------
bool ValidateRiskManagement(double stopLoss, double takeProfit, string strategy) {
   bool isScalping = (strategy == "Scalping");
   double minStopLoss  = isScalping ? 5 : 10;
   double maxStopLoss  = isScalping ? 50 : 200;
   double minTakeProfit = isScalping ? 5 : 20;
   double maxTakeProfit = isScalping ? 50 : 300;
   
   // Ensure SL and TP are within acceptable ranges.
   if(stopLoss < minStopLoss || stopLoss > maxStopLoss ||
      takeProfit < minTakeProfit || takeProfit > maxTakeProfit)
      return false;
   
   string sym = Symbol();
   // Check margin and equity conditions.
   if(MarketInfo(sym, MODE_MARGINREQUIRED) > AccountFreeMargin() * 0.8 ||
      stopLoss > AccountEquity() * 0.2)
      return false;
   
   double atr = cachedATR;
   if(atr <= 0 || (stopLoss / (takeProfit * atr)) > 1)
      return false;
   
   // Retrieve the current spread.
   double spread = MarketInfo(sym, MODE_SPREAD) * Point;
   // Ensure that both SL and TP are set further away than the current spread.
   if(stopLoss <= spread || takeProfit <= spread)
      return false;
   
   return true;
}

//------------------------------------------------------------------
// Return a fallback strategy based on evaluated market conditions
//------------------------------------------------------------------
TradingStrategy GetFallbackStrategy() {
    MarketCondition marketCondition = EvaluateMarketConditions();
    
    if (isVerboseLoggingEnabled) {
        static MarketCondition lastLoggedCondition = UNKNOWN;
        datetime now = TimeCurrent(); // cache current time
        if (marketCondition != lastLoggedCondition || now - lastLogTime > 60) {
            Print("Market condition: ", EnumToString(marketCondition));
            lastLoggedCondition = marketCondition;
            lastLogTime = now;
        }
    }
    
    switch (marketCondition) {
        case VOLATILE:
            return Grid;
        case TRENDING:
        case SHORT_TRADE: // combined cases returning the same strategy
            return TrendFollowing;
        case RANGE_BOUND:
            return Scalping;
        case REVERSING:
            return CounterTrend;
        default:
            return Hybrid;
    }
}

//+------------------------------------------------------------------+
//| Evaluates the market conditions and returns the current state    |
//+------------------------------------------------------------------+
MarketCondition EvaluateMarketConditions() {
    const int periodParam = 14;
    string symbolStr = Symbol();
    int periodVal = Period();
    
    double atr = cachedATR;
    double rsi = cachedRSI;
    
    if (atr <= 0 || rsi <= 0)
        return UNKNOWN;  // Handle invalid values
    
    if (isVerboseLoggingEnabled)
        Print("ATR: ", atr, " | RSI: ", rsi);
    
    if (atr > 0.5)
        return VOLATILE;
    if (rsi > 70)
        return TRENDING;
    if (rsi < 30)
        return RANGE_BOUND;
    
    return NEUTRAL;
}

//------------------------------------------------------------------
// Handle failure in market conditions validation
//------------------------------------------------------------------
void HandleMarketConditionsValidationFailure() {
    double currentEquity = AccountEquity();
    const double DynamicEquityThreshold = 500.0;
    
    if (ShouldLog(LOG_ERROR))
        Log("Market conditions validation failed. Strategy selection aborted.", LOG_ERROR);
    
    if (currentEquity < DynamicEquityThreshold && ShouldLog(LOG_WARNING))
        LogRiskBreach("Market Conditions Validation Failed", currentEquity);
    
    if (isVerboseLoggingEnabled) {
        Log("Verbose logging disabled after market validation failure.", LOG_DEBUG);
        ToggleVerboseLogging(false);
        isVerboseLoggingEnabled = false;
    }
}

//------------------------------------------------------------------
// Validates an indicator value and returns an appropriate status
//------------------------------------------------------------------
IndicatorValidationResult IsValidIndicatorValue(const double value, const double minVal = 0.0001, const double maxVal = 100000) {
    // Check for NaN or Infinity
    if (IsNaN(value) || value == INFINITY || value == -INFINITY) {
        Log("Invalid indicator: NaN/Infinity detected.", LOG_WARNING);
        return IsNaN(value) ? INVALID_NAN : INVALID_INFINITY;
    }
    
    // Check for EMPTY_VALUE or zero
    if (value == EMPTY_VALUE || value == 0.0) {
        Log("Invalid indicator: EMPTY_VALUE or 0.0 detected.", LOG_WARNING);
        return (value == EMPTY_VALUE) ? INVALID_EMPTY_VALUE : INVALID_ZERO;
    }
    
    // Check if the value is within the acceptable range
    if (value < minVal || value > maxVal) {
        Log(StringFormat("Invalid indicator: Out of range (%.8f).", value), LOG_WARNING);
        return INVALID_RANGE;
    }
    
    return VALID;
}

//------------------------------------------------------------------
// Determine market conditions based on updated indicators
//------------------------------------------------------------------
TradingStrategy DetermineMarketConditions() {
    const int UpdateInterval = 60; // seconds
    datetime now = TimeCurrent();

    // Update indicators only if the update interval has passed
    if(now - lastIndicatorUpdateTime >= UpdateInterval) {
        lastIndicatorUpdateTime = now;
        string sym = Symbol();
        
        // Update primary indicators
        cachedADX = iADX(sym, PERIOD_H1, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 0);
        const double BollingerDeviation = 2.0;
        double upperBand = iBands(sym, PERIOD_H1, BollingerPeriod, BollingerDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
        double lowerBand = iBands(sym, PERIOD_H1, BollingerPeriod, BollingerDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
        cachedBollingerWidth = upperBand - lowerBand;
        
        // Optionally, update other indicators here if needed.
    }
    
    // Use a different variable name for subsequent indicator calls
    string currentSymbol = Symbol();
    double macdMain = iMACD(currentSymbol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    double macdSignal = iMACD(currentSymbol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
    double rsi = cachedRSI; // Assumed updated elsewhere via UpdateCachedIndicators()
    
    // Define fixed thresholds; these could later be made dynamic.
    const double ADXThreshold   = 25;
    const double MAThreshold    = 0.005;
    const double ATRHighThresh  = 0.001;
    const double ATRLowThresh   = 0.0005;
    
    // Debug logging for additional indicators
    if(DEBUG_MODE)
        Print(StringFormat("MACD: %.4f, Signal: %.4f, RSI: %.2f", macdMain, macdSignal, rsi));
    
    // Enhanced decision logic using additional indicators:
    // 1. TrendFollowing: High ADX, significant MA difference, bullish MACD.
    if(cachedADX > ADXThreshold &&
       MathAbs(cachedFastMA - cachedSlowMA) > cachedSlowMA * MAThreshold &&
       macdMain > macdSignal && macdMain > 0)    {
        return LogAndReturnCondition(TrendFollowing, "Trend Following (Strong MACD & ADX)");
    }
    // 2. RangeBound: Narrow Bollinger width and low ADX.
    else if(cachedBollingerWidth < cachedFastMA * MAThreshold && cachedADX < 20)    {
        return LogAndReturnCondition(RangeBound, "Range Bound (Narrow Bollinger & Low ADX)");
    }
    // 3. Scalping: High ATR, bullish MACD, and RSI not overbought.
    else if(cachedATR > ATRHighThresh && macdMain > macdSignal && rsi < 70)    {
        return LogAndReturnCondition(Scalping, "Scalping (High ATR, Bullish MACD, Moderate RSI)");
    }
    // 4. CounterTrend: Low ATR, bearish MACD, and oversold RSI.
    else if(cachedATR < ATRLowThresh && macdMain < macdSignal && rsi < 30)    {
        return LogAndReturnCondition(CounterTrend, "Counter Trend (Low ATR, Bearish MACD, Oversold RSI)");
    }
    // 5. MeanReversion: Overbought RSI with weak MACD difference.
    else if(rsi > 70 && MathAbs(macdMain - macdSignal) < 0.01)    {
        return LogAndReturnCondition(MeanReversion, "Mean Reversion (Overbought RSI, Weak MACD)");
    }
    
    // Default fallback to Hybrid if none of the above conditions are strongly met.
    return LogAndReturnCondition(Hybrid, "Hybrid (Default fallback)");
}

//------------------------------------------------------------------
// Helper function: Log and return market condition
//------------------------------------------------------------------
TradingStrategy LogAndReturnCondition(TradingStrategy condition, string conditionName) {
    // Validate the condition name
    if (StringLen(conditionName) == 0 || !IsValidConditionName(conditionName)) {
        Print("Invalid condition name.");
        return TradingStrategy::OtherStrategy;  // Fallback for an invalid name
    }
    
    // Persist the last condition across calls
    static TradingStrategy lastCondition = TradingStrategy::OtherStrategy;
    
    // Validate the condition value range
    if (condition < TrendFollowing || condition > SafeMode) {
        if (debugMode)
            Print("Invalid condition: ", condition);
        return TradingStrategy::OtherStrategy;
    }
    
    // Log condition change if cooldown period has passed (60 seconds)
    static datetime lastLogTimeLocal = 0;
    if (lastCondition != condition && TimeCurrent() - lastLogTimeLocal > 60) {
        LogMarketCondition(conditionName);
        lastLogTimeLocal = TimeCurrent();
        lastCondition = condition;
    }
    
    return condition;
}

// Helper function to validate condition name
bool IsValidConditionName(string name) {
    // Check if name is empty or too long
    int len = StringLen(name);
    if (len == 0 || len > 50) return false;  // Invalid if empty or too long

    // Trim leading and trailing spaces
    name = StringTrim(name);

    bool lastCharWasSpace = false;
    
    // Ensure name only contains alphanumeric characters, spaces, hyphens, or underscores
    for (int i = 0; i < StringLen(name); i++) {
        char c = name[i];

        // Check for consecutive spaces
        if (c == ' ' && lastCharWasSpace) return false;

        lastCharWasSpace = (c == ' ');
    }

    return true;
}

// Log market condition with a standardized method
void LogMarketCondition(string condition) {
    if (StringLen(condition) == 0) return;  // Exit early if condition is empty

    string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
    string conditionLower = StringToLower(condition);

    // Log Market Condition at INFO level
    if (ShouldLog(LOG_INFO)) {
        Log(StringFormat("Market condition: %s at %s", condition, timestamp), LOG_INFO);
    }

    // Log Risk Breach at WARNING level for specific conditions
    if (ShouldLog(LOG_WARNING) && (conditionLower == "hybrid (default)" || conditionLower == "range bound" || conditionLower == "trend following") && cachedATR > 0) {
        LogRiskBreach(StringFormat("Market condition: %s, potential strategy mismatch.", condition), cachedATR);
    }

    // Log Scalping at ERROR level
    if (ShouldLog(LOG_ERROR) && conditionLower == "scalping") {
        Log("Scalping condition detected; high volatility expected.", LOG_ERROR);
    }

    // Log Debug information
    if (ShouldLog(LOG_DEBUG)) {
        Log(StringFormat("Market condition evaluation complete for %s at %s.", condition, timestamp), LOG_DEBUG);
    }
}

//------------------------------------------------------------------
// Validate and simulate the selected strategy
//------------------------------------------------------------------
bool ValidateAndSimulateStrategy(TradingStrategy selectedStrategy) {
    // Validate strategy range.
    if (selectedStrategy < TrendFollowing || selectedStrategy > SafeMode) {
        Log("Error: Invalid strategy.", LOG_ERROR);
        return false;
    }
    
    // Convert strategy to string; use a fallback if empty.
    string strategyStr = StrategyToString(selectedStrategy);
    if (strategyStr == "")
        strategyStr = "UndefinedStrategy";
    
    Log(StringFormat("Running Monte Carlo for strategy: %s.", strategyStr), LOG_INFO);
    
    // Run the simulation and check its status.
    if (MonteCarloSimulationWithCheck() != SIMULATION_OK) {
        Log("Monte Carlo simulation failed.", LOG_ERROR);
        return false;
    }
    
    Log("Simulation completed successfully.", LOG_INFO);
    return true;
}

//------------------------------------------------------------------
// Error-checking wrapper for Monte Carlo simulation
//------------------------------------------------------------------
int MonteCarloSimulationWithCheck() {
    if (!IsSimulationReady()) {
        Log("Monte Carlo simulation aborted: Missing resources or invalid parameters.", LOG_ERROR);
        return RESOURCE_FAILURE;
    }
    
    datetime startTime = TimeCurrent();
    int simulationStatus = MonteCarloSimulation(); // Run simulation
    
    if (TimeCurrent() - startTime > 30) {  // Timeout threshold of 30 seconds
        Log("Monte Carlo simulation timed out.", LOG_ERROR);
        return TIMEOUT;
    }
    
    if (simulationStatus == SIMULATION_OK)
        Log("Monte Carlo simulation completed successfully.", LOG_INFO);
    else
        Log(StringFormat("Monte Carlo simulation failed. Error code: %d.", simulationStatus), LOG_ERROR);
    
    return simulationStatus;
}

//------------------------------------------------------------------
// Check if the simulation is ready to run
//------------------------------------------------------------------
bool IsSimulationReady() {
    string sym = Symbol();
    MqlTick tick;
    
    if (!IsConnected() ||
        SymbolInfoDouble(sym, SYMBOL_BID) <= 0.0 ||
        !MarketInfo(sym, MODE_TRADEALLOWED) ||
        !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
        iTime(sym, PERIOD_CURRENT, 0) == 0 ||
        !SymbolInfoTick(sym, tick) ||
        tick.time == 0 ||
        AccountFreeMarginCheck(sym, OP_BUY, MarketInfo(sym, MODE_MINLOT)) < 0 ||
        MarketInfo(sym, MODE_SPREAD) > 20)
    {
        Print("Error: Conditions not met.");
        return false;
    }
    
    return true;  // All checks passed
}

//------------------------------------------------------------------
// Optimize and validate strategy parameters with logging
//------------------------------------------------------------------
void OptimizeAndValidateStrategyParameters(TradingStrategy selectedStrategy) {
    if (!IsValidStrategy(selectedStrategy)) {
        LogError(1, "Error: Invalid or unsupported strategy selected.", LOG_LEVEL_ERROR);
        return;
    }
    
    const datetime now = TimeCurrent();
    const string timeStr = TimeToString(now, TIME_DATE | TIME_MINUTES);
    LogMessage(0, StringFormat("Starting validation and optimization for strategy: %s at %s.",
                StrategyToString(selectedStrategy), timeStr), LOG_INFO);
    
    int optimizationStatus = OptimizeStrategyParameters();
    string resultMessage;
    
    if (optimizationStatus == OPTIMIZATION_SUCCESS)
         resultMessage = "Strategy parameters optimized successfully.";
    else if (optimizationStatus == OPTIMIZATION_FAILED)
         resultMessage = "Optimization failed. Please check the strategy parameters and try again.";
    else
         resultMessage = "Unknown optimization status. Please verify the optimization process.";
    
    if (optimizationStatus == OPTIMIZATION_SUCCESS)
         LogMessage(0, resultMessage, LOG_INFO);
    else
         LogError(optimizationStatus == OPTIMIZATION_FAILED ? 2 : 3, resultMessage, LOG_LEVEL_ERROR);
}

//------------------------------------------------------------------
// Select the best strategy based on market conditions.
//------------------------------------------------------------------
TradingStrategy SelectBestStrategy(){
   static datetime lastUpdate = 0;
   datetime now = TimeCurrent();
   if (now - lastUpdate >= 10)   {
      UpdateTrendStrength();
      lastUpdate = now;
   }
   
   bool isVolatile = IsMarketVolatile();
   double sentiment = CalculateMarketSentiment();
   if (ShouldLog(LOG_DEBUG))   {
      Log(StringFormat("Volatile=%d, Sentiment=%.2f, TrendStrength=%.2f", isVolatile, sentiment, trendStrength), LOG_DEBUG);
   }
   
   TradingStrategy strat = EnhancedStrategySelection();
   if (strat == NULL)   {
      Log("Fallback to CounterTrend.", LOG_WARNING);
      ExecuteCounterTrendLogic(isVolatile ? 30 : 20, isVolatile ? 50 : 40, "Fallback");
      return CounterTrend;
   }
   return strat;
}

//------------------------------------------------------------------
// Improved Monte Carlo simulation with detailed logging and risk management
//------------------------------------------------------------------
double GetMonteCarloSimulatedProfit(TradingStrategy strategy){
   const int SIMULATION_COUNT = 1000;
   double totalProfit = 0.0;
   static bool seeded = false;
   if (!seeded) { MathSrand(TimeLocal()); seeded = true; }
   
   for (int i = 0; i < SIMULATION_COUNT; i++) {
      double gridDistance = 0.5 + (MathRand() / 65535.0) * 1.5;
      double riskPercentage = 0.5 + (MathRand() / 65535.0) * 4.5;
      int tradeDurationInBars = 10 + (MathRand() % 20);
      totalProfit += SimulateTradingForStrategy(strategy, gridDistance, riskPercentage,
                                                  tradeDurationInBars, 0.0005, 0.0002);
   }
   return totalProfit / SIMULATION_COUNT;
}

//------------------------------------------------------------------
// Main simulation function for a given strategy and parameters
//------------------------------------------------------------------
double SimulateTradingForStrategy(TradingStrategy strategy, double gridDistance, double riskPercentage, int tradeDurationInBars, double transactionCost, double slippage){
    // Validate parameters upfront
    if (!ValidateParameters(gridDistance, riskPercentage, tradeDurationInBars, transactionCost, slippage))    {
        Log("Invalid parameters", LOG_ERROR);
        return EMPTY_VALUE;
    }
    
    double accountEquity = AccountEquity();                        // Cache account equity once
    double positionSize  = AccountBalance() * riskPercentage / 100;  // Calculate position size
    
    switch (strategy)    {
        case TrendFollowing:
            return SimulateTrendFollowing(gridDistance, riskPercentage, tradeDurationInBars, transactionCost, slippage, accountEquity);
        case Scalping:
            return SimulateScalping(gridDistance, riskPercentage, transactionCost, slippage, positionSize);
        case RangeBound:
            return SimulateRangeBound(gridDistance, riskPercentage, transactionCost, slippage);
        case Hybrid:
            return SimulateHybrid(gridDistance, riskPercentage, transactionCost, slippage);
        case CounterTrend:
            return SimulateCounterTrend(gridDistance, riskPercentage, transactionCost, slippage);
        case Grid:
            return SimulateGridTrading(gridDistance, riskPercentage, slippage);
        default:
            Log("Unknown strategy: " + StrategyToString(strategy), LOG_ERROR);
            return EMPTY_VALUE;
    }
}

//------------------------------------------------------------------
// Helper: Validate all parameters
//------------------------------------------------------------------
bool ValidateParameters(double gridDistance, double riskPercentage, int tradeDurationInBars, double transactionCost, double slippage){
    if (ValidateGridDistance(gridDistance) != GRID_SUCCESS)
        return false;
    if (ValidateRiskPercentage(riskPercentage) != RISK_SUCCESS)
        return false;
    if (!ValidateTradeDuration(tradeDurationInBars))
        return false;
    if (ValidateTransactionCost(transactionCost) != COST_SUCCESS)
        return false;
    if (!ValidateSlippage(slippage))
        return false;
    return true;
}

//------------------------------------------------------------------
// Validate grid distance
//------------------------------------------------------------------
GridDistanceError ValidateGridDistance(double gridDistance){
    const double minGridDistance = 0.0001;
    const double maxGridDistance = 10.0;
    
    if (gridDistance <= 0)    {
        Log("Error: Grid distance must be greater than 0. Provided: " + DoubleToString(gridDistance, 5), LOG_ERROR);
        return NEGATIVE_DISTANCE;
    }
    if (gridDistance < minGridDistance)    {
        Log("Error: Grid distance is too small. Minimum acceptable value is: " + DoubleToString(minGridDistance, 5), LOG_ERROR);
        return SMALL_DISTANCE;
    }
    if (gridDistance > maxGridDistance)    {
        Log("Error: Grid distance is too large. Maximum acceptable value is: " + DoubleToString(maxGridDistance, 5), LOG_ERROR);
        return LARGE_DISTANCE;
    }
    
    return GRID_SUCCESS;
}

//------------------------------------------------------------------
// Validate risk percentage
//------------------------------------------------------------------
RiskPercentageError ValidateRiskPercentage(double riskPercentage, double minRisk = 0.01, double maxRisk = 100.0){
    const double epsilon = 1e-4;
    
    if (riskPercentage < 0)    {
        Log("Error: Risk percentage cannot be negative. Provided: " + DoubleToString(riskPercentage, 5), LOG_ERROR);
        return RISK_NEGATIVE;
    }
    if (riskPercentage <= epsilon)    {
        Log("Warning: Risk percentage must be greater than " + DoubleToString(minRisk, 2) + ". Provided: " + DoubleToString(riskPercentage, 5), LOG_WARNING);
        return RISK_TOO_LOW;
    }
    if (riskPercentage > maxRisk)    {
        Log("Warning: Risk percentage must be less than or equal to " + DoubleToString(maxRisk, 2) + ". Provided: " + DoubleToString(riskPercentage, 5), LOG_WARNING);
        return RISK_TOO_HIGH;
    }
    
    return RISK_SUCCESS;
}

//------------------------------------------------------------------
// Validate transaction cost
//------------------------------------------------------------------
TransactionCostError ValidateTransactionCost(double transactionCost){
    const double MIN_TRANSACTION_COST = 0.0001;
    const double MAX_TRANSACTION_COST = 100.0;
    
    if (transactionCost <= 0)    {
        Log("Error: Invalid transaction cost. Should be greater than 0. Provided: " + DoubleToString(transactionCost, 3), LOG_ERROR);
        return COST_INVALID;
    }
    if (transactionCost < MIN_TRANSACTION_COST)    {
        Log("Error: Transaction cost is too low. Expected at least " + DoubleToString(MIN_TRANSACTION_COST, 3) + ". Provided: " + DoubleToString(transactionCost, 3), LOG_ERROR);
        return COST_TOO_LOW;
    }
    if (transactionCost > MAX_TRANSACTION_COST)    {
        Log("Error: Transaction cost is too high. Expected at most " + DoubleToString(MAX_TRANSACTION_COST, 3) + ". Provided: " + DoubleToString(transactionCost, 3), LOG_ERROR);
        return COST_TOO_HIGH;
    }
    
    return COST_SUCCESS;
}

//------------------------------------------------------------------
// Validate trade duration
//------------------------------------------------------------------
bool ValidateTradeDuration(int tradeDurationInBars){
    static datetime lastTradeLogTime = 0;
    datetime now = TimeLocal();
    const int MAX_TRADE_DURATION_BARS = 1000;
    
    if (tradeDurationInBars <= 0 || tradeDurationInBars > MAX_TRADE_DURATION_BARS)    {
        if (now - lastTradeLogTime > 10)        {
            Log(StringFormat("Trade duration must be between 1 and %d bars. Provided: %d", MAX_TRADE_DURATION_BARS, tradeDurationInBars), LOG_ERROR);
            lastTradeLogTime = now;
        }
        return false;
    }
    
    return true;
}

//------------------------------------------------------------------
// Validate slippage
//------------------------------------------------------------------
bool ValidateSlippage(double slippage){
    const int logCooldownTime = 10;
    datetime now = TimeLocal();
    static datetime lastSlippageLogTime = 0;
    const double MAX_SLIPPAGE_ALLOWED = 100;
    const double MIN_VALID_SLIPPAGE = 0.0001;
    
    if (slippage <= MIN_VALID_SLIPPAGE || slippage > MAX_SLIPPAGE_ALLOWED)    {
        string slippageStr = DoubleToString(slippage, 1);
        string maxSlippageStr = DoubleToString(MAX_SLIPPAGE_ALLOWED, 1);
        if (now - lastSlippageLogTime > logCooldownTime)        {
            Log("Invalid slippage. Must be between " + DoubleToString(MIN_VALID_SLIPPAGE, 4) + " and " + maxSlippageStr + " pips. Provided: " + slippageStr, LOG_ERROR);
            lastSlippageLogTime = now;
        }
        return false;
    }
    
    return true;
}

//------------------------------------------------------------------
// Optimized Trend Following simulation with dynamic stop-loss/take-profit
//------------------------------------------------------------------
double SimulateTrendFollowing(double gridDistance, double riskPercentage, int tradeDurationInBars, double transactionCost, double slippage, double accountEquity){
   // Validate inputs
   if(gridDistance <= 0 || riskPercentage <= 0 || riskPercentage > 100 || accountEquity <= 0)
      return 0;
      
   string sym = Symbol();
   double point = MarketInfo(sym, MODE_POINT);
   gridDistance = MathMax(gridDistance, point);
   
   // Choose timeframe based on trade duration and compute ATR
   int tf = (tradeDurationInBars > 50) ? PERIOD_H1 : PERIOD_M15;
   double atr = cachedATR;
   
   // Random factor adjustment
   double randomFactor = ((MathRand() % 10001) / 50000.0 - 0.1);
   
   // Calculate profit target based on risk percentage and ATR/grid ratio
   double profit = (riskPercentage / 100.0) * gridDistance * (1.0 + NormalizeDouble(atr / gridDistance, 2)) * (1.0 + randomFactor);
   
   // Determine spread based on market info and ATR
   double spread = MathMax(MarketInfo(sym, MODE_SPREAD) * point, atr * 0.05) * 1.2;
   
   // Calculate stop loss and take profit using dynamic functions
   double stopLoss = MathMin(CalculateDynamicStopLoss(accountEquity) + spread + slippage, accountEquity * 0.02);
   double takeProfit = MathMax(CalculateDynamicTakeProfit(stopLoss) * 1.2, stopLoss + transactionCost + slippage);
   
   // Check trend indicators and reverse profit if needed
   double ma10 = cachedFastMA;
   double ma50 = cachedSlowMA;
   double rsi  = cachedRSI;
   if(ma10 < ma50 && rsi < 45)
      profit *= -1;
      
   // Clamp final profit to a valid range
   return MathClamp(profit, -stopLoss * 1.2, takeProfit * 1.2);
}

//------------------------------------------------------------------
// Optimized dynamic stop-loss calculation
//------------------------------------------------------------------
double CalculateDynamicStopLoss(double availableEquity, double stopLossPercentage = DEFAULT_STOP_LOSS_PERCENTAGE, double maxStopLossThreshold = 0.5, double maxRiskPercentage = 0.5){
   if (availableEquity <= 0)
      return -1.0;  // Invalid equity

   // Clamp percentages to valid ranges [0,1]
   stopLossPercentage = MathMax(MathMin(stopLossPercentage, 1.0), 0.0);
   maxStopLossThreshold = MathMin(MathMax(maxStopLossThreshold, 0.0), 1.0);
   
   // Retrieve volatility factor and validate it
   double volatility = GetVolatilityFactor();
   if (volatility < 0)
      return -1.0;  // Propagate error from volatility calculation

   // Calculate initial stop loss based on volatility and clamp to max thresholds
   double stopLoss = -availableEquity * stopLossPercentage * volatility;
   stopLoss = MathMax(stopLoss, -availableEquity * maxStopLossThreshold);
   stopLoss = MathMin(stopLoss, availableEquity * maxRiskPercentage);
   
   return stopLoss;
}

//------------------------------------------------------------------
// Optimized volatility factor calculation
//------------------------------------------------------------------
double GetVolatilityFactor(int atrPeriod = 14){
    string sym = Symbol();

    // Validate symbol selection
    if(sym == "" || !SymbolInfoInteger(sym, SYMBOL_SELECT))    {
        Print("Invalid symbol: ", sym);
        return -1.0;
    }

    double atr = cachedATR;
    double pointSize = MarketInfo(sym, MODE_POINT);

    // Ensure valid ATR and point size values, including minimum thresholds
    if(atr <= 0 || pointSize <= 0 || atr < 0.0001 || pointSize < 1e-5)    {
        Print("Invalid ATR or point size for ", sym, " ATR: ", atr, " Point size: ", pointSize);
        return -1.0;
    }

    return atr / pointSize;
}

//------------------------------------------------------------------
// Optimized dynamic take-profit calculation
//------------------------------------------------------------------
double CalculateDynamicTakeProfit(double stopLossThreshold, double riskToRewardRatio = 1.0){
    const double maxVolatility = 200.0;  // Maximum allowed volatility factor

    // Validate inputs: stopLossThreshold must be negative; riskToRewardRatio in (0,100]
    if(stopLossThreshold >= 0 || riskToRewardRatio <= 0 || riskToRewardRatio > 100)    {
        Print("Invalid inputs: stopLossThreshold: ", stopLossThreshold, ", riskToRewardRatio: ", riskToRewardRatio);
        return -1000000.0;  // Error flag
    }

    double volatility = GetVolatilityFactor();
    if(volatility <= 0 || volatility > maxVolatility)    {
        Print("Invalid volatility factor: ", volatility);
        return -1000000.0;  // Error flag
    }

    // Compute take profit: use risk-to-reward factor scaled by volatility
    double tp1 = stopLossThreshold * -riskToRewardRatio * volatility;
    double tp2 = stopLossThreshold * -0.5;
    double takeProfit = MathMax(tp1, tp2);

    Print("Calculated Take Profit: ", takeProfit);
    return takeProfit;
}

//------------------------------------------------------------------
// Simulate Scalping strategy with volatility and market fluctuation adjustments
//------------------------------------------------------------------
double SimulateScalping(double gridDistance, double riskPercentage, double transactionCost, double slippage, double positionSize){
    if (riskPercentage <= 0 || riskPercentage > 100)
        return -1.0;
    
    const string sym = Symbol();
    double atr = cachedATR;
    if (atr == 0)
        atr = 1.0;  // Prevent division by zero
    
    double profit = riskPercentage * (1 + atr / 100 * 0.2);  // Volatility adjustment
    double spread = MarketInfo(sym, MODE_SPREAD);
    double gridPenalty = gridDistance * (atr / 100) * 0.1 + spread * 0.1;
    
    double adjustedProfit = profit - gridPenalty - transactionCost * positionSize - slippage * positionSize;
    return (adjustedProfit > 0) ? NormalizeDouble(adjustedProfit, 2) : -1.0;
}

//------------------------------------------------------------------
// Simulate RangeBound strategy with grid distance and risk percentage adjustments
//------------------------------------------------------------------
double SimulateRangeBound(double gridDistance, double riskPercentage, double transactionCost, double slippage){
    if (riskPercentage <= 0 || riskPercentage > 100)
        return -1.0;
    
    const string sym = Symbol();
    double atr = cachedATR;
    if (atr < 0.0001)
        atr = 0.0001;  // Avoid extremely small values
    
    double volatilityFactor = 1.0 + MathPow((atr / 100), 0.5) * 0.2;
    double profit = (gridDistance * 50.0 - riskPercentage * 25.0) * volatilityFactor;
    double penalty = gridDistance * (atr / 100) * 0.1 + transactionCost * gridDistance * 0.01 + slippage * gridDistance * 0.02;
    
    return NormalizeDouble(MathMax(profit - penalty, 0), 2);
}

//------------------------------------------------------------------
// Simulate Hybrid strategy combining trend and range components
//------------------------------------------------------------------
double SimulateHybrid(double gridDistance, double riskPercentage, double transactionCost, double slippage){
    if (gridDistance <= 0.0 || gridDistance > 100.0 || riskPercentage <= 0.0 || riskPercentage > 1.0)    {
        Print("Error: Invalid input parameters.");
        return 0.0;
    }
    
    double randomFactor = (double)MathRand() / 32767.0;
    double baseProfit = (gridDistance * riskPercentage * randomFactor + (1.0 / gridDistance) * 50.0);
    baseProfit *= (1.0 - transactionCost - slippage);
    baseProfit *= (1.0 + randomFactor * 0.05);
    baseProfit -= baseProfit * riskPercentage * 0.03;
    
    return MathMax(baseProfit, 0);
}

//------------------------------------------------------------------
// Simulate CounterTrend strategy with reversal and trend penalties
//------------------------------------------------------------------
double SimulateCounterTrend(double gridDistance, double riskPercentage, double transactionCost, double slippage){
    if (riskPercentage <= 0.0 || riskPercentage > 1.0)
        return EMPTY_VALUE;
    
    double reversalPotential = 100.0 / (riskPercentage + 0.01);  // Avoid division by zero
    reversalPotential = MathMin(reversalPotential, 20.0);
    
    const string sym = Symbol();
    double volatility = cachedATR;
    double trendPenalty = gridDistance * volatility * 0.1;
    
    return MathMax(reversalPotential - trendPenalty, 1.0);
}

//------------------------------------------------------------------
// Simulate Grid Trading strategy with basic adjustments
//------------------------------------------------------------------
double SimulateGridTrading(double gridDistance, double riskPercentage, double slippage){
    if (gridDistance <= 0 || riskPercentage <= 0 || riskPercentage > 100)
        return 0.0;
    
    const string sym = Symbol();
    double atr = cachedATR;
    double bid = MarketInfo(sym, MODE_BID);
    double ask = MarketInfo(sym, MODE_ASK);
    double avgPrice = (bid + ask) / 2;
    double volatilityFactor = 1.0 + atr / avgPrice;
    
    double profit = gridDistance * riskPercentage * 100.0 * volatilityFactor;
    profit *= 1.0 + AccountEquity() / AccountFreeMargin();
    
    double spread = MarketInfo(sym, MODE_SPREAD);
    profit -= spread + MathMin(slippage * spread, spread * 0.7);
    
    profit -= gridDistance * volatilityFactor * 0.8;
    
    return MathMax(profit, -gridDistance * 100.0);
}

//------------------------------------------------------------------
// Execute Trading Strategy with dynamic risk management and order retry
//------------------------------------------------------------------
bool ExecuteStrategy(TradingStrategy strategy, double equity, double drawdown, double marketSentiment){
   if(equity <= 0 || drawdown < 0) {
      Log("ExecuteStrategy: Invalid equity or drawdown.", LOG_ERROR);
      return false;
   }
   
   double lotSize = 0.0, sl = 0.0, tp = 0.0;
   RiskLevelType riskLevel = (drawdown > 0.2 * equity) ? RiskLow : RiskMedium;
   
   switch(strategy) {
      case TrendFollowing:
         sl = CalculateStopLoss(riskLevel);
         tp = CalculateTakeProfit(riskLevel);
         lotSize = CalculatePositionSize(riskLevel, sl);
         break;
      case Scalping:
         sl = CalculateStopLoss(RiskLow);
         tp = CalculateTakeProfit(RiskLow);
         lotSize = CalculatePositionSize(RiskLow, sl);
         break;
      case CounterTrend:
         Log("ExecuteStrategy: Processing CounterTrend.", LOG_INFO);
         sl = CalculateStopLoss(riskLevel);
         tp = CalculateTakeProfit(riskLevel);
         lotSize = CalculatePositionSize(riskLevel, sl);
         break;
      case MeanReversion:
         Log("ExecuteStrategy: Processing MeanReversion.", LOG_INFO);
         sl = CalculateStopLoss(RiskMedium);
         tp = CalculateTakeProfit(RiskMedium);
         lotSize = CalculatePositionSize(RiskMedium, sl);
         break;
      default:
         Log("ExecuteStrategy: Unsupported strategy " + IntegerToString(strategy), LOG_ERROR);
         return false;
   }
   
   if(lotSize <= 0 || sl <= 0 || tp <= 0) {
      Log("ExecuteStrategy: Computed invalid parameters. LotSize=" + DoubleToString(lotSize,2) +
          " SL=" + DoubleToString(sl,2) +
          " TP=" + DoubleToString(tp,2), LOG_ERROR);
      return false;
   }
   
   int orderType = (marketSentiment >= 0.5) ? OP_BUY : OP_SELL;
   double price = (orderType == OP_BUY) ? Ask : Bid;
   if((orderType == OP_BUY && (sl >= price || tp <= price)) ||
      (orderType == OP_SELL && (sl <= price || tp >= price))) {
      Log("ExecuteStrategy: Price conditions invalid. Price=" + DoubleToString(price, Digits()), LOG_ERROR);
      return false;
   }
   
   int slippage = Slippage;
   int ticket = -1;
   int maxRetries = 3;
   for(int attempt = 0; attempt < maxRetries; attempt++) {
      ticket = OrderSend(Symbol(), orderType, lotSize, price, slippage, sl, tp, "FlexEA Order", MagicNumber, 0, clrBlue);
      if(ticket >= 0) break;
      int errorCode = GetLastError();
      Log("ExecuteStrategy: OrderSend attempt " + IntegerToString(attempt+1) + " failed. Error: " + IntegerToString(errorCode), LOG_WARNING);
      Sleep(500); // Wait before retrying
      // Optionally, adjust slippage dynamically for the next attempt
      slippage += 1;
   }
   if(ticket < 0) {
      Log("ExecuteStrategy: All order send attempts failed.", LOG_ERROR);
      return false;
   }
   
   Log("ExecuteStrategy: Order executed successfully. Ticket: " + IntegerToString(ticket) +
       " Type: " + ((orderType == OP_BUY) ? "Buy" : "Sell") +
       " LotSize: " + DoubleToString(lotSize,2), LOG_INFO);
   return true;
}

//+------------------------------------------------------------------+
//| Set Custom Error                                                 |
//+------------------------------------------------------------------+
void SetCustomError(int errorCode){
   // Validate error code (allowed range: 0-99)
   if(errorCode < 0 || errorCode > 99)   {
      Print("Invalid error code: ", errorCode);
      return;
   }
   // For critical errors (99, 100, 101), reset the error stack
   if(errorCode == 99 || errorCode == 100 || errorCode == 101)   {
      Print("Critical error occurred: ", errorCode, " - resetting error stack.");
      ArrayResize(errorStack, 0);
      return;
   }
   
   #define MAX_ERROR_STACK_SIZE 50
   // If error stack reaches max size, reset it
   if(ArraySize(errorStack) >= MAX_ERROR_STACK_SIZE)
      ArrayResize(errorStack, 0);
      
   // Append new error code
   int newSize = ArraySize(errorStack) + 1;
   ArrayResize(errorStack, newSize);
   errorStack[newSize - 1] = errorCode;
   Print("Current Error Stack: ", ArrayToString(errorStack));
}

//------------------------------------------------------------------
// Convert a double array to a string
//------------------------------------------------------------------
string ArrayToString(double &arr[], string separator = " ", int maxSize = MAX_ARRAY_SIZE) {
   int arrSize = ArraySize(arr);
   if (arrSize == 0)
      return "Empty Array";
   if (arrSize > maxSize)
      return "Array too large to convert to string";
      
   string result = DoubleToString(arr[0], 2);
   for (int i = 1; i < arrSize; i++)
      result += separator + DoubleToString(arr[i], 2);
   return result;
}

//+------------------------------------------------------------------+
//| Determine Risk Level                                             |
//+------------------------------------------------------------------+
RiskLevelType DetermineRiskLevel(double equity, double drawdown, double freeMargin){
   // Cache common values
   double balance   = AccountBalance();
   if(balance <= 0)
      return RiskLow; // Prevent division by zero
      
   double leverage  = AccountLeverage();
   string sym     = Symbol();
   double atr     = cachedATR;
   double point   = MarketInfo(sym, MODE_POINT);
   double minLot  = MarketInfo(sym, MODE_MINLOT);
   
   // Basic safety checks
   if(equity <= 0 || freeMargin <= 0 || AccountMarginLevel() < 50.0)
      return RiskLow;
      
   if(drawdown > 50 - (equity / balance * 20))
      return RiskLow;
   if(drawdown > 40)
      return RiskMedium;
   if(atr > point * 100)
      return RiskLow;
   if(equity < balance * 0.1 / leverage)
      return RiskLow;
   if(equity < balance * 0.5 / leverage)
      return RiskMedium;
      
   // Check available free margin against a calculated minimum requirement
   double freeMarginCheck = AccountFreeMarginCheck(sym, OP_BUY, minLot);
   if(freeMarginCheck > 0 && freeMargin < freeMarginCheck * 1.5)
      return RiskLow;
      
   return RiskHigh;
}

//+------------------------------------------------------------------+
//| Execute Strategy Logic                                           |
//+------------------------------------------------------------------+
bool ExecuteStrategyLogic(TradingStrategy strategy, double lotSize, double slPoints, double tpPoints){
   // Validate trade parameters early
   if(lotSize <= 0 || slPoints <= 0 || tpPoints <= 0)   {
      Log("Invalid trade parameters.", LOG_ERROR);
      return false;
   }
   
   string strategyName = StrategyToString(strategy);
   Log(StringFormat("Executing strategy: %s", strategyName), LOG_INFO);
   
   // Retrieve essential account values
   double equity = AccountEquity();
   double drawdownPercentage = 0;   // Assume computed elsewhere
   double marketSentiment = 0;       // Assume provided externally
   
   // Cache symbol and ATR-based stop loss calculation
   string sym = Symbol();
   double period = Period();
   double point = MarketInfo(sym, MODE_POINT);
   double atr = cachedATR;
   double computedSL = MathMax(atr * (1.2 + marketSentiment * 0.3), point * 50);
   
   // Determine risk and calculate appropriate lot size using a fixed risk percentage
   double riskPercentage = 2.0;
   RiskLevelType riskLevel = DetermineRiskLevel(equity, drawdownPercentage, AccountFreeMargin());
   double computedLotSize = CalculateConsolidatedLotSize(equity, riskPercentage, riskLevel, drawdownPercentage, computedSL);
   
   // Check if margin is sufficient for the computed lot size
   if(!IsSufficientMargin(equity, drawdownPercentage, computedLotSize))   {
      Log("Not enough margin to open trade. Skipping execution.", LOG_ERROR);
      return false;
   }
   
   // Delegate to the main ExecuteStrategy for actual order placement
   bool result = ExecuteStrategy(strategy, equity, drawdownPercentage, marketSentiment);
   Log(StringFormat("Strategy execution %s: %s", result ? "succeeded" : "failed", strategyName),
       result ? LOG_INFO : LOG_ERROR);
       
   return result;
}

//+------------------------------------------------------------------+
//| Helper: Check if Sufficient Margin is Available                  |
//+------------------------------------------------------------------+
bool IsSufficientMargin(double equity, double drawdownPercentage, double lotSize, int orderType = OP_BUY){
   string sym = Symbol();
   double minLot = MarketInfo(sym, MODE_MINLOT);
   if(lotSize < minLot)   {
      Log(StringFormat("Lot size %.2f is less than the minimum allowed %.2f", lotSize, minLot), LOG_ERROR);
      return false;
   }
   
   double availableMargin = AccountFreeMargin();
   double requiredMargin  = MarketInfo(sym, MODE_MARGINREQUIRED) * lotSize;
   double equityAfterDrawdown = equity * (1 - drawdownPercentage / 100);
   
   if(availableMargin < requiredMargin || equityAfterDrawdown <= 0)   {
      Log(StringFormat("Insufficient margin: Available=%.2f, Required=%.2f, EquityAfterDrawdown=%.2f",
            availableMargin, requiredMargin, equityAfterDrawdown), LOG_ERROR);
      return false;
   }
   
   Log(StringFormat("Sufficient margin: Available=%.2f, Required=%.2f", availableMargin, requiredMargin), LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Calculate dynamic maximum drawdown percentage based on ATR and volatility
//------------------------------------------------------------------
double GetDynamicMaxDrawdownPercentage(int atrPeriod = 14, double volatilityCap = 3.0){
   double baseDrawdown = 0.20; // 20%
   string sym = Symbol();
   double atrValue = cachedATR;
   double pointSize = MarketInfo(sym, MODE_POINT);
   if (atrValue <= 0.0001 || pointSize <= 0)   {
      LogError(1001, "Invalid ATR or point size for symbol: " + sym, LOG_ERROR);
      return baseDrawdown;
   }
   double volatilityFactor = MathMax(1.0, atrValue / pointSize);
   double dynamicDrawdown = NormalizeDouble(baseDrawdown / volatilityFactor, 2);
   return MathMax(dynamicDrawdown, 0.05);  // Floor of 5%
}

//------------------------------------------------------------------
// Get dynamic equity stop threshold based on current equity
//------------------------------------------------------------------
double GetDynamicEquityStopThreshold(){
   double equity = AccountEquity();
   double base = MathMax(BaseThreshold, 0.0);
   
   if (equity <= 0 || IsNaN(equity))   {
      Log(StringFormat("Invalid equity: %.2f at %s", equity, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)), LOG_ERROR);
      return base;
   }
   if (equity > 1000000000.0)   {
      Log(StringFormat("High equity detected: %.2f", equity), LOG_WARNING);
      return base;
   }
   double dynamicThreshold = MathMin(equity * 0.05, 1000000.0);
   return MathMax(dynamicThreshold, base);
}

//------------------------------------------------------------------
// Check if fundamental risk conditions are acceptable
//------------------------------------------------------------------
bool IsRiskAcceptable(){
   double equity = AccountEquity();
   if(equity < 0)   {
      LogError(1001, "Equity is negative", LEVEL_ERROR);
      return false;
   }
   
   // Use dynamic equity threshold
   double threshold = GetDynamicEquityStopThreshold();
   if(equity < threshold)   {
      LogError(1002, "Equity stop threshold breached", LEVEL_WARNING);
      return false;
   }
   
   // Check drawdown against dynamic max drawdown
   double dd = CalculateDrawdownPercentage();
   double maxDD = GetDynamicMaxDrawdownPercentage();
   if(dd > maxDD)   {
      LogError(1003, "Maximum drawdown exceeded", LEVEL_WARNING);
      return false;
   }
   
   if(!IsAccountValid())   {
      LogError(1004, "Account not ready for trading", LEVEL_ERROR);
      return false;
   }
   
   return true;
}

//------------------------------------------------------------------
// Validate account status for trading readiness
//------------------------------------------------------------------
bool IsAccountValid(){
   double freeMargin  = AccountFreeMargin();
   double balance     = AccountBalance();
   double equity      = AccountEquity();
   double marginLevel = AccountMarginLevel();
   double floatProfit = GetFloatingProfit();
   
   if(freeMargin <= 0.01)   {
      LogError(1005, "Not enough free margin for trading", LEVEL_ERROR);
      return false;
   }
   if(marginLevel < 100)   {
      LogError(1006, StringFormat("Margin level too low: %.2f", marginLevel), LEVEL_WARNING);
      return false;
   }
   if(equity + floatProfit < balance)   {
      LogError(1007, "Account in margin call state", LEVEL_ERROR);
      return false;
   }
   if(balance <= 0)   {
      LogError(1009, StringFormat("Account balance is zero or negative: %.2f", balance), LEVEL_ERROR);
      return false;
   }
   if(balance < 1.0)   {
      LogError(1010, StringFormat("Account balance too low for trading: %.2f", balance), LEVEL_WARNING);
      return false;
   }
   
   // Warn if a cent account is detected
   if(StringFind(AccountCurrency(), "cent") >= 0)
      LogError(1008, "Cent account detected. Ensure correct configuration.", LEVEL_WARNING);
      
   return true;
}

//------------------------------------------------------------------
// Calculate the total floating profit for all open positions
//------------------------------------------------------------------
double GetFloatingProfit(){
   double totalFloatingProfit = 0.0;
   int totalOrders = OrdersTotal();  // Cache total orders
   
   // Loop through orders in reverse order
   for(int i = totalOrders - 1; i >= 0; i--)   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))      {
         int type = OrderType();
         // Only count market orders (OP_BUY and OP_SELL)
         if(type == OP_BUY || type == OP_SELL)         {
            totalFloatingProfit += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
      else      {
         Print("Warning: OrderSelect failed at index ", i);
         // Continue loop rather than aborting calculation
      }
   }
   
   // Normalize the result using the symbol's precision
   return NormalizeDouble(totalFloatingProfit, MarketInfo(Symbol(), MODE_DIGITS));
}

// Helper function to check for NaN values in an array
bool IsNaN(double value) {
    return value != value; // NaN is the only value that is not equal to itself
}

//+------------------------------------------------------------------+
//| Adjust Stop Loss / Take Profit for open orders                    |
//| If 'forAllOrders' is true, adjusts all orders; otherwise only the   |
//| specified ticket.                                                  |
//+------------------------------------------------------------------+
bool AdjustSLTP(bool forAllOrders = true, int specificTicket = 0, double atrValue = 0) {
   if (atrValue <= 0)
      return false;

   string sym = Symbol();
   // Cache static market info for the symbol.
   static double stopLevel = MarketInfo(sym, MODE_STOPLEVEL) * Point;
   static int digits = MarketInfo(sym, MODE_DIGITS);

   int modifiedOrders = 0;
   int ordersCount = forAllOrders ? OrdersTotal() : 1;
   int startIdx = forAllOrders ? 0 : specificTicket;
   int endIdx = forAllOrders ? ordersCount : specificTicket + 1;

   for (int i = startIdx; i < endIdx; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      int ticket = OrderTicket();
      if (!IsValidOrder(ticket, OrderMagicNumber(), OrderType(), sym))
         continue;

      double openPrice = OrderOpenPrice();
      int orderType = OrderType();
      // Determine new SL and TP prices based on order type.
      double slPrice = (orderType == OP_BUY) ? openPrice - atrValue * 1.5 : openPrice + atrValue * 1.5;
      double tpPrice = (orderType == OP_BUY) ? openPrice + atrValue * 2.0 : openPrice - atrValue * 2.0;

      if (MathAbs(openPrice - slPrice) < stopLevel || MathAbs(openPrice - tpPrice) < stopLevel)
         continue;

      // Adjust to the correct tick size and precision.
      slPrice = NormalizeDouble(AdjustPriceToTickSize(slPrice), digits);
      tpPrice = NormalizeDouble(AdjustPriceToTickSize(tpPrice), digits);

      if (OrderStopLoss() != slPrice || OrderTakeProfit() != tpPrice) {
         if (TryModifySLTP(ticket, openPrice, slPrice, tpPrice))
            modifiedOrders++;
      }
      
      if (!forAllOrders)
         break;
   }
   return (modifiedOrders > 0);
}

//------------------------------------------------------------------
// Adjust price to the nearest tick size
//------------------------------------------------------------------
double AdjustPriceToTickSize(double price){
   string sym = Symbol();
   if(price <= 0)   {
      Log(StringFormat("Error: Invalid price value (%.5f) for symbol %s.", price, sym), LOG_ERROR);
      return -1;
   }
   
   double tickSize = MarketInfo(sym, MODE_TICKSIZE);
   if(tickSize <= 0)   {
      Log(StringFormat("Error: Tick size is zero for symbol %s.", sym), LOG_ERROR);
      return -1;
   }
   
   // Adjust price to nearest lower tick and normalize with symbol digits
   double adjustedPrice = NormalizeDouble(MathFloor(price / tickSize) * tickSize, MarketInfo(sym, MODE_DIGITS));
   Log(StringFormat("Adjusted price: %.5f to nearest tick size %.5f for symbol %s.", price, tickSize, sym));
   
   return adjustedPrice;
}

//------------------------------------------------------------------
// Helper: Modify SL/TP with retries and adjust for spread and slippage
//------------------------------------------------------------------
bool TryModifySLTP(int orderTicket, double openPrice, double slPrice, double tpPrice){
   string sym = Symbol();
   if(orderTicket < 0 || slPrice <= 0 || tpPrice <= 0 || !OrderSelect(orderTicket, SELECT_BY_TICKET))
      return false;
      
   double spread = MarketInfo(sym, MODE_SPREAD) * Point;
   int slippageTolerance = 3;
   int orderType = OrderType();
   
   // Adjust SL/TP for spread and tolerance based on order type
   if(orderType == OP_BUY)   {
      slPrice += spread + slippageTolerance;
      tpPrice += spread + slippageTolerance;
   }
   else   {
      slPrice -= spread + slippageTolerance;
      tpPrice -= spread + slippageTolerance;
   }
   
   // Ensure stop loss is above stop level distance from open price
   if(MathAbs(slPrice - openPrice) < MarketInfo(sym, MODE_STOPLEVEL) * Point)
      return false;
   
   // Attempt to modify order with up to 3 retries
   for(int attempt = 0; attempt < 3; attempt++)   {
      if(OrderModify(orderTicket, openPrice, slPrice, tpPrice, 0, clrBlue))
         return true;
      Sleep(1000);
   }
   
   return false;
}

//------------------------------------------------------------------
// Execute CounterTrend Logic with Order Management and Updates
//------------------------------------------------------------------
bool ExecuteCounterTrendLogic(double slPoints, double tpPoints, string strategyTag){
   const string sym = Symbol();
   double atr = cachedATR;
   if (!CanTrade() || atr <= 0 ||
       GetMonteCarloSimulatedProfit(CounterTrend) < GetDynamicMonteCarloThreshold(ATRPeriod) ||
       !(IsOverbought() || IsOversold()))
      return false;

   double equity = AccountEquity();
   double ddPct = CalculateDrawdownPercentage();
   double lotSize = CalculateConsolidatedLotSize(equity, 2.0, RiskMedium, ddPct, slPoints);
   if (lotSize <= 0)
      return false;

   int orderType = IsOverbought() ? OP_SELL : OP_BUY;
   double entryPrice = (orderType == OP_BUY ? Ask : Bid);
   int slippage = CalculateDynamicSlippage(14, 3, 10, 10000.0, PERIOD_H1);
   int ticket = OrderSend(sym, orderType, lotSize, entryPrice, slippage,
                           0, 0, strategyTag, MagicNumber, 0, clrBlue);
   if (ticket <= 0)
      return false;

   double slPrice = (orderType == OP_BUY ? Ask - slPoints * Point : Bid + slPoints * Point);
   double tpPrice = (orderType == OP_BUY ? Ask + tpPoints * Point : Bid - tpPoints * Point);
   for (int attempt = 0; attempt < 3; attempt++) {
      if (RetryOrderModify(ticket, (orderType == OP_BUY ? Ask : Bid), slPrice, tpPrice))
         break;
      Sleep(1000 * (attempt + 1));
   }

   UnifiedPerformanceAndIndicatorUpdate(ticket, (int)currentStrategy);
   if (EnablePyramiding && IsPositionSignificantlyProfitable(ticket))
      PerformPyramiding(ticket);
   ReassessParameters();
   LogPerformanceMetrics();

   return true;
}

//------------------------------------------------------------------
// Calculate dynamic Monte Carlo threshold based on ATR and risk factors
//------------------------------------------------------------------
double GetDynamicMonteCarloThreshold(int inputATRPeriod, double riskFactor = 50.0, double drawdownAdjustment = 20.0){
   static double localCachedATR = 0;
   static int lastATRUpdateTime = 0;
   int updateInterval = (inputATRPeriod > 14) ? 120 : 60;
   int now = TimeCurrent();
   
   if(now - lastATRUpdateTime >= updateInterval)   {
      localCachedATR = cachedATR;
      lastATRUpdateTime = now;
   }
   
   double atr = (localCachedATR > 0) ? localCachedATR : 1.0;
   double threshold = CalculateThresholdBasedOnATR(atr, riskFactor);
   
   if(CalculateRecentProfit() < 0)
      threshold *= (1 + drawdownAdjustment / 100.0);
   
   threshold = ApplyVolatilityCap(AdjustForDrawdown(threshold));
   return (threshold > 0) ? threshold : AccountEquity() * 0.01;
}

//------------------------------------------------------------------
// Calculate recent profit (excluding deposits/withdrawals) over last 30 days
//------------------------------------------------------------------
double CalculateRecentProfit(){
   double balance = AccountBalance();
   double equity  = AccountEquity();
   if(balance <= 0.01 || equity <= 0.01)   {
      Print("Invalid balance or equity.");
      return 0;
   }
   
   double profit = AccountProfit() + (equity - balance);
   datetime startTime = TimeCurrent() - 30 * 24 * 60 * 60;  // 30 days ago
   
   // Subtract deposits/withdrawals recorded in the history
   for(int i = HistoryTotal() - 1; i >= 0; i--)   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))      {
         if(OrderOpenTime() >= startTime &&
            (StringFind(OrderComment(), "Deposit") >= 0 || StringFind(OrderComment(), "Withdrawal") >= 0))         {
            profit -= OrderProfit();
         }
      }
   }
   
   return profit;
}

//------------------------------------------------------------------
// Calculate threshold based on ATR and risk factor
//------------------------------------------------------------------
double CalculateThresholdBasedOnATR(double atr, double riskFactor){
   // Validate ATR input
   if(atr <= 0)   {
      LogError(3, "Invalid ATR value: ATR must be greater than zero. ATR=" + DoubleToString(atr), LOG_ERROR, -1, Param_ATR, atr);
      return NaN;
   }
   
   const double MAX_ATR = 1000.0;
   if(atr > MAX_ATR)   {
      LogError(3, "Excessive ATR value: ATR exceeds maximum allowed. MAX_ATR=" + DoubleToString(MAX_ATR) +
                      " ATR=" + DoubleToString(atr), LOG_ERROR, -1, Param_ATR, atr);
      return NaN;
   }
   
   // Validate Risk Factor input
   const double MAX_RISK_FACTOR = 10.0;
   if(riskFactor <= 0 || riskFactor > MAX_RISK_FACTOR)   {
      LogError(3, "Invalid Risk Factor: Must be between 0 and " + DoubleToString(MAX_RISK_FACTOR) +
                      ". RiskFactor=" + DoubleToString(riskFactor), LOG_ERROR, -1, Param_RiskLevel, riskFactor);
      return NaN;
   }
   
   return atr * riskFactor;
}

//------------------------------------------------------------------
// Apply dynamic cap based on account balance and volatility conditions
//------------------------------------------------------------------
double ApplyVolatilityCap(double threshold, double normalCapPercentage = 0.1, double highVolatilityCapPercentage = 0.05, double minThresholdPercentage = 0.01){
   if(threshold <= 0)
      return NaN;

   double accountBalance = AccountBalance();
   // Choose cap based on current market volatility
   double capPerc = IsHighVolatilityMarket() ? highVolatilityCapPercentage : normalCapPercentage;
   double maxThreshold = accountBalance * capPerc;
   double minThreshold = accountBalance * minThresholdPercentage;
   
   if(threshold > maxThreshold)   {
      threshold = maxThreshold;
      Print("Warning: Threshold exceeds max allowed value. Using dynamic cap.");
   }
   else if(threshold < minThreshold)   {
      threshold = minThreshold;
      Print("Threshold is too small. Using minimum threshold value.");
   }
   
   return threshold;
}

//------------------------------------------------------------------
// Adjust threshold based on drawdown conditions
//------------------------------------------------------------------
double AdjustForDrawdown(double threshold, double maxDrawdown = 0.2, int checkInterval = 60, bool localDebugMode = true){
   static double highestEquity = AccountEquity();
   static int lastCheckTick = 0;
   int now = TimeCurrent();
   
   if(now - lastCheckTick < checkInterval)
      return threshold;
   lastCheckTick = now;
   
   double equity = AccountEquity();
   if(equity <= 0.01 * AccountBalance())   {
      Print("Error: Equity too low.");
      return threshold;
   }
   
   highestEquity = MathMax(highestEquity, equity);
   double currentDrawdown = (highestEquity - equity) / highestEquity;
   
   // If drawdown exceeds maxDrawdown, adjust the threshold proportionally
   if(currentDrawdown > maxDrawdown)   {
      double adjustment = MathMin((equity - highestEquity * (1 - maxDrawdown)) * 0.5, 0.5);
      threshold *= (1 - adjustment);
      threshold = MathMax(0, threshold);
      if(localDebugMode)
         Print("Drawdown exceeded. New threshold: ", threshold);
   }
   
   return threshold;
}

//------------------------------------------------------------------
// Check if a position is significantly profitable
//------------------------------------------------------------------
bool IsPositionSignificantlyProfitable(int ticket, double customMultiplier = 2.0, int minTimeInTradeMinutes = 5, bool localDebugMode = false){
   if(customMultiplier <= 0 || minTimeInTradeMinutes <= 0 || !OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL)
      return false;

   double tickValue = MarketInfo(OrderSymbol(), MODE_TICKVALUE);
   if(tickValue <= 0)
      tickValue = 1.0;

   double closedProfit   = OrderProfit() + OrderSwap() + OrderCommission();
   double floatingProfit = (type == OP_BUY) ?
                           (MarketInfo(OrderSymbol(), MODE_BID) - OrderOpenPrice()) * OrderLots() * tickValue :
                           (OrderOpenPrice() - MarketInfo(OrderSymbol(), MODE_ASK)) * OrderLots() * tickValue;
   double netProfit = closedProfit + floatingProfit;
   
   // Ensure the order has been open long enough
   if((TimeCurrent() - OrderOpenTime()) / 60 < minTimeInTradeMinutes)
      return false;
   
   if(localDebugMode)
      Print("Trade ", ticket, " | Net Profit: ", netProfit, " | Threshold: ", customMultiplier * OrderLots() * tickValue);
      
   return (netProfit >= customMultiplier * OrderLots() * tickValue);
}

//------------------------------------------------------------------
// Check if the market is overbought based on RSI
//------------------------------------------------------------------
bool IsOverbought(int customPeriod = PERIOD_H1, int rsiPeriod = 14, double overboughtLevel = 70, int priceType = PRICE_CLOSE){
   if (rsiPeriod <= 1 || overboughtLevel <= 0 || overboughtLevel >= 100)
      return false;
   double rsi = cachedRSI;
   if (rsi == -1 || rsi < 0 || rsi > 100)
      return false;
   return (rsi > overboughtLevel);
}

//------------------------------------------------------------------
// Check if the market is oversold based on RSI
//------------------------------------------------------------------
bool IsOversold(int customPeriod = PERIOD_H1, int rsiPeriod = 14, double oversoldLevel = 30, int priceType = PRICE_CLOSE, bool debugLog = false){
   if (rsiPeriod <= 1 || rsiPeriod > 100 || oversoldLevel <= 0 || oversoldLevel >= 100 ||
       customPeriod <= 0 || customPeriod > 44640 || MarketInfo(Symbol(), MODE_TRADEALLOWED) == 0 ||
       Bars(Symbol(), customPeriod) < rsiPeriod + 1)   {
      Log("Invalid input or insufficient data.", LOG_ERROR);
      return false;
   }
   double rsi = cachedRSI;
   if (rsi <= 0 || rsi >= 100 || rsi == -1)   {
      Log("Invalid RSI value.", LOG_ERROR);
      return false;
   }
   static datetime lastLogTimeFunc = 0;
   if (Time[0] != lastLogTimeFunc) {
      lastLogTimeFunc = Time[0];
      if (debugLog) Log(StringFormat("RSI: %.2f", rsi), LOG_DEBUG);
   }
   if (rsi < oversoldLevel) {
      Log(StringFormat("RSI: %.2f falls below %.2f", rsi, oversoldLevel), LOG_INFO);
      return true;
   }
   return false;
}

//------------------------------------------------------------------
// Replace underperforming strategy if a better one exists
//------------------------------------------------------------------
void ReplaceUnderperformingStrategy(){
   const double sharpeRatioThreshold = 0.8;
   const double sharpeRatioMargin    = 0.1;
   
   Log("Evaluating strategy performance...", LOG_INFO);
   UnifiedPerformanceAndIndicatorUpdate(0, 0);
   CalculateWinRates(false);
   
   int bestStrategyIndex = -1;
   double bestSharpeRatio = -1;
   int perfCount = ArraySize(tradePerformance);
   for(int i = 0; i < perfCount; i++)   {
      // Only consider strategies with at least 10 trades
      if(tradePerformance[i].tradeCount >= 10 &&
         tradePerformance[i].sharpeRatio > bestSharpeRatio)      {
         bestSharpeRatio = tradePerformance[i].sharpeRatio;
         bestStrategyIndex = i;
      }
   }
   
   // If no better strategy found or current strategy is acceptable, exit.
   if(bestStrategyIndex == -1 ||
      tradePerformance[(int)currentStrategy].sharpeRatio >= bestSharpeRatio * sharpeRatioThreshold)   {
      Log("No strategy change required.", LOG_INFO);
      return;
   }
   
   TradingStrategy newStrategy = EnhancedStrategySelection();
   // Only switch if the new strategy is different and its performance differs significantly.
   if(newStrategy != currentStrategy &&
      MathAbs(tradePerformance[(int)newStrategy].sharpeRatio - bestSharpeRatio) >= sharpeRatioMargin)   {
      Log(StringFormat("Switching from %s to %s (Sharpe: %.2f).",
                        StrategyToString(currentStrategy),
                        StrategyToString((TradingStrategy)bestStrategyIndex),
                        bestSharpeRatio), LOG_INFO);
      
      static datetime lastSwitchTime = 0;
      if(TimeCurrent() - lastSwitchTime < 3600)      {
         Log("Strategy switch on cooldown.", LOG_WARNING);
         return;
      }
      
      currentStrategy = newStrategy;
      strategyConsecutiveLosses[(int)currentStrategy] = 0;
      recoveryMode = (bestSharpeRatio < sharpeRatioThreshold ||
                      strategyConsecutiveLosses[(int)currentStrategy] > 5);
      if(recoveryMode)
         Log("Entering recovery mode.", LOG_WARNING);
         
      lastSwitchTime = TimeCurrent();
      UnifiedPerformanceAndIndicatorUpdate(0, 0);
      SaveLastSwitchTimeToFile(lastSwitchTime);
   }
   else   {
      Log("No significant improvement or same strategy. No switch.", LOG_INFO);
   }
}

//------------------------------------------------------------------
// Save last strategy switch time to file for persistence
//------------------------------------------------------------------
void SaveLastSwitchTimeToFile(datetime lastSwitchTime){
   string filePath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL4\\Files\\strategy_switch_time.dat";
   int fileHandle, retryCount = 0;
   
   while(retryCount++ < 3)   {
      fileHandle = FileOpen(filePath, FILE_WRITE | FILE_TXT | FILE_COMMON);
      if(fileHandle != INVALID_HANDLE && FileWrite(fileHandle, lastSwitchTime) >= 1)      {
         FileClose(fileHandle);
         return;  // Success
      }
      Log("Failed to write last switch time, retrying...", LOG_ERROR);
      Sleep(MathMin(500 * MathPow(2, retryCount), 5000)); // Exponential backoff
   }
   Log("Failed to save last switch time after multiple attempts.", LOG_ERROR);
}

//------------------------------------------------------------------
// Evaluates strategy performance and switches strategy if needed
//------------------------------------------------------------------
void EvaluateStrategyPerformance(){
   const double profitFactorThreshold = 1.0;
   Log("Starting evaluation...", LOG_INFO);
   
   // Abort if not in recovery mode or drawdown is too high
   if (!CheckRecoveryMode() || CalculateDrawdownPercentage() > 50.0)   {
      Log("Error or high drawdown. Pausing.", LOG_ERROR);
      return;
   }
   
   double currentDrawdown = CalculateDrawdownPercentage();
   double adjustedRisk = AdjustRiskForRecovery(2.0, currentDrawdown, true);
   Log(StringFormat("Risk adjusted to %.2f%%", adjustedRisk), LOG_INFO);
   
   UnifiedPerformanceAndIndicatorUpdate(0, 0);
   CalculateWinRates(false);
   MonteCarloSimulation();
   
   int tradeCount = ArraySize(tradePerformance);
   if(tradeCount == 0)   {
      Log("No trade performance data.", LOG_ERROR);
      return;
   }
   
   bool performanceDropped = false;
   int bestStrategyIndex = -1;
   for(int i = 0; i < tradeCount; i++)   {
      // Consider only strategies with sufficient trade count and nonzero profit/loss
      if(tradePerformance[i].tradeCount <= 10 || 
         tradePerformance[i].grossProfit == 0 || 
         tradePerformance[i].grossLoss == 0)
         continue;
         
      double profitFactor = (MathAbs(tradePerformance[i].grossLoss) > EPSILON) ?
                            tradePerformance[i].grossProfit / MathAbs(tradePerformance[i].grossLoss) :
                            (tradePerformance[i].grossProfit > 0 ? DBL_MAX : 0);
      if(profitFactor < profitFactorThreshold)
         performanceDropped = true;
         
      // Use a weighted score to select a candidate strategy
      double score = tradePerformance[i].sharpeRatio * 0.5 + profitFactor * 0.3 + tradePerformance[i].winRate * 0.2;
      if(score > 0)
         bestStrategyIndex = i;
   }
   
   if(performanceDropped)
      AdaptParametersForUnderperformance();
   
   TradingStrategy validatedStrategy = EnhancedStrategySelection();
   if((int)currentStrategy != (int)validatedStrategy && IsStrategyValidForSwitch(validatedStrategy))
      SwitchToValidatedStrategy(validatedStrategy);
   
   if(bestStrategyIndex != -1)
      ReassessParameters();
   
   ExecuteAllStrategies();
   Log("Evaluation completed.", LOG_INFO);
}

//------------------------------------------------------------------
// Checks whether the strategy is valid for switching
//------------------------------------------------------------------
bool IsStrategyValidForSwitch(TradingStrategy strategy){
   int strategyIndex = (int)strategy;
   if(strategyIndex < 0 || strategyIndex >= ArraySize(tradePerformance))   {
      Log("Invalid strategy index.", LOG_ERROR);
      return false;
   }
   double sharpeRatio = tradePerformance[strategyIndex].sharpeRatio;
   double grossProfit = tradePerformance[strategyIndex].grossProfit;
   double grossLoss = tradePerformance[strategyIndex].grossLoss;
   if(IsNaN(sharpeRatio) || IsNaN(grossProfit) || IsNaN(grossLoss) ||
      (grossProfit == 0 && grossLoss == 0))   {
      Log("Invalid or zero profit/loss for strategy.", LOG_WARNING);
      return false;
   }
   return sharpeRatio >= 1.0 && ((grossLoss > 0) ? (grossProfit / grossLoss) : (grossProfit > 0 ? grossProfit : 1.0)) >= 1.0;
}

//------------------------------------------------------------------
// Switch to the validated strategy with fallback retries
//------------------------------------------------------------------
void SwitchToValidatedStrategy(TradingStrategy validatedStrategy) {
   // Static counters for retries and logging frequency
   static int retryCount = 0;
   static int logCount = 0;
   const int MAX_RETRIES = 2;
   #define ERR_INVALID_STRATEGY 1001

   // Check strategy bounds
   if(validatedStrategy < TrendFollowing || validatedStrategy > SafeMode) {
      LogError(ERR_INVALID_STRATEGY, "Invalid strategy", LOG_ERROR, (int)validatedStrategy, Param_RiskLevel, 0, 0);
      return;
   }
   
   // Avoid redundant switching if recently logged frequently
   if(currentStrategy == validatedStrategy && (TimeCurrent() - lastLogTime) <= 60 && logCount >= 3)
      return;
      
   Log(StringFormat("Switching from %s to %s.", StrategyToString(currentStrategy), StrategyToString(validatedStrategy)), LOG_INFO);
   currentStrategy = validatedStrategy;
   strategyConsecutiveLosses[(int)currentStrategy] = 0;
   
   // Validate and optimize parameters
   if(!OptimizeStrategyParameters() || !AreStrategyParametersValid((int)currentStrategy)) {
      static datetime lastErrorLogTime = 0;
      if(TimeCurrent() - lastErrorLogTime > 120) {
         LogError(ERR_VALIDATION_FAILED, StringFormat("Validation failed for %s.", StrategyToString(currentStrategy)), LOG_WARNING, (int)currentStrategy, Param_RiskLevel, 0, 0);
         lastErrorLogTime = TimeCurrent();
      }
      
      // Try fallback strategies up to MAX_RETRIES
      for(; retryCount < MAX_RETRIES; retryCount++) {
         TradingStrategy fallback = DetermineFallbackStrategy(GetCurrentDrawdown(), GetCurrentMarketSentiment());
         if(AreStrategyParametersValid((int)fallback)) {
            Log(StringFormat("Retrying with fallback: %s", StrategyToString(fallback)), LOG_WARNING);
            SwitchToValidatedStrategy(fallback);
            return;
         }
      }
      LogError(ERR_VALIDATION_FAILED, "Max retries reached, staying on current strategy.", LOG_ERROR, (int)currentStrategy, Param_RiskLevel, 0, 0);
      return;
   }
   
   // Successful validation: reset counters and log
   Log("Strategy validated.", LOG_INFO);
   lastLogTime = TimeCurrent();
   logCount = 0;
   retryCount = 0;
}

//------------------------------------------------------------------
// Determines the best fallback strategy
//------------------------------------------------------------------
TradingStrategy DetermineFallbackStrategy(double drawdown, double sentiment) {
   enum ErrorCodes { ERR_INVALID_PARAMETER = 101 };

   // Validate inputs
   if (drawdown < 0 || drawdown > 100 || sentiment < 0 || sentiment > 1) {
      LogError(ERR_INVALID_PARAMETER, "Invalid input values for drawdown or sentiment.", LOG_ERROR, (int)currentStrategy, Param_RiskLevel, 0, 0);
      return SafeMode;  // Default safe strategy for invalid inputs
   }

   Log(StringFormat("Evaluating fallback for strategy: %s, Drawdown: %.2f, Sentiment: %.2f", 
                     StrategyToString(currentStrategy), drawdown, sentiment), LOG_INFO);

   // Fallback logic based on thresholds
   if (drawdown > drawdownThreshold) {
      Log("Current drawdown exceeds threshold, switching to RangeBound.", LOG_INFO);
      return RangeBound;
   }

   const double sentimentThreshold = 0.5;
   if (sentiment < sentimentThreshold) {
      Log("Sentiment is low, switching to SafeMode.", LOG_INFO);
      return SafeMode;
   }

   Log("No specific conditions met, default fallback: SafeMode.", LOG_INFO);
   return SafeMode;
}

//------------------------------------------------------------------
// Returns the current drawdown, either as an absolute value or a percentage
//------------------------------------------------------------------
double GetCurrentDrawdown(bool returnPercentage = false) {
   // Cache the current equity to avoid multiple calls
   double currentEquity = AccountEquity();
   static double highestEquity = currentEquity;
   
   // Update highest equity if a new high is reached
   if (currentEquity > highestEquity)
      highestEquity = currentEquity;

   double drawdown = highestEquity - currentEquity;

   if (returnPercentage && highestEquity > 0)
      return NormalizeDouble((drawdown / highestEquity) * 100, 2);

   return NormalizeDouble(drawdown, 2);
}

//------------------------------------------------------------------
// Returns the current market sentiment based on moving average crossover
//------------------------------------------------------------------
double GetCurrentMarketSentiment(int shortPeriod = 10, int longPeriod = 50) {
   static double lastShortSMA = 0, lastLongSMA = 0;
   static datetime lastSMATime = 0;  // renamed from lastUpdateTime
   datetime currentTime = TimeCurrent();

   // Update SMAs at the start of each new bar
   if (currentTime - lastSMATime >= PeriodSeconds()) {
      lastShortSMA = cachedFastMA;
      lastLongSMA  = cachedSlowMA;
      lastSMATime = currentTime;
   }

   if (lastShortSMA == EMPTY_VALUE || lastLongSMA == EMPTY_VALUE)
      return 0.5;  // Return neutral sentiment if invalid

   double smaDifference = lastShortSMA - lastLongSMA;
   double dynamicThreshold = cachedATR * 0.01;  // Adjust neutral threshold based on ATR

   if (MathAbs(smaDifference) < dynamicThreshold)
      return 0.5;
   else if (smaDifference > 0)
      return MathMin(1.0, 0.5 + smaDifference / 0.0005);
   else
      return MathMax(0.0, 0.5 - MathAbs(smaDifference) / 0.0005);
}

//------------------------------------------------------------------
// Validates strategy parameters; optionally auto-corrects invalid values
//------------------------------------------------------------------
bool AreStrategyParametersValid(int strategyIndex, bool autoCorrect = true) {
   if (strategyIndex < 0 || strategyIndex >= ArraySize(tradePerformance)) {
      Log(StringFormat("Invalid strategy index: %d (ArraySize: %d)", strategyIndex, ArraySize(tradePerformance)), LOG_ERROR);
      return false;
   }
   
   TradePerformance current = tradePerformance[strategyIndex];
   const double MIN_RISK_LEVEL = 0.01;
   
   Log(StringFormat("Checking strategy parameters: RiskLevel=%.2f, SL=%.2f, TP=%.2f", 
       current.RiskLevel, current.SL, current.TP), LOG_INFO);

   if (current.RiskLevel < MIN_RISK_LEVEL || current.RiskLevel > MAX_RISK_LEVEL) {
      Log(StringFormat("Invalid RiskLevel: %.2f (Min: %.2f, Max: %.2f)", 
          current.RiskLevel, MIN_RISK_LEVEL, MAX_RISK_LEVEL), LOG_ERROR);
      if (autoCorrect)
         tradePerformance[strategyIndex].RiskLevel = DEFAULT_RISK_LEVEL;
      return false;
   }

   if (current.SL <= 0 || current.SL > 500.0) {
      Log(StringFormat("Invalid StopLoss: %.2f (Max: 500.0)", current.SL), LOG_ERROR);
      if (autoCorrect)
         tradePerformance[strategyIndex].SL = MathMin(500.0, MathMax(0, current.SL));
      return false;
   }

   if (current.TP < 50.0 || current.TP > 1000.0) {
      Log(StringFormat("Invalid TakeProfit: %.2f (Min: 50.0, Max: 1000.0)", current.TP), LOG_ERROR);
      if (autoCorrect)
         tradePerformance[strategyIndex].TP = MathMin(1000.0, MathMax(50.0, current.TP));
      return false;
   }

   return true;
}

//------------------------------------------------------------------
// Adapt parameters using Genetic Algorithm if performance drops
//------------------------------------------------------------------
void AdaptParametersForUnderperformance() {
   Log("Performance dropped. Initiating Genetic Algorithm Optimization.", LOG_WARNING);
   datetime startTime = TimeCurrent();
   Log(StringFormat("Started at %s.", TimeToString(startTime, TIME_DATE | TIME_MINUTES)), LOG_INFO);
   
   bool optimizationSuccess = false;
   int retries = 3;
   int retryDelay = 5;
   
   for (int i = 0; i < retries && !optimizationSuccess; i++) {
      optimizationSuccess = GeneticAlgorithmOptimization();
      if (!optimizationSuccess) {
         Log(StringFormat("Attempt %d failed. Retrying in %d seconds...", i + 1, retryDelay), LOG_DEBUG);
         Sleep(retryDelay * 1000);
         retryDelay = MathMin(retryDelay * 2, 30);
      }
   }
   
   double duration = TimeCurrent() - startTime;
   string timeUnit = (duration < 60) ? "seconds" : "minutes";
   double displayDuration = (duration < 60) ? duration : duration / 60;
   Log(StringFormat("Optimization %s in %.2f %s.", (optimizationSuccess ? "completed" : "failed"), displayDuration, timeUnit),
       (optimizationSuccess ? LOG_INFO : LOG_ERROR));
}

//------------------------------------------------------------------
// Unified Function for Managing Equity Updates, Thresholds,
// Rapid Changes, and Periodic Checks
//------------------------------------------------------------------
bool ManageEquity(double equityStopPercentage, double dynamicThresholdFactor = 1.0, double rapidChangeThreshold = 5.0, int checkInterval = 60){
   static datetime lastCheck = 0;
   static double lastEquity = AccountEquity();
   
   datetime now = TimeCurrent();
   if (now - lastCheck < checkInterval)
      return false;
   lastCheck = now;
   
   double currentEquity = AccountEquity();
   if (currentEquity < 0)
      return false;
      
   // Update the global peak equity.
   peakEquity = MathMax(peakEquity, currentEquity);
   
   // Compute percentage change; protect against division by zero.
   double changePercentage = (lastEquity != 0) ? ((currentEquity - lastEquity) / lastEquity) * 100.0 : 0;
   double dynamicStopThreshold = equityStopPercentage * dynamicThresholdFactor;
   
   if (currentEquity < dynamicStopThreshold)   {
      LogInfo("Equity drop below threshold");
      HandleEquityDrop(currentEquity, dynamicStopThreshold);
   }
   else if (MathAbs(changePercentage) > rapidChangeThreshold)   {
      LogInfo("Rapid equity change");
      HandleRapidEquityChange(changePercentage);
   }
   else if (ShouldLog(LOG_DEBUG))   {
      MonteCarloSimulation();
   }
   
   lastEquity = currentEquity;
   return true;
}

// Custom LogInfo function with timestamp, log levels, and file rotation
void LogInfo(string message, LogLevel level = LOG_INFO) {
    // Format log message with timestamp and log level
    string logMessage = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + " [" + 
                        ((level == LOG_INFO) ? "INFO" : (level == LOG_WARNING) ? "WARNING" : "ERROR") + "] - " + message;

    // Print to terminal
    Print(logMessage);

    // Open log file for writing and rotate if needed
    #define MAX_LOG_FILE_SIZE 1048576 // 1 MB
    #define LOG_FILE_PATH "log.txt"  // Log file path
    int fileHandle = FileOpen(LOG_FILE_PATH, FILE_WRITE | FILE_TXT);
    if (fileHandle != INVALID_HANDLE) {
        if (FileSize(fileHandle) > MAX_LOG_FILE_SIZE) {
            FileDelete(LOG_FILE_PATH); // Rotate log file
            fileHandle = FileOpen(LOG_FILE_PATH, FILE_WRITE | FILE_TXT);
        }

        // Write log message to file and close
        FileWriteString(fileHandle, logMessage + "\n");
        FileClose(fileHandle);
    } else {
        Print("Error opening log file.");
    }
}

//------------------------------------------------------------------
// Handles equity drops by switching strategies and triggering recovery
//------------------------------------------------------------------
void HandleEquityDrop(double currentEquity, double dynamicStopThreshold) {
   static datetime lastStrategySwitchTime = 0;
   static bool recoveryModeActive = false;
   datetime now = TimeCurrent();

   // Consolidated checks (includes NaN check and trading allowed)
   if (currentEquity <= 0 || dynamicStopThreshold <= 0 || (currentEquity != currentEquity) ||
       !MarketInfo(Symbol(), MODE_TRADEALLOWED) || (now - lastStrategySwitchTime < 300) ||
       (now < StrToTime("00:00") || now > StrToTime("23:59")))
      return;

   // Activate recovery mode if not already active
   if (!recoveryModeActive) {
      CheckRecoveryMode();
      recoveryModeActive = true;
   }

   TradingStrategy saferStrategy = EnhancedStrategySelection();
   if (saferStrategy == OtherStrategy) {
      CloseAllOrders();
      DisableTrading();
      return;
   }

   // Only switch if the strategy has changed
   if (currentStrategy != saferStrategy) {
      currentStrategy = saferStrategy;
      ResetAndOptimizeStrategyAsync();
      lastStrategySwitchTime = now;
   }

   UnifiedPerformanceAndIndicatorUpdate(0, 0);
}

//------------------------------------------------------------------
// Asynchronous reset and optimization trigger for strategy changes
//------------------------------------------------------------------
void ResetAndOptimizeStrategyAsync() {
   // Static flag to prevent multiple concurrent optimization triggers
   static bool strategyOptimizationPending = false;
   if (strategyOptimizationPending) {
      Log("Strategy optimization is already pending, skipping optimization request.", LOG_WARNING);
      return;
   }
   strategyOptimizationPending = true;

   Log("Starting strategy reset and optimization.", LOG_INFO);

   // Start optimization timer (interval defined as needed)
   #define OPTIMIZATION_TIMER_INTERVAL 5
   EventSetTimer(OPTIMIZATION_TIMER_INTERVAL);

   // Mark start time if not already set (optional logging/metrics)
   static datetime optimizationStartTime = 0;
   if (optimizationStartTime == 0)
      optimizationStartTime = TimeCurrent();
}

//------------------------------------------------------------------
// Handles rapid equity changes by adjusting strategy and updating metrics
//------------------------------------------------------------------
void HandleRapidEquityChange(double changePercentage) {
   static datetime lastOptimizationTime = 0;
   double absChange = MathAbs(changePercentage);

   // Ignore negligible or extreme values
   if (absChange < 5.0 || changePercentage < -100.0 || changePercentage > 100.0)
      return;

   Log(StringFormat("Rapid equity change: %.2f%%. Reevaluating strategy.", changePercentage), LOG_WARNING);

   TradingStrategy adaptiveStrategy = EnhancedStrategySelection();
   if (adaptiveStrategy == INVALID_STRATEGY)
      adaptiveStrategy = DefaultStrategy();

   // Rate-limit strategy changes (only if the strategy actually changes)
   if ((int)currentStrategy != (int)adaptiveStrategy && !IsRateLimited(lastOptimizationTime, 60)) {
      currentStrategy = adaptiveStrategy;
      ResetAndOptimizeStrategy();
      Log(StringFormat("Switched to adaptive strategy: %s.", StrategyToString(adaptiveStrategy)), LOG_WARNING);
      lastOptimizationTime = TimeCurrent();
   }

   // Update performance using a higher factor for significant changes
   int updateFactor = (absChange >= 10.0 ? 2 : 1);
   UnifiedPerformanceAndIndicatorUpdate(updateFactor, (int)currentStrategy);

   if (absChange > GetExtremeChangeThreshold(currentStrategy))
      Log("Unrealistic equity change detected. Pausing trading.", LOG_WARNING);
}

//------------------------------------------------------------------
// Returns the extreme change threshold based on strategy
//------------------------------------------------------------------
double GetExtremeChangeThreshold(TradingStrategy strategy) {
   if (strategy < TrendFollowing || strategy > Scalping) {
      Log(StringFormat("Invalid strategy: %d. Returning default threshold.", strategy), LOG_ERROR);
      return 80.0;
   }

   StrategyThreshold strategyThresholds[] = {
      {TrendFollowing, 70.0},
      {Scalping, 50.0}
   };

   for (int i = 0; i < ArraySize(strategyThresholds); i++) {
      if (strategyThresholds[i].strategy == strategy)
         return strategyThresholds[i].threshold;
   }

   Log(StringFormat("Unknown strategy: %d. Returning default threshold.", strategy), LOG_WARNING);
   return 80.0;
}

//------------------------------------------------------------------
// Helper function for rate-limiting actions with enhanced precision
//------------------------------------------------------------------
bool IsRateLimited(datetime &lastActionTime, int cooldownSeconds, string actionName = "", bool localDebugMode = false) {
   if (cooldownSeconds <= 0 || cooldownSeconds > 31536000) {
      Print("Error: Invalid cooldownSeconds.");
      return true;
   }

   datetime now = TimeCurrent();
   if (now - lastActionTime >= cooldownSeconds) {
      lastActionTime = now;
      return false;
   }

   if (localDebugMode && actionName != "")
      Print("Rate limit hit for action: " + actionName + ". Try again in " +
            IntegerToString(cooldownSeconds - (now - lastActionTime)) + " seconds.");

   return true;
}

//------------------------------------------------------------------
// Resets consecutive losses and optimizes strategy parameters
//------------------------------------------------------------------
void ResetAndOptimizeStrategy() {
   // Check for valid strategy index
   if (currentStrategy < 0 || currentStrategy >= ArraySize(strategyConsecutiveLosses)) {
      Log("Error: Invalid currentStrategy", LOG_ERROR);
      return;
   }
   
   // Reset consecutive losses for current strategy
   strategyConsecutiveLosses[(int)currentStrategy] = 0;
   
   // Check if parameters are already optimized
   if (AreParametersOptimized()) {
      Log(StringFormat("Optimization not needed for strategy: %s", StrategyToString(currentStrategy)), LOG_INFO);
      return;
   }
   
   // Begin optimization
   Log(StringFormat("Starting optimization for strategy: %s", StrategyToString(currentStrategy)), LOG_INFO);
   if (!OptimizeStrategyParameters() || !AreParametersOptimized())
      Log(StringFormat("Error optimizing parameters for strategy: %s", StrategyToString(currentStrategy)), LOG_WARNING);
   else
      Log(StringFormat("Successfully optimized parameters for strategy: %s", StrategyToString(currentStrategy)), LOG_INFO);
}

//------------------------------------------------------------------
// Validates a single parameter and returns an error message if invalid
//------------------------------------------------------------------
bool ValidateParameter(const Parameter &param, string &errorMessage) {
   if (param.value < param.minValue || param.value > param.maxValue) {
      errorMessage = StringFormat(
         "Parameter '%s': %d (Expected: [%d - %d]).\n",
         param.name, param.value, param.minValue, param.maxValue
      );
      return false;
   }
   return true;
}

//------------------------------------------------------------------
// Validates that all required parameters are optimized
//------------------------------------------------------------------
bool AreParametersOptimized(int logLevel = LOG_INFO) {
   Parameter parameters[] = {
      {14, 1, 200, "movingAveragePeriod"},
      {5, 1, 10, "riskLevel"},
      {3, 1, 50, "slippage"}
   };

   string errorLog = "";
   for (int i = 0; i < ArraySize(parameters); i++) {
      string errorMessage;
      if (!ValidateParameter(parameters[i], errorMessage))
         errorLog += errorMessage;
   }

   if (StringLen(errorLog) > 0) {
      Log("Parameter optimization failed:\n" + errorLog, LOG_ERROR);
      return false;
   }

   Log("All parameters are optimized.", logLevel);
   return true;
}

//+------------------------------------------------------------------+
//| Calculates the current drawdown percentage relative to the peak  |
//| equity. Updates the peak equity if a new high is reached and logs  |
//| changes.                                                         |
//+------------------------------------------------------------------+
double CalculateDrawdownPercentage() {
   double currentEquity = AccountEquity();
   if (currentEquity <= 0)
      return 0.0;
      
   // Update peak equity if current equity exceeds it.
   if (currentEquity > peakEquity)
      peakEquity = currentEquity;
      
   double ddPercent = NormalizeDouble(((peakEquity - currentEquity) / peakEquity) * 100.0, 2);
   
   static double lastLoggedDD = -1.0;
   if (ddPercent != lastLoggedDD) {
      Log(StringFormat("Drawdown -> Peak: %.2f, Current: %.2f, DD: %.2f%%", peakEquity, currentEquity, ddPercent), LOG_DEBUG);
      lastLoggedDD = ddPercent;
   }
   return ddPercent;
}

//------------------------------------------------------------------
// Calculate Consolidated Lot Size with Adjustments
//------------------------------------------------------------------
double CalculateConsolidatedLotSize(double equity, double riskPercentage, RiskLevelType riskLevel, double drawdownPercentage, double slPoints) {
   // Validate essential inputs
   if (slPoints <= 0 || Point <= 0 || AccountLeverage() <= 0 || riskPercentage <= 0)
      return 0.0;

   double baseRisk = equity * (riskPercentage / 100.0);
   double adjustedRisk = AdjustRiskForRecovery(baseRisk, drawdownPercentage, true);
   if (adjustedRisk <= 0)
      return 0.0;

   string sym = Symbol();
   double marginPerLot = MarketInfo(sym, MODE_MARGINREQUIRED) / AccountLeverage();
   double minLot = MarketInfo(sym, MODE_MINLOT);
   double maxLot = MarketInfo(sym, MODE_MAXLOT);
   double lotStep = MarketInfo(sym, MODE_LOTSTEP);
   int digits = MarketInfo(sym, MODE_DIGITS);
   if (minLot <= 0 || maxLot <= 0 || lotStep <= 0 || marginPerLot <= 0)
      return 0.0;

   double lotSize = adjustedRisk / (slPoints * Point * marginPerLot);
   if (lotSize < minLot)
      return 0.0;

   // Adjust lot size based on drawdown
   if (drawdownPercentage > 5.0) {
      if (drawdownPercentage < 10.0)
         lotSize *= 0.9;
      else if (drawdownPercentage < 20.0)
         lotSize *= 0.75;
      else
         lotSize *= 0.5;
   }
   
   lotSize = NormalizeDouble(MathMax(minLot, MathMin(lotSize, maxLot)), digits);
   // Reduce lot size further if free margin is insufficient
   while (lotSize > minLot && AccountFreeMarginCheck(sym, OP_BUY, lotSize) < marginPerLot * lotSize)
      lotSize = NormalizeDouble(lotSize - lotStep, digits);
   
   return (lotSize >= minLot) ? lotSize : 0.0;
}

//------------------------------------------------------------------
// Consolidated Risk Calculation (returns true if breach detected)
//------------------------------------------------------------------
bool CalculateConsolidatedRisk(double equity, double riskPercentage, RiskLevelType riskLevel, double drawdownPercentage) {
   // Validate inputs
   if (equity <= 0 || riskPercentage <= 0 || drawdownPercentage < 0)
      return LogError(1001, "Invalid input values.");

   // Update global peak equity and perform periodic win rate calculation
   peakEquity = MathMax(peakEquity, equity);
   datetime now = TimeCurrent();
   if (now - lastUpdateTime > 60) {
      CalculateWinRates(false);
      lastUpdateTime = now;
   }

   double baseRiskAmount = NormalizeDouble(equity * riskPercentage / 100.0, 2);
   // Breach conditions: insufficient free margin, equity loss or excessive drawdown
   if (AccountFreeMargin() < MarginThreshold || equity < peakEquity * 0.9 || drawdownPercentage > MaxDrawdown) {
      if (!ReduceExposure(0.5))
         Log("Exposure reduction failed.", LOG_WARNING);
      LogWarning("Risk breach detected.");
      return true;
   }

   // Adjust risk based on recovery, win rate, and risk level
   double adjustedRisk = AdjustRiskForRecovery(
                           AdjustRiskForWinRate( AdjustRiskForLevel(baseRiskAmount, riskLevel), GetHighestWinRate()),
                           drawdownPercentage, true);
   if (adjustedRisk <= 0) {
      LogWarning("Invalid risk amount.");
      return true;
   }
   
   Log(StringFormat("Risk: %.2f for %.2f%% drawdown", adjustedRisk, drawdownPercentage), LOG_INFO);
   return false;
}

void LogWarning(string message, int warningCode = 1001, int strategyIndex = -1, ParameterType parameter = -1, double value = 0.0) {
    const int MAX_MSG_LENGTH = 256;
    
    if (warningCode <= 0) warningCode = 1001;  // Ensure valid warning code

    if (StringLen(message) > MAX_MSG_LENGTH) 
        message = StringSubstr(message, 0, MAX_MSG_LENGTH - 3) + "...";  // Truncate if needed

    LogError(warningCode, message, LOG_WARNING, strategyIndex, parameter, value);
}

//------------------------------------------------------------------
// Reduce exposure by decreasing lot sizes on open orders
//------------------------------------------------------------------
bool ReduceExposure(double reductionAmount) {
   if (OrdersTotal() == 0 || reductionAmount <= 0)
      return false;

   string sym = Symbol(); // use EA's current symbol
   double minLot = MarketInfo(sym, MODE_MINLOT);
   double lotStep = MarketInfo(sym, MODE_LOTSTEP);
   bool success = false;
   
   int total = OrdersTotal();
   for (int i = 0; i < total; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      // Process only BUY/SELL orders matching the EA's magic number and symbol
      if (OrderMagicNumber() != MagicNumber || OrderSymbol() != sym)
         continue;

      double currentLots = OrderLots();
      // Calculate new lot size and normalize it
      double newLots = NormalizeLots(MathMax(currentLots * reductionAmount, minLot), lotStep);
      // Skip if reduction doesn't reduce the lot size or margin check fails
      if (newLots >= currentLots || newLots <= 0 || AccountFreeMarginCheck(sym, OrderType(), newLots) < 0)
         continue;

      if (OrderClose(OrderTicket(), newLots, OrderClosePrice(), 3, clrNONE)) {
         Log(StringFormat("Reduced lot size to %.2f for order #%d", newLots, OrderTicket()), LOG_WARNING);
         success = true;
      }
      else {
         Log(StringFormat("Failed to reduce order #%d. Error: %d", OrderTicket(), GetLastError()), LOG_ERROR);
      }
   }
   return success;
}

//------------------------------------------------------------------
// Normalize lot size based on market parameters
//------------------------------------------------------------------
double NormalizeLots(double lotSize, double lotStep) {
   if (lotSize <= 0 || lotStep <= 0)
      return 0.0;  

   // Check if trading is enabled for the symbol
   if (SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
      return 0.0;  

   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   if (minLot <= 0) minLot = 0.01;
   if (maxLot <= 0) maxLot = 100.0;
   if (lotStep <= 0) lotStep = 0.01;

   double normalizedLot = MathRound(lotSize / lotStep) * lotStep;
   normalizedLot = MathMax(minLot, MathMin(normalizedLot, maxLot));

   int stepPrecision = MathMin(4, MathCeil(-MathLog10(lotStep)));  
   return NormalizeDouble(normalizedLot, stepPrecision);
}

//------------------------------------------------------------------
// Get the highest win rate from trade performance data
//------------------------------------------------------------------
double GetHighestWinRate() {
   int size = ArraySize(tradePerformance);
   if (size == 0)
      return 0.0;

   double highestWinRate = 0.0;
   for (int i = 0; i < size; i++) {
      if (tradePerformance[i].tradeCount > 0) {
         double rate = NormalizeDouble(tradePerformance[i].winRate, 4);
         if (rate >= 0.0 && rate <= 100.0)
            highestWinRate = MathMax(highestWinRate, rate);
      }
   }
   return highestWinRate;
}

//------------------------------------------------------------------
// Adjust risk based on win rate
//------------------------------------------------------------------
double AdjustRiskForWinRate(double riskAmount, double winRate, double riskIncrease = 1.2, double riskDecrease = 0.8) {
   if (winRate < 0.0 || winRate > 100.0) {
      Log(StringFormat("Invalid win rate: %.2f. Must be between 0 and 100.", winRate), LOG_ERROR);
      return riskAmount;
   }
   double adjustmentFactor = 1.0;
   if (winRate >= 75.0)
      adjustmentFactor = riskIncrease;
   else if (winRate < 50.0)
      adjustmentFactor = riskDecrease;
   else
      adjustmentFactor = 1.0 + (winRate - 50.0) * (riskIncrease - 1.0) / 25.0;

   double adjustedRisk = riskAmount * adjustmentFactor;
   Log(StringFormat("Win Rate = %.2f%%, Adjusted Risk = %.2f%s", winRate, adjustedRisk,
         (adjustmentFactor > 1.0 ? " - Risk increased." : (adjustmentFactor < 1.0 ? " - Risk reduced." : " - No adjustment."))), LOG_INFO);
   return adjustedRisk;
}

//------------------------------------------------------------------
// Adjust risk based on risk level
//------------------------------------------------------------------
double AdjustRiskForLevel(double riskAmount, RiskLevelType riskLevel) {
   if (riskAmount <= 0) {
      Log(StringFormat("Invalid risk amount (%.2f). Must be positive.", riskAmount), LOG_ERROR);
      return -999; // Error indicator
   }
   double factor = (riskLevel == RiskLow) ? 0.5 : (riskLevel == RiskHigh) ? 1.5 : 1.0;
   Log(StringFormat("%s risk level detected. Adjusted risk: %.2f.",
         (factor == 1.0 ? "Medium" : (factor < 1.0 ? "Low" : "High")), riskAmount * factor), LOG_INFO);
   return riskAmount * factor;
}

// LogSuccess function (similar structure to LogError)
void LogSuccess(int successCode, string message, int logLevel = LOG_INFO, int strategyIndex = -1) {
    // Return if the message is empty
    if (StringLen(message) == 0) return;

    // Validate the log level (LOG_INFO, LOG_WARNING, LOG_ERROR, LOG_DEBUG)
    if (logLevel < LOG_INFO || logLevel > LOG_DEBUG) {
        Log("Error: Invalid log level.", LOG_ERROR);
        return;
    }

    // Prepare the context if strategyIndex is provided
    string context = (strategyIndex >= 0) ? StringFormat(" | StrategyIndex: %d", strategyIndex) : "";

    // Add account information for log levels LOG_WARNING and above
    if (logLevel >= LOG_WARNING) {
        context += StringFormat(" | AccountBalance: %.2f | AccountEquity: %.2f", AccountBalance(), AccountEquity());
    }

    // Log the success message
    Log(StringFormat("[%s] Success: %d - %s%s", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), successCode, message, context), logLevel);
}

//------------------------------------------------------------------
// Validate that the order matches expected parameters
//------------------------------------------------------------------
bool IsValidOrder(int orderTicket, int magicNumber, int orderType, string expectedSymbol){
   if(!OrderSelect(orderTicket, SELECT_BY_TICKET))   {
      Print("Order selection failed for Order ", orderTicket);
      return false;
   }
   
   // Check magic number, order type range, and symbol
   if(OrderMagicNumber() != magicNumber || OrderType() < OP_BUY || OrderType() > OP_SELLLIMIT || OrderSymbol() != expectedSymbol)   {
      Print("Invalid order parameters for Order ", orderTicket);
      return false;
   }
   
   return true;
}

//------------------------------------------------------------------
// Unified Trade Execution Function
//------------------------------------------------------------------
bool ExecuteTrade(int orderType, string strategyTag, bool enableRetry = false){
   static int failureCount = 0;
   static int retryCount = 0;  // Persist retry count across calls

   string sym = Symbol();
   datetime now = TimeCurrent();
   int currentHour = TimeHour(now);

   if (!MarketInfo(sym, MODE_TRADEALLOWED) || (currentHour < 8 || currentHour > 20))   {
      Log("Market closed.", LOG_WARNING);
      return false;
   }

   double currentSpread = Ask - Bid;
   double avgSpread = CalculateAverageSpread(10);
   if (currentSpread > avgSpread * 1.5)   {
      Log("Spread too high.", LOG_WARNING);
      return false;
   }

   double lotSize = CalculateConsolidatedLotSize(AccountEquity(), 2.0, RiskMedium, CalculateDrawdownPercentage(), 50);
   if (lotSize <= 0 || AccountFreeMarginCheck(sym, orderType, lotSize) < 0)   {
      Log("Invalid lot size or insufficient margin.", LOG_ERROR);
      return false;
   }

   double price = (orderType == OP_BUY) ? Ask : (orderType == OP_SELL) ? Bid : GetPendingOrderPrice(orderType);
   if (price <= 0)
      return false;

   double slPoints = GetSLBasedOnStrategy(strategyTag);
   double tpPoints = GetTPBasedOnStrategy(strategyTag);
   double slPrice = price - slPoints * Point * ((orderType == OP_BUY) ? 1 : -1);
   double tpPrice = price + tpPoints * Point * ((orderType == OP_BUY) ? 1 : -1);

   int ticket = PlaceOrder(orderType, lotSize, price, NormalizeDouble(slPrice, Digits), NormalizeDouble(tpPrice, Digits), strategyTag);
   if (ticket > 0)   {
      failureCount = 0;
      Log("Trade executed successfully.", LOG_INFO);
      return true;
   }

   if (++failureCount > 3 || !enableRetry)   {
      Log("Too many failures, stopping retries.", LOG_ERROR);
      return false;
   }

   Log("Retrying trade...", LOG_WARNING);
   return RetryTrade(orderType, strategyTag, true, 3, 5000, retryCount);
}

//------------------------------------------------------------------
// Calculate Average Spread over a given number of bars (in points)
//------------------------------------------------------------------
double CalculateAverageSpread(int bars) {
   if (bars <= 0)
      return 0;

   double openArray[], closeArray[];
   if (CopyOpen(Symbol(), PERIOD_M1, 0, bars, openArray) <= 0 ||
       CopyClose(Symbol(), PERIOD_M1, 0, bars, closeArray) <= 0) {
      Print("Error retrieving price data");
      return 0;
   }
   
   double totalSpread = 0;
   for (int i = 0; i < bars; i++)
      totalSpread += MathAbs(closeArray[i] - openArray[i]);
   
   return totalSpread / bars / MarketInfo(Symbol(), MODE_POINT);
}

//------------------------------------------------------------------
// Get SL (Stop Loss) based on strategy using ATR
//------------------------------------------------------------------
int GetSLBasedOnStrategy(string strategyTag, int atrPeriod = 14, double multiplier = 2.0) {
   double atr = cachedATR;
   if (atr <= 0) {
      Print("Error: ATR is too low, using default SL");
      return 30;
   }
   
   double sl;
   if (strategyTag == "Scalping")
      sl = atr * 0.5;
   else if (strategyTag == "TrendFollowing")
      sl = atr * 2.0;
   else
      sl = atr * multiplier;
      
   return MathMax(10, int(sl));
}

//------------------------------------------------------------------
// Get TP (Take Profit) based on strategy using ATR
//------------------------------------------------------------------
int GetTPBasedOnStrategy(string strategyTag, int atrPeriod = 14, double multiplier = 1.0) {
   double atr = cachedATR;
   if (atr < 0.01) {
      Print("Error: ATR too low, using default TP");
      return 60;
   }
   strategyTag = StringTrim(strategyTag);
   for (int i = 0; i < ArraySize(Strategies); i++) {
      if (StringCompare(strategyTag, Strategies[i].strategy, true) == 0)
         return int(atr * Strategies[i].multiplier * multiplier);
   }
   Print("Error: Invalid strategy tag - ", strategyTag);
   return int(atr * multiplier);
}

//------------------------------------------------------------------
// Calculate pending order price based on order type and buffer
//------------------------------------------------------------------
double GetPendingOrderPrice(int orderType, double bufferMultiplier = 10) {
    string sym = Symbol();
    double pointSize = MarketInfo(sym, MODE_POINT);
    if (pointSize <= 0) {
        LogError(1001, "Invalid point size for symbol: " + sym, LOG_ERROR);
        return -1;
    }
    
    // Clamp buffer between 5 and 50 points
    double buffer = MathMin(MathMax(bufferMultiplier * pointSize, 5 * pointSize), 50 * pointSize);
    if (buffer >= 50 * pointSize)
        LogError(1002, "Buffer adjusted to: " + DoubleToString(buffer), LOG_WARNING);
    
    double orderPrice = CalculateOrderPrice(orderType, buffer, Bid, Ask);
    if (orderPrice == -1) {
        LogError(1000, "Invalid order type: " + IntegerToString(orderType), LOG_ERROR);
        return -1;
    }
    return orderPrice;
}

//------------------------------------------------------------------
// Calculate order price based on order type and buffer
//------------------------------------------------------------------
double CalculateOrderPrice(int orderType, double buffer, double bidPrice, double askPrice) {
   // Validate input prices and buffer
   if (bidPrice <= 0 || askPrice <= 0 || buffer <= 0)
      return INVALID_PRICE;
   
   string sym = Symbol();
   double atr = cachedATR;
   if (atr <= 0)
      return INVALID_PRICE;
   
   // Warn if the buffer is significantly larger than volatility
   if (buffer > 5 * atr)
      LogOrderPriceWarning(1005, "Large buffer: " + DoubleToString(buffer));
   
   double price = INVALID_PRICE;
   // Determine pending order price based on order type
   switch (orderType) {
      case OP_BUYLIMIT:
      case OP_SELLSTOP:
         price = bidPrice - buffer;
         break;
      case OP_SELLLIMIT:
      case OP_BUYSTOP:
         price = askPrice + buffer;
         break;
      default:
         return INVALID_PRICE;
   }
   
   // Ensure calculated price is within a reasonable range (within 10 ATR from bid/ask)
   if (MathAbs(price - bidPrice) > 10 * atr || MathAbs(price - askPrice) > 10 * atr)
      return INVALID_PRICE;
   
   return price;
}

//------------------------------------------------------------------
// Log warning for order price with customizable log level and message truncation
//------------------------------------------------------------------
void LogOrderPriceWarning(int warningCode, string message, int logLevel = LOG_WARNING) {
   string sym = Symbol();
   string timeStr = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
   string logMessage = StringFormat("{\"warning_code\": %d, \"symbol\": \"%s\", \"time\": \"%s\", \"message\": \"%s\"}", 
                                    warningCode, sym, timeStr, message);
   
   // Truncate message if it exceeds MAX_LOG_MESSAGE_LENGTH
   if (StringLen(logMessage) > MAX_LOG_MESSAGE_LENGTH) {
      string truncationWarning = "Message too long, truncating: ";
      int remainingLength = MAX_LOG_MESSAGE_LENGTH - StringLen(truncationWarning);
      logMessage = truncationWarning + StringSubstr(logMessage, 0, remainingLength);
      LogError(warningCode, logMessage, logLevel);
   } else {
      LogError(warningCode, logMessage, logLevel);
   }
   
   // Optionally output to terminal based on log level or debug mode
   bool isDebugMode = false; // Set true if verbose output is desired
   if (logLevel == LOG_ERROR || logLevel == LOG_WARNING || (isDebugMode && (logLevel == LOG_INFO || logLevel == LOG_DEBUG)))
      Print("Log: ", logMessage);
}

//------------------------------------------------------------------
// Retry trade execution with a limit on retries
//------------------------------------------------------------------
bool RetryTrade(int orderType, string strategyTag, bool enableRetry, int maxRetries, int retryDelay, int &retryCount) {
   #define MAX_RETRY_DELAY 60000
   // Validate retry parameters
   if (maxRetries <= 0 || retryDelay <= 0 || retryDelay > MAX_RETRY_DELAY) {
      Print("Invalid retry parameters for order type ", orderType);
      return false;
   }
   
   // If we've reached the retry limit or retries are disabled, reset and try one final execution
   if (retryCount >= maxRetries || !enableRetry) {
      retryCount = 0;
      return ExecuteTrade(orderType, strategyTag, true);
   }
   
   // Increment retry counter, wait, and re-attempt trade execution
   retryCount++;
   Print("Retry ", retryCount, " for order type ", orderType, " Strategy: ", strategyTag);
   Sleep(retryDelay);
   
   bool result = ExecuteTrade(orderType, strategyTag, true);
   if (result) {
      retryCount = 0;
      Log(StringFormat("Trade succeeded on retry %d for order type %d", retryCount, orderType), LOG_INFO);
   } else {
      Log(StringFormat("Trade failed on retry attempt %d for order type %d", retryCount, orderType), LOG_WARNING);
   }
   return result;
}

//------------------------------------------------------------------
// Place order with given parameters and return ticket number
//------------------------------------------------------------------
int PlaceOrder(int orderType, double lotSize, double price, double slPrice, double tpPrice, string strategyTag) {
    string sym = Symbol();
    double minLot    = MarketInfo(sym, MODE_MINLOT);
    double maxLot    = MarketInfo(sym, MODE_MAXLOT);
    double stopLevel = MarketInfo(sym, MODE_STOPLEVEL) * Point;
    
    // Validate lot size and SL/TP distances
    if(lotSize <= 0 || lotSize < minLot || lotSize > maxLot ||
       MathAbs(slPrice - price) < stopLevel || MathAbs(tpPrice - price) < stopLevel) {
         Log(StringFormat("Invalid order parameters. Strategy=%s", strategyTag), LOG_WARNING);
         return -1;
    }
    
    int digits = MarketInfo(sym, MODE_DIGITS);
    slPrice = NormalizeDouble(slPrice, digits);
    tpPrice = NormalizeDouble(tpPrice, digits);
    
    #define MaxSlippage 3
    int dynamicSlippage = MathMin(CalculateDynamicSlippage(14, 3, 10, 10000.0, PERIOD_H1), MaxSlippage);
    int ticket = OrderSend(sym, orderType, lotSize, price, dynamicSlippage, slPrice, tpPrice, strategyTag, MagicNumber, 0, clrBlue);
    
    if(ticket > 0)
         Log(StringFormat("Order placed: Ticket=%d, Strategy=%s", ticket, strategyTag), LOG_INFO);
    else
         Log(StringFormat("OrderSend failed: ErrorCode=%d, Strategy=%s", GetLastError(), strategyTag), LOG_ERROR);
    
    ResetLastError();
    return ticket;
}

//------------------------------------------------------------------
// Count the number of open orders matching the magic number and valid order types
//------------------------------------------------------------------
int CountOpenOrders(){
   int count = 0;
   for (int i = 0; i < OrdersTotal(); i++)   {
      if (OrderSelect(i, SELECT_BY_POS))      {
         if (OrderMagicNumber() == MagicNumber &&
             (OrderType() == OP_BUY || OrderType() == OP_SELL) &&
             OrderCloseTime() == 0)         {
            count++;
         }
      }
   }
   Log(StringFormat("Current open orders: %d", count), LOG_INFO);
   return count;
}

//------------------------------------------------------------------
// Retry Order Modify with Progressive Backoff and Fallback
//------------------------------------------------------------------
bool RetryOrderModify(int orderTicket, double price, double newSL, double newTP) {
   // Set maximum retries based on account balance
   int maxRetries = (AccountBalance() < 1000) ? 3 : 5;
   int retries = 0;
   double tolerance = Point * 0.1;
   
   // Validate order selection and SL/TP validity
   if (!OrderSelect(orderTicket, SELECT_BY_TICKET) || !IsValidSLTP(price, newSL, newTP, OrderType()))
      return false;
   
   // If current SL and TP are already within tolerance, nothing to modify
   if (MathAbs(OrderStopLoss() - newSL) < tolerance &&
       MathAbs(OrderTakeProfit() - newTP) < tolerance)
      return true;
   
   // Attempt OrderModify with progressive backoff
   while (retries < maxRetries) {
      retries++;
      RefreshRates();
      if (OrderModify(orderTicket, price, newSL, newTP, 0))
         return true;
      
      int errorCode = GetLastError();
      // For certain errors, do not retry
      if (errorCode == 4108) return false;
      if (errorCode != 4104)
         Log(StringFormat("[WARNING] OrderModify failed. Error: %d", errorCode), LOG_WARNING);
      
      Sleep(MathMin(500 * retries, 5000));
   }
   
   // If modification still fails, attempt fallback order
   int newTicket = -1;
   return AttemptFallbackOrder(Symbol(), orderTicket, price, newSL, newTP, retries, maxRetries, newTicket);
}

//------------------------------------------------------------------
// Validate SL and TP values based on price, stop levels, and order type
//------------------------------------------------------------------
bool IsValidSLTP(double price, double newSL, double newTP, int orderType) {
   // Only market orders (BUY/SELL) are supported
   if (orderType != OP_BUY && orderType != OP_SELL)
      return false;
   if (price <= 0.0 || newSL <= 0.0 || newTP <= 0.0 || Point <= 0)
      return false;
   if (SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
      return false;

   // Determine minimum acceptable distance based on stop level, freeze level, and spread
   double sym = Symbol();
   double minStop    = MarketInfo(sym, MODE_STOPLEVEL) * Point;
   double freezeLevel= MarketInfo(sym, MODE_FREEZELEVEL) * Point;
   double spread     = MarketInfo(sym, MODE_SPREAD) * Point;
   spread = MathMax(spread, 2 * Point);
   minStop = MathMax(MathMax(minStop, freezeLevel), spread);

   // For BUY orders, SL must be below price and TP above price; vice versa for SELL orders.
   if (orderType == OP_BUY) {
      if (newSL >= price - minStop || newTP <= price + minStop)
         return false;
   } else {  // OP_SELL
      if (newSL <= price + minStop || newTP >= price - minStop)
         return false;
   }
   return true;
}

//------------------------------------------------------------------
// Attempt Fallback Order if OrderModify fails after retries
//------------------------------------------------------------------
bool AttemptFallbackOrder(string symbol, int orderTicket, double price, double newSL, double newTP, int retries, int maxRetries, int &outTicket, string fallbackComment = "Fallback Order", color fallbackColor = clrBlue) {
   // Exit early if max retries reached or order selection fails
   if (retries >= maxRetries || !OrderSelect(orderTicket, SELECT_BY_TICKET) || OrderSymbol() != symbol) {
      LogError(1, "Max retries or order selection failed.", LOG_ERROR);
      return false;
   }
   
   // Cache symbol and market parameters
   double minLot = MarketInfo(symbol, MODE_MINLOT);
   double marginRequired = MarketInfo(symbol, MODE_MARGINREQUIRED);
   
   // Validate trading parameters: price, SL, TP, market conditions, and margin
   if (price <= 0 || newSL <= 0 || newTP <= 0 || !IsMarketConditionValid() ||
       SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED ||
       OrderLots() <= 0 || OrderLots() < minLot ||
       OrderLots() > MarketInfo(symbol, MODE_MAXLOT) ||
       AccountFreeMargin() < OrderLots() * price * marginRequired) {
      LogError(2, "Invalid price, SL, TP, lot size, or insufficient margin.", LOG_ERROR);
      return false;
   }
   
   // Attempt to send fallback order with incremental delay
   for (int attempt = retries; attempt < maxRetries; attempt++) {
      ResetLastError();
      outTicket = OrderSend(symbol, OrderType(), OrderLots(), price,
                            CalculateDynamicSlippage(14, 3, 10, 10000.0, PERIOD_H1),
                            newSL, newTP, fallbackComment, MagicNumber, 0, fallbackColor);
      
      if (outTicket > 0) {
         LogSuccess(0, "Fallback order placed.", LOG_INFO);
         return true;
      }
      
      int errorCode = GetLastError();
      LogError(3, StringFormat("Attempt %d failed. Error: %d", attempt + 1, errorCode), LOG_ERROR);
      
      // Only retry for transient errors
      if (errorCode == ERR_REQUOTE || errorCode == ERR_BROKER_BUSY || errorCode == ERR_TRADE_CONTEXT_BUSY) {
         Sleep(500 + attempt * 500);
      } else {
         HandleFallbackError(errorCode);
         return false;
      }
   }
   
   LogError(4, "Fallback order failed after max attempts.", LOG_ERROR);
   return false;
}

//------------------------------------------------------------------
// Handle fallback errors based on error codes
//------------------------------------------------------------------
void HandleFallbackError(int errorCode) {
   string errorMsg;
   string actionSuggestion;
   int logLevel = LOG_ERROR;  // Default log level

   switch (errorCode) {
      case 133:
         errorMsg = "Invalid lot size or market conditions.";
         actionSuggestion = "Check lot size and ensure the market is open.";
         logLevel = LOG_WARNING;
         break;
      case 147:
         errorMsg = "Not enough money for the order.";
         actionSuggestion = "Check account balance and margin.";
         logLevel = LOG_WARNING;
         break;
      case 135:
         errorMsg = "Trade timeout.";
         actionSuggestion = "Increase timeout or check server conditions.";
         logLevel = LOG_WARNING;
         break;
      case 156:
         errorMsg = "Invalid SL/TP values.";
         actionSuggestion = "Verify SL/TP limits.";
         break;
      default:
         errorMsg = StringFormat("Unexpected error occurred: %d.", errorCode);
         actionSuggestion = "Review logs or contact support.";
         break;
   }

   Log(StringFormat("[ERROR] %s Action: %s", errorMsg, actionSuggestion), logLevel);
}

//------------------------------------------------------------------
// Strategy performance monitoring and fallback mechanism
//------------------------------------------------------------------
void MonitorAndSwitchStrategy() {
   int stratIdx = (int)currentStrategy;
   double winRate = strategyWinRate[stratIdx];
   int losses = strategyConsecutiveLosses[stratIdx];
   
   // Skip switching if losses are high (allow recovery) or win rate is acceptable
   if (losses >= 5 || (winRate >= 0.4 && losses < 3))
      return;
   
   Log(StringFormat("Strategy %s underperforming: WinRate = %.2f%%, Losses = %d.", 
         StrategyToString(currentStrategy), winRate * 100, losses), LOG_WARNING);
   
   // Switch to the best-performing strategy
   currentStrategy = SelectBestStrategyBasedOnPerformance();
   strategyConsecutiveLosses[(int)currentStrategy] = 0;
   
   // Update performance metrics and reassess parameters after switching
   UnifiedPerformanceAndIndicatorUpdate(0, 0);
   ReassessParameters();
   Log(StringFormat("Switched to: %s.", StrategyToString(currentStrategy)), LOG_INFO);
}

//+------------------------------------------------------------------+
//| Add trade details to history                                     |
//+------------------------------------------------------------------+
bool AddTradeToHistory(double profit, double duration, int strategy, double entryPrice, double exitPrice) {
    static RingBuffer tradeHistoryBuffer;

    // Initialize buffer only once
    static bool isBufferInitialized = false;
    if (!isBufferInitialized) {
        tradeHistoryBuffer.Init(20);  // Default buffer size 20
        isBufferInitialized = true;
    }

    // Remove oldest entry if buffer is full
    if (tradeHistoryBuffer.Size() >= 20) {
        tradeHistoryBuffer.RemoveOldest();
    }

    // Create trade data
    TradeData trade;
    trade.profit      = profit;
    trade.duration    = duration;
    trade.strategy    = strategy;
    trade.entryPrice  = entryPrice;
    trade.exitPrice   = exitPrice;
    trade.maxDrawdown = 0.0;  // Default value for maxDrawdown
    trade.sharpeRatio = 0.0;  // Default value for sharpeRatio

    // Add trade data to buffer
    tradeHistoryBuffer.Add(trade);

    return true;
}

//------------------------------------------------------------------
// Unified Performance and Indicator Update Utility
//------------------------------------------------------------------
bool UnifiedPerformanceAndIndicatorUpdate(int orderTicket, int strategyIndex) {
   static datetime lastPerfCheck = 0;
   datetime now = TimeCurrent();
   
   // If provided, validate the order ticket
   if (orderTicket > 0) {
      if (!OrderSelect(orderTicket, SELECT_BY_TICKET) || OrderCloseTime() != 0 || Symbol() != OrderSymbol()) {
         Log("[ERROR] Invalid order ticket or mismatch: " + IntegerToString(orderTicket), LOG_ERROR);
         return false;
      }
   }
   
   UpdateCachedIndicators();
   // Handle trade data (duration computed from order open time; assumes valid OrderOpenTime if ticket provided)
   HandleTradeData(orderTicket, OrderProfit(), now - OrderOpenTime(), (TradingStrategy)strategyIndex);
   CheckRiskMetrics();
   CalculateWinRates();
   AdjustSLTP(orderTicket);
   
   // Reassess strategies periodically (every performanceCheckInterval seconds)
   if (now - lastPerfCheck >= 3600) {
      PeriodicStrategyReassessment(lastPerfCheck);
      lastPerfCheck = now;
   }
   LogPerformanceMetrics();
   return true;
}

//------------------------------------------------------------------
// Helper function to handle trade data logging and history
//------------------------------------------------------------------
void HandleTradeData(int orderTicket, double profit, double duration, TradingStrategy strategy) {
   // Validate order and strategy selection
   if (strategy < 0 || strategy >= MAX_STRATEGIES ||
       (!OrderSelect(orderTicket, SELECT_BY_TICKET) && !OrderSelect(orderTicket, SELECT_BY_TICKET, MODE_HISTORY))) {
      DebugLog("Invalid order or strategy.");
      return;
   }

   double orderLots = OrderLots();
   if (orderLots <= 0) return;
   
   // Update performance metrics and win/loss counts
   static int strategyWins[MAX_STRATEGIES] = {0};
   static int strategyTrades[MAX_STRATEGIES] = {0};
   bool isProfitable = profit > 0;
   strategyConsecutiveLosses[strategy] = isProfitable ? 0 : strategyConsecutiveLosses[strategy] + 1;
   strategyWins[strategy] += isProfitable ? 1 : 0;
   strategyTrades[strategy]++;
   strategyWinRate[strategy] = (strategyTrades[strategy] > 0) ? (double)strategyWins[strategy] / strategyTrades[strategy] : 0.5;

   // Log trade details and execution
   DebugLog(StringFormat("[Trade #%d] Profit: %.2f | Duration: %.2f sec | Win Rate: %.2f%%", 
                          orderTicket, profit, duration, strategyWinRate[strategy] * 100));
   LogTradeExecution(orderTicket, orderLots, StrategyToString(strategy));
   AddTradeToHistory(profit, duration, strategy, OrderOpenPrice(), OrderClosePrice());

   // Execute pyramiding if enabled and conditions met
   if (isProfitable && EnablePyramiding && AccountFreeMarginCheck(Symbol(), OrderType(), orderLots) > 0 &&
       PerformPyramiding(orderTicket))
      DebugLog("Pyramiding executed.");
}

//------------------------------------------------------------------
// Returns the account's margin level as a percentage.
// Logs errors if margin or equity are invalid.
//------------------------------------------------------------------
double AccountMarginLevel(){
    double margin = AccountMargin();
    double equity = AccountEquity();
    static datetime lastErrorLogTime = 0;
    datetime now = TimeCurrent();
    bool canLog = (now - lastErrorLogTime >= 5);

    const double MIN_MARGIN_THRESHOLD = 0.0001;
    const double MAX_MARGIN_LEVEL     = 10000.0;

    // Validate margin.
    if (margin <= MIN_MARGIN_THRESHOLD || IsNaN(margin) || IsInfinite(margin))    {
        if (canLog)        {
            DebugLog("Invalid margin: " + DoubleToStr(margin, 2));
            lastErrorLogTime = now;
        }
        return INVALID_MARGIN_LEVEL;
    }

    // Validate equity.
    if (equity <= 0 || IsNaN(equity) || IsInfinite(equity))    {
        if (canLog)        {
            DebugLog("Invalid equity: " + DoubleToStr(equity, 2));
            lastErrorLogTime = now;
        }
        return INVALID_MARGIN_LEVEL;
    }
    
    double level = (equity / margin) * 100;
    // Clamp the margin level to the maximum allowed value.
    return NormalizeDouble(MathMin(level, MAX_MARGIN_LEVEL), 2);
}

bool IsInfinite(double x){
    // Check for NaN (NaN is the only value that does not equal itself)
    if (x != x)
        return false;

    // Check for true infinity (both positive and negative)
    return (x > DBL_MAX || x < -DBL_MAX);
}

//------------------------------------------------------------------
// Updates risk metrics and issues aggregated alerts with throttling
//------------------------------------------------------------------
void CheckRiskMetrics() {
   double drawdown = CalculateDrawdownPercentage();
   double equity   = AccountEquity();
   double margin   = AccountMarginLevel();
   if(drawdown < 0 || equity < 0 || margin < 0)
      return;
   
   double maxDrawdown = GetDynamicMaxDrawdownPercentage();
   // If using fractional drawdown, convert to percentage
   const bool DRAWDOWN_IS_FRACTION = true;
   if(DRAWDOWN_IS_FRACTION)
      maxDrawdown *= 100;
   
   double equityThreshold = GetDynamicEquityStopThreshold();
   if(maxDrawdown <= 0 || maxDrawdown > 100 || equityThreshold <= 0 || MinMarginLevel <= 0)
      return;
   
   string message = "";
   if(drawdown > maxDrawdown)
      message += "Drawdown " + DoubleToString(drawdown, 2) + "% > " + DoubleToString(maxDrawdown, 2) + "%; ";
   if(equity < equityThreshold)
      message += "Equity " + DoubleToString(equity, 2) + " < " + DoubleToString(equityThreshold, 2) + "; ";
   if(margin < MinMarginLevel)
      message += "Margin " + DoubleToString(margin, 2) + " < " + DoubleToString(MinMarginLevel, 2) + "; ";
   
   static datetime lastAlert = 0, lastAllClear = 0;
   datetime now = TimeCurrent();
   if(message != "") {
      LogRiskBreach("Risk Breach: " + message, 0);
      if(now - lastAlert > ALERT_INTERVAL) {
         Alert("Risk breach detected: ", message);
         lastAlert = now;
      }
      if(++alertCount >= ESCALATION_THRESHOLD)
         Print("Escalation: Risk breach persists for ", alertCount, " cycles.");
   }
   else {
      alertCount = 0;
      if(now - lastAllClear > ALL_CLEAR_INTERVAL) {
         Print("Risk OK: Drawdown ", drawdown, "%, Equity ", equity, ", Margin ", margin);
         lastAllClear = now;
      }
   }
}

//------------------------------------------------------------------
// Helper function for periodic strategy reassessment
//------------------------------------------------------------------
void PeriodicStrategyReassessment(datetime &lastCheck) {
   if (performanceCheckInterval <= 0)
      return;
      
   datetime now = TimeCurrent();
   if (now - lastCheck < performanceCheckInterval)
      return;
      
   ReassessStrategies();
   lastCheck = now;
}

//------------------------------------------------------------------
// Helper function: Reassess strategies and switch if needed
//------------------------------------------------------------------
void ReassessStrategies() {
   static datetime lastSwitchTime = 0;
   datetime currentTime = TimeCurrent();
   
   // Select and validate the best-performing strategy
   TradingStrategy bestStrategy = SelectBestStrategyBasedOnPerformance();
   if (!IsValidStrategy(bestStrategy)) {
      DebugLog("Selected strategy is invalid. Aborting strategy reassessment.");
      Log("Selected strategy is invalid. Aborting strategy reassessment.", LOG_ERROR);
      return;
   }
   
   // If candidate is the same as current, just monitor
   if (bestStrategy == currentStrategy) {
      MonitorAndSwitchStrategy();
      return;
   }
   
   // Enforce hysteresis: require at least MIN_SWITCH_INTERVAL seconds since last switch
   #define MIN_SWITCH_INTERVAL 60
   if (currentTime - lastSwitchTime < MIN_SWITCH_INTERVAL) {
      string intervalMsg = StringFormat("Switch suppressed: only %d seconds since last switch.", currentTime - lastSwitchTime);
      DebugLog(intervalMsg);
      Log(intervalMsg, LOG_INFO);
      MonitorAndSwitchStrategy();
      return;
   }
   
   // Only switch if the candidate is significantly better than the current strategy
   if (!IsSignificantlyBetterStrategy(currentStrategy, bestStrategy)) {
      string notBetterMsg = "New strategy is not significantly better than the current one. No switch performed.";
      DebugLog(notBetterMsg);
      Log(notBetterMsg, LOG_INFO);
      MonitorAndSwitchStrategy();
      return;
   }
   
   // Log and execute the switch
   string logMessage = StringFormat("Switching to best-performing strategy: %s", StrategyToString(bestStrategy));
   DebugLog(logMessage);
   Log(logMessage, LOG_INFO);
   
   currentStrategy = bestStrategy;
   lastSwitchTime = currentTime;
   
   // Continue monitoring after the switch
   MonitorAndSwitchStrategy();
}

//------------------------------------------------------------------
// Determines if the candidate strategy is significantly better than current
//------------------------------------------------------------------
bool IsSignificantlyBetterStrategy(TradingStrategy current, TradingStrategy candidate) {
   static const double threshold = 0.05;  // Minimum improvement required
   double cp = GetStrategyPerformance(current).performance;
   double ap = GetStrategyPerformance(candidate).performance;
   
   // Validate performance data
   if (IsValueNaN(cp) || IsValueNaN(ap) || IsValueInfinite(cp) || IsValueInfinite(ap)) {
      DebugLog("Invalid performance data (NaN or Infinite).");
      return false;
   }
   
   #ifdef DEBUG
   DebugLog(StringFormat("Current performance: %f, Candidate performance: %f", cp, ap));
   #endif
   
   // If current performance is non-positive, candidate is better if positive
   if (cp <= 0.0)
      return (ap > 0.0);
   
   // Otherwise, candidate must exceed current by at least the threshold
   return (ap > cp) && ((ap - cp) > threshold);
}

// Helper function to check if a value is infinite.
bool IsValueInfinite(double value){
   // If value is truly infinite, its absolute value will be greater than DBL_MAX.
   return (MathAbs(value) > DBL_MAX);
}

// Helper function to check if a value is NaN.
bool IsValueNaN(double value){
   // NaN is the only value that does not equal itself.
   double tmp = value;
   return (tmp != tmp);
}

//------------------------------------------------------------------
// Retrieves performance for a given strategy
//------------------------------------------------------------------
StrategyPerformanceResult GetStrategyPerformance(TradingStrategy strategy) {
   StrategyPerformanceResult result = { DBL_MIN, true }; // Default error result
   
   int index = GetStrategyIndex(strategy);
   int arraySize = ArraySize(strategyPerformances);
   
   if(arraySize == 0) {
      #ifdef DEBUG
         Print("Error in GetStrategyPerformance: strategyPerformances array is empty.");
      #endif
      return result;
   }
   
   if(index < 0 || index >= arraySize) {
      #ifdef DEBUG
         Print("Error in GetStrategyPerformance: Invalid TradingStrategy index ", index);
      #endif
      return result;
   }
   
   result.performance = strategyPerformances[index];
   result.error = false;
   return result;
}

//------------------------------------------------------------------
// Retrieves the index of the strategy from its enum value
//------------------------------------------------------------------
int GetStrategyIndex(TradingStrategy strategy) {
    int index = int(strategy);
    const int TOTAL_STRATEGIES = 11;  // Update if new strategies are added.
    
    if(index < 0 || index >= TOTAL_STRATEGIES) {
        #ifdef DEBUG
            Print("GetStrategyIndex error: Invalid strategy: ", TradingStrategyToString(strategy), " (", strategy, ")");
        #else
            Print("GetStrategyIndex error: Invalid strategy value: ", strategy);
        #endif
        return -1;
    }
    return index;
}

//------------------------------------------------------------------
// Function to validate the order type (BUY or SELL)
//------------------------------------------------------------------
bool TestDetermineOrderType(double fastMA, double slowMA, double rsi) {
   #define MAX_REALISTIC 1e10

   if(fastMA == EMPTY_VALUE || slowMA == EMPTY_VALUE || rsi == EMPTY_VALUE ||
      fastMA <= EPSILON || fastMA > MAX_REALISTIC ||
      slowMA <= EPSILON || slowMA > MAX_REALISTIC ||
      rsi < 0 || rsi > 100) {
         Log(StringFormat("TestDetermineOrderType: Invalid values (fastMA: %.4f, slowMA: %.4f, RSI: %.2f)", fastMA, slowMA, rsi), LOG_ERROR);
         return false;
   }
   
   int orderType = DetermineOrderType(fastMA, slowMA, rsi);
   if(orderType != OP_BUY && orderType != OP_SELL) {
      Log(StringFormat("TestDetermineOrderType: Invalid order type (%d)", orderType), LOG_ERROR);
      return false;
   }
   
   Log(StringFormat("TestDetermineOrderType: Order type %s valid", orderType == OP_BUY ? "BUY" : "SELL"), LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Test all required market conditions for strategy selection
//------------------------------------------------------------------
bool TestAllConditions(int chartTimeframe, int fastMAPeriod, int slowMAPeriod, int rsiPeriod, string symbol) {
   // Validate input parameters
   if(chartTimeframe <= 0 || fastMAPeriod <= 0 || slowMAPeriod <= 0 || rsiPeriod <= 0 || StringLen(symbol) == 0) {
      Log("TestAllConditions: Invalid parameters.", LOG_ERROR);
      return false;
   }
   
   int requiredBars = MathMax(MathMax(fastMAPeriod, slowMAPeriod), rsiPeriod) + 1;
   if(Bars < requiredBars) {
      Log("TestAllConditions: Insufficient bars.", LOG_ERROR);
      return false;
   }
   
   // Retrieve indicators
   double fastMA = cachedFastMA;
   double slowMA = cachedSlowMA;
   double rsi    = cachedRSI;
   if(fastMA == EMPTY_VALUE || slowMA == EMPTY_VALUE || rsi == EMPTY_VALUE) {
      Log("TestAllConditions: Indicator calculation failed.", LOG_ERROR);
      return false;
   }
   
   if(!TestDetermineOrderType(fastMA, slowMA, rsi) || !ValidateTradingThresholds()) {
      Log("TestAllConditions: Trading conditions not met.", LOG_ERROR);
      return false;
   }
   
   Log(StringFormat("TestAllConditions: Passed. fastMA: %.4f, slowMA: %.4f, RSI: %.2f", fastMA, slowMA, rsi), LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Helper function to validate trend strength and RSI thresholds
//------------------------------------------------------------------
bool ValidateTradingThresholds() {
   string sym = Symbol();
   RefreshRates();
   
   double rsi = cachedRSI;
   double localTrendStrength = cachedTrendStrength;
   
   // Validate indicator values
   if(rsi < 0 || localTrendStrength < 0) {
      if(LOG_LEVEL > 0)
         Log("[ValidateTradingThresholds] Invalid RSI or Trend Strength.", LOG_ERROR);
      return false;
   }
   
   if(LOG_LEVEL == 2)
      Log(StringFormat("[ValidateTradingThresholds] RSI: %.2f | Trend Strength: %.2f", rsi, localTrendStrength), LOG_INFO);
   
   // Set up thresholds for RSI and Trend Strength
   Threshold thresholds[2];
   
   thresholds[0].value = localTrendStrength;
   thresholds[0].min   = 0.01;
   thresholds[0].max   = 0.05;
   thresholds[0].name  = "Trend Strength";
   
   thresholds[1].value = rsi;
   thresholds[1].min   = 30.0;
   thresholds[1].max   = 70.0;
   thresholds[1].name  = "RSI";
   
   if(!IsValidThreshold(thresholds, 2)) {
      if(LOG_LEVEL > 0)
         Log("[ValidateTradingThresholds] Threshold validation failed.", LOG_ERROR);
      return false;
   }
   
   rsi = cachedRSI;
   trendStrength = localTrendStrength;
   return true;
}

//------------------------------------------------------------------
// Validates multiple thresholds; returns true only if all are valid
//------------------------------------------------------------------
bool IsValidThreshold(Threshold &thresholds[], int count) {
    if(count <= 0 || count > ArraySize(thresholds)) {
        Log("[IsValidThreshold] ERROR: Invalid count or empty array.", LOG_ERROR);
        return false;
    }
    
    bool allValid = true;
    for(int i = 0; i < count; i++) {
        string name = (StringLen(thresholds[i].name) > 0) ? thresholds[i].name : "Unnamed";
        if(!IsRangeValid(thresholds[i].min, thresholds[i].max) || !IsThresholdValid(thresholds[i])) {
            Log(StringFormat("[IsValidThreshold] ERROR: %s - Invalid range (%.2f - %.2f) or value (%.2f)",
                  name, thresholds[i].min, thresholds[i].max, thresholds[i].value), LOG_ERROR);
            allValid = false;
        }
    }
    
    if(allValid)
        Log("[IsValidThreshold] SUCCESS: All thresholds valid.", LOG_INFO);
    
    return allValid;
}

//------------------------------------------------------------------
// Logs threshold validation errors
//------------------------------------------------------------------
void LogThresholdError(const string name, const double value, const double min, const double max, const string errorMsg = "") {
   string actualName = (StringLen(name) > 0) ? name : "Unknown";
   string strValue = (value != value) ? "NaN" : DoubleToString(value, 2);
   string strMin   = (min   != min)   ? "NaN" : DoubleToString(min, 2);
   string strMax   = (max   != max)   ? "NaN" : DoubleToString(max, 2);
   
   string rangeInfo = "(" + strMin + " - " + strMax + ")";
   if (min > max)
      rangeInfo += " [Invalid Range]";
   
   string additional = (StringLen(errorMsg) > 0) ? " - " + errorMsg : "";
   Log(StringFormat("[ThresholdError] %s: %s out of range %s%s", actualName, strValue, rangeInfo, additional), LOG_ERROR);
}

//------------------------------------------------------------------
// Checks if the provided range is valid (and non-NaN)
//------------------------------------------------------------------
bool IsRangeValid(const double min, const double max) {
    // Use IsNaN helper function (NaN is not equal to itself)
    if(IsNaN(min) || IsNaN(max))
        return false;
    return (min <= max);
}

//------------------------------------------------------------------
// Validates a single threshold's range and value
//------------------------------------------------------------------
bool IsThresholdValid(const Threshold &t) {
   const double epsilon = DBL_EPSILON * 10;
   
   // Check for NaN values and proper range (accounting for epsilon)
   if (IsNaN(t.min) || IsNaN(t.max) || IsNaN(t.value) || t.min >= t.max - epsilon) {
      LogThresholdError(t.name, t.value, t.min, t.max,
         (t.min >= t.max - epsilon) ? "Invalid range: min must be less than max." : "Threshold contains NaN value(s).");
      return false;
   }
   
   // Ensure the threshold value is within the allowed range (with epsilon tolerance)
   if (t.value < t.min - epsilon || t.value > t.max + epsilon) {
      string direction = (t.value < t.min) ? "below" : "above";
      double boundary = (t.value < t.min) ? t.min : t.max;
      LogThresholdError(t.name, t.value, t.min, t.max,
         StringFormat("Value %.6f is %s threshold (%.6f).", t.value, direction, boundary));
      return false;
   }
   
   return true;
}

//------------------------------------------------------------------
// Simplified function to check and manage recovery mode
//------------------------------------------------------------------
bool CheckRecoveryMode() {
    ToggleVerboseLogging(true);
    Log("Checking recovery mode.", LOG_DEBUG);
    
    // Validate configuration parameters
    if(drawdownThreshold <= 0 || exitRecoveryThreshold <= 0 || exitRecoveryThreshold > 1.0 || peakEquity <= 0) {
        Log("Invalid configuration.", LOG_ERROR);
        ToggleVerboseLogging(false);
        return false;
    }
    
    double drawdown = CalculateDrawdownPercentage();
    if(drawdown < 0) {
        Log("Negative drawdown.", LOG_ERROR);
        ToggleVerboseLogging(false);
        return false;
    }
    
    // Activate recovery mode if drawdown exceeds threshold
    if(drawdown > drawdownThreshold * 100.0) {
        if(!IsRecoveryModeActive())
            ActivateRecoveryMode(drawdown);
        Log(StringFormat("Recovery mode activated: Drawdown=%.2f%%", drawdown), LOG_WARNING);
        ToggleVerboseLogging(false);
        return true;
    }
    
    // Deactivate recovery mode if conditions have improved
    if(IsRecoveryModeActive() && AccountEquity() >= peakEquity * exitRecoveryThreshold) {
        DeactivateRecoveryMode();
        Log("Recovery mode deactivated.", LOG_INFO);
    }
    
    ToggleVerboseLogging(false);
    return IsRecoveryModeActive();
}

//------------------------------------------------------------------
// Simplified function to check if recovery mode is active
//------------------------------------------------------------------
bool IsRecoveryModeActive() {
    const double TOLERANCE = 1e-6;
    const string VAR_NAME = "RecoveryModeActive";
    
    if(!GlobalVariableCheck(VAR_NAME)) {
        GlobalVariableSet(VAR_NAME, 0);
        return false;
    }
    
    double modeValue = GlobalVariableGet(VAR_NAME);
    if(MathAbs(modeValue - 1.0) < TOLERANCE)
        return true;
    if(MathAbs(modeValue) < TOLERANCE)
        return false;
    
    GlobalVariableSet(VAR_NAME, 0);
    return false;
}

//------------------------------------------------------------------
// Activate recovery mode with additional validations and logging
//------------------------------------------------------------------
void ActivateRecoveryMode(double drawdownPercentage) {
    // Ignore invalid input
    if (drawdownPercentage < 0)
        return;
    
    // Activate only if recovery mode is not already active or if drawdown worsens
    double currentDrawdownPercentage = 0.0;
    if (recoveryMode && drawdownPercentage <= currentDrawdownPercentage)
        return;
    
    recoveryMode = true;
    currentDrawdownPercentage = drawdownPercentage;
    
    Log(StringFormat("Recovery mode activated: Drawdown = %.2f%%", drawdownPercentage), LOG_WARNING);
    
    if (NeedsPerformanceLogging())
        LogPerformanceMetrics();
    if (drawdownPercentage > 10.0)
        RunMonteCarloSimulations();
    if (ShouldRecalculateWinRates())
        CalculateWinRates(false);
    if (ShouldSwitchToSaferStrategy())
        SwitchToSaferStrategy();
    
    OptimizeForRecoveryMode();
    ExecuteAllStrategies();
}

//------------------------------------------------------------------
// Determines if performance logging is needed based on equity 
// change and drawdown thresholds, with a cooldown period.
//------------------------------------------------------------------
bool NeedsPerformanceLogging(double eqThreshold = 0.05, double ddThreshold = 10.0, int cooldown = 60) {
    static bool initialized = false;
    static double lastEquity;
    static datetime lastEquityTime, lastDrawdownTime;
    
    datetime currentTime = TimeCurrent();
    double currentEquity = AccountEquity();

    if (!initialized) {
        initialized = true;
        lastEquity = currentEquity;
        lastEquityTime = lastDrawdownTime = currentTime;
        return true;
    }
    
    // Log if equity is non-positive and cooldown has passed.
    if (currentEquity <= 0) {
        if (currentTime - lastEquityTime >= cooldown) {
            lastEquityTime = currentTime;
            lastEquity = currentEquity;
            return true;
        }
    }
    else {
        // Calculate relative change in equity.
        double equityChange = MathAbs(currentEquity - lastEquity) / MathAbs(lastEquity);
        if (equityChange >= eqThreshold) {
            lastEquity = currentEquity;
            lastEquityTime = currentTime;
            return true;
        }
    }
    
    // Check drawdown threshold and ensure cooldown for drawdown logging.
    if (CalculateDrawdownPercentage() > ddThreshold && currentTime - lastDrawdownTime >= cooldown) {
        lastDrawdownTime = currentTime;
        return true;
    }
    
    return false;
}

//------------------------------------------------------------------
// Determines whether win rates should be recalculated.
// If forceReset is true or account changes, resets stored values.
//------------------------------------------------------------------
bool ShouldRecalculateWinRates(bool forceReset = false) {
    static const double THRESHOLD_WIN = 0.05, THRESHOLD_EQ = 1000.0;
    static bool initialized = false;
    static double lastWinRate, lastEquity;
    static long lastAccount = 0;
    
    long currentAccount = AccountNumber();
    double currentWinRate = GetCurrentWinRate();
    double currentEquity = AccountEquity();
    
    // Reset if forced, on first run, or when account changes.
    if (forceReset || !initialized || currentAccount != lastAccount) {
        lastAccount   = currentAccount;
        lastWinRate   = currentWinRate;
        lastEquity    = currentEquity;
        initialized   = true;
        return false;
    }
    
    // Determine if recalculation is needed based on thresholds.
    bool needRecalc = (MathAbs(currentWinRate - lastWinRate) >= THRESHOLD_WIN) ||
                      (MathAbs(currentEquity - lastEquity) >= THRESHOLD_EQ);
    if (needRecalc) {
        lastWinRate = currentWinRate;
        lastEquity  = currentEquity;
    }
    return needRecalc;
}

//------------------------------------------------------------------
// Calculates the current win rate based on historical orders.
// Only counts orders with non-zero profit (either win or loss).
//------------------------------------------------------------------
double GetCurrentWinRate() {
    static int totalWins = 0, totalLosses = 0, lastCheckedOrder = -1;
    int totalOrders = OrdersHistoryTotal();
    
    // If no new orders exist, return the current win rate.
    if (totalOrders == 0 || totalOrders <= lastCheckedOrder)
        return 0.0;
    
    // Process only new orders from the last checked index.
    for (int i = lastCheckedOrder + 1; i < totalOrders; i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            int orderType = OrderType();
            double profit = OrderProfit();
            // Consider only market orders with non-zero profit.
            if ((orderType == OP_BUY || orderType == OP_SELL) && profit != 0) {
                if (profit > 0)
                    totalWins++;
                else
                    totalLosses++;
            }
        }
    }
    
    lastCheckedOrder = totalOrders - 1;
    int totalTrades = totalWins + totalLosses;
    return (totalTrades > 0) ? (double)totalWins / totalTrades : 0.0;
}

//------------------------------------------------------------------
// Determines whether to switch to a safer strategy based on risk metrics.
// Checks balance, equity, drawdown percentage, and the equity ratio.
//------------------------------------------------------------------
bool ShouldSwitchToSaferStrategy() {
    const double DRAWDOWN_THRESHOLD   = 20.0;
    const double EQUITY_RATIO_THRESHOLD = 0.8;
    
    double balance = AccountBalance();
    double equity  = AccountEquity();
    
    // If balance or equity is invalid, trigger safer strategy.
    if (balance <= 0 || equity < 0)
        return true;
    
    double drawdown = CalculateDrawdownPercentage();
    // If drawdown value is out-of-range or NaN, switch strategy.
    if (drawdown < 0 || drawdown > 100 || IsNaN(drawdown))
        return true;
    
    double equityRatio = equity / balance;
    if (IsNaN(equityRatio))
        return true;
    
    return (drawdown > DRAWDOWN_THRESHOLD || equityRatio < EQUITY_RATIO_THRESHOLD);
}

//------------------------------------------------------------------
// Handles exit from recovery mode by validating account values,
// logging account state, and finalizing the exit process.
//------------------------------------------------------------------
void OnRecoveryModeExit() {
    double equity  = AccountEquity();
    double balance = AccountBalance();

    // Validate account state using EPSILON and NaN checks.
    if (equity < -EPSILON || balance < EPSILON || (equity != equity) || (balance != balance)) {
        PrintFormat("Warning: Invalid account state! Equity: %.2f, Balance: %.2f", equity, balance);
    }
    else {
        const double MAX_BALANCE_THRESHOLD = 1e9;
        if (equity > MAX_BALANCE_THRESHOLD || balance > MAX_BALANCE_THRESHOLD)
            Log("Extreme account values detected, review broker data.", LOG_WARNING);
        Log(StringFormat("Recovery mode exited. Equity: %.2f, Balance: %.2f", equity, balance), LOG_INFO);
    }

    recoveryMode = false;
    Print("Recovery mode exit completed.");
}

//------------------------------------------------------------------
// Simplified function to deactivate recovery mode.
// Logs key metrics and then calls the exit handler.
//------------------------------------------------------------------
void DeactivateRecoveryMode() {
    if (!recoveryMode)
        return;

    // Log deactivation details before exiting recovery mode.
    PrintFormat("Recovery mode deactivated. Equity: %.2f, Balance: %.2f", AccountEquity(), AccountBalance());
    LogPerformanceMetrics();
    OnRecoveryModeExit();
}

//------------------------------------------------------------------
// Run Monte Carlo simulations with simplified logic
//------------------------------------------------------------------
void RunMonteCarloSimulations(int numSimulations = 1000, bool logResults = true) {
    if (numSimulations <= 0) {
        Log("Error: Number of simulations must be greater than zero.", LOG_ERROR);
        return;
    }
    
    Log(StringFormat("Running %d Monte Carlo simulations...", numSimulations), LOG_INFO);
    datetime startTime = TimeCurrent();
    
    bool success = GeneticAlgorithmOptimization();
    double elapsed = MathMax((TimeCurrent() - startTime) / 60.0, 0.01); // Avoid zero elapsed time

    Log(StringFormat("Monte Carlo simulations %s in %.2f minutes.", 
         success ? "completed" : "failed", elapsed), success ? LOG_INFO : LOG_ERROR);
    
    if (success && logResults)
        Log("Using Monte Carlo results for recovery strategy adaptation.", LOG_INFO);
}

//------------------------------------------------------------------
// Switch to a safer strategy if necessary
//------------------------------------------------------------------
void SwitchToSaferStrategy() {
    TradingStrategy saferStrategy = EnhancedStrategySelection();
    if (currentStrategy == saferStrategy) {
        Log("No strategy change. Retaining current strategy.", LOG_INFO);
        return;
    }
    
    const int NUM_STRATEGIES = 11;
    if (ArraySize(strategyConsecutiveLosses) != NUM_STRATEGIES) {
        Log(StringFormat("Mismatch in strategyConsecutiveLosses array size. Expected: %d, Actual: %d", 
            NUM_STRATEGIES, ArraySize(strategyConsecutiveLosses)), LOG_ERROR);
        return;
    }
    
    int idx = StrategyToIndex(saferStrategy);
    if (idx < 0 || idx >= NUM_STRATEGIES) {
        Log("Index out-of-range when attempting to switch strategies.", LOG_ERROR);
        return;
    }
    
    TradingStrategy previousStrategy = currentStrategy;
    currentStrategy = saferStrategy;
    strategyConsecutiveLosses[idx] = 0;
    
    Log(StringFormat("Switched strategy from %s to safer strategy: %s", 
          StrategyToString(previousStrategy), StrategyToString(saferStrategy)), LOG_INFO);
}

//------------------------------------------------------------------
// Helper function to convert a TradingStrategy enum to an index safely
//------------------------------------------------------------------
int StrategyToIndex(TradingStrategy strategy) {
    if (!IsValidStrategy(strategy)) {
        Log(StringFormat("Invalid TradingStrategy value: %d", (int)strategy), LOG_ERROR);
        return -1;
    }
    
    const int MIN_STRATEGY = (int)TrendFollowing;
    const int MAX_STRATEGY = (int)SafeMode;
    const int EXPECTED_COUNT = MAX_STRATEGY - MIN_STRATEGY + 1;
    const int actualCount = ArraySize(strategyConsecutiveLosses);
    
    static datetime lastSizeCheck = 0;
    if (actualCount != EXPECTED_COUNT && TimeCurrent() - lastSizeCheck > 60) {
        Log(StringFormat("Warning: Enum size mismatch. Expected: %d, Found: %d", EXPECTED_COUNT, actualCount), LOG_WARNING);
        lastSizeCheck = TimeCurrent();
    }
    
    return (int)strategy;
}

//------------------------------------------------------------------
// Optimize parameters for recovery mode using a genetic algorithm
//------------------------------------------------------------------
OptimizationResult OptimizeForRecoveryMode(bool logResults = true, double maxTime = 30.0) {
    if (maxTime <= 0) {
        Log("Error: maxOptimizationTime must be > 0.", LOG_ERROR);
        return OPT_FAILURE;
    }
    
    datetime startTime = TimeCurrent();
    Log("Starting GA optimization for recovery mode...", LOG_INFO);
    
    bool success = GeneticAlgorithmOptimization();
    double elapsed = (TimeCurrent() - startTime) / 60.0; // elapsed time in minutes
    bool timedOut = (elapsed > maxTime);
    if (timedOut)
        success = false;
    
    if (success) {
        Log(StringFormat("Optimization completed in %.2f minutes.", elapsed), LOG_INFO);
        if (logResults)
            Log("Using optimization results for recovery mode.", LOG_INFO);
        return OPT_SUCCESS;
    }
    
    Log(StringFormat("Optimization %s after %.2f minutes.", timedOut ? "timed out" : "failed", elapsed), LOG_ERROR);
    return timedOut ? OPT_TIMEOUT : OPT_FAILURE;
}

//------------------------------------------------------------------
// Adjust risk for recovery mode based on drawdown percentage
//------------------------------------------------------------------
double AdjustRiskForRecovery(double baseRiskAmount, double drawdownPercentage, bool recoveryModeActive, bool logResults = true, double riskScalingFactor = 1.0) {
   if (baseRiskAmount <= 0.0 || !recoveryModeActive)
      return baseRiskAmount;

   // Clamp drawdown percentage and ensure scaling factor is sensible
   drawdownPercentage = MathMin(MathMax(drawdownPercentage, 0.0), 100.0);
   riskScalingFactor = MathMax(riskScalingFactor, 0.01);

   double riskFactor = 1.0;
   if (drawdownPercentage >= 30.0)
      riskFactor = 0.25;
   else if (drawdownPercentage >= 20.0)
      riskFactor = 0.5;
   else if (drawdownPercentage >= 10.0)
      riskFactor = 0.75;

   double adjustedRisk = MathMax(baseRiskAmount * riskFactor * riskScalingFactor, 0.0);
   if (logResults)
      Log(StringFormat("Risk Adjusted: Base=%.2f, Adjusted=%.2f, Drawdown=%.2f%%, Scaling=%.2f",
                        baseRiskAmount, adjustedRisk, drawdownPercentage, riskScalingFactor), LOG_INFO);
   return adjustedRisk;
}

//------------------------------------------------------------------
// Disables trading by removing the EA
//------------------------------------------------------------------
void DisableTrading(bool notifyUser = true) {
    static bool isDisabled = false;
    if (isDisabled)
        return;
    isDisabled = true;

    Log("Trading disabled", LOG_WARNING);

    bool ordersClosed = CloseOpenOrders();
    Log(ordersClosed ? "Orders closed" : "Order closure failed", ordersClosed ? LOG_INFO : LOG_ERROR);

    EventKillTimer();
    if (notifyUser)
        Alert("Trading disabled");

    ExpertRemove();
}

//------------------------------------------------------------------
// Closes open orders and returns true if at least one order is closed
//------------------------------------------------------------------
bool CloseOpenOrders() {
    int closedCount = 0;
    int totalOrders = OrdersTotal();

    for (int i = totalOrders - 1; i >= 0; i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

        int orderType = OrderType();
        // Only process market orders with a valid lot size.
        if ((orderType != OP_BUY && orderType != OP_SELL) || OrderLots() <= 0)
            continue;

        RefreshRates();
        double price = MarketInfo(OrderSymbol(), (orderType == OP_BUY) ? MODE_BID : MODE_ASK);
        if (price <= 0)
            continue;

        // Attempt to close the order up to 3 times.
        for (int retry = 0; retry < 3; retry++) {
            if (OrderClose(OrderTicket(), OrderLots(), price, 3, clrNONE)) {
                closedCount++;
                break;
            }
            Sleep(500);
        }
    }

    Log(StringFormat("Closed %d orders.", closedCount), LOG_INFO);
    return (closedCount > 0);
}

//------------------------------------------------------------------
// Triggers an alert, notification, and email with cooldown protection.
//------------------------------------------------------------------
void TriggerAlert(const string message, bool sendAlert, bool sendNotification, bool sendEmail, int cooldownSeconds = 5){
    string globalVar = "LastAlertTime_" + message;
    ulong now = GetTickCount();
    ulong cooldownMillis = (ulong)cooldownSeconds * 1000;
    ulong lastTriggerTime = GlobalVariableCheck(globalVar) ? (ulong)GlobalVariableGet(globalVar) : 0;
    
    // Skip alert if still in cooldown or if an overflow is detected.
    if(now < lastTriggerTime || (now - lastTriggerTime) < cooldownMillis)
        return;
        
    // Store the time of this alert.
    GlobalVariableSet(globalVar, (double)now);

    if(sendAlert)    {
        Alert(message);
        Log("Alert: " + message, LOG_WARNING);
    }
    if(sendNotification && SendNotification(message))
        Log("Notification: " + message, LOG_INFO);
    if(sendEmail && SendMail("Alert", message))
        Log("Email: " + message, LOG_INFO);
}

//------------------------------------------------------------------
// Main monitoring function
//------------------------------------------------------------------
void MonitorAndAlert() {
    // Configuration (with minimal sanity adjustments)
    const int debounceTicks       = MathMax(3, 1);      // At least 1 tick required before alert
    const int logIntervalSeconds  = MathMax(60, 1);     // Log every 60 seconds (minimum 1)
    const int alertCooldownSecs   = MathMax(300, 1);    // Minimum seconds between alerts
    const int maxAlertReminders   = 10;                 // Max reminder alerts per breach

    double dd = CalculateDrawdownPercentage();
    double fm = AccountFreeMargin();
    if(dd < 0 || fm < 0) {
        Log("Error: Abnormal account values.", LOG_ERROR);
        return;
    }

    datetime now = TimeCurrent();
    static datetime lastLog = 0;
    if(now - lastLog >= logIntervalSeconds) {
        Log(StringFormat("Monitor: DD = %.2f%%, FM = %.2f", dd, fm), LOG_INFO);
        lastLog = now;
    }

    // Static counters for each breach condition
    static int  ddBreachCount = 0, fmBreachCount = 0;
    static bool ddAlertSent   = false, fmAlertSent   = false;
    static datetime ddLastAlert = 0, fmLastAlert = 0;
    static int  ddAlertTotal  = 0, fmAlertTotal  = 0;

    // Handle drawdown and free margin breaches
    HandleBreach(dd > MaxDrawdown, ddBreachCount, ddAlertSent, ddLastAlert, ddAlertTotal,
                 debounceTicks, alertCooldownSecs, maxAlertReminders,
                 StringFormat("CRITICAL: Drawdown %.2f%% > %.2f%%", dd, MaxDrawdown));
    HandleBreach(fm < MarginThreshold, fmBreachCount, fmAlertSent, fmLastAlert, fmAlertTotal,
                 debounceTicks, alertCooldownSecs, maxAlertReminders,
                 StringFormat("WARNING: Free Margin %.2f < %.2f", fm, MarginThreshold));
}

//------------------------------------------------------------------
// Handles alert logic for a breach condition.
//------------------------------------------------------------------
void HandleBreach(bool breachCondition, int &breachCount, bool &alertSent, datetime &lastAlertTime, int &localAlertCount, const int debounceTicks, const int alertCooldown, const int maxAlertReminders, const string alertMessage, const int maxBreachCount = 1000000){
    // If there is no breach, reset counters and flags.
    if(!breachCondition)    {
        breachCount   = 0;
        alertSent     = false;
        lastAlertTime = 0;
        localAlertCount = 0;
        return;
    }
    
    // Update breach count and reset if exceeding max threshold.
    breachCount++;
    if(breachCount > maxBreachCount)
        breachCount = debounceTicks;

    datetime now = TimeCurrent();
    bool cooldownPassed   = (now - lastAlertTime >= alertCooldown);
    bool remindersAllowed = (maxAlertReminders == 0 || localAlertCount < maxAlertReminders);
    
    // Trigger alert if conditions are met.
    if(breachCount >= debounceTicks && (!alertSent || (cooldownPassed && remindersAllowed)))    {
        TriggerAlert(alertMessage, true, true, true, alertCooldown);
        alertSent = true;
        lastAlertTime = now;
        localAlertCount++;
    }
}

//------------------------------------------------------------------
// Check if Trading is Allowed
//------------------------------------------------------------------
bool CanTrade(){
   Log("Checking if trade is allowed...", LOG_DEBUG);

   // Check connection, risk, session, and broker conditions.
   if (!IsConnected())   {
      Log("No connection to broker.", LOG_ERROR);
      return false;
   }
   if (!IsRiskAllowed())   {
      Log("Risk breach detected.", LOG_ERROR);
      return false;
   }
   if (!IsTradingSession())   {
      Log("Market session is closed.", LOG_WARNING);
      return false;
   }
   if (!IsBrokerTradingAllowed())   {
      Log("Broker trading conditions not met.", LOG_ERROR);
      return false;
   }
   
   // Check symbol tradability.
   string sym = Symbol();
   if (!IsSymbolTradable(sym))   {
      Log("Symbol " + sym + " is not tradable.", LOG_WARNING);
      return false;
   }
   
   // Check free margin.
   double margin = AccountFreeMargin();
   const double MinimumFreeMargin = 100.0;
   if (margin < MinimumFreeMargin)   {
      Log("Insufficient free margin (" + DoubleToString(margin, 2) + ").", LOG_WARNING);
      return false;
   }
   
   // Adjust cooldown based on dynamic factors.
   AdjustDynamicCooldown();
   if (!IsCooldownComplete())   {
      Log("Cooldown period active.", LOG_WARNING);
      return false;
   }
   if (!IsMarketConditionValid())   {
      Log("Market conditions not favorable.", LOG_WARNING);
      return false;
   }
   if (CountOpenOrders() >= MaxOpenOrders)   {
      Log("Max open orders (" + IntegerToString(MaxOpenOrders) + ") reached.", LOG_WARNING);
      return false;
   }
   
   Log("Trade conditions satisfied. Proceeding with trade.", LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Check if the symbol is tradable
//------------------------------------------------------------------
bool IsSymbolTradable(string symbol){
   if (StringLen(symbol) == 0 || MarketInfo(symbol, MODE_TRADEALLOWED) == 0)
      return false;

   double minLot = MarketInfo(symbol, MODE_MINLOT);
   if (minLot <= 0)
      minLot = 0.1;

   if (AccountFreeMarginCheck(symbol, OP_BUY, minLot) <= 0)
      return false;

   double bid    = MarketInfo(symbol, MODE_BID);
   double ask    = MarketInfo(symbol, MODE_ASK);
   double spread = ask - bid;

   return (bid > 0 && ask > 0 && spread > 0 && spread <= 20.0);
}

//------------------------------------------------------------------
// Check if broker trading is allowed
//------------------------------------------------------------------
bool IsBrokerTradingAllowed() {
    const double MAX_SPREAD       = 50.0;
    const double MIN_FREE_MARGIN  = 100.0;
    const double MIN_MARGIN_LEVEL = 100.0;
    
    string sym = Symbol();
    if (StringLen(sym) == 0 ||
        !IsConnected() ||
        !IsExpertEnabled() ||
        !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
        MarketInfo(sym, MODE_TRADEALLOWED) != 1)    {
        return false;
    }

    double spread      = MarketInfo(sym, MODE_SPREAD);
    double freeMargin  = AccountFreeMargin();
    double marginLevel = AccountMarginLevel();

    return (spread >= 0 && spread <= MAX_SPREAD &&
            freeMargin >= MIN_FREE_MARGIN &&
            marginLevel >= MIN_MARGIN_LEVEL);
}

//------------------------------------------------------------------
// Check if current account risk conditions allow trading
//------------------------------------------------------------------
bool IsRiskAllowed(){
    const double MAX_DRAWDOWN    = 20.0;
    const double MIN_FREE_MARGIN  = 100.0;
    const double MIN_MARGIN_LEVEL = 100.0;
    const double MAX_DAILY_LOSS   = 10.0;
    
    double balance     = AccountBalance();
    double equity      = AccountEquity();
    double freeMargin  = AccountFreeMargin();
    double marginLevel = AccountMarginLevel();
    double g_DailyStartBalance = 0; // This may be set elsewhere in your EA

    // Basic validations.
    if (balance <= 0 || freeMargin < 0 || marginLevel < 0)
        return false;
    
    // If there are open orders, apply further risk checks.
    if (OrdersTotal() > 0)    {
        double drawdownPct = ((balance - equity) / balance) * 100;
        if (drawdownPct > MAX_DRAWDOWN)
            return false;
        if (freeMargin < MIN_FREE_MARGIN)
            return false;
        if (marginLevel > 0 && marginLevel < MIN_MARGIN_LEVEL)
            return false;
        if (g_DailyStartBalance > 0)        {
            double dailyLossPct = ((g_DailyStartBalance - equity) / g_DailyStartBalance) * 100;
            if (dailyLossPct > MAX_DAILY_LOSS)
                return false;
        }
    }
    return true;
}

//------------------------------------------------------------------
// Checks if the current time is within the allowed trading session
//------------------------------------------------------------------
bool IsTradingSession(){
   datetime t = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(t, dt);
   
   // Reject weekends or holidays.
   if (dt.day_of_week == 0 || dt.day_of_week == 6 || IsHoliday())
      return false;
   
   // Session start and end times in minutes (e.g., 09:00 to 16:00).
   const int start = 9 * 60;
   const int end   = 16 * 60;
   int nowMinutes = dt.hour * 60 + dt.min;
   
   // If start equals end, session is always open.
   if (start == end)
      return true;
   
   // For same-day sessions.
   if (start < end)
      return (nowMinutes >= start && nowMinutes < end);
   
   // For overnight sessions.
   return (nowMinutes >= start || nowMinutes < end);
}

//------------------------------------------------------------------
// Checks if today is a holiday based on a predefined list.
//------------------------------------------------------------------
bool IsHoliday(){
   // Predefined holiday strings.
   static const string rawHolidays[] = {
      "2025.01.01", // New Year's Day
      "2025.12.25"  // Christmas Day
   };
   
   // Cache holiday dates as datetime values on first run.
   static bool holidaysInitialized = false;
   static datetime holidayDates[];
   if (!holidaysInitialized)   {
      int count = ArraySize(rawHolidays);
      ArrayResize(holidayDates, count);
      for (int idx1 = 0; idx1 < count; idx1++)
         holidayDates[idx1] = StrToTime(rawHolidays[idx1] + " 00:00");
      holidaysInitialized = true;
   }
   
   // Normalize current time to today's midnight.
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   datetime todayMidnight = now - dt.hour * 3600 - dt.min * 60 - dt.sec;
   
   // Check if today's midnight matches any holiday.
   for (int idx2 = 0; idx2 < ArraySize(holidayDates); idx2++)   {
      if (todayMidnight == holidayDates[idx2])
         return true;
   }
   
   return false;
}

//------------------------------------------------------------------
// Utility: Logs a message (with optional timestamp and error details) and returns false.
//------------------------------------------------------------------
bool LogAndReturn(const string message, const int logLevel, const bool includeTimestamp = true, const bool includeErrorCode = false){
   string logMessage = (StringLen(message) > 0) ? message : "No message provided.";
   
   if (includeTimestamp)   {
      datetime currentTime = TimeCurrent();
      logMessage = StringFormat("[%s] %s", TimeToString(currentTime, TIME_DATE | TIME_MINUTES), logMessage);
   }
   
   Log(logMessage, logLevel);
   
   if (includeErrorCode)   {
      int errorCode = GetLastError();
      if (errorCode != 0)      {
         string errorDetails = StringFormat("Error Code: %d - %s", errorCode, ErrorDescription(errorCode));
         Log(errorDetails, LOG_ERROR);
         ResetLastError();
      }
   }
   
   return false;
}

//------------------------------------------------------------------
// Helper: Validate market conditions
//------------------------------------------------------------------
bool IsMarketConditionValid(){
   // Adjustable thresholds.
   const double maxChoppinessThreshold = 0.005;  // Minimum trend strength.
   const double minVolatilityThreshold   = 0.0001; // Minimum ATR-based volatility.

   // Validate input thresholds.
   if (ATRPeriod <= 0 || minVolatilityThreshold <= 0 || maxChoppinessThreshold <= 0)
      return LogAndReturn("Error: Invalid input parameters.", LOG_ERROR);

   string sym = Symbol();
   double atrValue = NormalizeDouble(cachedATR, 4);
   
   if (atrValue <= 0 || atrValue == DBL_MAX)
      return LogAndReturn("Error: Invalid ATR value (" + DoubleToString(atrValue, 4) + ").", LOG_ERROR);

   // Check if volatility meets threshold.
   if (atrValue < minVolatilityThreshold)
      return LogAndReturn("Trade skipped: Low volatility (ATR below threshold).", LOG_WARNING);

   // Validate market trend strength.
   if (trendStrength < 0 || trendStrength == DBL_MAX)
      return LogAndReturn("Error: Invalid trend strength (" + DoubleToString(trendStrength, 4) + ").", LOG_ERROR);
   
   if (trendStrength < maxChoppinessThreshold)
      return LogAndReturn("Trade skipped: Choppy market (trend strength below threshold).", LOG_WARNING);

   Log("Market conditions are valid. Proceeding with trade.", LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Helper: Check if the trade cooldown period has completed
//------------------------------------------------------------------
bool IsCooldownComplete(){
   static datetime lastWarn = 0;
   
   if (tradeCooldown < 0)   {
      Log(StringFormat("Error: negative tradeCooldown: %.2f", tradeCooldown), LOG_ERROR);
      return false;
   }
   
   // lastTradeTime should normally be maintained globally. Here we use 0 as a placeholder.
   datetime lastTradeTime = 0;
   if (tradeCooldown == 0 || lastTradeTime == 0)   {
      if (ShouldLog(LOG_DEBUG))
         Log("Cooldown bypassed.", LOG_DEBUG);
      return true;
   }
   
   datetime now = TimeCurrent();
   if (now < lastTradeTime)   {
      Log(StringFormat("Error: now (%d) < lastTradeTime (%d)", now, lastTradeTime), LOG_ERROR);
      return false;
   }
   
   double elapsed = now - lastTradeTime;
   if (ShouldLog(LOG_DEBUG))
      Log(StringFormat("Elapsed: %.2f sec / %.2f sec required", elapsed, tradeCooldown), LOG_DEBUG);
   
   if (elapsed < tradeCooldown)   {
      if (lastWarn != lastTradeTime)      {
         Log("Cooldown active.", LOG_WARNING);
         lastWarn = lastTradeTime;
      }
      return false;
   }
   return true;
}

//------------------------------------------------------------------
// Helper: Adjust cooldown dynamically based on volatility and performance
//------------------------------------------------------------------
void AdjustDynamicCooldown(){
   const double minCooldown = 10.0;
   const double maxCooldown = 300.0;
   
   Log("Adjusting dynamic cooldown...");

   // Validate the initial cooldown.
   if (tradeCooldown < 0 || tradeCooldown != tradeCooldown)   {
      tradeCooldown = minCooldown;
      Log("Invalid initial cooldown; reset to minimum.");
   }

   // Adjust based on external factors.
   AdjustCooldownBasedOnVolatility();
   AdjustCooldownBasedOnTradePerformance();

   // Clamp the cooldown within allowed range.
   double original = tradeCooldown;
   tradeCooldown = MathMax(minCooldown, MathMin(tradeCooldown, maxCooldown));
   if (tradeCooldown != original)
      Log(StringFormat("Cooldown clamped from %.2f to %.2f", original, tradeCooldown));

   Log(StringFormat("Final cooldown: %.2f", tradeCooldown));
}

//------------------------------------------------------------------
// Adjust cooldown based on current volatility using ATR values
//------------------------------------------------------------------
void AdjustCooldownBasedOnVolatility(){
   // Constants for volatility-based cooldown adjustments.
   const double HIGH_COOLDOWN     = 600.0;
   const double MODERATE_COOLDOWN = 300.0;
   const double LOW_COOLDOWN      = 180.0;
   const double HIGH_VOL_MULTIPLIER = 2.0;
   const double LOW_VOL_MULTIPLIER  = 0.5;
   const double BASE_ATR_MULTIPLIER = 10.0;

   string symbol = Symbol();
   if (StringLen(symbol) == 0 || ATRPeriod <= 0)
      return;

   double atr = NormalizeDouble(cachedATR, 5);
   double point = NormalizeDouble(MarketInfo(symbol, MODE_POINT), 5);
   if (atr <= 0 || point <= 0)
      return;

   double baseATR = point * BASE_ATR_MULTIPLIER;
   double newCooldown = MODERATE_COOLDOWN; // default to moderate cooldown

   // Determine new cooldown based on volatility.
   if (atr > baseATR * HIGH_VOL_MULTIPLIER)
      newCooldown = HIGH_COOLDOWN;
   else if (atr < baseATR * LOW_VOL_MULTIPLIER)
      newCooldown = LOW_COOLDOWN;

   // Cast to int if necessary.
   SetCooldown((int)newCooldown, StringFormat("Cooldown set to %.0f seconds based on volatility.", newCooldown));
}

//------------------------------------------------------------------
// Helper: Set cooldown and log the event
//------------------------------------------------------------------
void SetCooldown(const int cooldown, const string logMessage){
   if (cooldown < 0)   {
      Log(StringFormat("SetCooldown error: negative cooldown value (%d) received.", cooldown), LOG_ERROR);
      return;
   }
   
   if (tradeCooldown == cooldown)   {
      if (ShouldLog(LOG_DEBUG))
         DebugLog(StringFormat("SetCooldown: No change; cooldown remains %d seconds.", tradeCooldown));
      return;
   }
   
   int previousCooldown = tradeCooldown;
   tradeCooldown = cooldown;
   
   string trimmedMessage = TrimString(logMessage);
   string finalMessage = (StringLen(trimmedMessage) > 0)
      ? StringFormat("%s (Cooldown changed from %d to %d seconds.)", trimmedMessage, previousCooldown, tradeCooldown)
      : StringFormat("Trade cooldown changed from %d to %d seconds.", previousCooldown, tradeCooldown);
      
   Log(finalMessage, LOG_INFO);
   
   if (ShouldLog(LOG_DEBUG))
      DebugLog(StringFormat("Cooldown updated: was %d seconds, now %d seconds.", previousCooldown, tradeCooldown));
}

//------------------------------------------------------------------
// Helper: Trim leading and trailing whitespace (ASCII <= 32) from a string
//------------------------------------------------------------------
string TrimString(const string s) {
   int len = StringLen(s);
   if (len == 0)
      return "";
      
   int start = 0, end = len - 1;
   
   // Advance start index past whitespace.
   while (start < len && s[start] <= ' ')
      start++;
      
   // If string is all whitespace, return empty string.
   if (start == len)
      return "";
      
   // Retreat end index past whitespace.
   while (s[end] <= ' ')
      end--;
      
   return StringSubstr(s, start, end - start + 1);
}

//------------------------------------------------------------------
// Adjust cooldown based on recent trade performance
//------------------------------------------------------------------
void AdjustCooldownBasedOnTradePerformance(){
   // Parameters for trade performance adjustments.
   const int    LossThreshold    = 3;
   const int    MaxCooldown      = 1200;
   const int    MinCooldown      = 180;
   const int    DefaultCooldown  = 300;
   const int    IntervalSeconds  = 60;
   const int    Tolerance        = 5;
   const double HighWinRate      = 0.7;

   static datetime lastAdjustmentTime = 0;
   datetime now = TimeCurrent();
   if (now - lastAdjustmentTime < IntervalSeconds)
      return;

   int stratIndex = (int)currentStrategy;
   if (stratIndex < 0 || stratIndex >= ArraySize(strategyConsecutiveLosses))
      return;

   int losses = strategyConsecutiveLosses[stratIndex];
   double winRate = strategyWinRate[stratIndex];
   if (winRate < 0 || winRate > 1)
      return;

   // Reset tradeCooldown if outside valid range.
   if (tradeCooldown < MinCooldown || tradeCooldown > MaxCooldown)
      tradeCooldown = DefaultCooldown;

   int current = tradeCooldown;
   int newCooldown = current;

   if (losses >= LossThreshold)
      newCooldown = MathMin(current * 2, MaxCooldown);
   else if (winRate > HighWinRate)
      newCooldown = MathMax(current / 2, MinCooldown);
   else if (current != DefaultCooldown)
      newCooldown = (MathAbs(current - DefaultCooldown) < Tolerance) ? DefaultCooldown : (current + DefaultCooldown) / 2;

   if (newCooldown != current)
      tradeCooldown = newCooldown;

   lastAdjustmentTime = now;
}

//------------------------------------------------------------------
// Calculate Dynamic Slippage based on ATR and scaling factor
//------------------------------------------------------------------
int CalculateDynamicSlippage(int atrPeriod, int baseSlippage, int maxSlippage, double scalingFactor, int calcTimeframe) {
   string sym = Symbol();
   // Validate input parameters and available bars
   if (atrPeriod <= 0 || scalingFactor <= 0 || Bars < atrPeriod)
      return baseSlippage;
   
   if (maxSlippage < baseSlippage)
      maxSlippage = baseSlippage;
   
   double atr = cachedATR;
   if (atr <= 0)
      return baseSlippage;
   
   int calculatedSlippage = baseSlippage + (int)MathRound(atr * scalingFactor);
   return MathMax(baseSlippage, MathMin(calculatedSlippage, maxSlippage));
}

//------------------------------------------------------------------
// Updates real-time monitoring dashboard on the chart
//------------------------------------------------------------------
void UpdateDashboard(){
   // Dashboard layout constants
   const int NUM_METRICS      = 5;
   const int X_DISTANCE       = 10;
   const int Y_DISTANCE_BASE  = 20;
   const int Y_DISTANCE_STEP  = 20;
   const int CORNER           = 0;
   const int FONT_SIZE        = 10;
   const color FONT_COLOR     = clrWhite;
   const string BASE_OBJ_NAME = "Dashboard_";

   // Prepare metric strings
   string metrics[5];
   metrics[0] = "Equity: " + DoubleToString(AccountEquity(), 2);
   metrics[1] = "Balance: " + DoubleToString(AccountBalance(), 2);
   metrics[2] = "Free Margin: " + DoubleToString(AccountFreeMargin(), 2);
   metrics[3] = "Drawdown: " + DoubleToString(CalculateDrawdownPercentage(), 2) + "%";
   metrics[4] = "Open Positions: " + IntegerToString(OrdersTotal());

   // Update or create dashboard objects
   for (int i = 0; i < NUM_METRICS; i++)   {
      string objName = BASE_OBJ_NAME + IntegerToString(i);
      if (ObjectFind(0, objName) == -1)
         ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);

      ObjectSetString(0, objName, OBJPROP_TEXT, metrics[i]);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, X_DISTANCE);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, Y_DISTANCE_BASE + i * Y_DISTANCE_STEP);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, FONT_COLOR);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, FONT_SIZE);
   }

   // Remove any excess dashboard objects beyond the defined metrics
   for (int j = NUM_METRICS; ObjectFind(0, BASE_OBJ_NAME + IntegerToString(j)) != -1; j++)
      ObjectDelete(0, BASE_OBJ_NAME + IntegerToString(j));
}

//+------------------------------------------------------------------+
//| Adjust Risk Level                                                |
//+------------------------------------------------------------------+
RiskLevelType AdjustRiskLevel(RiskLevelType baseRisk, double equity, double drawdownPercentage){
   const double HE = 100000.0, ME = 50000.0, LD = 5.0, HD = 10.0, IB = 1e12;
   
   // Validate inputs (check for NaN or extreme values)
   if(equity != equity || drawdownPercentage != drawdownPercentage || equity > IB || drawdownPercentage > IB || equity <= 0)   {
      Log("Warning: Invalid input encountered. Using base risk.", LOG_WARNING);
      return baseRisk;
   }
   if(drawdownPercentage < 0)   {
      Log("Warning: Negative drawdown encountered. Setting drawdown to 0.", LOG_WARNING);
      drawdownPercentage = 0;
   }
   return (equity >= HE && drawdownPercentage <= LD) ? RiskHigh :
          (drawdownPercentage >= HD)              ? RiskLow  :
          (equity >= ME)                          ? RiskMedium : baseRisk;
}

//------------------------------------------------------------------
// Logs the market state and sentiment efficiently
//------------------------------------------------------------------
void LogMarketState(MarketState &marketState, double &marketSentiment) {
    if (marketSentiment != marketSentiment) {  // Check for NaN.
        Log("Warning: marketSentiment is NaN. Defaulting to 0.", LOG_WARNING);
        marketSentiment = 0.0;
    }
    marketSentiment = MathMax(-1.0, MathMin(1.0, marketSentiment));
    
    marketState.isBullish = (marketSentiment > 0);
    marketState.isBearish = (marketSentiment < 0);
    marketState.isNeutral = (marketSentiment == 0);
    
    Log(StringFormat("Market State: Volatile=%d, Bullish=%d, Bearish=%d, Neutral=%d, Sentiment=%.5f",
          marketState.isVolatile, marketState.isBullish, marketState.isBearish, marketState.isNeutral, marketSentiment),
          LOG_DEBUG);
}

//------------------------------------------------------------------
// Function to determine order type (buy/sell) based on signals
//------------------------------------------------------------------
int DetermineOrderType(double fastMA, double slowMA, double rsi) {
    // Validate inputs for NaN, EMPTY_VALUE, and RSI range
    if (fastMA != fastMA || slowMA != slowMA || rsi != rsi ||
        fastMA == EMPTY_VALUE || slowMA == EMPTY_VALUE || rsi == EMPTY_VALUE ||
        rsi < 0 || rsi > 100) {
        return INVALID_ORDER_TYPE;
    }
    
    const double RSI_OVERBOUGHT = 70.0;
    const double RSI_OVERSOLD   = 30.0;
    const double EPSILON_MA     = 0.0001;

    // Avoid orders when moving averages are nearly equal
    if (MathAbs(fastMA - slowMA) < EPSILON_MA)
        return INVALID_ORDER_TYPE;
    
    // Determine order type based on MA crossover and RSI levels
    if (fastMA > slowMA && rsi < RSI_OVERBOUGHT)
        return OP_BUY;
    
    if (fastMA < slowMA && rsi > RSI_OVERSOLD)
        return OP_SELL;
    
    return INVALID_ORDER_TYPE;
}

//------------------------------------------------------------------
// Minimalist risk management: Checks if total risk exposure is within allowed limits.
//------------------------------------------------------------------
bool IsTotalRiskWithinLimits(){
   double maxAllowedRisk = AccountEquity() * MaxDrawdown / 100.0;
   double totalExposure = 0.0;
   
   for (int i = OrdersTotal() - 1; i >= 0; i--)   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
         
      // Only consider orders with the correct magic number and a valid stop loss.
      if (OrderMagicNumber() != MagicNumber || OrderStopLoss() == 0)
         continue;
      
      totalExposure += OrderLots() * MathAbs(OrderOpenPrice() - OrderStopLoss());
      
      if (totalExposure >= maxAllowedRisk)      {
         Log(StringFormat("Risk limit exceeded! Exposure = %.2f, Max Allowed = %.2f", totalExposure, maxAllowedRisk), LOG_WARNING);
         return false;
      }
   }
   
   return true;
}

//------------------------------------------------------------------
// Execute all strategies with risk and equity checks
//------------------------------------------------------------------
bool ExecuteAllStrategies(){
   // If any pre-check fails, exit early.
   if (ManageEquity(0.9, 1.0, 5.0, 60))
      return false;
   if (!PerformRiskChecks())
      return false;
   if (!IsTradeAllowed())
      return false;
      
   int sl = 0, tp = 0;
   DetermineDynamicSLTP(sl, tp);
   double equity = AccountEquity();
   if (sl <= 0 || tp <= 0 || equity <= 0)
      return false;
      
   // Validate lot size based on current equity and risk adjustments.
   double lotSize = ValidateAndAdjustLotSize(equity, AdjustRiskPercentage(equity), sl);
   if (lotSize <= 0)
      return false;
      
   TradingStrategy strategy = SelectAppropriateStrategy(0.5);
   if (!strategy)
      return false;
      
   if (!ExecuteStrategy(strategy, equity, CalculateDrawdownPercentage(), CalculateMarketSentiment()))
      return false;
      
   int ticket = OrderTicket();
   if (ticket <= 0 || !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return false;
      
   return AdjustSLTP(ticket, sl, tp);
}

//------------------------------------------------------------------
// Perform risk checks based on drawdown, orders count, and total risk.
//------------------------------------------------------------------
bool PerformRiskChecks(){
   const double MAX_DRAWDOWN_PERCENT_RISK = 20.0;
   const int    MAX_ORDERS = 10;
   
   double dd = CalculateDrawdownPercentage();
   int orders = OrdersTotal();
   
   // Ensure drawdown is non-negative.
   if (dd < 0)   {
      Log(StringFormat("Negative drawdown (%.2f). Adjusting to 0.", dd), LOG_WARNING);
      dd = 0;
   }
   
   // Check total risk exposure.
   if (!IsTotalRiskWithinLimits())   {
      Log("Risk: Total risk exceeded.", LOG_ERROR);
      return false;
   }
   
   if (dd > MAX_DRAWDOWN_PERCENT_RISK)   {
      Log(StringFormat("Risk: Drawdown (%.2f%%) exceeds %.2f%%.", dd, MAX_DRAWDOWN_PERCENT_RISK), LOG_ERROR);
      return false;
   }
   
   if (orders < 0)   {
      Log(StringFormat("Risk: Negative orders (%d).", orders), LOG_ERROR);
      return false;
   }
   
   if (orders >= MAX_ORDERS)   {
      Log(StringFormat("Risk: Orders (%d) >= %d.", orders, MAX_ORDERS), LOG_ERROR);
      return false;
   }
   
   return true;
}

//------------------------------------------------------------------
// Adjust risk percentage based on current equity drawdown.
//------------------------------------------------------------------
double AdjustRiskPercentage(double equity){
   const double MAX_DRAWDOWN_PERCENT = 10.0;
   if (equity <= 0.0)
      return MIN_RISK;
      
   if (equity > peakEquity)
      peakEquity = equity;
      
   double dd = ((peakEquity - equity) / peakEquity) * 100.0;
   if (dd <= 0.0)
      return MAX_RISK;
   if (dd >= MAX_DRAWDOWN_PERCENT)
      return MIN_RISK;
      
   double risk = MAX_RISK - ((MAX_RISK - MIN_RISK) * (dd / MAX_DRAWDOWN_PERCENT));
   return NormalizeDouble(MathMax(MathMin(risk, MAX_RISK), MIN_RISK), 2);
}

//------------------------------------------------------------------
// Determine dynamic Stop Loss (SL) and Take Profit (TP) values.
//------------------------------------------------------------------
void DetermineDynamicSLTP(int &slPoints, int &tpPoints){
   double sma20 = cachedFastMA;
   double sma50 = cachedSlowMA;
   double atrValue = cachedATR;
   
   const double MinSMAThreshold = 0.0001;
   if (sma20 <= MinSMAThreshold || sma50 <= MinSMAThreshold)   {
      slPoints = tpPoints = 0;
      Log("Error: Invalid SMA values. SL/TP calculation aborted.", LOG_ERROR);
      return;
   }
   
   // Select base SL based on SMA comparison.
   const int TightSL = 50, WideSL = 100, DefaultSL = 70;
   slPoints = (sma20 > sma50) ? TightSL : (sma20 < sma50) ? WideSL : DefaultSL;
   slPoints = MathMax(slPoints, atrValue * ATRMultiplier);
   
   // Adjust SL based on order type.
   double offset = (OrderType() == OP_BUY) ? -slPoints : slPoints;
   slPoints = (OrderType() == OP_BUY) ? Bid + offset : Ask + offset;
   
   // Set TP as a multiple of SL.
   double RiskRewardMultiplier = 1.5;
   tpPoints = slPoints + (slPoints * RiskRewardMultiplier);
   
   Log("SL: " + DoubleToString(slPoints, 4) + ", TP: " + DoubleToString(tpPoints, 4), LOG_DEBUG);
}

//------------------------------------------------------------------
// Validate and adjust the lot size based on risk, margin, and SL points.
//------------------------------------------------------------------
double ValidateAndAdjustLotSize(double equity, double riskPct, int slPts){
   if (equity <= 0 || riskPct <= 0 || slPts <= 0)   {
      Log("Invalid input: equity, riskPct, and slPts must be > 0.", LOG_ERROR);
      return 0.0;
   }
   
   string sym = Symbol();
   double minLot  = MarketInfo(sym, MODE_MINLOT);
   double maxLot  = MarketInfo(sym, MODE_MAXLOT);
   double step    = MarketInfo(sym, MODE_LOTSTEP);
   int digits     = (int)MarketInfo(sym, MODE_DIGITS);
   double mReq    = MarketInfo(sym, MODE_MARGINREQUIRED);
   double pVal    = MarketInfo(sym, MODE_POINT);
   double lev     = AccountLeverage();
   
   if (lev <= 0 || step <= 0)   {
      Log("Invalid leverage or lot step.", LOG_ERROR);
      return 0.0;
   }
   
   double mPerLot = mReq / lev;
   if (mPerLot <= 0)   {
      Log("Non-positive margin per lot.", LOG_ERROR);
      return 0.0;
   }
   
   double riskAmt = equity * riskPct / 100.0;
   double lotSize = riskAmt / (slPts * pVal * mPerLot);
   
   if (lotSize < minLot)   {
      Log(StringFormat("Lot size %.2f < min %.2f.", lotSize, minLot), LOG_WARNING);
      return 0.0;
   }
   if (lotSize > maxLot)   {
      Log(StringFormat("Lot size %.2f > max %.2f; using max.", lotSize, maxLot), LOG_WARNING);
      lotSize = maxLot;
   }
   
   lotSize = NormalizeDouble(MathFloor(lotSize / step) * step, digits);
   
   int cnt = 0;
   while (lotSize >= minLot && AccountFreeMarginCheck(sym, OP_BUY, lotSize) < mPerLot * lotSize)   {
      Log(StringFormat("Margin insufficient for %.2f; reducing.", lotSize), LOG_WARNING);
      lotSize = NormalizeDouble(lotSize - step, digits);
      if (++cnt > 100)      {
         Log("Too many margin adjustments; aborting.", LOG_ERROR);
         return 0.0;
      }
   }
   if (lotSize < minLot)   {
      Log("Adjusted lot size below minimum; aborting.", LOG_ERROR);
      return 0.0;
   }
   
   Log(StringFormat("Final lot size: %.2f", lotSize), LOG_INFO);
   return lotSize;
}

//------------------------------------------------------------------
// Select an appropriate trading strategy based on win rate and volatility.
//------------------------------------------------------------------
TradingStrategy SelectAppropriateStrategy(double lowWinRateThreshold){
   // Ensure the win rate threshold is valid.
   if (lowWinRateThreshold < 0.0 || lowWinRateThreshold > 1.0)
      lowWinRateThreshold = 0.5;
      
   if (ArraySize(strategyWinRate) <= 0)
      return SelectFallbackStrategy();
      
   int idx = (int)currentStrategy;
   if (idx < 0 || idx >= ArraySize(strategyWinRate))
      return SelectFallbackStrategy();
      
   double winRate = strategyWinRate[idx];
   if (winRate != winRate || winRate < 0.0 || winRate > 1.0)
      return SelectFallbackStrategy();
      
   // Return fallback if win rate is below threshold or market is not volatile.
   return (winRate < lowWinRateThreshold || !IsMarketVolatile())
            ? SelectFallbackStrategy() : SelectBestStrategy();
}

//------------------------------------------------------------------
// Select fallback strategy if the primary one is not acceptable.
//------------------------------------------------------------------
TradingStrategy SelectFallbackStrategy(){
   if (!ValidateFallbackStrategy(fallbackStrategy))   {
      Log(StringFormat("Invalid fallback strategy (%s). Defaulting to TrendFollowing.", EnumToString(fallbackStrategy)), LOG_ERROR);
      fallbackStrategy = TrendFollowing;  // Ensure fallback is valid.
   }
   Log(StringFormat("Fallback strategy selected: %s.", EnumToString(fallbackStrategy)), LOG_INFO);
   return fallbackStrategy;
}

//------------------------------------------------------------------
// Validate the fallback strategy.
//------------------------------------------------------------------
inline bool ValidateFallbackStrategy(const TradingStrategy strategy){
    if(strategy != CounterTrend && strategy != RangeBound && strategy != Scalping)    {
        #ifdef _DEBUG
            assert(false && "Invalid fallback strategy specified");
        #endif
        Print("Warning: Invalid fallback strategy specified: ", TradingStrategyToString(strategy));
        return false;
    }
    return true;
}

//------------------------------------------------------------------
// Converts a TradingStrategy enum to a string
//------------------------------------------------------------------
inline string TradingStrategyToString(const TradingStrategy strategy){
    switch(strategy)    {
        case CounterTrend: return "CounterTrend";
        case RangeBound:   return "RangeBound";
        case Scalping:     return "Scalping";
        default:          return "Unknown";
    }
}

//------------------------------------------------------------------
// Handle Existing Orders (with pyramiding/scaling)
//------------------------------------------------------------------
OrderStatus HandleExistingOrders(double marginThreshold = 100.0, bool enablePyramiding = true, bool enableScalingOut = true, double scaleOutFactor = 0.1, int maxPyramidingOrders = 5){
   // Validate parameters early
   if(marginThreshold <= 0 || scaleOutFactor <= 0 || scaleOutFactor > 0.99 || maxPyramidingOrders <= 0)   {
      Log("Error: Invalid parameters.", LOG_WARNING);
      return STATUS_INVALID_PARAMETER;
   }

   double freeMargin = AccountFreeMargin();
   double equity     = AccountEquity();
   double balance    = AccountBalance();

   // Check margin/equity condition
   if(equity < (balance - GetDynamicEquityStopThreshold()) || freeMargin < marginThreshold)   {
      Log("Warning: Low margin/equity detected. Attempting to close high-risk orders.", LOG_WARNING);
      if(CloseHighRiskOrders(100.0))
         return STATUS_CLOSED_ALL;
      Log("Error: Failed to close high-risk orders.", LOG_ERROR);
      return STATUS_CRITICAL_ERROR;
   }

   int totalOrders = OrdersTotal();
   if(totalOrders == 0) return STATUS_OK;

   // Process each order in reverse order
   for(int i = totalOrders - 1; i >= 0; i--)   {
      if(!OrderSelect(i, SELECT_BY_POS))
         continue;

      int ticket   = OrderTicket();
      string comm  = OrderComment();

      // Apply pyramiding if enabled, the position is profitable and not yet pyramided
      if(enablePyramiding && IsPositionSignificantlyProfitable(ticket) && StringFind(comm, "Pyramided") == -1)      {
         if(PerformPyramidingForOrders() && OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), 0))         {
            Log("Success: Pyramiding applied to order #" + IntegerToString(ticket), LOG_INFO);
            return STATUS_OK;
         }
      }

      // Apply scaling out if enabled and the position is in significant loss
      if(enableScalingOut && IsPositionSignificantlyInLoss(ticket))      {
         if(MonitorAndScaleOutTrades())         {
            Log("Success: Scaling out applied to order #" + IntegerToString(ticket), LOG_INFO);
            return STATUS_OK;
         }
      }
   }
   return STATUS_OK;
}

//------------------------------------------------------------------
// Close high-risk orders if margin is low
//------------------------------------------------------------------
bool CloseHighRiskOrders(double marginThreshold, int slippage = 3){
   #define HIGH_RISK_MAGIC 123456  // Define your high-risk order magic number
   RefreshRates();
   if(AccountFreeMargin() > marginThreshold)
      return true;

   bool allClosed = true;
   int totalOrders = OrdersTotal();
   // Iterate while margin is low
   for(int i = totalOrders - 1; i >= 0 && AccountFreeMargin() <= marginThreshold; i--)   {
      if(IsStopped() || !OrderSelect(i, SELECT_BY_POS, MODE_TRADES) || OrderMagicNumber() != HIGH_RISK_MAGIC)
         continue;
      
      bool op = false;
      int type = OrderType();
      // Close market orders
      if(type == OP_BUY || type == OP_SELL)      {
         double price = MarketInfo(OrderSymbol(), (type == OP_BUY ? MODE_BID : MODE_ASK));
         if(price > 0)
            op = OrderClose(OrderTicket(), OrderLots(), price, slippage, clrRed);
      }
      // Delete pending orders
      #ifndef OP_BUY_LIMIT
      #define OP_BUY_LIMIT 2
      #endif
      #ifndef OP_SELL_LIMIT
      #define OP_SELL_LIMIT 3
      #endif
      #ifndef OP_BUY_STOP
      #define OP_BUY_STOP 4
      #endif
      #ifndef OP_SELL_STOP
      #define OP_SELL_STOP 5
      #endif
      else if(type == OP_BUY_LIMIT || type == OP_SELL_LIMIT || type == OP_BUY_STOP  || type == OP_SELL_STOP)
         op = OrderDelete(OrderTicket());

      if(!op)
         allClosed = false;
   }
   return allClosed;
}

//------------------------------------------------------------------
// Helper to perform pyramiding for all matching orders
//------------------------------------------------------------------
bool PerformPyramidingForOrders(){
   int count = 0;
   int totalOrders = OrdersTotal();
   for (int i = totalOrders - 1; i >= 0; i--)   {
      if (!OrderSelect(i, SELECT_BY_POS))
         continue;

      // Only process orders with the correct magic number, valid order type and eligible for pyramiding.
      if (OrderMagicNumber() != MagicNumber || (OrderType() != OP_BUY && OrderType() != OP_SELL) || !IsEligibleForPyramiding())
         continue;
      
      string sym      = OrderSymbol();
      double marginReq = MarketInfo(sym, MODE_MARGINREQUIRED);
      double lots      = OrderLots();
      if (marginReq <= 0 || lots <= 0)
         continue;
      
      double requiredMargin = marginReq * lots;
      if (!CanPyramid(OrderTicket()))      {
         Print(StringFormat("Order #%d: insufficient margin (Req: %.2f, Free: %.2f)", 
               OrderTicket(), requiredMargin, AccountFreeMargin()));
         continue;
      }
      
      int ticket = OrderTicket();
      if (PerformPyramiding(ticket))      {
         count++;
         Print(StringFormat("Order #%d pyramided (Profit: %.2f, Lots: %.2f)", 
               ticket, OrderProfit(), lots));
      }
      else
         Print(StringFormat("Order #%d pyramiding failed. Error: %d", ticket, GetLastError()));
   }
   Print(count ? StringFormat("Pyramiding performed on %d orders.", count) : "No orders eligible for pyramiding.");
   return (count > 0);
}

//------------------------------------------------------------------
// Check if current order is eligible for pyramiding
//------------------------------------------------------------------
bool IsEligibleForPyramiding(){
   // Define minimum thresholds
   #define MIN_PROFIT_FOR_PYRAMIDING 500.0
   #define MIN_TIME_FOR_PYRAMIDING   60

   // Validate profit, order duration, and order type range
   if (OrderProfit() < MIN_PROFIT_FOR_PYRAMIDING || (TimeCurrent() - OrderOpenTime()) < MIN_TIME_FOR_PYRAMIDING ||
       OrderType() < OP_BUY || OrderType() > OP_SELLSTOP)
      return false;
   
   // Exclude current order when summing total lot size from matching orders
   double currentLots = OrderLots();
   double totalLotSize = 0;
   int totalOrders = OrdersTotal();
   int currentTicket = OrderTicket();
   
   for (int i = 0; i < totalOrders; i++)   {
      if (OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderTicket() != currentTicket)      {
         totalLotSize += OrderLots();
         if (totalLotSize > MaxAllowedLotSize)
            return false;  // Exceeds allowed limit, exit early
      }
   }
   
   double marginPerLot = MarketInfo(OrderSymbol(), MODE_MARGINREQUIRED);
   if (marginPerLot <= 0 || (totalLotSize + currentLots) > MaxAllowedLotSize ||
       AccountFreeMargin() < (totalLotSize + currentLots) * marginPerLot)
      return false;
   
   return true;
}

//------------------------------------------------------------------
// Check if pyramiding is allowed for a given order (by ticket)
//------------------------------------------------------------------
bool CanPyramid(int orderTicket){
   const double RiskLimitPercent = 20.0; // Maximum percentage of account balance allowed for margin usage

   if (MinMarginLevel < 0 || RiskLimitPercent < 0 || RiskLimitPercent > 100)
      return false;
   if (!OrderSelect(orderTicket, SELECT_BY_TICKET))
      return false;

   int type = OrderType();
   if (type != OP_BUY && type != OP_SELL)
      return false;

   // Check expiration if applicable
   if (OrderExpiration() > 0 && OrderExpiration() < TimeCurrent())
      return false;

   string symbol = OrderSymbol();
   double lots   = OrderLots();
   if (symbol == "" || lots <= 0)
      return false;

   double marginPerLot = MarketInfo(symbol, MODE_MARGINREQUIRED);
   if (marginPerLot <= 0)
      return false;
   double marginRequired = marginPerLot * lots;

   double freeMargin = AccountFreeMargin();
   double marginLevel = AccountMarginLevel();
   double balance     = AccountBalance();
   if (balance < 0 || freeMargin < 0 || marginLevel < 0)
      return false;

   double maxMargin = balance * (RiskLimitPercent / 100.0);
   return (marginRequired <= maxMargin && marginLevel >= MinMarginLevel && freeMargin >= marginRequired);
}

//------------------------------------------------------------------
// Function to close an order with retries and exponential backoff
//------------------------------------------------------------------
bool CloseOrderWithRetries(const int ticket) {
    if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
        Log(StringFormat("Invalid order: #%d", ticket), LOG_ERROR);
        return false;
    }
    
    const int maxRetries = 3;
    int delay = 1000; // Initial delay in milliseconds (1 second)
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
        ResetLastError();
        if (CloseOrder(ticket, "Low equity or margin")) {
            Log(StringFormat("Order #%d closed successfully.", ticket), LOG_INFO);
            return true;
        }
        
        const int error = GetLastError();
        // Abort on critical errors
        if (error == 133 || error == 134 || error == 4109) {
            Log("Critical error encountered. Aborting.", LOG_ERROR);
            return false;
        }
        
        Log(StringFormat("Retry #%d for order #%d failed. Error: %s", attempt + 1, ticket, ErrorDescription(error)), LOG_WARNING);
        Sleep(delay);
        delay *= 2; // Exponential backoff
    }
    
    Log(StringFormat("Order #%d failed to close after %d attempts.", ticket, maxRetries), LOG_ERROR);
    return false;
}

//------------------------------------------------------------------
// Perform Pyramiding if conditions are met for the given initial ticket
//------------------------------------------------------------------
bool PerformPyramiding(int initialTicket){
   // Exit early if any prerequisite condition fails.
   if (!EnablePyramiding ||
       !OrderSelect(initialTicket, SELECT_BY_TICKET) ||
       OrderCloseTime() != 0 ||
       OrderMagicNumber() != MagicNumber ||
       OrderSymbol() != Symbol() ||
       CountPyramidOrders(MagicNumber) >= MaxPyramidLevels ||
       (CalculateDrawdownPercentage() * 100) > GetDynamicMaxDrawdownPercentage() ||
       AccountEquity() < GetDynamicEquityStopThreshold() ||
       OrderProfit() <= MathMax(MinPyramidProfitThreshold, 0.0))
      return false;

   double lotSize = CalculateLotSizeForPyramiding();
   if (lotSize <= 0 || AccountFreeMargin() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * lotSize)
      return false;

   LoggingConfig logCfg = { true, 60, 0 };
   ValidationResult validationRes;
   if (!IsValidOrderType(OrderType(), logCfg, TimeCurrent(), Symbol(), validationRes))
      return false;

   int newTicket = ExecuteTrade(OrderType(), "Pyramid", false);
   if (newTicket <= 0)
      return false;

   // Adjust SL/TP; if adjustment fails, close the new trade.
   if (!AdjustSLTP(newTicket))   {
      CloseTrade(newTicket);
      return false;
   }
   return true;
}

//------------------------------------------------------------------
// Close a trade (by ticket) if conditions are met.
//------------------------------------------------------------------
bool CloseTrade(int ticket){
    if (!OrderSelect(ticket, SELECT_BY_TICKET) || OrderMagicNumber() != MagicNumber)
        return false;
    if (OrderCloseTime() != 0)
        return true;

    double lotSize = OrderLots();
    if (lotSize <= 0)
        return false;

    RefreshRates();
    int orderType = OrderType();
    double closePrice = (orderType == OP_BUY) ? Bid : (orderType == OP_SELL ? Ask : -1);
    if (closePrice == -1)
        return false;

    for (int attempt = 0; attempt < 3; attempt++)    {
        if (OrderClose(ticket, lotSize, closePrice, 3, clrRed))
            return true;
        if (GetLastError() != 138)
            break;
        Sleep(100);
    }
    return false;
}

//------------------------------------------------------------------
// Helper function to count pyramid orders matching criteria
//------------------------------------------------------------------
int CountPyramidOrders(int magicNumber, string pyramidIdentifier = "Pyramid", string symbolFilter = ""){
    if (pyramidIdentifier == "")
        return 0; // Avoid false matches

    if (StringLen(symbolFilter) == 0)
        symbolFilter = Symbol();

    int pyramidCount = 0;
    int totalOrders = OrdersTotal();
    for (int i = 0; i < totalOrders; i++)    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
        if (OrderSymbol() != symbolFilter || OrderMagicNumber() != magicNumber ||
            StringFind(OrderComment(), pyramidIdentifier) < 0)
            continue;
        pyramidCount++;
    }
    return pyramidCount;
}

//------------------------------------------------------------------
// Calculates recovery progress using global variables: peakEquity and exitRecoveryThreshold.
//------------------------------------------------------------------
double CalculateRecoveryProgress(){
    // Validate global parameters.
    if (peakEquity <= 0 || exitRecoveryThreshold <= 0 || exitRecoveryThreshold >= 1)    {
        Log(StringConcatenate("[ERROR] Invalid parameters for recovery progress calculation: peakEquity=",
            DoubleToStr(peakEquity, 2), ", exitRecoveryThreshold=", DoubleToStr(exitRecoveryThreshold, 4)), LOG_ERROR);
        return 0.0;
    }
    
    double currentEquity = AccountEquity();
    double peakThreshold = peakEquity * exitRecoveryThreshold;
    double recoveryRange = peakEquity * (1.0 - exitRecoveryThreshold);
    
    // Guard against an extremely small recovery range.
    if (MathAbs(recoveryRange) < EPSILON)    {
        Log(StringConcatenate("[ERROR] Recovery range too small: ", DoubleToStr(recoveryRange, 10)), LOG_ERROR);
        return 0.0;
    }
    
    double progress = (currentEquity - peakThreshold) / recoveryRange;
    return MathMax(0.0, MathMin(progress, 1.0));
}

//------------------------------------------------------------------
// Helper function to calculate lot size for pyramiding.
//------------------------------------------------------------------
double CalculateLotSizeForPyramiding(){
    // Cache the current symbol.
    string sym = Symbol();

    // Calculate recovery progress (clamped between 0 and 1).
    double recoveryProgress = MathMax(0.0, MathMin(CalculateRecoveryProgress(), 1.0));
    double baseLotSize = OrderLots() * 0.5 * (0.25 + 0.75 * recoveryProgress);

    double minLot  = MathMax(MarketInfo(sym, MODE_MINLOT), 0.01);
    double maxLot  = MarketInfo(sym, MODE_MAXLOT);
    double lotStep = MathMax(MarketInfo(sym, MODE_LOTSTEP), minLot / 10);

    // Ensure that maximum lot is not below the minimum.
    if (maxLot < minLot)
       return 0.0;

    // Clamp base lot size between minLot and maxLot.
    double clampedLot = MathMax(minLot, MathMin(baseLotSize, maxLot));
    // Round the lot size to the nearest valid step.
    double lotSize = MathRound(clampedLot / lotStep) * lotStep;
    return NormalizeDouble(lotSize, 2);
}

//------------------------------------------------------------------
// Perform scaling out based on the dynamic scale-out percentage
//------------------------------------------------------------------
bool PerformScalingOut(double scaleOutPercentage){
   // Validate scale-out conditions.
   if (scaleOutPercentage <= 0 || scaleOutPercentage > 1.0 ||
       CalculateDrawdownPercentage() < 5.0 ||
       AccountEquity() < GetDynamicEquityStopThreshold())
      return false;
      
   string sym = Symbol();
   double lotStep = MarketInfo(sym, MODE_LOTSTEP);
   double minLot  = MarketInfo(sym, MODE_MINLOT);
   if (lotStep <= 0 || minLot <= 0)
      return false;
      
   // Determine the number of decimals for rounding lot sizes.
   int lotDecimals = 0;
   for (double tmp = lotStep; tmp < 1.0; tmp *= 10.0)
      lotDecimals++;
      
   bool anySuccess = false;
   int totalOrders = OrdersTotal();
   for (int i = totalOrders - 1; i >= 0; i--)   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
         
      // Process only orders matching the current symbol, magic number, and valid order types.
      if (OrderSymbol() != sym || OrderMagicNumber() != MagicNumber ||
          (OrderType() != OP_BUY && OrderType() != OP_SELL))
         continue;
         
      int ticket = OrderTicket();
      double currentLots = OrderLots();
      double scaleOutLots = NormalizeDouble(currentLots * scaleOutPercentage, lotDecimals);
      
      // Skip if the scaled lot is too small; if nearly the full order is being closed, use full size.
      if (scaleOutLots < minLot)
         continue;
      if (currentLots - scaleOutLots < minLot)
         scaleOutLots = currentLots;
         
      RefreshRates();
      double price = (OrderType() == OP_BUY) ? Bid : Ask;
      if (OrderClose(ticket, scaleOutLots, price, Slippage, clrRed))      {
         // For partial closes, attempt to modify the remaining order.
         if (scaleOutLots < currentLots)         {
            if (!OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), 0, clrRed))            {
               Log(StringFormat("OrderModify failed for ticket #%d. Error: %d", ticket, GetLastError()), LOG_ERROR);
            }
         }
         anySuccess = true;
      }
   }
   return anySuccess;
}

//------------------------------------------------------------------
// Monitor and scale out trades
//------------------------------------------------------------------
bool MonitorAndScaleOutTrades(){
   static bool isScalingOutInProgress = false;
   // Exit early if scaling out is disabled, already in progress, or no orders exist.
   if (!EnableScalingOut || isScalingOutInProgress || OrdersTotal() == 0)   {
      Log("Scaling out not executed: disabled, in progress, or no orders.", LOG_INFO);
      return false;
   }
   
   isScalingOutInProgress = true;
   bool success = false;
   double scalePct = CalculateDynamicScaleOutPercentage();
   
   // Ensure scalePct is valid.
   if (!IsNaN(scalePct) && scalePct > 0 && scalePct <= 1.0)   {
      Log(StringFormat("Scale-out percentage: %.2f%%", scalePct * 100), LOG_DEBUG);
      success = PerformScalingOut(scalePct);
      Log(success ? "Scaling out successful." : StringFormat("Scaling out failed. Error: %d", GetLastError()),
          success ? LOG_INFO : LOG_ERROR);
   }
   else   {
      Log(StringFormat("Invalid scale-out percentage: %.2f%%", scalePct * 100), LOG_WARNING);
   }
   
   isScalingOutInProgress = false;
   return success;
}

//------------------------------------------------------------------
// Check if a position is significantly in loss
//------------------------------------------------------------------
bool IsPositionSignificantlyInLoss(int ticket, double customMultiplier = 2.0, double maxLossPercentage = 10.0){
   if(maxLossPercentage <= 0 || maxLossPercentage > 100)
      return false;
   if(!OrderSelect(ticket, SELECT_BY_TICKET) || OrderCloseTime() > 0)
      return false;

   double tickValue = MarketInfo(OrderSymbol(), MODE_TICKVALUE);
   if(tickValue == 0)
      tickValue = MarketInfo(OrderSymbol(), MODE_POINT);

   double marginRequired = AccountFreeMarginCheck(OrderSymbol(), OrderType(), OrderLots());
   if(marginRequired == 0)
      marginRequired = MarketInfo(OrderSymbol(), MODE_MARGINREQUIRED);

   double loss = fabs((OrderOpenPrice() - ((OrderType() == OP_BUY) ? Ask : Bid)) * tickValue * OrderLots())
                 + OrderCommission() + OrderSwap();

   return (loss >= customMultiplier * OrderLots() * tickValue || loss >= (maxLossPercentage / 100.0) * marginRequired);
}

//------------------------------------------------------------------
// Calculate the dynamic scaling-out percentage based on multiple market conditions
//------------------------------------------------------------------
double CalculateDynamicScaleOutPercentage() {
   const string sym   = Symbol();
   const int period   = Period();
   const double price = Close[0];

   double atr = cachedATR;
   atr = (atr <= 0.0001) ? price * 0.0001 : atr;
   
   const double volAdj   = (atr > 0.0010) ? 0.2 : -0.2;
   const double ma       = cachedFastMA;
   const double trendAdj = (price > ma) ? 0.8 : 1.2;
   double rsi      = cachedRSI;
   const double rsiAdj   = (rsi > 70) ? 0.6 : ((rsi < 30) ? 1.4 : 1.0);
   
   return Clamp(0.5 + 0.5 * volAdj + 0.3 * trendAdj + 0.2 * rsiAdj, 0.1, 1.0);
}

//------------------------------------------------------------------
// Closes an order with a given reason and retry loop
//------------------------------------------------------------------
bool CloseOrder(int ticket, string reason = "", int customSlippage = -1){
    const int maxAttempts = 3;
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++)    {
        if (!OrderSelect(ticket, SELECT_BY_TICKET))        {
            Log(StringFormat("Order #%d not found. Assuming already closed.", ticket), LOG_INFO);
            return true;
        }
        
        double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
        int slippage = (customSlippage == -1) ? Slippage : customSlippage;
        
        if (OrderClose(ticket, OrderLots(), closePrice, slippage, clrRed))        {
            Log(StringFormat("Order #%d closed. Reason: %s", ticket, reason), LOG_INFO);
            return true;
        }
        
        RefreshRates();
        Sleep(2000);
    }
    
    Log(StringFormat("Failed to close order #%d after %d attempts.", ticket, maxAttempts), LOG_ERROR);
    return false;
}

//------------------------------------------------------------------
// Helper to close all matching orders and cancel pending orders
//------------------------------------------------------------------
bool CloseAllOrders() {
   if (!IsTradeAllowed()) {
      Log("Trading not allowed.", LOG_WARNING);
      return false;
   }

   const int total = OrdersTotal();
   if (total == 0) {
      Log("No orders to close.", LOG_INFO);
      return false;
   }

   const string sym = Symbol();
   int closedCount = 0;

   for (int i = total - 1; i >= 0; i--) {
      ResetLastError();
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES) || OrderMagicNumber() != MagicNumber || OrderSymbol() != sym)
         continue;

      const int ticket = OrderTicket();
      const int orderType = OrderType();
      bool success = false;
      
      if (orderType == OP_BUY || orderType == OP_SELL)
         success = CloseOrderWithRetries(ticket);
      else if (orderType == OP_BUYLIMIT || orderType == OP_SELLLIMIT ||
               orderType == OP_BUYSTOP  || orderType == OP_SELLSTOP)
         success = DeleteOrderWithRetries(ticket);

      if (success)
         closedCount++;
   }

   Log(StringFormat(closedCount ? "Closed/canceled %d orders." : "No orders closed.", closedCount),
       closedCount ? LOG_INFO : LOG_WARNING);
   return (closedCount > 0);
}

//------------------------------------------------------------------
// Helper function to delete a pending order with retries
//------------------------------------------------------------------
bool DeleteOrderWithRetries(const int ticket) {
    const int maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
        ResetLastError();
        if (OrderDelete(ticket)) {
            Log(StringFormat("Order %d deleted successfully.", ticket), LOG_INFO);
            return true;
        }
        Sleep((attempt + 1) * 100); // Simple backoff: 100ms, 200ms, 300ms
    }
    
    const int error = GetLastError();
    Log(StringFormat("Failed to delete order %d after %d attempts. Error %d: %s", ticket, maxRetries, error, ErrorDescription(error)), LOG_WARNING);
    return false;
}

//------------------------------------------------------------------
// Enhanced debug logging with timestamp and trimming.
//------------------------------------------------------------------
void DebugLog(const string message) {
   if (!ShouldLog(LOG_DEBUG))
      return;
      
   string trimmed = TrimString(message);
   if (StringLen(trimmed) == 0)
      return;
      
   string fullMsg = StringFormat("[%s] DEBUG: %s", TimeToString(TimeCurrent(), TIME_SECONDS), trimmed);
   Log(fullMsg, LOG_DEBUG);
}

//+------------------------------------------------------------------+
//| Logging Trade Execution Events                                   |
//+------------------------------------------------------------------+
void LogTradeExecution(int orderTicket, double lotSize, string strategyTag) {
   if (!OrderSelect(orderTicket, SELECT_BY_TICKET)) {
      Log(StringFormat("[ERROR] Trade log failed. Order #%d not found.", orderTicket), LOG_ERROR);
      return;
   }
   
   string symbol  = OrderSymbol();
   int digits     = MarketInfo(symbol, MODE_DIGITS);
   if (digits < 0) digits = 5;
   
   // Use current order selection for type, open time, etc.
   string orderType = GetOrderTypeString();   
   string openTime  = (OrderOpenTime() > 0) ? TimeToString(OrderOpenTime(), TIME_SECONDS) : "PENDING";
   string expiration = ((OrderType() >= OP_BUYLIMIT && OrderType() <= OP_SELLSTOP) && OrderExpiration() > 0)
                       ? TimeToString(OrderExpiration(), TIME_SECONDS) : "N/A";
   string stopLoss  = (OrderStopLoss() > 0) ? DoubleToString(OrderStopLoss(), digits) : "NONE";
   string takeProfit= (OrderTakeProfit() > 0) ? DoubleToString(OrderTakeProfit(), digits) : "NONE";
   string magic     = (OrderMagicNumber() > 0) ? IntegerToString(OrderMagicNumber()) : "NONE";
   
   // Trim and fallback for empty comment/strategy tag
   string comment = StringTrim(OrderComment());
   comment = (StringLen(comment) > 0) ? comment : "NONE";
   string strat   = StringTrim(strategyTag);
   strat = (StringLen(strat) > 0) ? strat : "N/A";
   
   Log(StringFormat(
      "[INFO] Trade Executed: Ticket=%d | Symbol=%s | Type=%s | Lots=%.2f | OpenPrice=%.*f | OpenTime=%s | Expiration=%s | SL=%s | TP=%s | Magic=%s | Comment=%s | Strategy=%s",
      orderTicket,
      symbol,
      orderType,
      OrderLots(),
      digits, OrderOpenPrice(),
      openTime,
      expiration,
      stopLoss,
      takeProfit,
      magic,
      comment,
      strat
   ), LOG_INFO);
}

//+------------------------------------------------------------------+
//| Helper: Get string representation for current order type         |
//+------------------------------------------------------------------+
string GetOrderTypeString(int orderPos = 0) {
   if (!OrderSelect(orderPos, SELECT_BY_POS, MODE_TRADES))
      return "ERROR: " + IntegerToString(GetLastError());
   
   switch(OrderType()) {
      case OP_BUY:       return "BUY";
      case OP_SELL:      return "SELL";
      case OP_BUYLIMIT:  return "BUY LIMIT";
      case OP_SELLLIMIT: return "SELL LIMIT";
      case OP_BUYSTOP:   return "BUY STOP";
      case OP_SELLSTOP:  return "SELL STOP";
      default:           return "ERROR: Unknown Order Type";
   }
}

//------------------------------------------------------------------
// Logs when a critical risk threshold is breached
//------------------------------------------------------------------
void LogRiskBreach(string reason, double value) {
   if (!ShouldLog(LOG_WARNING))
      return;
   
   double balance = AccountBalance();
   double equity  = AccountEquity();
   double drawdown = (balance > 0.0) ? (balance - equity) / balance * 100.0 : 0.0;
   drawdown = MathMax(-100.0, MathMin(100.0, drawdown));
   
   Log(StringFormat("Risk threshold breached: %s | Value=%.2f | Equity=%.2f | Balance=%.2f | Drawdown=%.2f%% | Account: %s",
         reason, value, equity, balance, drawdown, AccountNumber()), LOG_WARNING);
}

//------------------------------------------------------------------
// Logs key performance metrics for each strategy.
//------------------------------------------------------------------
void LogPerformanceMetrics() {
    if (!ShouldLog(LOG_INFO))
        return;

    int count = ArraySize(tradePerformance);
    if (count == 0) {
        Log("No trade performance data available.", LOG_INFO);
        return;
    }
    
    for (int i = 0; i < count; i++) {
        if (tradePerformance[i].tradeCount <= 0)
            continue;
        double grossProfit  = tradePerformance[i].grossProfit;
        double grossLoss    = MathAbs(tradePerformance[i].grossLoss);
        double sharpeRatio  = tradePerformance[i].sharpeRatio;
        double maxDrawdown  = tradePerformance[i].maxDrawdown;
        double profitFactor = (grossLoss > EPSILON) ? grossProfit / grossLoss : (grossProfit > 0 ? DBL_MAX : 0);
        
        Log(StringFormat("Strategy %d | Trades: %d | PF: %.2f | Sharpe: %.2f | Max DD: %.2f%%", 
              i, tradePerformance[i].tradeCount, profitFactor, sharpeRatio, maxDrawdown), LOG_INFO);
    }
}

//------------------------------------------------------------------
// Toggle verbose logging mode with persistent state
//------------------------------------------------------------------
void ToggleVerboseLogging(bool enable) {
    static bool IsVerboseLogging = false;
    if(IsVerboseLogging == enable)
        return;
    IsVerboseLogging = enable;
    if(ShouldLog(LOG_INFO))
        Log(StringFormat("Verbose logging %s", enable ? "enabled" : "disabled"), LOG_INFO);
}

//+------------------------------------------------------------------+
//| Finds an element in an integer array                             |
//+------------------------------------------------------------------+
int ArrayFind(int &array[], int value){
   int size = ArraySize(array);
   for(int i = 0; i < size; i++)   {
      if(array[i] == value)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Finds an element in a string array                               |
//+------------------------------------------------------------------+
int ArrayFind(string &array[], string value){
   int size = ArraySize(array);
   for(int i = 0; i < size; i++)   {
      // Use StringCompare for equality (0 indicates equal strings)
      if(StringCompare(array[i], value) == 0)
         return i;
   }
   return -1;
}

//------------------------------------------------------------------
// Determines if a message at a given numeric log level should be logged.
//------------------------------------------------------------------
bool ShouldLog(const int logLevel) {
   return (currentLogLevel >= logLevel);
}

//------------------------------------------------------------------
// Calculates win rates from trade history or per-strategy performance
//------------------------------------------------------------------
bool CalculateWinRates(bool forAllTrades = true) {
   const double eps = 1e-6;
   
   if (forAllTrades) {
      int totalTrades = ArraySize(tradeHistory);
      if (totalTrades == 0)
         return false;
      
      int wins = 0;
      for (int i = 0; i < totalTrades; i++)
         wins += (tradeHistory[i].profit > 0) ? 1 : 0;
      
      double overallRate = (wins / double(totalTrades)) * 100.0;
      overallRate = MathMax(0.0, MathMin(overallRate, 100.0));
      Log(StringFormat("Overall win rate: %.2f%%", overallRate), LOG_INFO);
      return true;
   }
   else {
      int cnt = ArraySize(tradePerformance);
      if (cnt == 0 || ArraySize(strategyWinRate) != cnt)
         return false;
      
      for (int j = 0; j < cnt; j++) {
         double gp = tradePerformance[j].grossProfit;
         double gl = MathAbs(tradePerformance[j].grossLoss);
         double tot = gp + gl;
         double stratRate = (tradePerformance[j].tradeCount > 0 && tot > eps) ? (gp / tot) * 100.0 : 0.0;
         stratRate = MathMax(0.0, MathMin(stratRate, 100.0));
         strategyWinRate[j] = stratRate;
         tradePerformance[j].winRate = stratRate;
         Log(StringFormat("Strategy %d win rate: %.2f%%", j, stratRate), LOG_INFO);
      }
      return true;
   }
}

//------------------------------------------------------------------
// Utility: Clamp a value between min and max values
//------------------------------------------------------------------
double MathClamp(double value, double minValue, double maxValue){
   if(minValue > maxValue)
      return value;
   return MathMax(minValue, MathMin(value, maxValue));
}

//+------------------------------------------------------------------+
//| Optimize Strategy Parameters Using Machine Learning              |
//+------------------------------------------------------------------+
bool OptimizeStrategyParametersUsingML() {
   double volatility = CalculateMultiTimeframeATR();
   const double MIN_VOL_THRESHOLD = 0.0015;
   
   // Validate volatility and strategy parameters.
   if (volatility <= MIN_VOL_THRESHOLD || currentStrategy < 0 ||
       currentStrategy >= ArraySize(strategyWinRate) || strategyWinRate[(int)currentStrategy] <= 0.1)   {
      Log("Skipping optimization: Low volatility or invalid strategy.", LOG_WARNING);
      return false;
   }
   
   double currentWinRate = strategyWinRate[(int)currentStrategy];
   // Use unique local names to avoid conflict with global macros.
   const double LOCAL_MIN_RISK = 0.01, LOCAL_MAX_RISK = 0.05, LOCAL_DRAWDOWN_FACTOR = 0.5;
   double drawdown = CalculateDrawdown();
   
   // Calculate risk level based on win rate and drawdown.
   double riskCandidate = LOCAL_MIN_RISK + currentWinRate * (LOCAL_MAX_RISK - LOCAL_MIN_RISK);
   double calculatedRisk = MathMin(riskCandidate, MathMin(LOCAL_MAX_RISK, drawdown * LOCAL_DRAWDOWN_FACTOR));
   
   // Set optimized stop loss and take profit based on volatility.
   SL = MathMax((1.2 + (volatility > 0.02 ? 0.2 : 0)) * volatility, BaseSL);
   TP = MathMax((1.8 + (volatility > 0.02 ? 0.2 : 0)) * volatility, BaseTP);
   TradeRisk = calculatedRisk;
   
   // Optional logging based on a frequency counter.
   const int OPTIMIZATION_FREQUENCY = 10;
   if (++tradesSinceLastOptimization >= OPTIMIZATION_FREQUENCY) {
      tradesSinceLastOptimization = 0;
      Log(StringFormat("Optimized: SL=%.2f, TP=%.2f, RiskLevel=%.2f%%, Volatility=%.4f, Drawdown=%.2f%%",
                        SL, TP, TradeRisk * 100, volatility, drawdown * 100), LOG_INFO);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Multi-timeframe ATR calculation to assess volatility             |
//+------------------------------------------------------------------+
double CalculateMultiTimeframeATR(int atrPeriod = 14, int updateInterval = 60) {
   const double FALLBACK_VALUE = 0.0001;
   
   // Update timestamp if the interval has passed.
   if (TimeCurrent() - lastUpdateTime > updateInterval)
      lastUpdateTime = TimeCurrent();
   
   double atrH1 = iATR(Symbol(), PERIOD_H1, atrPeriod, 0);
   double atrM5 = iATR(Symbol(), PERIOD_M5, atrPeriod, 0);
   double atrD1 = iATR(Symbol(), PERIOD_D1, atrPeriod, 0);
   
   // Use fallback value for any invalid ATR readings.
   if (atrH1 <= 0) atrH1 = FALLBACK_VALUE;
   if (atrM5 <= 0) atrM5 = FALLBACK_VALUE;
   if (atrD1 <= 0) atrD1 = FALLBACK_VALUE;
   
   // Return the simple average of ATR values.
   return (atrH1 + atrM5 + atrD1) / 3.0;
}

//+------------------------------------------------------------------+
//| Calculate actual drawdown based on account equity                |
//+------------------------------------------------------------------+
double CalculateDrawdown() {
   double equity = AccountEquity();
   if (equity < 0)
      return 1.0;
      
   // Use a uniquely named static variable to store the peak equity.
   static double s_peakEquity = equity;
   if (equity > s_peakEquity)
      s_peakEquity = equity;
      
   return (s_peakEquity > 1e-10) ? ((s_peakEquity - equity) / s_peakEquity) : 0;
}

//------------------------------------------------------------------
// Reassess strategy parameters based on optimization interval and failure count
//------------------------------------------------------------------
bool ReassessParameters(int optimizationInterval = 10) {
   static int consecutiveFailures = 0;
   // Constrain the optimization interval between 5 and 1000 trades.
   optimizationInterval = MathMax(5, MathMin(optimizationInterval, 1000));
   tradesSinceLastOptimization++;  // global counter for trades since last optimization

   if (tradesSinceLastOptimization < optimizationInterval)
      return false;

   if (consecutiveFailures >= 3) {
      Log("Skipping optimization due to repeated failures.", LOG_WARNING);
      tradesSinceLastOptimization = 0;
      return false;
   }

   // Attempt optimization using machine learning.
   if (!OptimizeStrategyParametersUsingML()) {
      consecutiveFailures++;
      Log(StringFormat("Optimization failed. Consecutive failures: %d", consecutiveFailures), LOG_ERROR);
      return false;
   }

   // Reset counters and adjust SL/TP based on new parameters.
   tradesSinceLastOptimization = 0;
   consecutiveFailures = 0;
   double atrValue = CalculateMultiTimeframeATR(); // Use current volatility as basis for adjustment
   AdjustSLTP(true, 0, atrValue);
   Log("Parameters optimized successfully.", LOG_INFO);
   return true;
}

//+------------------------------------------------------------------+
//| Convert TradingStrategy enum to string                           |
//+------------------------------------------------------------------+
string StrategyToString(TradingStrategy strategy){
   switch(strategy)   {
      case TrendFollowing: return "TrendFollowing";
      case Scalping:       return "Scalping";
      case RangeBound:     return "RangeBound";
      case Hybrid:         return "Hybrid";
      case CounterTrend:   return "CounterTrend";
      case Grid:           return "Grid";
      case MeanReversion:  return "MeanReversion";
      case Breakout:       return "Breakout";
      case Momentum:       return "Momentum";
      case OtherStrategy:  return "OtherStrategy";
      case SafeMode:       return "SafeMode";
      default:           return "Unknown TradingStrategy (" + IntegerToString(strategy) + ")";
   }
}

//------------------------------------------------------------------
// Genetic Algorithm Optimization routine
//------------------------------------------------------------------
bool GeneticAlgorithmOptimization(int logFrequency = 5) {
   const int populationSize = 20, generations = 50, topPerformers = populationSize / 2;
   double gridDistances[], riskPercentages[], fitnessScores[];
   ArrayResize(gridDistances, populationSize);
   ArrayResize(riskPercentages, populationSize);
   ArrayResize(fitnessScores, populationSize);

   ToggleVerboseLogging(false);

   if (!InitializePopulation(gridDistances, riskPercentages, populationSize)) {
      Log("Error: Population initialization failed. Aborting optimization.", LOG_ERROR);
      ToggleVerboseLogging(true);
      return false;
   }

   for (int gen = 0; gen < generations; gen++) {
      if (logFrequency > 0 && (gen % logFrequency == 0 || gen == generations - 1))
         Log(StringFormat("Generation %d: Evaluating...", gen + 1), LOG_INFO);

      double averageFitness = 0.0;
      EvaluateFitness(gridDistances, riskPercentages, fitnessScores, averageFitness, populationSize, gen);

      // On first generation or if convergence has not been reached, sort and log top performers.
      if (gen == 0 || !CheckConvergence(fitnessScores))      {
         SortByFitness(gridDistances, riskPercentages, fitnessScores, topPerformers);
         LogTopPerformers(gridDistances, riskPercentages, fitnessScores, topPerformers, gen);
      }

      // Perform crossover/mutation on the whole population.
      PerformCrossoverAndMutation(gridDistances, riskPercentages, topPerformers, populationSize);

      if (CheckConvergence(fitnessScores)) {
         Log(StringFormat("Optimization converged early at generation %d.", gen + 1), LOG_INFO);
         break;
      }
   }

   int bestIndex = GetBestIndividualIndex(fitnessScores, populationSize);
   if (bestIndex < 0 || bestIndex >= populationSize) {
      Log(StringFormat("Error: Best individual index is invalid (index=%d). Optimization failed.", bestIndex), LOG_ERROR);
      Log("Debug Info: Fitness scores were: " + ArrayToString(fitnessScores), LOG_DEBUG);
      ToggleVerboseLogging(true);
      return false;
   }

   Log(StringFormat("Optimization Complete: Best GridDistance=%.2f, RiskPercentage=%.2f",
         gridDistances[bestIndex], riskPercentages[bestIndex]), LOG_INFO);

   ToggleVerboseLogging(true);
   return true;
}

//------------------------------------------------------------------
// Initialize Population
//------------------------------------------------------------------
bool InitializePopulation(double &gridDistances[], double &riskPercentages[], int populationSize) {
   if (populationSize <= 0) {
      Print("Invalid population size.");
      return false;
   }
   ArrayResize(gridDistances, populationSize);
   ArrayResize(riskPercentages, populationSize);

   static bool seeded = false;
   if (!seeded) {
      MathSrand(TimeLocal());
      seeded = true;
   }
   const double MAX_RAND = 32767.0, GRID_DISTANCE_SCALE = 10.0;
   for (int i = 0; i < populationSize; i++) {
      gridDistances[i] = (MathRand() / MAX_RAND) * GRID_DISTANCE_SCALE;
      riskPercentages[i] = MathRand() / MAX_RAND;
   }
   return true;
}

//------------------------------------------------------------------
// Check Convergence
//------------------------------------------------------------------
bool CheckConvergence(double &fitnessScores[], double threshold = 0.01, int requiredConsecutive = 3, bool reset = false) {
   if (ArraySize(fitnessScores) < 1 || fitnessScores[0] == DBL_MAX || fitnessScores[0] != fitnessScores[0]) {
      Print("Error: Invalid or empty fitnessScores array.");
      return false;
   }
   
   // Ensure safe threshold and count.
   threshold = MathMax(threshold, EPSILON);
   requiredConsecutive = MathMax(1, requiredConsecutive);
   
   static double previousBestFitness = 0.0;
   static int consecutiveCount = 0;
   
   if (reset) {
      consecutiveCount = 0;
      return false;
   }
   
   consecutiveCount = (MathAbs(previousBestFitness - fitnessScores[0]) <= threshold) ? (consecutiveCount + 1) : 0;
   previousBestFitness = fitnessScores[0];
   return (consecutiveCount >= requiredConsecutive);
}

//------------------------------------------------------------------
// Log Top Performers
//------------------------------------------------------------------
void LogTopPerformers(double &gridDistances[], double &riskPercentages[], double &fitnessScores[], int topCount, int generation) {
   const int size = ArraySize(gridDistances);
   if(size == 0 || size != ArraySize(riskPercentages) || size != ArraySize(fitnessScores)) {
      Log("Error: Input arrays are empty or mismatched.", LOG_ERROR);
      return;
   }
   if(topCount <= 0) {
      Log("Warning: topCount must be greater than zero.", LOG_WARNING);
      return;
   }
   
   const int count = MathMin(topCount, size);
   int indices[];
   ArrayResize(indices, size);
   for(int i = 0; i < size; i++) {
      indices[i] = i;
   }
   
   QuickSortIndices(indices, fitnessScores, 0, size - 1);
   
   Log(StringFormat("Generation %d: Top %d Performers:", generation + 1, count), LOG_INFO);
   for(int j = 0; j < count; j++) {
      int idx = indices[j];
      Log(StringFormat("Rank %d: GridDistance=%.2f, RiskPercentage=%.2f, FitnessScore=%.5f",
            j + 1, gridDistances[idx], riskPercentages[idx], fitnessScores[idx]), LOG_DEBUG);
   }
}

//------------------------------------------------------------------
// Optimized QuickSortIndices using an inline swap and the Lomuto partition scheme
//------------------------------------------------------------------
void QuickSortIndices(int &indices[], double &fitnessScores[], int left, int right) {
   while(left < right) {
      double pivot = fitnessScores[indices[right]];
      int i = left;
      
      // Partition: move all indices with fitness > pivot to the left.
      for (int j = left; j < right; j++) {
         if (fitnessScores[indices[j]] > pivot) {
            // Inline swap without extra function call.
            int tmp = indices[i];
            indices[i] = indices[j];
            indices[j] = tmp;
            i++;
         }
      }
      
      // Place pivot in its correct sorted position.
      int tmp2 = indices[i];
      indices[i] = indices[right];
      indices[right] = tmp2;
      
      // Tail recursion optimization: process smaller partition recursively.
      if(i - left < right - i) {
         QuickSortIndices(indices, fitnessScores, left, i - 1);
         left = i + 1;
      } else {
         QuickSortIndices(indices, fitnessScores, i + 1, right);
         right = i - 1;
      }
   }
}

//------------------------------------------------------------------
// Evaluate Fitness: Uses updated Backtest (with output profit) to assign fitness scores.
//------------------------------------------------------------------
bool EvaluateFitness(const double &gridDistances[], const double &riskPercentages[], double &fitnessScores[], double &averageFitness, int populationSize, int generation){
   if (populationSize <= 0 ||
       ArraySize(gridDistances) < populationSize ||
       ArraySize(riskPercentages) < populationSize ||
       ArraySize(fitnessScores) < populationSize)   {
      Log("EvaluateFitness error: Invalid input parameters or insufficient array sizes.", LOG_ERROR);
      return false;
   }
   
   Log(StringFormat("Gen %d: Evaluating fitness...", generation + 1), LOG_INFO);
   averageFitness = 0.0;
   
   double profit = 0.0;
   for (int i = 0; i < populationSize; i++)   {
      // If backtest returns false, profit is assumed 0.0.
      if(Backtest(gridDistances[i], riskPercentages[i], profit))
         fitnessScores[i] = MathMax(profit, 0.0);
      else
         fitnessScores[i] = 0.0;
         
      averageFitness += fitnessScores[i];
      
      #ifdef DEBUG_MODE
         Log(StringFormat("Gen %d, Individual %d: Fitness=%.5f", generation + 1, i, fitnessScores[i]), LOG_DEBUG);
      #endif
   }
   
   averageFitness /= populationSize;
   Log(StringFormat("Gen %d: Average Fitness=%.5f", generation + 1, averageFitness), LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Get Best Individual Index
//------------------------------------------------------------------
int GetBestIndividualIndex(const double &fitnessScores[], int populationSize) {
   int n = ArraySize(fitnessScores);
   if (populationSize <= 0 || n < populationSize)
      return -1;
      
   const double eps = 1e-9;
   double best = fitnessScores[0];
   int bestIndex = 0, tieCount = 1;
   
   for (int i = 1; i < populationSize; i++) {
      double tol = MathMax(MathAbs(best), 1.0) * eps;
      if (fitnessScores[i] > best + tol) {
         best = fitnessScores[i];
         bestIndex = i;
         tieCount = 1;
      } else if (MathAbs(fitnessScores[i] - best) <= tol) {
         tieCount++;
         if ((double)MathRand() / 32768.0 < 1.0 / tieCount)
            bestIndex = i;
      }
   }
   return bestIndex;
}

//------------------------------------------------------------------
// Perform Crossover and Mutation
//------------------------------------------------------------------
void PerformCrossoverAndMutation(double &gridDistances[], double &riskPercentages[], int topCount, int index) {
   if (topCount < 2 || index < 0 || index >= ArraySize(gridDistances) || index >= ArraySize(riskPercentages))
      return;

   const double GRID_MIN = 0.01, GRID_MAX = 10.0;
   const double RISK_MIN = 0.1, RISK_MAX = 10.0;
   #define RAND_DOUBLE ((double)MathRand() / 32768.0)
   
   int parent1 = (int)(RAND_DOUBLE * topCount), parent2;
   while ((parent2 = (int)(RAND_DOUBLE * topCount)) == parent1);
   
   gridDistances[index] = (gridDistances[parent1] + gridDistances[parent2]) / 2.0;
   riskPercentages[index] = (riskPercentages[parent1] + riskPercentages[parent2]) / 2.0;
   
   if (RAND_DOUBLE < 0.1)
      gridDistances[index] = MathMax(GRID_MIN, MathMin(GRID_MAX, gridDistances[index] + (RAND_DOUBLE - 0.5) * 0.1));
   if (RAND_DOUBLE < 0.1)
      riskPercentages[index] = MathMax(RISK_MIN, MathMin(RISK_MAX, riskPercentages[index] + (RAND_DOUBLE - 0.5) * 0.5));
}

//------------------------------------------------------------------
// Backtest: Computes profit based on gridDistance and riskPercentage.
// Returns false if input is invalid or simulation fails.
//------------------------------------------------------------------
bool Backtest(const double gridDistance, const double riskPercentage, double &profit) {
   if(gridDistance <= 0) {
      Log(StringFormat("Invalid gridDistance: %.2f (must be > 0)", gridDistance), LOG_ERROR);
      profit = 0.0;
      return false;
   }
   
   if(riskPercentage <= 0 || riskPercentage > 1.0) {
      Log(StringFormat("Invalid riskPercentage: %.2f (must be > 0 and <= 1.0)", riskPercentage), LOG_ERROR);
      profit = 0.0;
      return false;
   }
   
   profit = SimulateTrading(gridDistance, riskPercentage);
   if(!IsValidProfit(profit)) {
      Log("Backtest error: Simulation returned an invalid profit value.", LOG_ERROR);
      profit = 0.0;
      return false;
   }
   
   Log(StringFormat("Backtest: GridDistance=%.2f, RiskPercentage=%.2f, Profit=%.2f", 
                     gridDistance, riskPercentage, profit), LOG_INFO);
   return true;
}

//------------------------------------------------------------------
// Overloaded Backtest for compatibility.
//------------------------------------------------------------------
double Backtest(const double gridDistance, const double riskPercentage) {
   double profit = 0.0;
   return Backtest(gridDistance, riskPercentage, profit) ? profit : 0.0;
}

//------------------------------------------------------------------
// IsValidProfit: Validates profit values.
//------------------------------------------------------------------
bool IsValidProfit(const double value) {
   const double MAX_PROFIT_THRESHOLD = 1e+10;
   // Checks for NaN, infinity, or excessive magnitude.
   return (value == value) && (!IsInfinite(value)) && (MathAbs(value) <= MAX_PROFIT_THRESHOLD);
}

//------------------------------------------------------------------
// Sort by Fitness and Retain Top Performers
//------------------------------------------------------------------
void SortByFitness(double &gridDistances[], double &riskPercentages[], double &fitnessScores[], int topCount) {
   int n = ArraySize(fitnessScores);
   if(n == 0 || ArraySize(gridDistances) != n || ArraySize(riskPercentages) != n || topCount <= 0 || topCount > n) {
      Log(StringFormat("Error: Invalid input parameters (topCount=%d, population=%d).", topCount, n), LOG_ERROR);
      return;
   }
   
   QuickSortTopN(fitnessScores, gridDistances, riskPercentages, 0, n - 1, topCount);
   ArrayResize(fitnessScores, topCount);
   ArrayResize(gridDistances, topCount);
   ArrayResize(riskPercentages, topCount);
}

//------------------------------------------------------------------
// QuickSortTopN: Partially sorts arrays based on fitnessScores (descending)
// to retain the top performers only.
//------------------------------------------------------------------
void QuickSortTopN(double &fitnessScores[], double &gridDistances[], double &riskPercentages[], int low, int high, int topCount) {
   if(low >= high || topCount <= 0)
      return;
      
   int n = high - low + 1;
   // For very small subarrays or when the entire segment is needed, use insertion sort.
   if(n < 10 || topCount >= n) {
      InsertionSort(fitnessScores, gridDistances, riskPercentages, low, high);
      return;
   }
   
   int pivotIndex = Partition(fitnessScores, gridDistances, riskPercentages, low, high);
   int k = pivotIndex - low + 1; // Pivot's 1-based rank in the subarray.
   
   if(k == topCount) {
      InsertionSort(fitnessScores, gridDistances, riskPercentages, low, pivotIndex);
   }
   else if(k > topCount) {
      QuickSortTopN(fitnessScores, gridDistances, riskPercentages, low, pivotIndex - 1, topCount);
   }
   else {
      InsertionSort(fitnessScores, gridDistances, riskPercentages, low, pivotIndex);
      QuickSortTopN(fitnessScores, gridDistances, riskPercentages, pivotIndex + 1, high, topCount - k);
   }
}

//------------------------------------------------------------------
// MedianOfThree: Returns the index of the median (2nd largest) among
// three elements in fitnessScores, based on descending order.
//------------------------------------------------------------------
int MedianOfThree(const double &fitnessScores[], int a, int b, int c) {
   if ((fitnessScores[a] >= fitnessScores[b] && fitnessScores[a] <= fitnessScores[c]) ||
       (fitnessScores[a] <= fitnessScores[b] && fitnessScores[a] >= fitnessScores[c]))
      return a;
   if ((fitnessScores[b] >= fitnessScores[a] && fitnessScores[b] <= fitnessScores[c]) ||
       (fitnessScores[b] <= fitnessScores[a] && fitnessScores[b] >= fitnessScores[c]))
      return b;
   return c;
}

//------------------------------------------------------------------
// InsertionSort: Sorts the subarray [low..high] in descending order
// based on fitnessScores, carrying along gridDistances and riskPercentages.
//------------------------------------------------------------------
void InsertionSort(double &fitnessScores[], double &gridDistances[], double &riskPercentages[], int low, int high) {
   int size = ArraySize(fitnessScores);
   if(size == 0 || low < 0 || high >= size || low >= high ||
      size != ArraySize(gridDistances) || size != ArraySize(riskPercentages))
      return;
      
   for(int i = low + 1; i <= high; i++) {
      double keyScore   = fitnessScores[i],
             keyGrid    = gridDistances[i],
             keyRisk    = riskPercentages[i];
      int j = i - 1;
      // For descending order, shift elements smaller than keyScore to the right.
      while(j >= low && fitnessScores[j] < keyScore) {
         fitnessScores[j+1]   = fitnessScores[j];
         gridDistances[j+1]   = gridDistances[j];
         riskPercentages[j+1] = riskPercentages[j];
         j--;
      }
      fitnessScores[j+1]   = keyScore;
      gridDistances[j+1]   = keyGrid;
      riskPercentages[j+1] = keyRisk;
   }
}

//------------------------------------------------------------------
// Partition: Rearranges the subarray [low..high] around a pivot chosen
// using median-of-three and returns the final pivot index.
//------------------------------------------------------------------
int Partition(double &fitnessScores[], double &gridDistances[], double &riskPercentages[], int low, int high) {
   int mid = low + ((high - low) / 2);
   int medianIndex = MedianOfThree(fitnessScores, low, mid, high);
   
   // Move the median to the end to serve as the pivot.
   SwapTriples(fitnessScores[medianIndex], fitnessScores[high],
               gridDistances[medianIndex], gridDistances[high],
               riskPercentages[medianIndex], riskPercentages[high]);
               
   double pivot = fitnessScores[high];
   int i = low - 1;
   
   // Partitioning: for descending order, move elements greater than the pivot to the left.
   for (int j = low; j < high; j++) {
      if (fitnessScores[j] > pivot) {
         i++;
         SwapTriples(fitnessScores[i], fitnessScores[j],
                     gridDistances[i], gridDistances[j],
                     riskPercentages[i], riskPercentages[j]);
      }
   }
   
   // Place the pivot in its correct sorted position.
   SwapTriples(fitnessScores[i+1], fitnessScores[high],
               gridDistances[i+1], gridDistances[high],
               riskPercentages[i+1], riskPercentages[high]);
   return i + 1;
}

//------------------------------------------------------------------
// SwapTriples: Swaps corresponding elements in all three arrays.
//------------------------------------------------------------------
void SwapTriples(double &score1, double &score2, double &grid1,  double &grid2, double &risk1,  double &risk2) {
   double temp = score1;
   score1 = score2;
   score2 = temp;
   
   temp = grid1;
   grid1 = grid2;
   grid2 = temp;
   
   temp = risk1;
   risk1 = risk2;
   risk2 = temp;
}

//------------------------------------------------------------------
// Monte Carlo simulation routine
//------------------------------------------------------------------
int MonteCarloSimulation() {
   const int simulations = 1000;
   double totalProfit = 0.0;
   int failedSimulations = 0;
   static bool seeded = false;
   
   if(!seeded) {
      MathSrand(TimeLocal());
      seeded = true;
   }
   
   const double factor = 1.0 / 32768.0;
   for(int i = 0; i < simulations; i++) {
      double risk = 0.5 + MathRand() * factor * 4.5;
      double grid = 0.5 + MathRand() * factor * 1.5;
      double profit = SimulateTrading(grid, risk);
      if(profit == EMPTY_VALUE)
         failedSimulations++;
      else
         totalProfit += profit;
   }
   
   int validSimulations = simulations - failedSimulations;
   if(validSimulations == 0) {
      Log("MonteCarloSimulation: All simulations failed!", LOG_ERROR);
      return -1;
   }
   
   double avgProfit = totalProfit / validSimulations;
   double failRate = (double)failedSimulations / simulations * 100.0;
   string warning = (failRate > 50.0) ? " [WARNING: High Fail Rate]" : "";
   Log(StringFormat("Monte Carlo Avg Profit: %.2f (Valid: %d, Failed: %d, FailRate: %.2f%%)%s",
         avgProfit, validSimulations, failedSimulations, failRate, warning),
         (failRate > 50.0) ? LOG_WARNING : LOG_INFO);
         
   return SIMULATION_OK;
}

//------------------------------------------------------------------
// SimulateTrading: Generates a simulated profit value using a basic model.
//------------------------------------------------------------------
double SimulateTrading(double gridDistance, double riskPercentage) {
   if (gridDistance <= 0 || riskPercentage <= 0 || riskPercentage > 1.0)
      return 0.0;
   
   const double BASE_RETURN       = 10.0;   // Base return before adjustments.
   const double GRID_PENALTY      = 50.0;   // Penalty per unit of grid distance.
   const double VOLATILITY_STDDEV = 50.0;   // Standard deviation for market volatility.
   
   double randomFluctuation = RandomNormal(0.0, VOLATILITY_STDDEV);
   double rawReturn = BASE_RETURN + randomFluctuation - (gridDistance * GRID_PENALTY);
   return riskPercentage * rawReturn;
}

//------------------------------------------------------------------
// RandomNormal: Generates a normally distributed random number using
// the Box–Muller transform with caching for efficiency.
//------------------------------------------------------------------
double RandomNormal(double mean, double stddev) {
   if (stddev == 0.0)
      return mean;
      
   // Cache for the second generated random number.
   static bool haveSpare = false;
   static double spare;
   
   if (haveSpare) {
      haveSpare = false;
      return mean + stddev * spare;
   }
   
   double u1, u2;
   do {
      u1 = (MathRand() + 1.0) / 32769.0; // u1 is never zero.
      u2 = (MathRand() + 1.0) / 32769.0;
   } while (u1 < 1e-10);
   
   double mag = sqrt(-2.0 * log(u1));
   double z0 = mag * cos(6.28318530718 * u2); // 2*PI constant.
   double z1 = mag * sin(6.28318530718 * u2);
   
   spare = z1;
   haveSpare = true;
   return mean + stddev * z0;
}

//------------------------------------------------------------------
// Calculates a weighted score for a strategy
//------------------------------------------------------------------
double CalculateStrategyScore(int strategyIndex) {
   int totalStrategies = ArraySize(tradePerformance);
   if (strategyIndex < 0 || strategyIndex >= totalStrategies)
      return -1.0;
      
   TradePerformance s = tradePerformance[strategyIndex];
   if (s.tradeCount < 10)
      return -1.0;
      
   // NaN check using the property that NaN != NaN
   if (s.sharpeRatio != s.sharpeRatio || s.winRate != s.winRate ||
       s.grossProfit != s.grossProfit || s.grossLoss != s.grossLoss)
      return -1.0;
      
   double sharpe = MathMax(0.0, s.sharpeRatio);
   double winRate = (s.winRate < 0 ? 0 : (s.winRate > 1 ? 1 : s.winRate));
   double profitFactor = (s.grossLoss > 1e-6) 
                           ? s.grossProfit / s.grossLoss 
                           : (s.grossProfit > 0 ? 3.0 : 0);
   profitFactor = MathMax(0.0, MathMin(profitFactor, 5.0));
   
   // Weighted score: 50% Sharpe, 30% win rate, 20% profit factor
   return sharpe * 0.5 + winRate * 0.3 + profitFactor * 0.2;
}

double Clamp(double value, double minValue, double maxValue) {
    return MathMax(minValue, MathMin(value, maxValue));
}

//------------------------------------------------------------------
// Selects the best-performing strategy based on performance score
//------------------------------------------------------------------
TradingStrategy SelectBestStrategyBasedOnPerformance() {
   double bestScore = -DBL_MAX;
   int bestIdx = -1;
   
   // Update win rates and performance statistics before scoring
   CalculateWinRates(false);
   int count = ArraySize(tradePerformance);
   for (int i = 0; i < count; i++) {
      double score = CalculateStrategyScore(i);
      if (score > bestScore) {
         bestScore = score;
         bestIdx = i;
      }
   }
   
   if (bestIdx == -1) {
      Log("No valid strategy found. Using fallback strategy.", LOG_WARNING);
      return fallbackStrategy;
   }
   return (TradingStrategy)bestIdx;
}

//+------------------------------------------------------------------+
//| Writes critical metrics to a CSV file                            |
//+------------------------------------------------------------------+
bool ExportMetricsToFile() {
   // Build a unique filename using structured time formatting to avoid invalid characters
   datetime now = TimeLocal();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   string filename = StringFormat("TradingMetrics_%04d-%02d-%02d_%02d-%02d-%02d_%d.csv", 
                                    dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec, MathRand());
                                    
   int fh = FileOpen(filename, FILE_CSV | FILE_WRITE | FILE_COMMON);
   if(fh < 0) {
      PrintFormat("Error opening file '%s': %d", filename, GetLastError());
      return false;
   }
   
   // Write header row
   if(!FileWrite(fh, "Metric", "Value")) {
      PrintFormat("Error writing header to file '%s': %d", filename, GetLastError());
      FileClose(fh);
      return false;
   }
   
   const int metricCount = 5;
   string keys[5] = {"Equity", "Balance", "Free Margin", "Drawdown (%)", "Open Positions"};
   string values[5];

   values[0] = DoubleToString(AccountEquity(), 2);
   values[1] = DoubleToString(AccountBalance(), 2);
   values[2] = DoubleToString(AccountFreeMargin(), 2);
   values[3] = DoubleToString(CalculateDrawdownPercentage(), 2);
   values[4] = IntegerToString(OrdersTotal());
   
   for(int i = 0; i < metricCount; i++) {
      if(!FileWrite(fh, keys[i], values[i])) {
         PrintFormat("Error writing %s to file '%s': %d", keys[i], filename, GetLastError());
         FileClose(fh);
         return false;
      }
   }
   
   FileFlush(fh);
   FileClose(fh);
   
   PrintFormat("Metrics successfully exported to: %s", filename);
   return true;
}

//+------------------------------------------------------------------+
//| Further Simplified Deinitialization Function                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
    // Log the start of deinitialization with the reason code.
    Log("EA Deinit started. Reason: " + IntegerToString(reason), LOG_INFO);

    // Perform cleanup.
    EventKillTimer();
    ArrayFree(tradePerformance);
    ArrayFree(tradeHistory);
    ArrayFree(tradePerformanceBuffer);

    // Log completion.
    Log("EA deinit completed.", LOG_INFO);

    // Close the log file if open.
    if(logFileHandle >= 0)    {
        FileClose(logFileHandle);
        Print("Log file closed.");
        logFileHandle = -1;
    }
}
