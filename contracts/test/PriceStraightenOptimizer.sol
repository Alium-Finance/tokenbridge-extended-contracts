pragma solidity ^0.8.2;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IERC20.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import "./ExampleSwapToPrice.sol";

contract PriceStraightenOptimizer is Ownable, ExampleSwapToPrice {
	// @dev Constructor.
	constructor(address _factory, address _router)
		ExampleSwapToPrice(_factory, IUniswapV2Router01(_router))
	{}

	struct Rebalance {
		address tokenA;
		address tokenB;
		uint256 truePriceTokenA;
		uint256 truePriceTokenB;
		uint liquidity;
		uint deadline;
	}

	function swapToPrice(
		address tokenA,
		address tokenB,
		uint256 truePriceTokenA,
		uint256 truePriceTokenB,
		uint256 maxSpendTokenA,
		uint256 maxSpendTokenB,
		address to,
		uint256 deadline
	) public override {
		require(msg.sender == owner() || msg.sender == address(this), "NO_PERMISSION");

		super.swapToPrice(
			tokenA,
			tokenB,
			truePriceTokenA,
			truePriceTokenB,
			maxSpendTokenA,
			maxSpendTokenB,
			to,
			deadline
		);
	}

	function rebalance(
		Rebalance calldata _data
	) external onlyOwner {
		address pair = IUniswapV2Factory(factory).getPair(_data.tokenA, _data.tokenB);

		(IERC20(pair).allowance(pair, address(router)) == 0) ? _approve(pair) : ();
		(IERC20(_data.tokenA).allowance(_data.tokenA, address(router)) == 0) ? _approve(_data.tokenA) : ();
		(IERC20(_data.tokenB).allowance(_data.tokenB, address(router)) == 0) ? _approve(_data.tokenB) : ();

		(uint amountA, uint amountB) = IUniswapV2Router01(router).removeLiquidity(
			_data.tokenA,
			_data.tokenB,
			_data.liquidity,
			0,
			0,
			address(this),
			_data.deadline
		);

		swapToPrice(
			_data.tokenA,
			_data.tokenB,
			_data.truePriceTokenA,
			_data.truePriceTokenB,
			amountA,
			amountB,
			address(this),
			_data.deadline
		);

		uint256 thisBalanceA = IERC20(_data.tokenA).balanceOf(address(this));
		uint256 thisBalanceB = IERC20(_data.tokenB).balanceOf(address(this));

		IUniswapV2Router01(router).addLiquidity(
			_data.tokenA,
			_data.tokenB,
			thisBalanceA,
			thisBalanceB,
//			(thisBalanceA >= amountA)
//				? amountA
//				: thisBalanceA, //_data.amountADesired,
//			(thisBalanceB >= amountB)
//				? amountB
//				: thisBalanceB, // _data.amountBDesired,
			0, // _data.amountAMin,
			0, // _data.amountBMin,
			address(this), // _data.to,
			_data.deadline
		);
	}

	// @dev Onwer can reclaim his tokens.
	function reclaim(address _token, uint256 _amount) external onlyOwner {
		IERC20(_token).transfer(owner(), _amount);
	}

	function _approve(address _token) internal {
		IERC20(_token).approve(address(router), type(uint256).max);
	}
}
