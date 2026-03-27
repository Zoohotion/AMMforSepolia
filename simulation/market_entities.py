import numpy as np
from scipy.optimize import minimize_scalar

class LP:
    def __init__(self, initial_x, initial_y):
        self.initial_x = initial_x
        self.initial_y = initial_y

    def calculate_pnl(self, contract, final_px, final_py):
        initial_value_usd = self.initial_x * 1.0 + self.initial_y * 1.0 
        current_value_usd = (contract.x * final_px) + (contract.y * final_py)
        hold_value_usd = (self.initial_x * final_px) + (self.initial_y * final_py)
        
        unrealized_pnl = current_value_usd - initial_value_usd
        impermanent_loss = current_value_usd - hold_value_usd 
        
        return unrealized_pnl, impermanent_loss

class Trader:
    def __init__(self):
        self.trade_volume = 0

    def random_trade(self, contract):
        num_trades = np.random.poisson(5)
        for _ in range(num_trades):
            is_buying_x = np.random.rand() > 0.5
            trade_size = np.random.lognormal(mean=5, sigma=1) 
            
            if is_buying_x:
                contract.swap_y_for_x(trade_size)
            else:
                contract.swap_x_for_y(trade_size)
            self.trade_volume += trade_size

class Borrower:
    def __init__(self):
        self.collateral_syx = 0.0
        self.debt_zhc = 0.0
        self.last_borrow_day = 0
        
    def random_action(self, contract, current_day):
        action = np.random.rand()
        
        if action < 0.05 and self.debt_zhc == 0:  
            add_collat = np.random.lognormal(mean=6, sigma=1)
            self.collateral_syx += add_collat
        
            request_borrow = add_collat * contract.get_internal_price() * 0.4
            borrowed = contract.borrow_zhc(self.collateral_syx, request_borrow)
            if borrowed > 0:
                self.debt_zhc += borrowed
                self.last_borrow_day = current_day
                
        
        elif action > 0.95 and self.debt_zhc > 0:  
            days_elapsed = current_day - self.last_borrow_day
            if days_elapsed > 0:
        
                interest = self.debt_zhc * 0.05 * (days_elapsed / 365)
                contract.repay_zhc(self.debt_zhc, interest)
                
                self.debt_zhc = 0.0
                self.collateral_syx = 0.0 
                
    def force_repay_all(self, contract, current_day):
        
        if self.debt_zhc > 0:
            days_elapsed = current_day - self.last_borrow_day
            interest = self.debt_zhc * 0.05 * (days_elapsed / 365)
            contract.repay_zhc(self.debt_zhc, interest)
            self.debt_zhc = 0.0
            self.collateral_syx = 0.0

class Arbitrager:
    def __init__(self):
        self.cumulative_profit_zhc = 0.0

    def execute_arbitrage(self, contract, market_price):
        amm_price = contract.get_internal_price()
        
        if abs(amm_price - market_price) / market_price > contract.total_fee:
            if amm_price < market_price:
                def obj_func(dy):
                    
                    dy_net = dy * (1 - contract.total_fee)
                    dx = (contract.x * dy_net) / (contract.y + dy_net)
                    new_price = (contract.y + dy) / (contract.x - dx)
                    return abs(new_price - market_price)
                
                res = minimize_scalar(obj_func, bounds=(0, contract.y * 0.1), method='bounded')
                optimal_dy = res.x
                dx_received = contract.swap_y_for_x(optimal_dy)
                
                profit = (dx_received * market_price) - optimal_dy
                if profit > 0:
                    self.cumulative_profit_zhc += profit
                    
            else:
                def obj_func(dx):
                    dx_net = dx * (1 - contract.total_fee)
                    dy = (contract.y * dx_net) / (contract.x + dx_net)
                    new_price = (contract.y - dy) / (contract.x + dx)
                    return abs(new_price - market_price)
                
                res = minimize_scalar(obj_func, bounds=(0, contract.x * 0.1), method='bounded')
                optimal_dx = res.x
                dy_received = contract.swap_x_for_y(optimal_dx)
                
                profit = dy_received - (optimal_dx * market_price)
                if profit > 0:
                    self.cumulative_profit_zhc += profit

if __name__ == "__main__":
    pass