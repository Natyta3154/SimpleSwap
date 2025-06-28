// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    /// @notice Returns the total token supply
    function totalSupply() external view returns (uint256);
    /// @notice Returns the token balance of an account
    function balanceOf(address account) external view returns (uint256);
    /// @notice Transfers tokens to a recipient
    function transfer(address recipient, uint256 amount) external returns (bool);
    /// @notice Returns the remaining allowance for a spender by owner
    function allowance(address owner, address spender) external view returns (uint256);
    /// @notice Approves a spender to spend tokens on behalf of caller
    function approve(address spender, uint256 amount) external returns (bool);
    /// @notice Transfers tokens on behalf of owner to recipient
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

library Math {
    /// @notice Calculates integer square root of a given number
    /// @param y The input number
    /// @return z The integer square root result
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

interface ILPToken {
    /// @notice Mints LP tokens to an address
    function mint(address to, uint256 amount) external;
    /// @notice Burns LP tokens from an address
    function burn(address from, uint256 amount) external;
    /// @notice Returns LP token balance of an account
    function balanceOf(address account) external view returns (uint256);
    /// @notice Returns total supply of LP tokens
    function totalSupply() external view returns (uint256);
}

/// @title SimpleSwap - Basic AMM for token swaps and liquidity management
contract SimpleSwap {
    using Math for uint256;

    /// @notice Address of token A in the pair
    address public immutable tokenA;
    /// @notice Address of token B in the pair
    address public immutable tokenB;
    /// @notice Contract owner address
    address public owner;

    /// @notice LP token contract managing liquidity shares
    ILPToken public lpToken;

    /// @notice Reserve of token A in the liquidity pool
    uint public reserveA;
    /// @notice Reserve of token B in the liquidity pool
    uint public reserveB;

    /// @notice Emitted when liquidity is added
    event LiquidityAdded(address indexed provider, uint amountA, uint amountB, uint liquidity);
    /// @notice Emitted when liquidity is removed
    event LiquidityRemoved(address indexed provider, uint amountA, uint amountB, uint liquidity);

    /// @notice Constructor sets the tokens and LP token contract addresses
    /// @param _tokenA Address of token A
    /// @param _tokenB Address of token B
    /// @param _lpToken Address of LP token contract
    constructor(address _tokenA, address _tokenB, address _lpToken) {
        require(_tokenA != _tokenB, "Tokens must be different");
        tokenA = _tokenA;
        tokenB = _tokenB;
        owner = msg.sender;
        lpToken = ILPToken(_lpToken);
    }

    /// @notice Adds liquidity to the pool with specified tokens and mints LP tokens
    /// @param _tokenA Address of token A (must match contract tokenA)
    /// @param _tokenB Address of token B (must match contract tokenB)
    /// @param amountADesired Desired amount of token A to add
    /// @param amountBDesired Desired amount of token B to add
    /// @param amountAMin Minimum amount of token A accepted (slippage protection)
    /// @param amountBMin Minimum amount of token B accepted (slippage protection)
    /// @param to Address receiving LP tokens
    /// @param deadline Timestamp by which transaction must be mined
    /// @return amountA Actual amount of token A added
    /// @return amountB Actual amount of token B added
    /// @return liquidity Amount of LP tokens minted to `to`
    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        require(_tokenA == tokenA && _tokenB == tokenB, "Invalid tokens");
        require(block.timestamp <= deadline, "Transaction expired");
        require(to != address(0), "Invalid recipient");

        if (reserveA == 0 && reserveB == 0) {
            // Initial liquidity provision
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            // Maintain price ratio to prevent arbitrage
            uint amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Slippage: B too low");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal >= amountAMin, "Slippage: A too low");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        // Transfer tokens from sender to contract
        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer tokenA failed");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer tokenB failed");

        // Update reserves
        reserveA += amountA;
        reserveB += amountB;

        // Mint LP tokens proportional to liquidity added
        liquidity = Math.sqrt(amountA * amountB);
        lpToken.mint(to, liquidity);

        emit LiquidityAdded(to, amountA, amountB, liquidity);
    }

    /// @notice Removes liquidity by burning LP tokens and returning proportional token amounts
    /// @param _tokenA Address of token A (must match contract tokenA)
    /// @param _tokenB Address of token B (must match contract tokenB)
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountAMin Minimum amount of token A accepted (slippage protection)
    /// @param amountBMin Minimum amount of token B accepted (slippage protection)
    /// @param to Address to send withdrawn tokens
    /// @param deadline Timestamp by which transaction must be mined
    /// @return amountA Amount of token A returned
    /// @return amountB Amount of token B returned
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
        require(_tokenA == tokenA && _tokenB == tokenB, "Invalid tokens");
        require(block.timestamp <= deadline, "Transaction expired");
        require(to != address(0), "Invalid recipient");
        require(lpToken.balanceOf(msg.sender) >= liquidity, "Not enough liquidity");

        uint totalLiq = lpToken.totalSupply();
        require(totalLiq > 0, "No liquidity");

        // Calculate proportional amounts to withdraw
        amountA = (liquidity * reserveA) / totalLiq;
        amountB = (liquidity * reserveB) / totalLiq;

        require(amountA >= amountAMin, "Slippage: A too low");
        require(amountB >= amountBMin, "Slippage: B too low");

        // Update reserves
        reserveA -= amountA;
        reserveB -= amountB;

        // Burn LP tokens from sender
        lpToken.burn(msg.sender, liquidity);

        // Transfer tokens back to user
        require(IERC20(tokenA).transfer(to, amountA), "Transfer tokenA failed");
        require(IERC20(tokenB).transfer(to, amountB), "Transfer tokenB failed");

        emit LiquidityRemoved(to, amountA, amountB, liquidity);
    }

    /// @notice Swaps an exact amount of input tokens for a minimum amount of output tokens
    /// @param amountIn Exact amount of input tokens
    /// @param amountOutMin Minimum acceptable output tokens (slippage protection)
    /// @param path Array of token addresses [input, output]
    /// @param to Recipient address for output tokens
    /// @param deadline Timestamp by which transaction must be mined
    /// @return amounts Array with input and output token amounts
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(path.length == 2, "Only direct token swaps supported");

        address input = path[0];
        address output = path[1];
        require(
            (input == tokenA && output == tokenB) || (input == tokenB && output == tokenA),
            "Invalid token path"
        );

        // Transfer input tokens to contract
        require(IERC20(input).transferFrom(msg.sender, address(this), amountIn), "TransferFrom failed");

        uint amountInWithFee = amountIn * 997; // 0.3% fee
        uint numerator;
        uint denominator;
        uint amountOut;

        if (input == tokenA) {
            numerator = amountInWithFee * reserveB;
            denominator = reserveA * 1000 + amountInWithFee;
            amountOut = numerator / denominator;
            require(amountOut >= amountOutMin, "Insufficient output");
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            numerator = amountInWithFee * reserveA;
            denominator = reserveB * 1000 + amountInWithFee;
            amountOut = numerator / denominator;
            require(amountOut >= amountOutMin, "Insufficient output");
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // Transfer output tokens to recipient
        require(IERC20(output).transfer(to, amountOut), "Transfer output failed");

        // Return swap amounts
        amounts = new uint [](1) ;
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    /// @notice Returns price of base token in terms of quote token (scaled by 1e18)
    /// @param base Token to price (numerator)
    /// @param quote Token as reference (denominator)
    /// @return price Current price scaled by 1e18
    function getPrice(address base, address quote) external view returns (uint price) {
        require(base != quote, "Tokens must differ");
        require(base != address(0) && quote != address(0), "Invalid address");

        uint rA = IERC20(base).balanceOf(address(this));
        uint rB = IERC20(quote).balanceOf(address(this));

        require(rA > 0 && rB > 0, "No liquidity");

        price = (rB * 1e18) / rA;
    }

    /// @notice Calculates expected output token amount for given input amount, factoring fees
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param amountIn Amount of input tokens
    /// @return amountOut Expected output token amount
    function getAmountOut(address tokenIn, address tokenOut, uint amountIn) external view returns (uint amountOut) {
        require(amountIn > 0, "Invalid input");
        require(
            (tokenIn == tokenA && tokenOut == tokenB) || (tokenIn == tokenB && tokenOut == tokenA),
            "Invalid tokens"
        );

        uint reserveIn = (tokenIn == tokenA) ? reserveA : reserveB;
        uint reserveOut = (tokenOut == tokenA) ? reserveA : reserveB;

        require(reserveIn > 0 && reserveOut > 0, "No liquidity");

        uint amountInWithFee = amountIn * 997;

        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    /// @notice Returns total liquidity as geometric mean of reserves
    /// @return total Total liquidity in pool
    function totalLiquidity() public view returns (uint total) {
        total = Math.sqrt(reserveA * reserveB);
    }
}
