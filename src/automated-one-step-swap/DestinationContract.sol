// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/**
 * @title DestinationContract
 * @dev RSC calls this contract to handle token swaps using Uniswap V3
 */

/// @dev Interface for Uniswap V3 SwapRouter
interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract DestinationContract {
    /// CONSTANTS

    address constant SWAP_ROUTER = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
    address public constant WETH9 = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant USDT = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;

    /// STRUCTS

    struct InputParameters {
        address tokenOut;
        uint256 amountOutMin;
        uint24 fee;
    }

    /// STATE VARIABLES

    InputParameters inputParameters;
    address private callback_sender;

    /// EVENTS

    event CallbackReceived(
        address indexed owner, address indexed spender, address indexed tokenIn, uint256 amountIn, uint256 eventTag
    );

    event UniSwapV3Swap(
        address indexed owner, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /// CONSTRUCTOR

    constructor( /* _callback_sender */ ) {
        // callback_sender = _callback_sender;
        inputParameters = InputParameters({tokenOut: USDT, amountOutMin: 0, fee: 3000});
    }

    /// MODIFIERS

    modifier onlyReactive() {
        // TODO: Verify the callback_sender address
        // if (callback_sender != address(0)) {
        //     require(msg.sender == callback_sender, 'Unauthorized');
        // }
        _;
    }

    /// EXTERNAL FUNCTIONS

    /**
     * @dev Set up remaining parameters for swap
     * @param _tokenOut The address of the token to receive
     * @param _amountOutMin The minimum amount of tokens to receive
     * @param _fee The fee tier for the swap
     */
    function setInputParameters(address _tokenOut, uint256 _amountOutMin, uint24 _fee) external {
        if (_tokenOut != address(0)) inputParameters.tokenOut = _tokenOut;
        if (_amountOutMin != 0) inputParameters.amountOutMin = _amountOutMin;
        if (_fee != 0) inputParameters.fee = _fee;
    }

    /**
     * @dev Callback function called by the Reactive contract
     * @param owner The address of the token owner
     * @param spender The address of the token spender
     * @param tokenIn The address of the input token
     * @param amountIn The amount of input tokens
     */
    function callback(address, /* sender */ address owner, address spender, address tokenIn, uint256 amountIn)
        external
        onlyReactive
    {
        emit CallbackReceived(owner, spender, tokenIn, amountIn, 42);

        IERC20 IERC20tokenIn = IERC20(tokenIn);

        IERC20tokenIn.transferFrom(owner, address(this), amountIn);
        IERC20tokenIn.approve(SWAP_ROUTER, amountIn);

        _uniSwapV3Swap(
            owner, tokenIn, inputParameters.tokenOut, amountIn, inputParameters.amountOutMin, inputParameters.fee
        );
    }

    /// PRIVATE FUNCTIONS

    /**
     * @dev Internal function to perform Uniswap V3 swap
     * @param owner The address of the token owner
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param amountIn The amount of input tokens
     * @param amountOutMin The minimum amount of output tokens
     * @param fee The fee tier for the swap
     */
    function _uniSwapV3Swap(
        address owner,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint24 fee
    ) private {
        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: owner,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin, // naively set to zero for demo purposes
            sqrtPriceLimitX96: 0 // naively set to zero for demo purposes
        });

        uint256 amountOut = ISwapRouter02(SWAP_ROUTER).exactInputSingle(params);

        emit UniSwapV3Swap(owner, tokenIn, tokenOut, amountIn, amountOut);
    }
}