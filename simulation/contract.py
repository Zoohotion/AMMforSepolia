class AMMContract:
    def __init__(self, x_init, y_init, total_fee=0.003, protocol_fee=0.0005):
        self.x = x_init  # reserveA (SYX)
        self.y = y_init  # reserveB (ZHC)
        self.total_fee = total_fee
        self.protocol_fee = protocol_fee
        
        
        self.protocol_fee_x = 0.0
        self.protocol_fee_y = 0.0
        
        self.debt_y = 0.0  
        self.k_history = [x_init * y_init]

    def get_internal_price(self):
        
        return self.y / self.x

    def get_amount_out(self, amount_in, reserve_in, reserve_out):
        
        amount_in_after_fee = amount_in * (1 - self.total_fee)
        return (amount_in_after_fee * reserve_out) / (reserve_in + amount_in_after_fee)

    def swap_x_for_y(self, dx):
        
        dy = self.get_amount_out(dx, self.x, self.y)
        
        
        p_fee = dx * self.protocol_fee
        self.protocol_fee_x += p_fee
        
        
        self.x += (dx - p_fee)
        self.y -= dy
        self.k_history.append(self.x * self.y)
        return dy

    def swap_y_for_x(self, dy):
        dx = self.get_amount_out(dy, self.y, self.x)
        
        p_fee = dy * self.protocol_fee
        self.protocol_fee_y += p_fee
        
        self.y += (dy - p_fee)
        self.x -= dx
        self.k_history.append(self.x * self.y)
        return dx
        
    def borrow_zhc(self, collateral_x, request_zhc):
        
        max_borrow = collateral_x * self.get_internal_price() * 0.5
        if request_zhc <= max_borrow and request_zhc <= self.y:
            self.y -= request_zhc
            self.debt_y += request_zhc
            self.k_history.append(self.x * self.y)
            return request_zhc
        return 0

    def repay_zhc(self, principal, interest):
        
        total_repay = principal + interest
        self.y += total_repay
        self.debt_y -= principal
        self.k_history.append(self.x * self.y)

if __name__ == "__main__":
    pass