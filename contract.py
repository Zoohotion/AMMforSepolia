# ----------------- 1. 市场环境与合约基建 -----------------

class AMMContract:
    def __init__(self, x_init, y_init, fee=0.003):
        self.x = x_init  # SYX 数量
        self.y = y_init  # ZHC 数量
        self.fee = fee
        self.k_history = [x_init * y_init]

    def get_internal_price(self):
        return self.y / self.x

    def swap_x_for_y(self, dx):
        # Trader 存入 SYX，换走 ZHC
        dx_with_fee = dx * (1 - self.fee)
        dy = (self.y * dx_with_fee) / (self.x + dx_with_fee)
        self.x += dx
        self.y -= dy
        self.k_history.append(self.x * self.y)
        return dy

    def swap_y_for_x(self, dy):
        # Trader 存入 ZHC，换走 SYX
        dy_with_fee = dy * (1 - self.fee)
        dx = (self.x * dy_with_fee) / (self.y + dy_with_fee)
        self.y += dy
        self.x -= dx
        self.k_history.append(self.x * self.y)
        return dx
    

if __name__ == "main":
    pass