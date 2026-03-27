// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AMM {
    IERC20 public tokenA; // SYX
    IERC20 public tokenB; // ZHC

    address public owner;
    address public feeRecipient;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public totalShares;
    mapping(address => uint256) public shares;

    bool public paused;

    // Fee settings
    uint256 public constant TOTAL_FEE_BPS = 30;      // 0.30%
    uint256 public constant PROTOCOL_FEE_BPS = 5;    // 0.05%
    uint256 public constant LP_FEE_BPS = 25;         // 0.25%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // Protocol fee balances (excluded from reserves)
    uint256 public protocolFeesA;
    uint256 public protocolFeesB;

    // Lending state
    mapping(address => uint256) public collateralSYX;

    // debt principal with accrued interest rolled in whenever user interacts
    mapping(address => uint256) public debtPrincipalZHC;
    mapping(address => uint256) public lastAccruedTime;

    uint256 public constant ANNUAL_INTEREST_BPS = 500; // 5% APR
    uint256 public constant YEAR_IN_SECONDS = 365 days;

    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 shareMinted
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 shareBurned
    );

    event Swap(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        address indexed tokenOut,
        uint256 amountOut
    );

    event Paused();
    event Unpaused();

    event ProtocolFeesWithdrawn(
        address indexed recipient,
        uint256 amountA,
        uint256 amountB
    );

    event CollateralDeposited(address indexed user, uint256 amountSYX);
    event CollateralWithdrawn(address indexed user, uint256 amountSYX);
    event Borrowed(address indexed user, uint256 amountZHC);
    event Repaid(address indexed user, uint256 amountZHC);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "swap paused");
        _;
    }

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0), "invalid tokenA");
        require(_tokenB != address(0), "invalid tokenB");
        require(_tokenA != _tokenB, "same token");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);

        owner = msg.sender;
        feeRecipient = msg.sender;
    }

    // ---------- admin ----------

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "invalid recipient");
        feeRecipient = _feeRecipient;
    }

    function pauseSwap() external onlyOwner {
        paused = true;
        emit Paused();
    }

    function unpauseSwap() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    function withdrawProtocolFees() external onlyOwner {
        uint256 amountA = protocolFeesA;
        uint256 amountB = protocolFeesB;

        require(amountA > 0 || amountB > 0, "no fees");

        protocolFeesA = 0;
        protocolFeesB = 0;

        if (amountA > 0) {
            require(tokenA.transfer(feeRecipient, amountA), "fee A transfer failed");
        }
        if (amountB > 0) {
            require(tokenB.transfer(feeRecipient, amountB), "fee B transfer failed");
        }

        emit ProtocolFeesWithdrawn(feeRecipient, amountA, amountB);
    }

    // ---------- helpers ----------

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getPriceSYXInZHC() public view returns (uint256) {
        require(reserveA > 0 && reserveB > 0, "empty pool");
        return (reserveB * 1e18) / reserveA;
    }

    function getPriceZHCInSYX() public view returns (uint256) {
        require(reserveA > 0 && reserveB > 0, "empty pool");
        return (reserveA * 1e18) / reserveB;
    }

    // ---------- liquidity ----------

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 share) {
        require(amountA > 0 && amountB > 0, "invalid amounts");

        require(tokenA.transferFrom(msg.sender, address(this), amountA), "tokenA transfer failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "tokenB transfer failed");

        if (totalShares == 0) {
            share = _sqrt(amountA * amountB);
        } else {
            uint256 shareA = (amountA * totalShares) / reserveA;
            uint256 shareB = (amountB * totalShares) / reserveB;
            share = _min(shareA, shareB);
        }

        require(share > 0, "share = 0");

        shares[msg.sender] += share;
        totalShares += share;

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, share);
    }

    function removeLiquidity(uint256 share) external returns (uint256 amountA, uint256 amountB) {
        require(share > 0, "share must be > 0");
        require(shares[msg.sender] >= share, "not enough shares");
        require(totalShares > 0, "no shares");

        amountA = (share * reserveA) / totalShares;
        amountB = (share * reserveB) / totalShares;

        require(amountA > 0 && amountB > 0, "amounts = 0");

        shares[msg.sender] -= share;
        totalShares -= share;

        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(msg.sender, amountA), "tokenA transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "tokenB transfer failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, share);
    }

    // ---------- swap ----------

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "amountIn = 0");
        require(reserveIn > 0 && reserveOut > 0, "bad reserves");

        uint256 amountInAfterTotalFee =
            (amountIn * (BPS_DENOMINATOR - TOTAL_FEE_BPS)) / BPS_DENOMINATOR;

        uint256 numerator = amountInAfterTotalFee * reserveOut;
        uint256 denominator = reserveIn + amountInAfterTotalFee;

        amountOut = numerator / denominator;
    }

    function swapSYXForZHC(
        uint256 amountIn,
        uint256 minAmountOut
    ) external notPaused returns (uint256 amountOut) {
        require(amountIn > 0, "amountIn = 0");

        amountOut = getAmountOut(amountIn, reserveA, reserveB);
        require(amountOut >= minAmountOut, "slippage too high");
        require(amountOut < reserveB, "insufficient liquidity");

        uint256 protocolFee = (amountIn * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 lpInput = amountIn - protocolFee;

        require(tokenA.transferFrom(msg.sender, address(this), amountIn), "tokenA transfer failed");
        require(tokenB.transfer(msg.sender, amountOut), "tokenB transfer failed");

        protocolFeesA += protocolFee;
        reserveA += lpInput;
        reserveB -= amountOut;

        emit Swap(msg.sender, address(tokenA), amountIn, address(tokenB), amountOut);
    }

    function swapZHCForSYX(
        uint256 amountIn,
        uint256 minAmountOut
    ) external notPaused returns (uint256 amountOut) {
        require(amountIn > 0, "amountIn = 0");

        amountOut = getAmountOut(amountIn, reserveB, reserveA);
        require(amountOut >= minAmountOut, "slippage too high");
        require(amountOut < reserveA, "insufficient liquidity");

        uint256 protocolFee = (amountIn * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 lpInput = amountIn - protocolFee;

        require(tokenB.transferFrom(msg.sender, address(this), amountIn), "tokenB transfer failed");
        require(tokenA.transfer(msg.sender, amountOut), "tokenA transfer failed");

        protocolFeesB += protocolFee;
        reserveB += lpInput;
        reserveA -= amountOut;

        emit Swap(msg.sender, address(tokenB), amountIn, address(tokenA), amountOut);
    }

    // ---------- lending interest helpers ----------

    function getCurrentDebtZHC(address user) public view returns (uint256) {
        uint256 principal = debtPrincipalZHC[user];
        if (principal == 0) return 0;

        uint256 lastTime = lastAccruedTime[user];
        if (lastTime == 0) return principal;

        uint256 elapsed = block.timestamp - lastTime;
        uint256 interest =
            (principal * ANNUAL_INTEREST_BPS * elapsed) /
            BPS_DENOMINATOR /
            YEAR_IN_SECONDS;

        return principal + interest;
    }

    function _accrueInterest(address user) internal {
        uint256 principal = debtPrincipalZHC[user];

        if (principal == 0) {
            lastAccruedTime[user] = block.timestamp;
            return;
        }

        uint256 lastTime = lastAccruedTime[user];
        if (lastTime == 0) {
            lastAccruedTime[user] = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - lastTime;
        if (elapsed == 0) return;

        uint256 interest =
            (principal * ANNUAL_INTEREST_BPS * elapsed) /
            BPS_DENOMINATOR /
            YEAR_IN_SECONDS;

        debtPrincipalZHC[user] = principal + interest;
        lastAccruedTime[user] = block.timestamp;
    }

    // ---------- lending ----------
    // collateral = SYX
    // debt = ZHC
    // max debt = collateral value * 50%

    function depositCollateral(uint256 amountSYX) external {
        require(amountSYX > 0, "amount = 0");

        require(tokenA.transferFrom(msg.sender, address(this), amountSYX), "collateral transfer failed");
        collateralSYX[msg.sender] += amountSYX;

        emit CollateralDeposited(msg.sender, amountSYX);
    }

    function getBorrowLimitZHC(address user) public view returns (uint256) {
        if (collateralSYX[user] == 0) return 0;

        uint256 priceSYXInZHC = getPriceSYXInZHC();
        uint256 collateralValueInZHC = (collateralSYX[user] * priceSYXInZHC) / 1e18;

        return collateralValueInZHC / 2; // 50% LTV
    }

    function getAvailableToBorrowZHC(address user) external view returns (uint256) {
        uint256 limit = getBorrowLimitZHC(user);
        uint256 currentDebt = getCurrentDebtZHC(user);

        if (limit <= currentDebt) {
            return 0;
        }
        return limit - currentDebt;
    }

    function borrowZHC(uint256 amountZHC) external {
        require(amountZHC > 0, "amount = 0");
        require(reserveB >= amountZHC, "not enough pool liquidity");

        _accrueInterest(msg.sender);

        uint256 newDebt = debtPrincipalZHC[msg.sender] + amountZHC;
        require(newDebt <= getBorrowLimitZHC(msg.sender), "borrow exceeds 50% LTV");

        debtPrincipalZHC[msg.sender] = newDebt;
        lastAccruedTime[msg.sender] = block.timestamp;

        reserveB -= amountZHC;
        require(tokenB.transfer(msg.sender, amountZHC), "borrow transfer failed");

        emit Borrowed(msg.sender, amountZHC);
    }

    function repayZHC(uint256 amountZHC) external {
        require(amountZHC > 0, "amount = 0");

        _accrueInterest(msg.sender);

        uint256 currentDebt = debtPrincipalZHC[msg.sender];
        require(currentDebt > 0, "no debt");

        require(tokenB.transferFrom(msg.sender, address(this), amountZHC), "repay transfer failed");

        if (amountZHC >= currentDebt) {
            reserveB += currentDebt;
            debtPrincipalZHC[msg.sender] = 0;
            lastAccruedTime[msg.sender] = 0;
            emit Repaid(msg.sender, currentDebt);
        } else {
            reserveB += amountZHC;
            debtPrincipalZHC[msg.sender] = currentDebt - amountZHC;
            lastAccruedTime[msg.sender] = block.timestamp;
            emit Repaid(msg.sender, amountZHC);
        }
    }

    function withdrawCollateral(uint256 amountSYX) external {
        require(amountSYX > 0, "amount = 0");
        require(collateralSYX[msg.sender] >= amountSYX, "not enough collateral");

        _accrueInterest(msg.sender);

        uint256 remainingCollateral = collateralSYX[msg.sender] - amountSYX;
        uint256 currentDebt = debtPrincipalZHC[msg.sender];

        if (currentDebt > 0) {
            uint256 priceSYXInZHC = getPriceSYXInZHC();
            uint256 remainingCollateralValueInZHC = (remainingCollateral * priceSYXInZHC) / 1e18;
            uint256 remainingBorrowLimit = remainingCollateralValueInZHC / 2;

            require(currentDebt <= remainingBorrowLimit, "would violate 50% LTV");
        }

        collateralSYX[msg.sender] = remainingCollateral;
        require(tokenA.transfer(msg.sender, amountSYX), "withdraw collateral failed");

        emit CollateralWithdrawn(msg.sender, amountSYX);
    }

    function getUserLendingPosition(address user)
        external
        view
        returns (
            uint256 collateral,
            uint256 debt,
            uint256 borrowLimit,
            uint256 availableToBorrow
        )
    {
        collateral = collateralSYX[user];
        debt = getCurrentDebtZHC(user);
        borrowLimit = getBorrowLimitZHC(user);

        if (borrowLimit > debt) {
            availableToBorrow = borrowLimit - debt;
        } else {
            availableToBorrow = 0;
        }
    }
}