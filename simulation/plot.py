import matplotlib.pyplot as plt

def plot_price_dynamics(df):
    df_subset = df.head(100).copy()
    
    plt.figure(figsize=(14, 7))
    
    
    plt.plot(df_subset['Day'], df_subset['AMM_Price_Post_Arb'], label='Post-Arbitrageur Correction', color='blue', alpha=0.4, linewidth=5, zorder=1)
    plt.plot(df_subset['Day'], df_subset['Market_Relative_Price'], label='External Market Price', color='black', linewidth=1.5, linestyle='--', zorder=2)
    
    plt.plot(df_subset['Day'], df_subset['AMM_Price_Post_Trader'], label='Post-Trader Perturbation', color='red', alpha=0.7, linewidth=1, zorder=3)
    
    borrow_events = df_subset[df_subset['AMM_Price_Post_Borrow'] != df_subset['AMM_Price_Post_Trader']]
    
    plt.scatter(borrow_events['Day'], borrow_events['AMM_Price_Post_Borrow'], 
                label='Borrower Liquidity Shock (Discrete Event)', color='orange', s=100, marker='*', zorder=4)
    
    plt.title('AMM Price Dynamics: Trading & Borrowing Shocks vs Arbitrage Correction (First 100 Days)')
    plt.xlabel('Days')
    plt.ylabel('Relative Price (SYX/ZHC)')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.show()

def plot_lp_performance(df):
    plt.figure(figsize=(12, 6))
    plt.plot(df['Day'], df['LP_Position_USD'], label='LP Position Value (in AMM)', color='green', linewidth=2)
    plt.plot(df['Day'], df['LP_HODL_Value_USD'], label='HODL Strategy', color='orange', linestyle='--')
    plt.title('LP Portfolio Performance')
    plt.xlabel('Days')
    plt.ylabel('Total Value (USD)')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.gca().get_yaxis().set_major_formatter(plt.matplotlib.ticker.StrMethodFormatter('${x:,.0f}'))
    plt.show()

def plot_arbitrager_profit_curve(df):
    plt.figure(figsize=(12, 6))
    plt.plot(df['Day'], df['Arbitrageur_Profit_USD'], color='purple', linewidth=2)
    plt.fill_between(df['Day'], df['Arbitrageur_Profit_USD'], color='purple', alpha=0.1)
    plt.title('Arbitrager Cumulative Profit (USD)')
    plt.xlabel('Days')
    plt.ylabel('Cumulative Profit (USD)')
    plt.grid(True, alpha=0.3)
    plt.gca().get_yaxis().set_major_formatter(plt.matplotlib.ticker.StrMethodFormatter('${x:,.0f}'))
    plt.show()