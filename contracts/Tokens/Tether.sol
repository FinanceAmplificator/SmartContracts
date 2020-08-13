// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Tether is ERC20 {

    constructor () public ERC20("Tether", "USDT") {
        _setupDecimals(6);
        _mint(msg.sender, 6877479171538729 * (10 ** uint256(decimals())));
    }
}