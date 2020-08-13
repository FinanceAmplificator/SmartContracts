// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../ERC20/MXXERC20.sol";

contract Multiplier is MXXERC20 {

    constructor () public MXXERC20("Multiplier", "MXX") {
        _setupDecimals(8);
        _mint(msg.sender, 9000000000 * (10 ** uint256(decimals())));
    }
}