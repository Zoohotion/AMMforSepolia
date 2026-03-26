import numpy as np # type: ignore

class Market:
    def __init__(self, initial_px=1.0, initial_py=1.0, mu_x=0.05, mu_y=0.05, 
                 sigma_x=0.2, sigma_y=0.2, rho=0.5, days=1000):
        self.mu_x = mu_x
        self.mu_y = mu_y
        self.sigma_x = sigma_x
        self.sigma_y = sigma_y
        self.rho = rho
        self.days = days
        self.dt = 1 / 365
        self.prices_x, self.prices_y = self._generate_correlated_gbm(initial_px, initial_py)

    def _generate_correlated_gbm(self, px_0, py_0):
        prices_x = [px_0]
        prices_y = [py_0]
        
        # 相关系数矩阵 (数值上等同于标准正态变量的协方差矩阵)
        corr_matrix = [[1.0, self.rho], 
                       [self.rho, 1.0]]
        
        for _ in range(1, self.days):
            # 生成两个相关的标准正态随机变量
            Z = np.random.multivariate_normal([0, 0], corr_matrix)
            dW_x = Z[0] * np.sqrt(self.dt)
            dW_y = Z[1] * np.sqrt(self.dt)
            
            # 分别计算两个资产的价格路径
            dp_x = prices_x[-1] * (self.mu_x * self.dt + self.sigma_x * dW_x)
            dp_y = prices_y[-1] * (self.mu_y * self.dt + self.sigma_y * dW_y)
            
            prices_x.append(prices_x[-1] + dp_x)
            prices_y.append(prices_y[-1] + dp_y)
            
        return prices_x, prices_y

    def get_price(self, day):
        # 核心：对外输出 SYX 相对于 ZHC 的相对市场价格，保证其他类的逻辑完全兼容
        return self.prices_x[day] / self.prices_y[day]
        
    def get_absolute_prices(self, day):
        # 预留接口，如果你的 Excel 报告需要记录它们的独立价格
        return self.prices_x[day], self.prices_y[day]

if __name__ == "main":
    pass