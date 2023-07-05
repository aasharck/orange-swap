// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OrangeSwap {
    using SafeERC20 for IERC20;

    enum Stage {
        Inactive,
        Requested,
        Fullfilled,
        Canceled
    }

    struct Trade {
        address seller;
        address buyToken;
        uint256 buyAmount;
        address sellToken;
        uint256 sellAmount;
        uint32 deadline;
        Stage tradeStage;
    }

    mapping(uint256 => Trade) public trades;
    uint256 numberOfTrades;

    error INVALID_STAGE();
    error TRADE_EXPIRED();
    error LOW_BALANCE();
    error LOW_ALLOWANCE();
    error NOT_AUTHORIZED();

    event TradeRequested(
        address indexed requester,
        address indexed buyToken,
        uint256 buyAmount,
        address indexed sellToken,
        uint256 sellAmount
    );
    event TradeFullfilled(
        address indexed requester,
        address indexed fullfiller,
        uint256 tradeId
    );
    event TradeCanceled(address indexed requester, uint256 tradeId);

    function requestForTrade(
        address buyToken,
        uint256 buyAmount,
        address sellToken,
        uint256 sellAmount,
        uint32 deadline
    ) external {
        isApprovedAndHasBalance(msg.sender, sellToken, sellAmount);
        uint256 tradeId = ++numberOfTrades;
        Trade memory newTrade = Trade({
            seller: msg.sender,
            buyToken: buyToken,
            buyAmount: buyAmount,
            sellToken: sellToken,
            sellAmount: sellAmount,
            deadline: deadline,
            tradeStage: Stage.Requested
        });
        trades[tradeId] = newTrade;
        emit TradeRequested(
            msg.sender,
            buyToken,
            buyAmount,
            sellToken,
            sellAmount
        );
    }

    function fullfillTrade(uint256 tradeId) external {
        Trade storage trade = trades[tradeId];
        isApprovedAndHasBalance(
            trade.seller,
            trade.sellToken,
            trade.sellAmount
        );
        if (block.timestamp >= trade.deadline) revert TRADE_EXPIRED();
        if (trade.tradeStage != Stage.Requested) revert INVALID_STAGE();
        IERC20(trade.buyToken).safeTransferFrom(
            msg.sender,
            trade.seller,
            trade.buyAmount
        );
        IERC20(trade.sellToken).safeTransferFrom(
            trade.seller,
            msg.sender,
            trade.sellAmount
        );
        trade.tradeStage = Stage.Fullfilled;
        emit TradeFullfilled(trade.seller, msg.sender, tradeId);
    }

    function cancelTrade(uint256 tradeId) external {
        Trade storage trade = trades[tradeId];
        if (trade.seller != msg.sender) revert NOT_AUTHORIZED();
        if (trade.tradeStage != Stage.Requested) revert INVALID_STAGE();
        trade.tradeStage = Stage.Canceled;
        emit TradeCanceled(msg.sender, tradeId);
    }

    // VIEW FUNCTIONS

    function isApprovedAndHasBalance(
        address seller,
        address token,
        uint256 amount
    ) private view {
        if (IERC20(token).allowance(seller, address(this)) < amount)
            revert LOW_ALLOWANCE();
        if (IERC20(token).balanceOf(seller) < amount) revert LOW_BALANCE();
    }

    function getAllActiveTrades() external view returns (Trade[] memory) {
        uint256 limit = numberOfTrades;
        Trade[] memory allTrades = new Trade[](limit);
        uint256 j;
        for (uint i = 1; i <= limit; ) {
            if (
                trades[i].deadline <= block.timestamp &&
                trades[i].tradeStage != Stage.Canceled
            ) {
                allTrades[j] = trades[i];
                unchecked {
                    j++;
                }
            }
            unchecked {
                i++;
            }
        }
        return allTrades;
    }
}
