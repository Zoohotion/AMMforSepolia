import numpy as np # type: ignore
from scipy.optimize import minimize_scalar # type:ignore
# ----------------- 2. 参与者行为逻辑 -----------------

class LP:
    def __init__(self, initial_x, initial_y):
        self.initial_x = initial_x
        self.initial_y = initial_y
        self.share = 1.0  # 假设是唯一的初始 LP，占据 100% 份额

    def calculate_pnl(self, current_x, current_y, current_market_price):
        # 期末结算：当前份额总价值 - 期初存入总价值
        initial_value = self.initial_x * 1.0 + self.initial_y * 1.0  # 初始价格为 1:1
        current_value = (current_x * current_market_price) + current_y
        unrealized_pnl = current_value - initial_value
        
        # 纯持币 (Hold) 价值用于对比计算无常损失
        hold_value = (self.initial_x * current_market_price) + self.initial_y
        impermanent_loss = current_value - hold_value 
        
        return unrealized_pnl, impermanent_loss

class Trader:
    def __init__(self):
        self.trade_volume = 0

    def random_trade(self, contract):
        # 使用泊松分布决定每天的交易次数 (平均每天 5 次)
        num_trades = np.random.poisson(5)
        for _ in range(num_trades):
            # 交易方向：50% 概率买入，50% 卖出
            is_buying_x = np.random.rand() > 0.5
            # 使用对数正态分布决定交易规模，避免数值过大抽干池子
            trade_size = np.random.lognormal(mean=5, sigma=1) 
            
            if is_buying_x:
                contract.swap_y_for_x(trade_size)
            else:
                contract.swap_x_for_y(trade_size)
            self.trade_volume += trade_size

class Arbitrager:
    def __init__(self):
        self.cumulative_profit_zhc = 0.0

    def execute_arbitrage(self, contract, market_price):
        amm_price = contract.get_internal_price()
        
        # 只有价差大于手续费摩擦时才进行套利
        if abs(amm_price - market_price) / market_price > contract.fee:
            if amm_price < market_price:
                # AMM 内部 SYX 被低估，套利者在 AMM 存入 ZHC 换取 SYX，然后去外部市场卖掉 SYX
                def obj_func(dy): # type: ignore
                    dy_net = dy * (1 - contract.fee)
                    dx = (contract.x * dy_net) / (contract.y + dy_net)
                    new_price = (contract.y + dy) / (contract.x - dx)
                    return abs(new_price - market_price)
                
                # 寻找最优注入量 dy，使 AMM 价格被推平到 market_price
                res = minimize_scalar(obj_func, bounds=(0, contract.y * 0.1), method='bounded')
                optimal_dy = res.x
                dx_received = contract.swap_y_for_x(optimal_dy)
                
                # 利润计算：在外部市场以真实价格卖出换得的 SYX，减去最初投入的 ZHC
                profit = (dx_received * market_price) - optimal_dy
                if profit > 0:
                    self.cumulative_profit_zhc += profit
                    
            else:
                # AMM 内部 SYX 被高估，套利者在外部市场买入 SYX，存入 AMM 换取 ZHC
                def obj_func(dx):
                    dx_net = dx * (1 - contract.fee)
                    dy = (contract.y * dx_net) / (contract.x + dx_net)
                    new_price = (contract.y - dy) / (contract.x + dx)
                    return abs(new_price - market_price)
                
                res = minimize_scalar(obj_func, bounds=(0, contract.x * 0.1), method='bounded')
                optimal_dx = res.x
                dy_received = contract.swap_x_for_y(optimal_dx)
                
                # 利润计算：换回的 ZHC，减去在外部市场买入 SYX 的成本
                profit = dy_received - (optimal_dx * market_price)
                if profit > 0:
                    self.cumulative_profit_zhc += profit


if __name__ == "main":
    pass